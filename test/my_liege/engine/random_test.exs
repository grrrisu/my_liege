defmodule MyLiege.Engine.RandomTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Random

  test "the same seed gives the same random sequence" do
    {42, first_rand} = Random.new(42)
    {42, second_rand} = Random.new(42)
    assert first_number(first_rand) == first_number(second_rand)
  end

  test "without a seed, the generated seed is returned and replays the run" do
    {seed, first_rand} = Random.new()
    {^seed, second_rand} = Random.new(seed)
    assert first_number(first_rand) == first_number(second_rand)
  end

  defp first_number(rand), do: rand |> :rand.uniform_s() |> elem(0)
end
