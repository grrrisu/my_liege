defmodule MyLiege.Engine.Rules.Ways do
  @moduledoc """
  R13, ways: a way is a place type of a colour that makes a good of another colour's home
  place (`Blueprint.way?/1`), e.g. the granary, violet to food. One rule unlocks every way:
  the village holds at least one book (R12) of the way's colour and one of the colour of its
  good's home place. Books are not used up, so a way once unlocked stays unlocked. A locked way
  can't be ordered (a building) or started (an invention); any other type is never locked.
  """

  alias MyLiege.Engine.Place.Blueprint

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

  @doc "`:ok` if `blueprint` is unlocked with `books`, else `{:error, :locked}`."
  def check(%Blueprint{} = blueprint, books),
    do: if(unlocked?(blueprint, books), do: :ok, else: {:error, :locked})
end
