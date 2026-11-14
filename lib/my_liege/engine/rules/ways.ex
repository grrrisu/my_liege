defmodule MyLiege.Engine.Rules.Ways do
  @moduledoc """
  R13, ways: a way is a place type of a colour that makes a good of another colour's home
  place (`Blueprint.way?/1`), e.g. the granary, violet to food. One rule unlocks every way:
  the village holds at least one book (R12) of the way's colour and one of the colour of its
  good's home place. Books are not used up, so a way once unlocked stays unlocked. A locked way
  can't be ordered (a building) or started (an invention); any other type is never locked. A
  way that is a standing place, a trade route (R16) or the hunting camp (R17), opens by
  itself once unlocked (`open/2`).
  """

  alias MyLiege.Engine.Place
  alias MyLiege.Engine.Place.{Blueprint, Expedition, Trade}

  @standing for %{engine: engine} = blueprint <- Blueprint.ways(),
                engine in [:trade, :expedition],
                do: blueprint

  @doc """
  The colours whose book the village still lacks for `blueprint`, in the order place colour,
  then the good's home colour; `[]` if unlocked or not a way. `books` is colour => count.
  """
  def missing(%Blueprint{} = blueprint, books) do
    if Blueprint.way?(blueprint) do
      [blueprint.colour, Blueprint.home_colour(blueprint.good)]
      |> Enum.filter(&(Map.fetch!(books, &1) < 1))
    else
      []
    end
  end

  @doc "Whether `blueprint` can be ordered or started with `books`: not a way, or unlocked."
  def unlocked?(%Blueprint{} = blueprint, books), do: missing(blueprint, books) == []

  @doc """
  Appends every standing way (a trade route, the hunting camp) that `books` unlock and that
  isn't open yet to `places`, in catalogue order, each with the next free id and empty.
  Returns `{places, opened_types}`.
  """
  def open(places, books) do
    Enum.reduce(@standing, {places, []}, fn blueprint, {places, opened} ->
      if open?(places, blueprint) or not unlocked?(blueprint, books) do
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

  @doc "`:ok` if `blueprint` is unlocked with `books`, else `{:error, :locked}`."
  def check(%Blueprint{} = blueprint, books),
    do: if(unlocked?(blueprint, books), do: :ok, else: {:error, :locked})
end
