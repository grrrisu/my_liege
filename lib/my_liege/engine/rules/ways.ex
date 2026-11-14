defmodule MyLiege.Engine.Rules.Ways do
  @moduledoc """
  R13, ways: a way is a place type of a colour that makes a good of another colour's home
  place (`Blueprint.way?/1`), e.g. the granary, violet to food. One rule unlocks every way:
  the village holds at least `books_needed/2` books (R12) of the way's colour and as many of
  the colour of its good's home place (1 unless its catalogue entry says otherwise), and has
  made the invention its entry `requires`, if any. Books are not used up and inventions are
  kept, so a way once unlocked stays unlocked. A locked way
  can't be ordered (a building) or started (an invention); any other type is never locked. A
  way that is a standing place, a trade route (R16) or the hunting camp (R17), opens by
  itself once unlocked (`open/4`).
  """

  alias MyLiege.Engine.{Config, Place}
  alias MyLiege.Engine.Place.{Blueprint, Expedition, Trade}

  @type missing :: {:book, atom(), pos_integer()} | {:invention, atom()}

  @standing for %{engine: engine} = blueprint <- Blueprint.ways(),
                engine in [:trade, :expedition],
                do: blueprint

  @doc "How many books of each of its two colours `blueprint` needs (`Blueprint` `books`)."
  def books_needed(%Blueprint{books: :config, type: type}, %Config{} = config),
    do: Map.fetch!(config.way_books, type)

  def books_needed(%Blueprint{books: books}, %Config{}), do: books

  @doc """
  What the village still lacks for `blueprint`: `{:book, colour, count}` for each of the
  way's colour and its good's home colour (in that order) with `count` books still to be
  written, then `{:invention, type}` if the required invention isn't among `inventions`.
  `[]` if unlocked or not a way. `books` is colour => count.
  """
  @spec missing(Blueprint.t(), map(), [atom()], Config.t()) :: [missing()]
  def missing(%Blueprint{} = blueprint, books, inventions, %Config{} = config) do
    if Blueprint.way?(blueprint) do
      needed = books_needed(blueprint, config)

      book_gaps =
        for colour <- [blueprint.colour, Blueprint.home_colour(blueprint.good)],
            Map.fetch!(books, colour) < needed,
            do: {:book, colour, needed - Map.fetch!(books, colour)}

      invention_gap =
        for type <- List.wrap(blueprint.requires), type not in inventions, do: {:invention, type}

      book_gaps ++ invention_gap
    else
      []
    end
  end

  @doc "Whether `blueprint` can be ordered or started: not a way, or unlocked."
  def unlocked?(%Blueprint{} = blueprint, books, inventions, %Config{} = config),
    do: missing(blueprint, books, inventions, config) == []

  @doc "`:ok` if `blueprint` is unlocked, else `{:error, :locked}`."
  def check(%Blueprint{} = blueprint, books, inventions, %Config{} = config),
    do: if(unlocked?(blueprint, books, inventions, config), do: :ok, else: {:error, :locked})

  @doc """
  Appends every standing way (a trade route, the hunting camp) that is unlocked and isn't
  open yet to `places`, in catalogue order, each with the next free id and empty. Returns
  `{places, opened_types}`.
  """
  def open(places, books, inventions, %Config{} = config) do
    Enum.reduce(@standing, {places, []}, fn blueprint, {places, opened} ->
      if open?(places, blueprint) or not unlocked?(blueprint, books, inventions, config) do
        {places, opened}
      else
        {places ++ [new_place(blueprint, Place.next_id(places))], opened ++ [blueprint.type]}
      end
    end)
  end

  @doc "Whether the standing way `type` is open among `places`."
  def open?(places, %Blueprint{type: type}),
    do: Enum.any?(places, &(Place.type(&1) == type))

  defp new_place(%{engine: :trade} = blueprint, id), do: %Trade{id: id, blueprint: blueprint}

  defp new_place(%{engine: :expedition} = blueprint, id),
    do: %Expedition{id: id, blueprint: blueprint}
end
