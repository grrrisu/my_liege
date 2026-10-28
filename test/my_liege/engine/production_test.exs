defmodule MyLiege.Engine.ProductionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Building, Config, Pentagon, Production, Worker}

  describe "R2: production by colour" do
    setup do
      config = %Config{}
      buildings = Building.starting(config)
      buildings_by_type = Map.new(buildings, &{&1.type, &1})
      %{config: config, buildings: buildings, buildings_by_type: buildings_by_type}
    end

    test "colours relate as same, neighbour or opposite on the pentagon" do
      assert Pentagon.relation(:green, :green) == :same
      assert Pentagon.relation(:green, :blue) == :neighbour
      assert Pentagon.relation(:green, :violet) == :neighbour
      assert Pentagon.relation(:green, :red) == :opposite
      assert Pentagon.relation(:green, :yellow) == :opposite
    end

    test "buildings take the colour of their path" do
      building_types = [:farm, :monastery, :watchtower, :market, :tavern]

      assert Enum.map(building_types, &building_colour/1) ==
               [:green, :blue, :red, :yellow, :violet]
    end

    test "untrained workers: same 100%, neighbour 80%, opposite 50%", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Production.worker_output(worker(:green), farm, config) == 15.0
      assert Production.worker_output(worker(:blue), farm, config) == 12.0
      assert Production.worker_output(worker(:red), farm, config) == 7.5
    end

    test "trained workers: same 125%, neighbour 60%, opposite 30%", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Production.worker_output(worker(:green, true), farm, config) == 18.75
      assert Production.worker_output(worker(:violet, true), farm, config) == 9.0
      assert Production.worker_output(worker(:yellow, true), farm, config) == 4.5
    end

    test "base production: farm 15, other buildings 3", context do
      %{config: config, buildings_by_type: buildings_by_type} = context

      assert Production.worker_output(worker(:blue), buildings_by_type.monastery, config) == 3.0
      assert Production.worker_output(worker(:red), buildings_by_type.watchtower, config) == 3.0
      assert Production.worker_output(worker(:yellow), buildings_by_type.market, config) == 3.0
      assert Production.worker_output(worker(:violet), buildings_by_type.tavern, config) == 3.0
    end

    test "weekly totals per product, decimals kept, unplaced workers produce nothing", context do
      %{config: config, buildings: buildings, buildings_by_type: buildings_by_type} = context
      farm_id = buildings_by_type.farm.id

      workers = [
        worker(:green, false, farm_id),
        worker(:red, false, farm_id),
        worker(:blue, false, buildings_by_type.monastery.id),
        worker(:yellow)
      ]

      assert Production.week(workers, buildings, 0, config) ==
               %{food: 22.5, knowledge: 3.0, defence: 0.0, gold: 0.0, entertainment: 0.0}
    end

    test "the game starts with one building of each type, all ready", %{config: config} do
      buildings = Building.starting(config)

      assert Enum.map(buildings, & &1.type) == [:farm, :monastery, :watchtower, :market, :tavern]
      assert Enum.all?(buildings, &Building.ready?(&1, 0))
    end

    test "a new building ordered in week N produces from week N+1", context do
      %{config: config, buildings: buildings} = context
      buildings = Building.construct(buildings, :farm, 5, config)
      new_farm = List.last(buildings)
      workers = [worker(:green, false, new_farm.id)]

      assert Production.week(workers, buildings, 5, config).food == 0.0
      assert Production.week(workers, buildings, 6, config).food == 15.0
    end

    test "buildings can be built without limit", %{config: config, buildings: buildings} do
      buildings =
        Enum.reduce(1..10, buildings, fn _, current_buildings ->
          Building.construct(current_buildings, :market, 0, config)
        end)

      building_ids = Enum.map(buildings, & &1.id)

      assert Enum.count(buildings, &(&1.type == :market)) == 11
      assert Enum.uniq(building_ids) == building_ids
    end

    test "a building holds 3 workers", %{config: config, buildings_by_type: %{farm: farm}} do
      two_workers = for _ <- 1..2, do: worker(:green, false, farm.id)
      three_workers = [worker(:green, false, farm.id) | two_workers]

      assert Building.has_room?(farm, two_workers, config)
      refute Building.has_room?(farm, three_workers, config)
    end
  end

  defp worker(colour, trained \\ false, building_id \\ nil),
    do: %Worker{colour: colour, trained: trained, building: building_id}

  defp building_colour(type), do: Building.colour(%Building{id: 0, type: type})
end
