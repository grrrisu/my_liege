defmodule MyLiege.Engine.SimSteps.DemandMadeTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, WeeklyReport, Worker}
  alias MyLiege.Engine.SimSteps.DemandMade
  alias MyLiege.EngineFixtures

  setup do
    start = %{Game.new(EngineFixtures.config(), 1) | demand_weeks: [1]}
    %{start: start}
  end

  test "the amount uses the population at the start of the week", %{start: start} do
    newborn = %Worker{id: 3, colour: :green, born_week: 1}
    now = %{start | week: 1, workers: start.workers ++ [newborn]}

    {game, report} = DemandMade.run(now, WeeklyReport.new(1, start))

    # 2 workers × 100‰ × 9 food (farm, green leads) × 8 weeks
    assert report.demand == %{product: :food, amount: 14_400, due_week: 9}
    assert game.demand == report.demand
  end

  test "no demand outside the demand weeks", %{start: start} do
    now = %{start | week: 2}
    report = WeeklyReport.new(2, start)

    assert DemandMade.run(now, report) == {now, report}
  end
end
