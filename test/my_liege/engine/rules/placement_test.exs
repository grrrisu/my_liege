defmodule MyLiege.Engine.Rules.PlacementTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Manameter, Worker}
  alias MyLiege.Engine.Rules.Placement
  alias MyLiege.EngineFixtures

  setup do
    config = EngineFixtures.config(build_capacity: 2)
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

    test "an arrived worker of any colour may enter a site with room", context do
      %{facts: facts} = context
      site = EngineFixtures.new_site(3, :tavern)

      assert Placement.check_enter(site, worker(:violet), facts) == :ok
      assert Placement.check_enter(site, worker(:blue, true), facts) == :ok
    end

    test "a site refuses a travelling unplaced worker, then a builder over capacity", context do
      %{config: config, facts: facts} = context
      site = EngineFixtures.new_site(3, :market)
      builders = for _ <- 1..config.build_capacity, do: worker(:green, false, site.id)
      travelling = %{worker(:green) | travel: 1}

      assert Placement.check_enter(site, travelling, %{facts | workers: builders}) ==
               {:error, :travelling}

      assert Placement.check_enter(site, worker(:green), %{facts | workers: builders}) ==
               {:error, :full}
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
      site = EngineFixtures.new_site(3, :guildhouse)

      assert Placement.check_enter(site, worker(:blue, true), facts) == :ok
    end

    test "the reasons are checked in order: travelling, full, training", context do
      %{config: config, facts: facts} = context
      guildhouse = EngineFixtures.new_building(3, :guildhouse)
      trainee = worker(:green, false, guildhouse.id)
      trained = %{worker(:green, true) | travel: 1}

      assert Placement.check_enter(guildhouse, trained, %{facts | workers: [trainee]}) ==
               {:error, :travelling}

      trained = %{trained | travel: 0}
      assert config.place_capacity.guildhouse == 1

      assert Placement.check_enter(guildhouse, trained, %{facts | workers: [trainee]}) ==
               {:error, :full}

      assert Placement.check_enter(guildhouse, trained, facts) == {:error, :already_trained}
    end

    test "a worker can only be placed in a building with room", context do
      %{config: config, farm: farm} = context
      full_farm = for _ <- 1..config.place_capacity.farm, do: worker(:green, false, farm.id)

      assert has_room?(farm, [], config)
      refute has_room?(farm, full_farm, config)
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
    test "a building takes its capacity, a site build_capacity", context do
      %{config: config, farm: farm} = context
      site = EngineFixtures.new_site(3, :farm)

      assert Placement.capacity(farm, config) == config.place_capacity.farm
      assert Placement.capacity(site, config) == 2
    end
  end

  describe "trains?/1" do
    test "only the guildhouse trains, not a site for one", %{farm: farm} do
      assert Placement.trains?(EngineFixtures.new_building(3, :guildhouse))
      refute Placement.trains?(EngineFixtures.new_site(3, :guildhouse))
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

  defp has_room?(place, workers, config),
    do: Placement.check_enter(place, worker(:green), facts(config, workers)) != {:error, :full}

  defp worker(colour, trained \\ false, place_id \\ nil),
    do: %Worker{colour: colour, trained: trained, place: place_id}
end
