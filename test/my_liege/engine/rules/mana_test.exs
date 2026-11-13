defmodule MyLiege.Engine.Rules.ManaTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Place, Worker}
  alias MyLiege.Engine.Place.Building
  alias MyLiege.Engine.Rules.Mana
  alias MyLiege.EngineFixtures

  describe "R3: mana per worker" do
    setup do
      config = EngineFixtures.config()
      buildings = Building.starting()
      buildings_by_type = Map.new(buildings, &{Place.type(&1), &1})
      %{config: config, buildings: buildings, buildings_by_type: buildings_by_type}
    end

    test "untrained: 2 in the building's colour, 1 in their own", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Mana.worker_mana(worker(:red), farm, config) == %{green: 2, red: 1}
    end

    test "trained: 1 in the building's colour, 2 in their own", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Mana.worker_mana(worker(:red, true), farm, config) == %{green: 1, red: 2}
    end

    test "same colour gives 3 of that colour, trained or not", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Mana.worker_mana(worker(:green), farm, config) == %{green: 3}
      assert Mana.worker_mana(worker(:green, true), farm, config) == %{green: 3}
    end

    test "weekly totals per colour; unplaced workers make no mana", context do
      %{config: config, buildings: buildings, buildings_by_type: buildings_by_type} = context

      workers = [
        worker(:green, false, buildings_by_type.farm.id),
        worker(:red, false, buildings_by_type.farm.id),
        worker(:blue, true, buildings_by_type.watchtower.id),
        worker(:violet)
      ]

      assert Mana.produced(workers, buildings, 0, config) ==
               %{green: 5, blue: 2, red: 2, yellow: 0, violet: 0}
    end
  end

  describe "R7: mana on a king's demand project" do
    test "the same mana as in a building of the project's colour; none on a site" do
      config = EngineFixtures.config()
      tavern = EngineFixtures.new_building(1, :tavern)
      project = EngineFixtures.new_demand_project(2, :culture)

      for worker <- [worker(:violet), worker(:red), worker(:green, true)] do
        assert Mana.worker_mana(worker, project, config) ==
                 Mana.worker_mana(worker, tavern, config)
      end

      assert Mana.worker_mana(worker(:red), project, config) == %{violet: 2, red: 1}

      on_project = %{worker(:red) | place: 2}
      on_site = %{worker(:red) | place: 3}
      site = EngineFixtures.new_site(3, :farm)

      assert Mana.produced([on_project, on_site], [project, site], 1, config) ==
               %{green: 0, yellow: 0, blue: 0, red: 1, violet: 2}
    end
  end

  describe "R12: mana on a book" do
    test "the same mana as in a blue building, whatever the book's colour" do
      config = EngineFixtures.config()
      monastery = EngineFixtures.new_building(1, :monastery)
      book = EngineFixtures.new_book(2, :red)

      for worker <- [worker(:blue), worker(:green), worker(:red, true)] do
        assert Mana.worker_mana(worker, book, config) ==
                 Mana.worker_mana(worker, monastery, config)
      end

      assert Mana.worker_mana(worker(:green), book, config) == %{blue: 2, green: 1}
    end
  end

  defp worker(colour, trained \\ false, place_id \\ nil),
    do: %Worker{colour: colour, trained: trained, place: place_id}
end
