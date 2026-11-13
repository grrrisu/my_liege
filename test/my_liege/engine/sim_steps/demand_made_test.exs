defmodule MyLiege.Engine.SimSteps.DemandMadeTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, WeeklyReport, Worker}
  alias MyLiege.Engine.Place.Project
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
    assert report.demand == %{product: :food, amount: 14_400, due_week: 9, project_id: nil}
    assert game.demand == report.demand
  end

  test "a knowledge demand opens its project at progress 0, shown in the report", context do
    %{start: start} = context
    start = %{start | manameter: %{start.manameter | green: 0, blue: 850}}

    {game, report} = DemandMade.run(%{start | week: 1}, WeeklyReport.new(1, start))

    # 2 workers × 100‰ × 3 knowledge (monastery, blue leads) × 8 weeks
    assert game.demand == %{product: :knowledge, amount: 4_800, due_week: 9, project_id: 3}

    assert %Project{id: 3, target: 4_800, gives: {:demand, 9}, progress: 0} =
             List.last(game.places)

    assert report.demand_progress == 0
  end

  test "no demand outside the demand weeks", %{start: start} do
    now = %{start | week: 2}
    report = WeeklyReport.new(2, start)

    assert DemandMade.run(now, report) == {now, report}
  end
end
