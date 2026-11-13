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

  test "the game starts with the farm and the tower (a watchtower)" do
    buildings = Building.starting()

    assert Enum.map(buildings, &Place.type/1) == [:farm, :watchtower]
    assert Enum.map(buildings, & &1.id) == [1, 2]
  end

  test "next_id is one more than the highest id over all places" do
    places = [EngineFixtures.new_building(1, :farm), EngineFixtures.new_site(4, :market)]

    assert Place.next_id(places) == 5
    assert Place.next_id([]) == 1
  end

  test "workers_at lists the workers placed at a place" do
    workers = [%{id: 1, place: 1}, %{id: 2, place: 2}, %{id: 3, place: 1}, %{id: 4, place: nil}]

    assert Enum.map(Place.workers_at(workers, 1), & &1.id) == [1, 3]
    assert Enum.map(Place.workers_at(workers, nil), & &1.id) == [4]
  end
end
