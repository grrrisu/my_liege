defmodule MyLiege.Engine.SimSteps.TradesTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place.{Blueprint, Trade}
  alias MyLiege.Engine.SimSteps.Trades
  alias MyLiege.Engine.{WeeklyReport, Worker}
  alias MyLiege.EngineFixtures

  # worker 1 trades on a grain trade (id 3) returning at the end of week 18; 1 week of travel
  setup do
    config = EngineFixtures.config(travel_weeks: 1)
    game = EngineFixtures.game_without_demands(config, 1)
    trade = %Trade{id: 3, blueprint: Blueprint.fetch!(:grain_trade), return_week: 18}
    workers = Enum.map(game.workers, &if(&1.id == 1, do: %{&1 | place: 3}, else: &1))
    %{game: %{game | places: game.places ++ [trade], workers: workers}}
  end

  test "in its return week the food goes into the stock and the trader travels back",
       %{game: game} do
    game = %{game | week: 18}
    {after_step, report} = Trades.run(game, WeeklyReport.new(18, game))

    assert report.food_from_trade == 480_000
    assert after_step.stocks.food == game.stocks.food + 480_000
    refute Enum.any?(after_step.places, &(&1.id == 3))
    assert %Worker{place: nil, travel: 1} = Enum.find(after_step.workers, &(&1.id == 1))
  end

  test "before its return week nothing happens", %{game: game} do
    game = %{game | week: 17}
    {after_step, report} = Trades.run(game, WeeklyReport.new(17, game))

    assert report.food_from_trade == 0
    assert after_step == game
  end
end
