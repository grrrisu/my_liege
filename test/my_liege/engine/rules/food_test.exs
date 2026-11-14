defmodule MyLiege.Engine.Rules.FoodTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Rules.Food
  alias MyLiege.Engine.Worker
  alias MyLiege.EngineFixtures

  describe "R8: food" do
    setup do
      %{config: EngineFixtures.config()}
    end

    test "the game starts with start_food in stock", %{config: config} do
      assert Food.starting(config) == 24_000
    end

    test "every worker eats 3 a week", %{config: config} do
      assert Food.eat(24_000, workers(3), config) == {15_000, false}
    end

    test "unplaced workers eat too", %{config: config} do
      workers = [%Worker{colour: :green, place: 1}, %Worker{colour: :red}]

      assert Food.eat(24_000, workers, config) == {18_000, false}
    end

    test "leftover food carries over with no limit", %{config: config} do
      assert Food.eat(1_000_000, workers(1), config) == {997_000, false}
    end

    test "exactly enough food leaves 0", %{config: config} do
      assert Food.eat(9_000, workers(3), config) == {0, false}
    end

    test "without enough food the missing food is forgotten: the stock stops at 0, short",
         context do
      assert Food.eat(5_000, workers(3), context.config) == {0, true}
      assert Food.eat(0, workers(1), context.config) == {0, true}
    end
  end

  defp workers(count), do: for(_ <- 1..count, do: %Worker{colour: :green})
end
