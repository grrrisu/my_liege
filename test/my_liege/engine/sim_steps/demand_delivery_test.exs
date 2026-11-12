defmodule MyLiege.Engine.SimSteps.DemandDeliveryTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, WeeklyReport, Worker}
  alias MyLiege.Engine.SimSteps.DemandDelivery
  alias MyLiege.EngineFixtures

  # week 2; a knowledge project (id 3, target 4, due week 5) with worker 1 on it; 1 week of
  # travel
  setup do
    config = EngineFixtures.config(travel_weeks: 1)
    game = EngineFixtures.game_without_demands(config, 1)
    game = EngineFixtures.open_demand(%{game | week: 2}, :knowledge, 4_000, 5)
    workers = Enum.map(game.workers, &if(&1.id == 1, do: %{&1 | place: 3}, else: &1))
    %{game: %{game | workers: workers}}
  end

  test "an open project short of its target waits for its deadline", %{game: game} do
    report = WeeklyReport.new(2, game)

    assert DemandDelivery.run(game, report) == {game, report}
  end

  test "delivered in the week the target is reached, before the deadline", %{game: game} do
    game = with_progress(game, 4_000)

    {game, report} = DemandDelivery.run(game, WeeklyReport.new(2, game))

    assert report.demand_outcome == :delivered
    assert game.demand == nil
    assert game.misses == 0
    refute Enum.any?(game.places, &(&1.id == 3))
    assert %Worker{place: nil, travel: 1} = find_worker(game, 1)
  end

  test "missed at the deadline; the workers are released", %{game: game} do
    game = with_progress(%{game | week: 5}, 3_999)

    {game, report} = DemandDelivery.run(game, WeeklyReport.new(5, game))

    assert report.demand_outcome == :missed
    assert game.misses == 1
    refute Enum.any?(game.places, &(&1.id == 3))
    assert %Worker{place: nil, travel: 1} = find_worker(game, 1)
  end

  test "a refused project is settled before its deadline and counts as a miss", %{game: game} do
    {:ok, game} = Game.refuse_project(game)

    {game, report} = DemandDelivery.run(game, WeeklyReport.new(2, game))

    assert report.demand_outcome == :refused
    assert game.demand == nil
    assert game.deliver_demand == nil
    assert game.misses == 1
  end

  defp with_progress(game, progress),
    do: %{
      game
      | places: Enum.map(game.places, &if(&1.id == 3, do: %{&1 | progress: progress}, else: &1))
    }

  defp find_worker(game, id), do: Enum.find(game.workers, &(&1.id == id))
end
