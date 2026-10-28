defmodule MyLiege.Engine.Random do
  @moduledoc """
  Seeded random state for a run. Engine functions take the state and return the next one;
  the seed is kept with the run so it can be replayed exactly.
  """

  @algorithm :exsss

  @doc "Returns `{seed, rand}`. Without a seed, one is generated and returned for storing."
  def new(seed \\ nil)
  def new(nil), do: new(:rand.uniform(4_294_967_296))
  def new(seed) when is_integer(seed), do: {seed, :rand.seed_s(@algorithm, seed)}
end
