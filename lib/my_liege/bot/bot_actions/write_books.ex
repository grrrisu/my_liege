defmodule MyLiege.Bot.BotActions.WriteBooks do
  @moduledoc """
  The designer's rule: writes one book of each colour in `colours`, from `from_week` on.

  Options: `colours:` (a list of colours, `[]` = no books) and `from_week:`.

  1. Once the game stands at `from_week` or later (`game.week >= from_week`), for each
     listed colour with no book held (`game.books`) and none in progress, it starts a book of
     that colour (`Game.start_book/2`, in `before_pass/2`). Once every listed colour has a
     book it starts nothing.
  2. Each book in progress without a writer gets one, in this order:
     a. an unplaced, arrived blue worker;
     b. else a worker taken from a monastery (arrived, not travelling): blue ones first, then
        any colour, in worker order (`after_pass/2`);
     c. else any unplaced, arrived worker.
     One writer per book. Only workers the earlier actions of the pass leave alone count
     (`Placing.left_over?/3`): a non-blue unplaced worker gets a book only while there are
     more books without a writer than left-over unplaced blue workers and monastery workers.

  A placing action (`MyLiege.Bot.Placing`), with a `{:place, book_id}` target. Books have no
  effect in the game yet (R12).
  """

  @behaviour MyLiege.Bot.BotAction
  @behaviour MyLiege.Bot.Placing

  alias MyLiege.Bot.Placing
  alias MyLiege.Engine.{Game, Place}
  alias MyLiege.Engine.Place.{Building, Project}

  @impl MyLiege.Bot.BotAction
  def run(%Game{} = game, opts),
    do: Placing.run(game, Keyword.put(opts, :rules, [{__MODULE__, opts}]))

  @impl MyLiege.Bot.Placing
  def before_pass(%Game{} = game, opts) do
    if game.week >= Keyword.fetch!(opts, :from_week) do
      opts
      |> Keyword.fetch!(:colours)
      |> Enum.reject(&(Map.fetch!(game.books, &1) > 0 or in_progress?(game, &1)))
      |> Enum.reduce(game, fn colour, game -> game |> Game.start_book(colour) |> elem(1) end)
    else
      game
    end
  end

  @impl MyLiege.Bot.Placing
  def target(worker, game, opts) do
    case without_writer(game) do
      [] -> nil
      [book | _] = books -> if takes_book?(worker, books, game, opts), do: {:place, book.id}
    end
  end

  @impl MyLiege.Bot.Placing
  def after_pass(%Game{} = game, _opts) do
    game
    |> without_writer()
    |> Enum.reduce(game, fn book, game ->
      case monastery_workers(game) do
        [] -> game
        [worker | _] -> game |> Game.place_worker(worker.id, book.id) |> ok_or(game)
      end
    end)
  end

  # a blue worker takes a free book; another one only if blue and monastery workers can't
  # fill them all
  defp takes_book?(%{colour: :blue}, _books, _game, _opts), do: true

  defp takes_book?(_worker, books, game, opts) do
    blue =
      game
      |> Placing.available()
      |> Enum.count(&(&1.colour == :blue and Placing.left_over?(&1, game, opts)))

    length(books) > blue + length(monastery_workers(game))
  end

  defp in_progress?(game, colour),
    do: Enum.any?(game.places, &match?(%Project{gives: {:book, ^colour}}, &1))

  defp without_writer(game) do
    writing = MapSet.new(game.workers, & &1.place)

    for %Project{gives: {:book, _}} = book <- game.places,
        not MapSet.member?(writing, book.id),
        do: book
  end

  # arrived workers in a monastery, blue ones first, each group in worker order
  defp monastery_workers(game) do
    monasteries =
      for %Building{} = b <- game.places,
          Place.type(b) == :monastery,
          into: MapSet.new(),
          do: b.id

    game.workers
    |> Enum.filter(&(MapSet.member?(monasteries, &1.place) and &1.travel == 0))
    |> Enum.sort_by(&(&1.colour != :blue))
  end

  defp ok_or({:ok, game}, _game), do: game
  defp ok_or({:error, _reason}, game), do: game
end
