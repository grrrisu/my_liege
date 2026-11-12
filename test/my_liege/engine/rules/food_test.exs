defmodule MyLiege.Engine.Rules.FoodTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Random, Worker}
  alias MyLiege.Engine.Rules.{Births, Food}
  alias MyLiege.EngineFixtures

  describe "R8: food" do
    setup do
      %{config: EngineFixtures.config()}
    end

    test "the game starts with start_food in stock", %{config: config} do
      assert Food.starting(config) == 24_000
    end

    test "every worker eats 3 a week", %{config: config} do
      assert Food.eat(24_000, workers(3), config) == 15_000
    end

    test "unplaced workers eat too", %{config: config} do
      workers = [%Worker{colour: :green, building: 1}, %Worker{colour: :red}]

      assert Food.eat(24_000, workers, config) == 18_000
    end

    test "leftover food carries over with no limit", %{config: config} do
      assert Food.eat(1_000_000, workers(1), config) == 997_000
    end

    test "exactly enough food leaves 0", %{config: config} do
      assert Food.eat(9_000, workers(3), config) == 0
    end

    test "without enough food the missing food is forgotten and the stock is -1", context do
      assert Food.eat(5_000, workers(3), context.config) == -1
    end

    test "no birth after a short week, even with a minimum of 0" do
      config = EngineFixtures.config(birth_min_food_left: 0)
      food_left = Food.eat(5_000, workers(3), config)
      rand = 1 |> Random.new() |> elem(1)

      assert {nil, _} =
               Births.attempt(0, food_left, config.manameter_start, config, rand)
    end
  end

  defp workers(count), do: for(_ <- 1..count, do: %Worker{colour: :green})
end
