defmodule MyLiege.Engine.Actions.ConstructTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.Construct
  alias MyLiege.Engine.Place
  alias MyLiege.Engine.Place.{Blueprint, Building}
  alias MyLiege.EngineFixtures

  # 100 gold, build_cost_gold 30
  setup do
    %{game: EngineFixtures.game_without_demands(EngineFixtures.config(), 1)}
  end

  test "adds a site with the next id", %{game: game} do
    assert {:ok, game} = Construct.run(game, :market)

    assert %Building{id: 3, blueprint: %{type: :market}, ready_week: nil, progress: 0} =
             List.last(game.places)
  end

  test "pays build_cost_gold at once and adds it to the current report", %{game: game} do
    assert {:ok, game} = Construct.run(game, :market)
    assert {:ok, game} = Construct.run(game, :tavern)

    assert game.stocks.gold == 40_000
    assert game.report.gold_spent_buildings == 60_000
    # the report stays the current week's; its end-of-week gold is not rewritten
    assert game.report.week == 0
    assert game.report.gold == 100_000
  end

  test "every type costs the same, the guildhouse included", %{game: game} do
    for type <- Blueprint.types() do
      assert {:ok, built} = Construct.run(game, type)
      assert built.stocks.gold == 70_000
    end
  end

  test "any number of buildings can be ordered, also of the same type", %{game: game} do
    {:ok, game} = Construct.run(game, :market)
    {:ok, game} = Construct.run(game, :market)

    assert Enum.map(game.places, &Place.type/1) == [:farm, :watchtower, :market, :market]
  end

  test "exactly the price is enough", %{game: game} do
    game = %{game | stocks: %{game.stocks | gold: 30_000}}

    assert {:ok, %{stocks: %{gold: 0}}} = Construct.run(game, :farm)
  end

  test "less gold than the price is refused", %{game: game} do
    game = %{game | stocks: %{game.stocks | gold: 29_999}}

    assert Construct.run(game, :farm) == {:error, :not_enough_gold}
  end

  test "an unknown type is refused", %{game: game} do
    assert Construct.run(game, :castle) == {:error, :unknown_type}
  end
end
