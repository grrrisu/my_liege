defmodule MyLiege.Engine.SimSteps.EndOfWeekTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, WeeklyReport}
  alias MyLiege.Engine.SimSteps.{EndOfWeek, Spoilage}
  alias MyLiege.EngineFixtures

  test "food and gold are the values after spoilage; start is cleared" do
    rates = %{food: 500, knowledge: 0, defence: 0, gold: 100, culture: 0}
    start = Game.new(EngineFixtures.config(good_spoilage: rates), 1)
    now = %{start | week: 1}

    {game, report} = Spoilage.run(now, WeeklyReport.new(1, start))
    {_game, report} = EndOfWeek.run(game, report)

    # 24 food − 50%, 100 gold − 10%
    assert report.food_left == 12_000
    assert report.gold == 90_000
    assert report.start == nil
  end
end
