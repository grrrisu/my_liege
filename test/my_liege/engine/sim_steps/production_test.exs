defmodule MyLiege.Engine.SimSteps.ProductionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.SimSteps.Production
  alias MyLiege.Engine.{WeeklyReport, Worker}
  alias MyLiege.EngineFixtures

  # a blue worker in a monastery makes 3 knowledge a week
  setup do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
    monastery = EngineFixtures.new_building(3, :monastery)
    monk = %Worker{id: 3, colour: :blue, place: 3}
    project = %{product: :knowledge, amount: 4_000, due_week: 5, progress: 2_000}

    %{
      game: %{
        game
        | places: game.places ++ [monastery],
          workers: game.workers ++ [monk],
          demand: project
      }
    }
  end

  test "an open project receives its product up to the amount, the stock the rest", %{game: game} do
    {game, report} = Production.run(%{game | week: 1}, WeeklyReport.new(1, game))

    assert game.demand.progress == 4_000
    assert report.demand_progress == 4_000
    assert report.production.knowledge == 3_000
    assert game.stocks.knowledge == 1_000
  end

  test "a refused project receives nothing", %{game: game} do
    game = %{game | deliver_demand: false}

    {game, report} = Production.run(%{game | week: 1}, WeeklyReport.new(1, game))

    assert game.demand.progress == 2_000
    assert report.demand_progress == nil
    assert game.stocks.knowledge == 3_000
  end
end
