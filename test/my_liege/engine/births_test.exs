defmodule MyLiege.Engine.BirthsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Births, Building, Fixed, Manameter, Random, Worker}
  alias MyLiege.EngineFixtures

  defp seeded_rand(seed), do: seed |> Random.new() |> elem(1)

  describe "R1: birth of a new worker" do
    setup do
      config = EngineFixtures.config()
      %{config: config, manameter: config.starting_manameter}
    end

    test "the game starts with green farmers on the farm and red soldiers in the tower" do
      config = EngineFixtures.config(starting_farmers: 2, starting_soldiers: 1)
      [farm, tower] = Building.starting()

      assert Worker.starting([farm, tower], config) == [
               %Worker{colour: :green, building: farm.id},
               %Worker{colour: :green, building: farm.id},
               %Worker{colour: :red, building: tower.id}
             ]
    end

    test "a birth is attempted on weeks 0, 2, 4, ...", %{config: config} do
      assert Enum.filter(1..10, &Births.birth_week?(&1, config)) == [1, 3, 5, 7, 9]
    end

    test "the birth interval comes from the configuration", %{config: config} do
      config = %{config | birth_interval_weeks: 3}
      assert Enum.filter(1..10, &Births.birth_week?(&1, config)) == [1, 4, 7, 10]
    end

    test "no birth in a week between attempts", %{config: config, manameter: manameter} do
      food_left = Fixed.from(24)
      assert {nil, _} = Births.attempt(2, food_left, manameter, config, seeded_rand(1))
    end

    test "a birth passes with exactly birth_min_food_left left after eating", context do
      %{config: config, manameter: manameter} = context
      food_left = Fixed.from(config.birth_min_food_left)
      assert {%Worker{}, _} = Births.attempt(1, food_left, manameter, config, seeded_rand(1))
    end

    test "a birth is lost when food left after eating is below birth_min_food_left", context do
      %{config: config, manameter: manameter} = context
      food_left = Fixed.from(config.birth_min_food_left) - 1
      rand = seeded_rand(1)
      assert {nil, ^rand} = Births.attempt(1, food_left, manameter, config, rand)
    end

    test "a newborn is untrained and unplaced", %{config: config, manameter: manameter} do
      food_left = Fixed.from(24)
      {newborn, _} = Births.attempt(1, food_left, manameter, config, seeded_rand(1))
      assert %Worker{trained: false, building: nil} = newborn
      assert newborn.colour in Manameter.colours()
    end

    test "colour chances equal the Manameter shares", %{manameter: manameter} do
      draw_count = 20_000
      colour_counts = count_colours(manameter, seeded_rand(42), draw_count)

      for {colour, share} <- Map.from_struct(manameter) do
        observed = Map.get(colour_counts, colour, 0) * 1000 / draw_count
        assert abs(observed - share) < 10, "#{colour}: expected ~#{share}‰, got #{observed}‰"
      end
    end

    test "a colour with a 0% share is never born", %{manameter: manameter} do
      colour_counts = count_colours(manameter, seeded_rand(7), 20_000)
      refute Map.has_key?(colour_counts, :violet)
    end

    test "the same seed gives the same colours", %{manameter: manameter} do
      assert draw_colours(manameter, seeded_rand(3), 50) ==
               draw_colours(manameter, seeded_rand(3), 50)
    end
  end

  defp draw_colours(manameter, rand, draw_count) do
    {colours, _} =
      Enum.map_reduce(1..draw_count, rand, fn _, current_rand ->
        Births.draw_colour(manameter, current_rand)
      end)

    colours
  end

  defp count_colours(manameter, rand, draw_count) do
    manameter |> draw_colours(rand, draw_count) |> Enum.frequencies()
  end
end
