defmodule MyLiege.Engine.Rules.Books do
  @moduledoc """
  R12, books: the player may start writing a book of any colour at any time, at no cost, and
  several at once. A book is a `Place.Project` that takes one worker of any colour and needs
  `book_work` knowledge, whatever its colour. The worker writes as he would produce in a blue
  building (see `Rules.Production`), times the experience factor of the book's colour: its
  Manameter share ÷ 200 (normal at 20%, linear, no floor, no cap), from the Manameter at the
  start of the week, rounded down per worker. What he writes goes into the book, up to its
  target; the rest is lost. Mana as in a blue building. Once done (at the end of the week),
  the book is held by the village (`game.books`, colour => count), the project disappears and
  its worker is released, travelling. Books have no effect yet.
  """

  alias MyLiege.Engine.{Config, Fixed, Manameter, Pentagon, Place}
  alias MyLiege.Engine.Place.Project
  alias MyLiege.Engine.Rules.Placement

  # the Manameter share (per mille) at which a book is written at the normal rate
  @normal_share 200
  @colours Pentagon.colours()

  @doc "Whether `colour` is a colour a book can be written in."
  def colour?(colour), do: colour in @colours

  @doc "No books: every colour at 0, in pentagon order."
  def none, do: Map.new(@colours, &{&1, 0})

  @doc """
  Appends a new book of `colour` to `places`, with the next free id and `book_work` knowledge
  as target. The caller checks the colour (`colour?/1`); any other colour raises.
  """
  def new_book(places, colour, %Config{} = config) when colour in @colours do
    book = %Project{
      id: Place.next_id(places),
      blueprint: Project.book_blueprint(),
      target: Fixed.from(config.book_work),
      gives: {:book, colour}
    }

    places ++ [book]
  end

  @doc "The experience factor of `colour`, in per mille: its Manameter share × 1000 ÷ 200."
  def experience(%Manameter{} = manameter, colour),
    do: div(Map.fetch!(manameter, colour) * 1000, @normal_share)

  @doc """
  Scales a worker's `output` (thousandths) on a book of `colour` by the experience factor,
  rounded down.
  """
  def written(output, %Manameter{} = manameter, colour),
    do: div(output * Map.fetch!(manameter, colour), @normal_share)

  @doc """
  For every finished book: adds one book of its colour to `books`, removes the project and
  releases its worker. Returns `{places, workers, books, finished_colours}`.
  """
  def finish(places, workers, books, %Config{} = config) do
    finished = for %Project{gives: {:book, _}} = book <- places, Project.done?(book), do: book
    finished_ids = MapSet.new(finished, & &1.id)

    places = Enum.reject(places, &MapSet.member?(finished_ids, &1.id))
    workers = Enum.reduce(finished, workers, &Placement.release(&2, &1.id, config))
    colours = Enum.map(finished, fn %Project{gives: {:book, colour}} -> colour end)

    books =
      Enum.reduce(colours, books, fn colour, books -> Map.update!(books, colour, &(&1 + 1)) end)

    {places, workers, books, colours}
  end
end
