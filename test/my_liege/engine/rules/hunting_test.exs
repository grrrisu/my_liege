defmodule MyLiege.Engine.Rules.HuntingTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place.{Blueprint, Expedition}
  alias MyLiege.Engine.Random
  alias MyLiege.Engine.Rules.{Books, Hunting}
  alias MyLiege.Engine.Worker
  alias MyLiege.EngineFixtures

  @unlocked %{Books.none() | red: 1, green: 1}

  setup do
    %{config: EngineFixtures.config()}
  end

  describe "R17: time and haul" do
    test "away 3 + 12 + 3 weeks", %{config: config} do
      assert Hunting.weeks(config) == 18
    end

    test "a hunter brings 15 × 12 × his factor against red", %{config: config} do
      assert Hunting.hunter_haul(worker(:red), config) == 180_000
      assert Hunting.hunter_haul(worker(:blue), config) == 135_000
      assert Hunting.hunter_haul(worker(:violet), config) == 135_000
      assert Hunting.hunter_haul(worker(:green), config) == 90_000
      assert Hunting.hunter_haul(worker(:red, true), config) == 270_000
      assert Hunting.hunter_haul(worker(:green, true), config) == 45_000
    end

    test "the party's hauls summed, × the luck factor, rounded down once", %{config: config} do
      party = [worker(:red), worker(:blue)]

      assert Hunting.haul(party, :low, config) == 157_500
      assert Hunting.haul(party, :mid, config) == 315_000
      assert Hunting.haul(party, :high, config) == 472_500

      odd = EngineFixtures.config(way_hunting_luck: %{low: 333, mid: 1000, high: 1500})
      # 90 + 90 = 180, × 0.333 = 59.94 (each alone 29.97: rounding once keeps the total)
      assert Hunting.haul([worker(:green), worker(:green)], :low, odd) == 59_940
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

  describe "R17: setting out" do
    test "needs the way unlocked, 1 to max_party distinct arrived workers not away",
         %{config: config} do
      farm = EngineFixtures.new_building(1, :farm)
      away = %Expedition{id: 9, blueprint: Blueprint.fetch!(:hunting), return_week: 20}
      a = {worker(:red, false, 1), nil}
      b = {worker(:green, false, 2), farm}

      assert Hunting.check_start([a], Books.none(), config) == {:error, :locked}
      assert Hunting.check_start([], @unlocked, config) == {:error, :party_size}

      five = for id <- 1..5, do: {worker(:red, false, id), nil}
      assert Hunting.check_start(five, @unlocked, config) == {:error, :party_size}
      assert Hunting.check_start([a, a], @unlocked, config) == {:error, :duplicate}

      assert Hunting.check_start([a, {worker(:red, false, 3), away}], @unlocked, config) ==
               {:error, :away}

      travelling = {%{worker(:red, false, 4) | travel: 1}, nil}
      assert Hunting.check_start([a, travelling], @unlocked, config) == {:error, :travelling}

      assert Hunting.check_start([a, b], @unlocked, config) == :ok
      assert Hunting.check_start(Enum.take(five, 4), @unlocked, config) == :ok
    end

    test "a hunt set out at week N returns at the end of week N + 18", %{config: config} do
      places = Hunting.new_expedition([EngineFixtures.new_building(1, :farm)], 5, config)

      assert %Expedition{id: 2, return_week: 23} = hunt = List.last(places)
      assert hunt.blueprint == Blueprint.fetch!(:hunting)
    end
  end

  describe "R17: return" do
    test "in its return week: luck drawn, haul, the hunt removed, the party released" do
      config =
        EngineFixtures.config(
          travel_weeks: 1,
          way_hunting_party: %{
            1 => %{low: 10, mid: 0, high: 0},
            2 => %{low: 0, mid: 0, high: 10},
            3 => %{low: 2, mid: 4, high: 4},
            4 => %{low: 1, mid: 3, high: 6}
          }
        )

      hunt = %Expedition{id: 3, blueprint: Blueprint.fetch!(:hunting), return_week: 18}
      later = %{hunt | id: 4, return_week: 30}

      workers = [
        %{worker(:red, false, 1) | place: 3},
        %{worker(:blue, false, 2) | place: 3},
        %{worker(:red, false, 5) | place: 4}
      ]

      {_seed, rand} = Random.new(1)

      assert {[^later], released, 472_500, [%{hunters: 2, luck: :high, food: 472_500}], next} =
               Hunting.return([hunt, later], workers, 18, config, rand)

      assert next != rand

      assert Enum.map(released, &{&1.id, &1.place, &1.travel}) == [
               {1, nil, 1},
               {2, nil, 1},
               {5, 4, 0}
             ]

      # no hunt returning: no draw
      assert {_, ^workers, 0, [], ^rand} =
               Hunting.return([hunt, later], workers, 17, config, rand)
    end
  end

  defp worker(colour, trained \\ false, id \\ 1),
    do: %Worker{id: id, colour: colour, trained: trained}
end
