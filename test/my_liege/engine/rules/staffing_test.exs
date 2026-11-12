defmodule MyLiege.Engine.Rules.StaffingTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Rules.Staffing
  alias MyLiege.Engine.Worker
  alias MyLiege.EngineFixtures

  setup do
    farm = EngineFixtures.new_building(1, :farm)
    tavern = EngineFixtures.new_building(2, :tavern, ready_week: 5)
    guildhouse = EngineFixtures.new_building(3, :guildhouse)
    site = EngineFixtures.new_building(4, :market, ready_week: nil)
    %{places: [farm, tavern, guildhouse, site], farm: farm, tavern: tavern}
  end

  test "pairs an arrived worker with its ready place", %{places: places, farm: farm} do
    worker = worker(farm.id)

    assert Staffing.working([worker], places, 0) == [{worker, farm}]
  end

  test "a travelling or unplaced worker doesn't work", %{places: places, farm: farm} do
    assert Staffing.working([%{worker(farm.id) | travel: 1}, worker(nil)], places, 0) == []
  end

  test "a place not ready yet has no one working", %{places: places, tavern: tavern} do
    worker = worker(tavern.id)

    assert Staffing.working([worker], places, 4) == []
    assert Staffing.working([worker], places, 5) == [{worker, tavern}]
  end

  test "workers in the guildhouse or on a site don't work", %{places: places} do
    assert Staffing.working([worker(3), worker(4)], places, 99) == []
  end

  defp worker(place_id), do: %Worker{colour: :green, place: place_id}
end
