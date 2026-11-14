defmodule MyLiege.Engine.Rules.HuntingTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place.{Blueprint, Expedition}
  alias MyLiege.Engine.Random
  alias MyLiege.Engine.Rules.Hunting
  alias MyLiege.Engine.Worker
  alias MyLiege.EngineFixtures

  setup do
    %{config: EngineFixtures.config(), rand: 1 |> Random.new() |> elem(1)}
  end

  defp camp(fields \\ []),
    do: struct!(%Expedition{id: 3, blueprint: Blueprint.fetch!(:hunting)}, fields)

  defp hunter(id, colour, travel \\ 0),
    do: %Worker{id: id, colour: colour, place: 3, travel: travel}

  defp always(luck, config) do
    table = %{low: 0, mid: 0, high: 0} |> Map.put(luck, 10)
    %{config | way_hunting_party: Map.new(1..4, &{&1, table})}
  end

  describe "R17: the week's hunting" do
    test "a hunter adds 15 × his factor against red to the bag", %{config: config} do
      assert Hunting.hunter_week(%Worker{colour: :red}, config) == 15_000
      assert Hunting.hunter_week(%Worker{colour: :violet}, config) == 11_250
      assert Hunting.hunter_week(%Worker{colour: :green}, config) == 7_500
      assert Hunting.hunter_week(%Worker{colour: :red, trained: true}, config) == 22_500
    end

    test "arrived hunters fill the bag and the week counts; no draw before the haul",
         %{config: config, rand: rand} do
      workers = [hunter(1, :red), hunter(2, :green), hunter(3, :red, 2)]

      assert {%Expedition{bag: 22_500, weeks: 1, hunted_in_block: true}, nil, ^rand} =
               Hunting.hunt(camp(), workers, config, rand)
    end

    test "a week without an arrived hunter changes nothing", %{config: config, rand: rand} do
      camp = camp(bag: 5_000, weeks: 2)

      assert {^camp, nil, ^rand} = Hunting.hunt(camp, [hunter(1, :red, 1)], config, rand)
      assert {^camp, nil, ^rand} = Hunting.hunt(camp, [], config, rand)
    end

    test "at haul_weeks counted weeks: one draw by the arrived hunters, bag × luck, bag and count start again",
         %{config: config, rand: rand} do
      config = always(:high, config)
      camp = camp(bag: 75_000, weeks: 5)
      workers = [hunter(1, :red), hunter(2, :red), hunter(3, :red, 1)]

      {camp, haul, next} = Hunting.hunt(camp, workers, config, rand)

      # 75 + 2 × 15 = 105, × 1.5
      assert haul == %{hunters: 2, luck: :high, food: 157_500}
      assert %Expedition{bag: 0, weeks: 0} = camp
      assert next != rand
    end

    test "the haul is rounded down", %{config: config} do
      assert Hunting.haul(1_001, :low, config) == 500
    end
  end

  describe "R17: leaving" do
    test "a camp no worker is on loses its bag and count; one with a travelling hunter keeps them" do
      camp = camp(bag: 50_000, weeks: 4, hunted_in_block: true)

      assert [%Expedition{bag: 0, weeks: 0, hunted_in_block: true}] =
               Hunting.abandon_empty([camp], [%Worker{id: 1, colour: :red, place: 1}])

      assert Hunting.abandon_empty([camp], [hunter(1, :red, 3)]) == [camp]
    end
  end

  describe "R17: luck" do
    test "a draw maps to low, mid, high by the party's counts" do
      counts = %{low: 4, mid: 4, high: 2}

      assert Enum.map(1..10, &Hunting.luck_for(&1, counts)) ==
               List.duplicate(:low, 4) ++ List.duplicate(:mid, 4) ++ List.duplicate(:high, 2)

      assert Enum.map(1..10, &Hunting.luck_for(&1, %{low: 0, mid: 0, high: 10})) ==
               List.duplicate(:high, 10)
    end

    test "one draw from the random state, by party size; the same state draws the same",
         %{config: config} do
      {_seed, rand} = Random.new(7)

      assert {luck, next} = Hunting.draw_luck(4, config, rand)
      assert luck in [:low, :mid, :high]
      assert next != rand
      assert Hunting.draw_luck(4, config, rand) == {luck, next}

      always_low = %{config | way_hunting_party: %{1 => %{low: 10, mid: 0, high: 0}}}
      assert {:low, _} = Hunting.draw_luck(1, always_low, rand)
    end
  end
end
