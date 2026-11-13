defmodule MyLiege.Engine.Rules.StaffingTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Rules.Staffing
  alias MyLiege.Engine.Worker
  alias MyLiege.EngineFixtures

  setup do
    farm = EngineFixtures.new_building(1, :farm)
    tavern = EngineFixtures.new_building(2, :tavern)
    guildhouse = EngineFixtures.new_building(3, :guildhouse)
    site = EngineFixtures.new_site(4, :market)
    %{places: [farm, tavern, guildhouse, site], farm: farm, site: site}
  end

  test "pairs an arrived worker with its building", %{places: places, farm: farm} do
    worker = worker(farm.id)

    assert Staffing.working([worker], places, 0) == [{worker, farm}]
  end

  test "a travelling or unplaced worker doesn't work", %{places: places, farm: farm} do
    assert Staffing.working([%{worker(farm.id) | travel: 1}, worker(nil)], places, 0) == []
  end

  test "workers in the guildhouse or on a site don't work", %{places: places} do
    assert Staffing.working([worker(3), worker(4)], places, 99) == []
  end

  describe "works?/2" do
    test "a path building works; the guildhouse and a site don't", context do
      %{farm: farm, site: site} = context

      assert Staffing.works?(farm, 0)
      refute Staffing.works?(EngineFixtures.new_building(3, :guildhouse), 0)
      refute Staffing.works?(site, 0)
      refute Staffing.works?(EngineFixtures.new_site(5, :farm, progress: 1), 99)
    end

    test "a book works, like a blue building" do
      assert Staffing.works?(EngineFixtures.new_book(6, :violet), 0)
    end

    test "an invention works, like a blue building; a granary works though it produces nothing" do
      assert Staffing.works?(EngineFixtures.new_invention(6, :plough), 0)
      assert Staffing.works?(EngineFixtures.new_building(7, :granary), 0)
    end

    test "a king's demand project works, like a building of its colour" do
      assert Staffing.works?(EngineFixtures.new_demand_project(6, :knowledge), 0)
    end
  end

  test "a worker on a demand project works; a builder on a site doesn't", %{places: places} do
    project = EngineFixtures.new_demand_project(5, :culture)
    on_project = worker(5)

    assert Staffing.working([on_project, worker(4)], places ++ [project], 0) ==
             [{on_project, project}]
  end

  defp worker(place_id), do: %Worker{colour: :green, place: place_id}
end
