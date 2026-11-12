defmodule MyLiege.Engine.Place.BuildingTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place
  alias MyLiege.Engine.Place.Building
  alias MyLiege.EngineFixtures

  test "buildings take the colour of their path" do
    building_types = [:farm, :monastery, :watchtower, :market, :tavern]

    assert Enum.map(building_types, &Place.colour(EngineFixtures.new_building(0, &1))) ==
             [:green, :blue, :red, :yellow, :violet]
  end

  test "the guildhouse is neutral and makes no good" do
    guildhouse = EngineFixtures.new_building(0, :guildhouse)

    assert Place.neutral?(guildhouse)
    assert Place.good(guildhouse) == nil
    refute Place.neutral?(EngineFixtures.new_building(0, :farm))
    assert Place.good(EngineFixtures.new_building(0, :farm)) == :food
  end

  test "the game starts with the farm and the tower (a watchtower), both ready" do
    buildings = Building.starting()

    assert Enum.map(buildings, &Place.type/1) == [:farm, :watchtower]
    assert Enum.all?(buildings, &Building.ready?(&1, 0))
  end

  test "an added site is not ready and has no progress" do
    site = Building.starting() |> Building.add_site(:market) |> List.last()

    assert %Building{id: 3, ready_week: nil, progress: 0} = site
    assert Building.site?(site)
    refute Building.ready?(site, 99)
  end

  test "buildings can be built without limit" do
    buildings =
      Enum.reduce(1..10, Building.starting(), fn _, current_buildings ->
        Building.add_site(current_buildings, :market)
      end)

    building_ids = Enum.map(buildings, & &1.id)

    assert Enum.count(buildings, &(Place.type(&1) == :market)) == 10
    assert Enum.uniq(building_ids) == building_ids
  end

  test "workers_at lists the workers placed at a place" do
    workers = [%{id: 1, place: 1}, %{id: 2, place: 2}, %{id: 3, place: 1}, %{id: 4, place: nil}]

    assert Enum.map(Place.workers_at(workers, 1), & &1.id) == [1, 3]
    assert Enum.map(Place.workers_at(workers, nil), & &1.id) == [4]
  end
end
