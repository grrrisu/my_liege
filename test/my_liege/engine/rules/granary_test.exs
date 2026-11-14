defmodule MyLiege.Engine.Rules.GranaryTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Rules.Granary
  alias MyLiege.Engine.Worker
  alias MyLiege.EngineFixtures

  # place.granary.culture_upkeep 5, place.granary.food_spoilage_permille 10
  setup do
    %{
      config:
        EngineFixtures.config(
          good_spoilage: %{food: 50, knowledge: 0, defence: 0, gold: 0, culture: 0}
        )
    }
  end

  describe "R14: working granaries" do
    test "a granary works while an arrived keeper is there" do
      places = [
        EngineFixtures.new_building(1, :granary),
        EngineFixtures.new_building(2, :granary)
      ]

      assert Granary.working([], places, 1) == 0
      assert Granary.working([keeper(1)], places, 1) == 1
      assert Granary.working([%{keeper(1) | travel: 1}], places, 1) == 0
      assert Granary.working([keeper(1), keeper(2)], places, 1) == 2
    end

    test "a keeper on a granary site works nowhere" do
      assert Granary.working([keeper(1)], [EngineFixtures.new_site(1, :granary)], 1) == 0
    end
  end

  describe "R14: culture upkeep" do
    test "each working granary owes the upkeep, taken from the stock, never below 0",
         %{config: config} do
      assert Granary.upkeep(0, 20_000, config) == 0
      assert Granary.upkeep(1, 20_000, config) == 5_000
      assert Granary.upkeep(2, 20_000, config) == 10_000
      assert Granary.upkeep(1, 3_000, config) == 3_000
      assert Granary.upkeep(1, 0, config) == 0
      assert Granary.upkeep(1, -1, config) == 0
    end

    test "the culture for happiness is the culture made minus the culture spent, never below 0" do
      assert Granary.culture_for_happiness(8_000, 5_000) == 3_000
      assert Granary.culture_for_happiness(3_000, 5_000) == 0
      assert Granary.culture_for_happiness(3_000, 0) == 3_000
    end
  end

  describe "R14: protected food" do
    test "working granaries × place.granary.food_capacity, at most the stock", %{config: config} do
      assert Granary.protected(0, 850_000, config) == 0
      assert Granary.protected(1, 850_000, config) == 300_000
      assert Granary.protected(2, 850_000, config) == 600_000
      assert Granary.protected(3, 850_000, config) == 850_000
      assert Granary.protected(2, 0, config) == 0
    end

    test "protected food spoils at the granary's rate, the rest at the good's, each rounded down",
         %{config: config} do
      # 600 → 6, 250 → 12.5 (exact in thousandths): 18.5 instead of 42.5
      assert Granary.food_spoiled(850_000, 600_000, config) == 18_500
      assert Granary.food_spoiled(850_000, 0, config) == 42_500
      # rounded down in thousandths: 999 × 10 ÷ 1000 = 9.99 → 9, 100 × 50 ÷ 1000 = 5
      assert Granary.food_spoiled(1_099, 999, config) == 9 + 5
      assert Granary.food_spoiled(0, 0, config) == 0
    end
  end

  defp keeper(place_id), do: %Worker{id: place_id, colour: :violet, place: place_id}
end
