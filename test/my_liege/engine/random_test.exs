defmodule MyLiege.Engine.RandomTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Random

  test "the same seed gives the same random sequence" do
    {42, a} = Random.new(42)
    {42, b} = Random.new(42)
    assert elem(:rand.uniform_s(a), 0) == elem(:rand.uniform_s(b), 0)
  end

  test "without a seed, the generated seed is returned and replays the run" do
    {seed, a} = Random.new()
    {^seed, b} = Random.new(seed)
    assert elem(:rand.uniform_s(a), 0) == elem(:rand.uniform_s(b), 0)
  end
end
