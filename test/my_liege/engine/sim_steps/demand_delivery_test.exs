defmodule MyLiege.Engine.SimSteps.DemandDeliveryTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.SimSteps.DemandDelivery
  alias MyLiege.Engine.WeeklyReport
  alias MyLiege.EngineFixtures

  setup do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
    project = %{product: :knowledge, amount: 4_000, due_week: 5, progress: 1_000}
    %{game: %{game | week: 2, demand: project}}
  end

  test "an open project waits for its deadline", %{game: game} do
    report = WeeklyReport.new(2, game)

    assert DemandDelivery.run(game, report) == {game, report}
  end

  test "a refused project is settled before its deadline and counts as a miss", %{game: game} do
    game = %{game | deliver_demand: false}

    {game, report} = DemandDelivery.run(game, WeeklyReport.new(2, game))

    assert report.demand_outcome == :refused
    assert game.demand == nil
    assert game.deliver_demand == nil
    assert game.misses == 1
  end
end
