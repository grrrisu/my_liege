defmodule MyLiege.Engine.SimSteps.TaxCountTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.SimSteps.TaxCount
  alias MyLiege.Engine.{WeeklyReport, Worker}
  alias MyLiege.EngineFixtures

  # due in week 24, counted 4 weeks earlier
  @count_week 20

  setup do
    %{start: EngineFixtures.game_without_demands(EngineFixtures.config(), 1)}
  end

  test "counts the workers at the start of the week", %{start: start} do
    now = %{start | week: @count_week, workers: start.workers ++ [%Worker{id: 3, colour: :red}]}

    {game, report} = TaxCount.run(now, WeeklyReport.new(@count_week, start))

    # 2 workers × 10 gold
    assert report.tax_due == 20_000
    assert game.tax_due == 20_000
  end

  test "outside a count week nothing changes", %{start: start} do
    now = %{start | week: @count_week + 1}
    report = WeeklyReport.new(@count_week + 1, start)

    assert TaxCount.run(now, report) == {now, report}
  end
end
