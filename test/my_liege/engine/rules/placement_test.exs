defmodule MyLiege.Engine.Rules.PlacementTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Manameter, Worker}
  alias MyLiege.Engine.Place.Building
  alias MyLiege.Engine.Rules.Placement
  alias MyLiege.EngineFixtures

  setup do
    config = EngineFixtures.config(build_builders: 2)
    farm = EngineFixtures.new_building(1, :farm)
    %{config: config, farm: farm, facts: facts(config)}
  end

  describe "check_enter/3" do
    test "an arrived worker may enter a finished building with room", context do
      %{farm: farm, facts: facts} = context

      assert Placement.check_enter(farm, worker(:green), facts) == :ok
    end

    test "an unplaced worker still travelling can't be placed", context do
      %{farm: farm, facts: facts} = context

      assert Placement.check_enter(farm, %{worker(:green) | travel: 1}, facts) ==
               {:error, :travelling}
    end

    test "a placed worker may move while still travelling", context do
      %{farm: farm, facts: facts} = context
      moving = %{worker(:green) | place: 2, travel: 1}

      assert Placement.check_enter(farm, moving, facts) == :ok
    end

    test "a building not ready next week is refused; a site is not", context do
      %{facts: facts} = context
      new_tavern = EngineFixtures.new_building(3, :tavern, ready_week: 2)
      site = EngineFixtures.new_building(4, :tavern, ready_week: nil)

      assert Placement.check_enter(new_tavern, worker(:violet), facts) == {:error, :not_ready}
      assert Placement.check_enter(new_tavern, worker(:violet), %{facts | week: 1}) == :ok
      assert Placement.check_enter(site, worker(:violet), facts) == :ok
    end

    test "a full place is refused", context do
      %{config: config, farm: farm, facts: facts} = context
      full_farm = for _ <- 1..config.place_capacity.farm, do: worker(:green, false, farm.id)

      assert Placement.check_enter(farm, worker(:green), %{facts | workers: full_farm}) ==
               {:error, :full}
    end

    test "the guildhouse refuses a trained worker", context do
      %{facts: facts} = context
      guildhouse = EngineFixtures.new_building(3, :guildhouse)

      assert Placement.check_enter(guildhouse, worker(:green, true), facts) ==
               {:error, :already_trained}
    end

    test "the guildhouse refuses a colour below the training threshold", context do
      %{facts: facts} = context
      guildhouse = EngineFixtures.new_building(3, :guildhouse)

      assert Placement.check_enter(guildhouse, worker(:blue), facts) ==
               {:error, :below_threshold}

      assert Placement.check_enter(guildhouse, worker(:green), facts) == :ok
    end

    test "builders on a guildhouse site are not checked for training", context do
      %{facts: facts} = context
      site = EngineFixtures.new_building(3, :guildhouse, ready_week: nil)

      assert Placement.check_enter(site, worker(:blue, true), facts) == :ok
    end

    test "the reasons are checked in order: travelling, not ready, full, training", context do
      %{config: config, facts: facts} = context
      guildhouse = EngineFixtures.new_building(3, :guildhouse, ready_week: 5)
      trainee = worker(:green, false, guildhouse.id)
      trained = %{worker(:green, true) | travel: 1}

      assert Placement.check_enter(guildhouse, trained, facts) == {:error, :travelling}

      trained = %{trained | travel: 0}
      assert Placement.check_enter(guildhouse, trained, facts) == {:error, :not_ready}

      facts = %{facts | week: 5, workers: [trainee]}
      assert config.place_capacity.guildhouse == 1
      assert Placement.check_enter(guildhouse, trained, facts) == {:error, :full}
    end

    test "a worker can only be placed in a finished building with room", context do
      %{config: config, farm: farm} = context
      new_tavern = EngineFixtures.new_building(3, :tavern, ready_week: 7)
      full_farm = for _ <- 1..config.place_capacity.farm, do: worker(:green, false, farm.id)

      refute can_place?(new_tavern, [], 6, config)
      assert can_place?(new_tavern, [], 7, config)
      assert can_place?(farm, [], 0, config)
      refute can_place?(farm, full_farm, 0, config)
    end

    test "each building has its own capacity", context do
      %{farm: farm} = context
      monastery = EngineFixtures.new_building(2, :monastery)

      config =
        EngineFixtures.config(
          place_capacity: %{farm: 4, monastery: 2, watchtower: 4, market: 4, tavern: 4}
        )

      three_farmers = for _ <- 1..3, do: worker(:green, false, farm.id)
      four_farmers = [worker(:green, false, farm.id) | three_farmers]
      two_monks = for _ <- 1..2, do: worker(:blue, false, monastery.id)

      assert has_room?(farm, three_farmers, config)
      refute has_room?(farm, four_farmers, config)
      refute has_room?(monastery, two_monks, config)
    end
  end

  describe "capacity/2" do
    test "a building takes its capacity, a site build_builders", context do
      %{config: config, farm: farm} = context
      site = EngineFixtures.new_building(3, :farm, ready_week: nil)

      assert Placement.capacity(farm, config) == config.place_capacity.farm
      assert Placement.capacity(site, config) == 2
    end
  end

  describe "leave/1" do
    test "a builder leaving a site resets its progress" do
      site = EngineFixtures.new_building(3, :market, ready_week: nil, progress: 1)

      assert %Building{progress: 0} = Placement.leave(site)
    end

    test "leaving a finished building leaves it unchanged", %{farm: farm} do
      assert Placement.leave(farm) == farm
    end
  end

  describe "trains?/1" do
    test "only a finished guildhouse trains", %{farm: farm} do
      assert Placement.trains?(EngineFixtures.new_building(3, :guildhouse))
      refute Placement.trains?(EngineFixtures.new_building(3, :guildhouse, ready_week: nil))
      refute Placement.trains?(farm)
    end
  end

  defp facts(config, workers \\ []) do
    %{
      week: 0,
      workers: workers,
      manameter: %Manameter{green: 800, blue: 50, red: 100, yellow: 50, violet: 0},
      config: config
    }
  end

  # a worker who has arrived can enter `place` at `week`, i.e. while the game stands at the
  # week before
  defp can_place?(place, workers, week, config),
    do:
      Placement.check_enter(place, worker(:green), %{facts(config, workers) | week: week - 1}) ==
        :ok

  defp has_room?(place, workers, config),
    do: Placement.check_enter(place, worker(:green), facts(config, workers)) != {:error, :full}

  defp worker(colour, trained \\ false, place_id \\ nil),
    do: %Worker{colour: colour, trained: trained, place: place_id}
end
