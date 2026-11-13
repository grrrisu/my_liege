defmodule MyLiege.Engine.Rules.ManaTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Place, Worker}
  alias MyLiege.Engine.Place.Building
  alias MyLiege.Engine.Rules.Mana
  alias MyLiege.EngineFixtures

  describe "R3: mana per working worker" do
    setup do
      config = EngineFixtures.config()
      buildings = Building.starting()
      buildings_by_type = Map.new(buildings, &{Place.type(&1), &1})
      %{config: config, buildings: buildings, buildings_by_type: buildings_by_type}
    end

    test "a home place gives place and good colour mana to its own colour: 3", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Mana.worker_mana(farm, config) == %{green: 3}
    end

    test "a way gives 2 in its colour and 1 in the colour of its good's home place" do
      config = EngineFixtures.config()

      assert Mana.worker_mana(EngineFixtures.new_building(1, :granary), config) ==
               %{violet: 2, green: 1}

      assert Mana.worker_mana(EngineFixtures.new_invention(2, :plough), config) ==
               %{blue: 2, green: 1}
    end

    test "uses mana.place_colour and mana.good_colour" do
      config = EngineFixtures.config(mana_place_colour: 5, mana_good_colour: 7)

      assert Mana.worker_mana(EngineFixtures.new_building(1, :granary), config) ==
               %{violet: 5, green: 7}

      assert Mana.worker_mana(EngineFixtures.new_building(2, :tavern), config) == %{violet: 12}
    end

    test "weekly totals per colour; the worker's colour and training play no part; unplaced and travelling workers make none",
         context do
      %{config: config, buildings: buildings, buildings_by_type: buildings_by_type} = context

      workers = [
        worker(:green, false, buildings_by_type.farm.id),
        worker(:red, false, buildings_by_type.farm.id),
        worker(:blue, true, buildings_by_type.watchtower.id),
        %{worker(:red, false, buildings_by_type.watchtower.id) | travel: 1},
        worker(:violet)
      ]

      assert Mana.produced(workers, buildings, 0, config) ==
               %{green: 6, blue: 0, red: 3, yellow: 0, violet: 0}
    end
  end

  describe "R7: mana on a king's demand project" do
    test "the same mana as in a building of the project's colour; none on a site" do
      config = EngineFixtures.config()
      tavern = EngineFixtures.new_building(1, :tavern)
      project = EngineFixtures.new_demand_project(2, :culture)

      assert Mana.worker_mana(project, config) == Mana.worker_mana(tavern, config)

      on_project = %{worker(:red) | place: 2}
      on_site = %{worker(:red) | place: 3}
      site = EngineFixtures.new_site(3, :farm)

      assert Mana.produced([on_project, on_site], [project, site], 1, config) ==
               %{green: 0, yellow: 0, blue: 0, red: 0, violet: 3}
    end
  end

  describe "R12: mana on a book" do
    test "the same mana as in a blue building, whatever the book's colour" do
      config = EngineFixtures.config()
      monastery = EngineFixtures.new_building(1, :monastery)

      for colour <- [:red, :green, :violet] do
        assert Mana.worker_mana(EngineFixtures.new_book(2, colour), config) ==
                 Mana.worker_mana(monastery, config)
      end
    end
  end

  describe "R14: mana in a granary" do
    test "a keeper makes mana though he produces nothing" do
      config = EngineFixtures.config()
      granary = EngineFixtures.new_building(1, :granary)

      assert Mana.produced([worker(:red, false, 1)], [granary], 1, config) ==
               %{green: 1, yellow: 0, blue: 0, red: 0, violet: 2}
    end
  end

  defp worker(colour, trained \\ false, place_id \\ nil),
    do: %Worker{colour: colour, trained: trained, place: place_id}
end
