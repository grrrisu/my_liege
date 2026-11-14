defmodule MyLiege.Engine.Place.BlueprintTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Pentagon
  alias MyLiege.Engine.Place.Blueprint

  test "the five home places come first, in pentagon order, one per colour" do
    homes = Enum.take(Blueprint.all(), 5)

    assert Enum.map(homes, & &1.colour) == Pentagon.colours()
    assert Enum.map(homes, & &1.type) == Blueprint.home_types()

    for home <- homes do
      assert Blueprint.home_colour(home.good) == home.colour
      refute Blueprint.way?(home)
    end
  end

  test "types, home types and goods" do
    assert Blueprint.types() ==
             [
               :farm,
               :market,
               :monastery,
               :watchtower,
               :tavern,
               :granary,
               :plough,
               :grain_trade,
               :hunting,
               :guildhouse
             ]

    assert Blueprint.building_types() ==
             [:farm, :market, :monastery, :watchtower, :tavern, :granary, :guildhouse]

    assert Blueprint.home_type(:green) == :farm
    assert Blueprint.home_colour(:food) == :green
    assert Blueprint.goods() == [:food, :gold, :knowledge, :defence, :culture]
    assert Blueprint.fetch!(:guildhouse).colour == nil
  end

  test "R13: the ways come after the home places; a way's colour is not its good's home colour" do
    assert Enum.map(Blueprint.ways(), & &1.type) == [:granary, :plough, :grain_trade, :hunting]
    assert Blueprint.trade_types() == [:grain_trade]
    assert Blueprint.expedition_types() == [:hunting]

    assert %Blueprint{colour: :red, good: :food, engine: :expedition} =
             Blueprint.fetch!(:hunting)

    assert %Blueprint{colour: :yellow, good: :food, engine: :trade} =
             Blueprint.fetch!(:grain_trade)

    assert %Blueprint{colour: :violet, good: :food, engine: :building} =
             Blueprint.fetch!(:granary)

    assert %Blueprint{colour: :blue, good: :food, engine: :project} = Blueprint.fetch!(:plough)
    assert Enum.all?(Blueprint.ways(), &Blueprint.way?/1)
    refute Blueprint.way?(Blueprint.fetch!(:guildhouse))
  end
end
