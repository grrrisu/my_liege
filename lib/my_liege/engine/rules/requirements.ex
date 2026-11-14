defmodule MyLiege.Engine.Rules.Requirements do
  @moduledoc """
  What a place type needs before it can be used, read from its catalogue entry (`Blueprint`):
  `books_needed/2` books (R12) of its colour and as many of the colour of its good's home
  place, and the invention its entry `requires`, if any. Today the ways (R13) need them; a
  type that needs no books and no invention is never locked. Books are not used up and
  inventions are kept, so a type once unlocked stays unlocked.

  A locked type can't be ordered (a building) or started (an invention). A trade route (R16)
  or the hunting camp (R17) is never ordered: it opens by itself as a place once unlocked
  (`open/4`).
  """

  alias MyLiege.Engine.{Config, Place}
  alias MyLiege.Engine.Place.{Blueprint, Expedition, Trade}

  @type missing :: {:book, atom(), pos_integer()} | {:invention, atom()}

  # the types that stand as places without being ordered: the trade routes and expeditions
  @standing for %{engine: engine} = blueprint <- Blueprint.all(),
                engine in [:trade, :expedition],
                do: blueprint

  @doc "How many books of each of its two colours `blueprint` needs (`Blueprint` `books`)."
  def books_needed(%Blueprint{books: :config, type: type}, %Config{} = config),
    do: Map.fetch!(config.books_needed, type)

  def books_needed(%Blueprint{books: books}, %Config{}), do: books

  @doc """
  What the village still lacks for `blueprint`: `{:book, colour, count}` for each of the
  type's colour and its good's home colour (in that order) with `count` books still to be
  written, then `{:invention, type}` if the required invention isn't among `inventions`.
  `[]` if unlocked. `books` is colour => count.
  """
  @spec missing(Blueprint.t(), map(), [atom()], Config.t()) :: [missing()]
  def missing(%Blueprint{} = blueprint, books, inventions, %Config{} = config) do
    needed = books_needed(blueprint, config)

    book_gaps =
      for colour <- book_colours(blueprint, needed),
          Map.fetch!(books, colour) < needed,
          do: {:book, colour, needed - Map.fetch!(books, colour)}

    invention_gap =
      for type <- List.wrap(blueprint.requires), type not in inventions, do: {:invention, type}

    book_gaps ++ invention_gap
  end

  @doc "Whether `blueprint` can be ordered or started: nothing is `missing/4`."
  def unlocked?(%Blueprint{} = blueprint, books, inventions, %Config{} = config),
    do: missing(blueprint, books, inventions, config) == []

  @doc "`:ok` if `blueprint` is unlocked, else `{:error, :locked}`."
  def check(%Blueprint{} = blueprint, books, inventions, %Config{} = config),
    do: if(unlocked?(blueprint, books, inventions, config), do: :ok, else: {:error, :locked})

  @doc """
  Appends every trade route and expedition (the hunting camp) that is unlocked and isn't
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

  @doc "Whether a place of `blueprint`'s type is open among `places`."
  def open?(places, %Blueprint{type: type}),
    do: Enum.any?(places, &(Place.type(&1) == type))

  defp new_place(%{engine: :trade} = blueprint, id), do: %Trade{id: id, blueprint: blueprint}

  defp new_place(%{engine: :expedition} = blueprint, id),
    do: %Expedition{id: id, blueprint: blueprint}

  # the colours whose books a type needs: its own and its good's home colour; none if it
  # needs no books (the guildhouse has neither colour nor good)
  defp book_colours(_blueprint, 0), do: []

  defp book_colours(%Blueprint{colour: colour, good: good}, _needed),
    do: [colour, Blueprint.home_colour(good)]
end
