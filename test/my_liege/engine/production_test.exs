defmodule MyLiege.Engine.ProductionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Building, Pentagon, Production, Worker}
  alias MyLiege.EngineFixtures

  describe "R2: production by colour" do
    setup do
      config = EngineFixtures.config()
      buildings = all_building_types(config)
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

      assert Production.worker_output(worker(:green), farm, config) == 9_000
      assert Production.worker_output(worker(:blue), farm, config) == 7_200
      assert Production.worker_output(worker(:red), farm, config) == 4_500
    end

    test "trained workers: same 125%, neighbour 60%, opposite 30%", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Production.worker_output(worker(:green, true), farm, config) == 11_250
      assert Production.worker_output(worker(:violet, true), farm, config) == 5_400
      assert Production.worker_output(worker(:yellow, true), farm, config) == 2_700
    end

    test "each building has its own base production", context do
      %{buildings_by_type: buildings_by_type} = context

      config =
        EngineFixtures.config(
          base_production: %{farm: 9, monastery: 2, watchtower: 4, market: 3, tavern: 5}
        )

      assert Production.worker_output(worker(:blue), buildings_by_type.monastery, config) == 2_000
      assert Production.worker_output(worker(:red), buildings_by_type.watchtower, config) == 4_000
      assert Production.worker_output(worker(:yellow), buildings_by_type.market, config) == 3_000
      assert Production.worker_output(worker(:violet), buildings_by_type.tavern, config) == 5_000
    end

    test "weekly totals per product in thousandths, unplaced workers produce nothing", context do
      %{config: config, buildings: buildings, buildings_by_type: buildings_by_type} = context
      farm_id = buildings_by_type.farm.id

      workers = [
        worker(:green, false, farm_id),
        worker(:red, false, farm_id),
        worker(:blue, false, buildings_by_type.monastery.id),
        worker(:yellow)
      ]

      assert Production.week(workers, buildings, 0, config) ==
               %{food: 13_500, knowledge: 3_000, defence: 0, gold: 0, entertainment: 0}
    end

    test "the game starts with the farm and the tower (a watchtower), both ready" do
      buildings = Building.starting()

      assert Enum.map(buildings, & &1.type) == [:farm, :watchtower]
      assert Enum.all?(buildings, &Building.ready?(&1, 0))
    end

    test "a new building ordered in week N produces from week N + construction_weeks", context do
      %{config: config, buildings: buildings} = context
      buildings = Building.construct(buildings, :farm, 5, config)
      new_farm = List.last(buildings)
      workers = [worker(:green, false, new_farm.id)]

      assert Production.week(workers, buildings, 6, config).food == 0
      assert Production.week(workers, buildings, 7, config).food == 9_000
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

    test "each building has its own capacity", %{buildings_by_type: buildings_by_type} do
      config =
        EngineFixtures.config(
          capacity: %{farm: 4, monastery: 2, watchtower: 4, market: 4, tavern: 4}
        )

      %{farm: farm, monastery: monastery} = buildings_by_type
      three_farmers = for _ <- 1..3, do: worker(:green, false, farm.id)
      four_farmers = [worker(:green, false, farm.id) | three_farmers]
      two_monks = for _ <- 1..2, do: worker(:blue, false, monastery.id)

      assert Building.has_room?(farm, three_farmers, config)
      refute Building.has_room?(farm, four_farmers, config)
      refute Building.has_room?(monastery, two_monks, config)
    end
  end

  defp all_building_types(config) do
    Enum.reduce([:farm, :monastery, :watchtower, :market, :tavern], [], fn type, buildings ->
      Building.construct(buildings, type, -config.construction_weeks, config)
    end)
  end

  defp worker(colour, trained \\ false, building_id \\ nil),
    do: %Worker{colour: colour, trained: trained, building: building_id}

  defp building_colour(type), do: Building.colour(%Building{id: 0, type: type})
end
