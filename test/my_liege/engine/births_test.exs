defmodule MyLiege.Engine.BirthsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Births, Config, Manameter, Random, Worker}

  defp seeded_rand(seed), do: seed |> Random.new() |> elem(1)

  describe "R1: birth of a new worker" do
    setup do
      %{config: %Config{}}
    end

    test "a birth is attempted on weeks 0, 2, 4, ...", %{config: config} do
      assert Enum.filter(0..9, &Births.birth_week?(&1, config)) == [0, 2, 4, 6, 8]
    end

    test "the birth interval comes from the configuration", %{config: config} do
      config = %{config | birth_interval_weeks: 3}
      assert Enum.filter(0..9, &Births.birth_week?(&1, config)) == [0, 3, 6, 9]
    end

    test "no birth in a week between attempts", %{config: config} do
      assert {nil, _} = Births.attempt(1, 24, config.starting_manameter, config, seeded_rand(1))
    end

    test "a birth passes with 0 food left after eating", %{config: config} do
      assert {%Worker{}, _} =
               Births.attempt(0, 0, config.starting_manameter, config, seeded_rand(1))
    end

    test "a birth is lost when food left after eating is below 0", %{config: config} do
      rand = seeded_rand(1)
      assert {nil, ^rand} = Births.attempt(0, -1, config.starting_manameter, config, rand)
    end

    test "a newborn is untrained and unplaced", %{config: config} do
      {newborn, _} = Births.attempt(0, 24, config.starting_manameter, config, seeded_rand(1))
      assert %Worker{trained: false, building: nil} = newborn
      assert newborn.colour in Manameter.colours()
    end

    test "colour chances equal the Manameter shares", %{config: config} do
      draw_count = 20_000
      colour_counts = count_colours(config.starting_manameter, seeded_rand(42), draw_count)

      for {colour, share} <- Map.from_struct(config.starting_manameter) do
        observed = Map.get(colour_counts, colour, 0) * 100 / draw_count
        assert abs(observed - share) < 1, "#{colour}: expected ~#{share}%, got #{observed}%"
      end
    end

    test "a colour with a 0% share is never born", %{config: config} do
      colour_counts = count_colours(config.starting_manameter, seeded_rand(7), 20_000)
      refute Map.has_key?(colour_counts, :violet)
    end

    test "the same seed gives the same colours", %{config: config} do
      assert draw_colours(config.starting_manameter, seeded_rand(3), 50) ==
               draw_colours(config.starting_manameter, seeded_rand(3), 50)
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
