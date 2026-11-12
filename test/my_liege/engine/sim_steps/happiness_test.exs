defmodule MyLiege.Engine.SimSteps.HappinessTest do
  @moduledoc "R11 happiness inside step 1 (production), across the week."
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Building, Game, Worker}
  alias MyLiege.EngineFixtures

  # a farmer (9 food) and a soldier (3 defence) as at the start; steps of 10/20/30%
  defp config(overrides \\ []) do
    EngineFixtures.config(
      [
        king_grace_weeks: 1,
        start_food: 1_000,
        happiness_change: %{level1: 100, level2: 200, level3: 300}
      ] ++ overrides
    )
  end

  # adds a tavern with `count` violet workers (3 culture each)
  defp with_tavern(game, count) do
    tavern = %Building{id: 10, type: :tavern}
    workers = for i <- 1..count//1, do: %Worker{id: 100 + i, colour: :violet, building: 10}
    %{game | buildings: game.buildings ++ [tavern], workers: game.workers ++ workers}
  end

  test "no tavern: −3 after the grace period, food and defence production down 30%" do
    game = EngineFixtures.game_without_demands(config(), 1)
    {[week_1, week_2], _game} = EngineFixtures.run_weeks(game, 2)

    assert week_1.happiness == %{ratio: 0, step: 0, step_without_grace: -3}

    assert week_1.production.food == 9_000
    assert week_1.production.defence == 3_000

    assert week_2.happiness == %{ratio: 0, step: -3, step_without_grace: -3}
    assert week_2.production.food == 6_300
    assert week_2.production.defence == 2_100
    assert week_2.production.gold == 0
  end

  test "the population is every worker, also unplaced ones" do
    # 2 tavern workers make 6 culture for 4 workers (+1 unplaced = 5): 1200, neutral
    game = config() |> EngineFixtures.game_without_demands(1) |> with_tavern(2)
    game = %{game | workers: game.workers ++ [%Worker{id: 200, colour: :green}]}
    {:ok, report, _game} = Game.run_week(%{game | week: 1})

    assert report.happiness.ratio == 1_200
    assert report.happiness.step == 0
    assert report.production.food == 9_000
  end

  test "a bonus raises food and defence; the stocks and protected gold use the changed values" do
    # 4 tavern workers make 12 culture for 6 workers: 2000, +2
    game =
      config(bandit_cover_weeks: 20) |> EngineFixtures.game_without_demands(1) |> with_tavern(4)

    {:ok, report, game} = Game.run_week(%{game | week: 1})

    assert report.happiness.ratio == 2_000
    assert report.happiness.step == 2
    assert report.production.food == 10_800
    assert report.production.defence == 3_600
    assert report.production.culture == 12_000
    assert game.stocks.defence == 3_600
    assert report.bandit_protected == 72_000
    # 1000 + 10.8 - 6 × 3 eaten
    assert report.food_left == 992_800
  end

  test "culture going into a project counts" do
    game = config() |> EngineFixtures.game_without_demands(1) |> with_tavern(4)
    project = %{product: :culture, amount: 100_000, due_week: 8, progress: 0}
    {:ok, report, game} = Game.run_week(%{game | week: 1, demand: project})

    assert game.stocks.culture == 0
    assert report.demand_progress == 12_000
    assert report.happiness.ratio == 2_000
  end

  test "the culture stock doesn't count" do
    game = EngineFixtures.game_without_demands(config(), 1)
    game = %{game | week: 1, stocks: %{game.stocks | culture: 1_000_000}}
    {:ok, report, _game} = Game.run_week(game)

    assert report.happiness.ratio == 0
    assert report.happiness.step == -3
  end
end
