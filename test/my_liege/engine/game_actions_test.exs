defmodule MyLiege.Engine.GameActionsTest do
  use ExUnit.Case, async: true

  # Player actions through `Game`, followed by the next week. What each action does on its
  # own is unit-tested in test/my_liege/engine/actions/.

  alias MyLiege.Engine.{Game, Worker}
  alias MyLiege.EngineFixtures

  setup do
    %{game: after_week_1(EngineFixtures.config())}
  end

  test "an unplaced worker can be placed and works from the next week", %{game: game} do
    {:ok, game} = Game.place_worker(game, 3, 1)
    {:ok, report, _game} = Game.run_week(game)

    assert %Worker{building: 1} = find_worker(game, 3)
    assert report.production.food > 9_000
  end

  test "the gold for a building is gone before the next week's production", %{game: game} do
    {:ok, game} = Game.construct(game, :market)
    {:ok, report, _game} = Game.run_week(game)

    assert report.gold == 70_000 + report.production.gold
    assert report.gold_spent_buildings == 0
  end

  test "a finished building takes workers who produce from the next week", %{game: game} do
    # no builders needed: ordered at week 1, built in weeks 2 and 3, produces from week 4
    {:ok, game} = Game.construct(game, :market)
    market = List.last(game.buildings)
    {_reports, game} = EngineFixtures.run_weeks(game, 2)
    {:ok, game} = Game.place_worker(game, 3, market.id)
    {:ok, report, _game} = Game.run_week(game)

    assert report.week == 4
    assert report.production.gold > 0
  end

  defp find_worker(game, id), do: Enum.find(game.workers, &(&1.id == id))

  # week 1 brings a newborn (id 3), unplaced
  defp after_week_1(config) do
    {:ok, _report, game} = config |> Game.new(1) |> Game.run_week()
    game
  end
end
