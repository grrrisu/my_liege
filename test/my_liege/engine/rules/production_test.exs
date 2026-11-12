defmodule MyLiege.Engine.Rules.ProductionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Manameter, Place, Worker}
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
      site = buildings |> Place.next_id() |> EngineFixtures.new_site(:farm, progress: 1)
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

  describe "R7: production on a king's demand project" do
    setup do
      config = EngineFixtures.config()
      tavern = EngineFixtures.new_building(1, :tavern)
      project = EngineFixtures.new_demand_project(2, :culture)
      %{config: config, tavern: tavern, project: project}
    end

    test "a worker produces as in a building of the project's colour and good", context do
      %{config: config, tavern: tavern, project: project} = context

      for worker <- [worker(:violet), worker(:violet, true), worker(:blue), worker(:green, true)] do
        assert Production.worker_output(worker, project, config) ==
                 Production.worker_output(worker, tavern, config)
      end

      # same colour 100% of 3, opposite (blue on violet) 50%
      assert Production.worker_output(worker(:violet), project, config) == 3_000
      assert Production.worker_output(worker(:blue), project, config) == 1_500
    end

    test "its output goes to project_output, not to the stock's output", context do
      %{config: config, tavern: tavern, project: project} = context
      workers = [worker(:violet, false, 2), worker(:blue, false, 2), worker(:violet, false, 1)]
      places = [tavern, project]

      assert Production.output(workers, places, 1, config).culture == 3_000

      assert Production.project_output(workers, places, 1, config.manameter_start, config) == %{
               2 => 4_500
             }
    end

    test "builders on a site produce nothing anywhere", %{config: config} do
      site = EngineFixtures.new_site(3, :tavern)
      workers = [worker(:violet, false, 3)]

      assert Production.output(workers, [site], 1, config).culture == 0
      assert Production.project_output(workers, [site], 1, config.manameter_start, config) == %{}
    end
  end

  describe "R12: writing a book" do
    # Manameter at the start of the week: green 30%, red 10%
    setup do
      config = EngineFixtures.config()
      manameter = %Manameter{green: 300, yellow: 100, blue: 200, red: 100, violet: 300}
      monastery = EngineFixtures.new_building(1, :monastery)
      %{config: config, manameter: manameter, monastery: monastery}
    end

    test "a worker writes as in a blue building, times the book colour's experience", context do
      %{config: config, manameter: manameter, monastery: monastery} = context
      green_book = EngineFixtures.new_book(2, :green)
      red_book = EngineFixtures.new_book(3, :red)
      monk = worker(:blue, false, 2)
      farmer = worker(:green, false, 3)
      places = [monastery, green_book, red_book]

      # as in the monastery before experience: monk 3, farmer (opposite) 1.5
      assert Production.worker_output(monk, green_book, config) ==
               Production.worker_output(monk, monastery, config)

      assert Production.worker_output(farmer, red_book, config) == 1_500

      # monk on green (×1.5): 4.5; farmer on red (×0.5): 0.75
      assert Production.project_output([monk, farmer], places, 1, manameter, config) ==
               %{2 => 4_500, 3 => 750}

      # nothing to the stock
      assert Production.output([monk, farmer], places, 1, config).knowledge == 0
    end
  end

  defp worker(colour, trained \\ false, place_id \\ nil),
    do: %Worker{colour: colour, trained: trained, place: place_id}
end
