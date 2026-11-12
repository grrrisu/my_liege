defmodule MyLiege.Engine.Place.BlueprintTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Pentagon
  alias MyLiege.Engine.Place.Blueprint

  test "the five home places come first, in pentagon order, one per colour" do
    homes = Enum.filter(Blueprint.all(), & &1.colour)

    assert Enum.map(homes, & &1.colour) == Pentagon.colours()
    assert Enum.take(Blueprint.all(), length(homes)) == homes

    for colour <- Pentagon.colours() do
      assert [_] = Enum.filter(Blueprint.all(), &(&1.colour == colour))
    end
  end

  test "types, home types and goods" do
    assert Blueprint.types() == [:farm, :market, :monastery, :watchtower, :tavern, :guildhouse]
    assert Blueprint.home_type(:green) == :farm
    assert Blueprint.goods() == [:food, :gold, :knowledge, :defence, :culture]
    assert Blueprint.fetch!(:guildhouse).colour == nil
    assert Enum.all?(Blueprint.all(), &(&1.engine == :building))
  end
end
