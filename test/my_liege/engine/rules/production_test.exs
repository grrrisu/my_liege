defmodule MyLiege.Engine.Rules.ProductionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Place, Worker}
  alias MyLiege.Engine.Rules.Production
  alias MyLiege.EngineFixtures

  describe "R2: production by colour" do
    setup do
      config = EngineFixtures.config()
      buildings = all_building_types()
      buildings_by_type = Map.new(buildings, &{Place.type(&1), &1})
      %{config: config, buildings: buildings, buildings_by_type: buildings_by_type}
    end

    test "untrained workers: same 100%, neighbour 80%, opposite 50%", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Production.worker_output(worker(:green), farm, config) == 9_000
      assert Production.worker_output(worker(:yellow), farm, config) == 7_200
      assert Production.worker_output(worker(:blue), farm, config) == 4_500
    end

    test "trained workers: same 125%, neighbour 60%, opposite 30%", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Production.worker_output(worker(:green, true), farm, config) == 11_250
      assert Production.worker_output(worker(:violet, true), farm, config) == 5_400
      assert Production.worker_output(worker(:red, true), farm, config) == 2_700
    end

    test "each building has its own base production", context do
      %{buildings_by_type: buildings_by_type} = context

      config =
        EngineFixtures.config(
          place_output_per_worker: %{farm: 9, monastery: 2, watchtower: 4, market: 3, tavern: 5}
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

      assert Production.output(workers, buildings, 0, config) ==
               %{food: 13_500, knowledge: 3_000, defence: 0, gold: 0, culture: 0}
    end

    test "a site produces nothing; the building that replaces it does", context do
      %{config: config, buildings: buildings} = context
      site = EngineFixtures.new_site(Place.next_id(buildings), :farm, progress: 1)
      workers = [worker(:green, false, site.id)]

      assert Production.output(workers, buildings ++ [site], 99, config).food == 0

      farm = EngineFixtures.new_building(site.id, :farm)
      assert Production.output(workers, buildings ++ [farm], 99, config).food == 9_000
    end

    test "a worker still travelling produces nothing", context do
      %{config: config, buildings: buildings, buildings_by_type: %{farm: farm}} = context
      workers = [%{worker(:green, false, farm.id) | travel: 1}]

      assert Production.output(workers, buildings, 0, config).food == 0
    end
  end

  defp all_building_types do
    [:farm, :monastery, :watchtower, :market, :tavern]
    |> Enum.with_index(1)
    |> Enum.map(fn {type, id} -> EngineFixtures.new_building(id, type) end)
  end

  defp worker(colour, trained \\ false, place_id \\ nil),
    do: %Worker{colour: colour, trained: trained, place: place_id}
end
