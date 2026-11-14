defmodule MyLiege.Engine.SimSteps.HuntsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place.{Blueprint, Expedition}
  alias MyLiege.Engine.SimSteps.Hunts
  alias MyLiege.Engine.{WeeklyReport, Worker}
  alias MyLiege.EngineFixtures

  # worker 2 (red) hunts alone on a hunt (id 3) returning at the end of week 18; always mid luck
  setup do
    config =
      EngineFixtures.config(
        travel_weeks: 1,
        way_hunting_party: %{
          1 => %{low: 0, mid: 10, high: 0},
          2 => %{low: 4, mid: 4, high: 2},
          3 => %{low: 2, mid: 4, high: 4},
          4 => %{low: 1, mid: 3, high: 6}
        }
      )

    game = EngineFixtures.game_without_demands(config, 1)
    hunt = %Expedition{id: 3, blueprint: Blueprint.fetch!(:hunting), return_week: 18}
    workers = Enum.map(game.workers, &if(&1.id == 2, do: %{&1 | place: 3}, else: &1))
    %{game: %{game | places: game.places ++ [hunt], workers: workers}}
  end

  test "in its return week the haul goes into the stock, the luck is drawn, the party travels back",
       %{game: game} do
    game = %{game | week: 18}
    {after_step, report} = Hunts.run(game, WeeklyReport.new(18, game))

    assert report.food_from_hunting == 180_000
    assert report.hunts_returned == [%{hunters: 1, luck: :mid, food: 180_000}]
    assert after_step.stocks.food == game.stocks.food + 180_000
    assert after_step.rand != game.rand
    refute Enum.any?(after_step.places, &(&1.id == 3))
    assert %Worker{place: nil, travel: 1} = Enum.find(after_step.workers, &(&1.id == 2))
  end

  test "before its return week nothing happens and nothing is drawn", %{game: game} do
    game = %{game | week: 17}
    {after_step, report} = Hunts.run(game, WeeklyReport.new(17, game))

    assert report.food_from_hunting == 0
    assert after_step == game
  end
end
