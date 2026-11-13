defmodule MyLiege.Engine.GameActionsTest do
  use ExUnit.Case, async: true

  # Player actions through `Game`, followed by the next week. What each action does on its
  # own is unit-tested in test/my_liege/engine/actions/.

  alias MyLiege.Engine.{Game, Manameter, Worker}
  alias MyLiege.EngineFixtures

  setup do
    %{game: after_week_1(EngineFixtures.config())}
  end

  test "an unplaced worker can be placed and works from the next week", %{game: game} do
    {:ok, game} = Game.place_worker(game, 3, 1)
    {:ok, report, _game} = Game.run_week(game)

    assert %Worker{place: 1} = find_worker(game, 3)
    assert report.production.food > 9_000
  end

  test "the gold for a building is gone before the next week's production", %{game: game} do
    {:ok, game} = Game.construct(game, :market)
    {:ok, report, _game} = Game.run_week(game)

    assert report.gold == 70_000 + report.production.gold
    assert report.gold_spent_buildings == 0
  end

  test "a finished building takes workers who produce from the next week", %{game: game} do
    # no travel: ordered at week 1, 2 builders work in weeks 2 and 3, produces from week 4
    {:ok, game} = Game.construct(game, :market)
    site = List.last(game.places)
    {:ok, game} = Game.place_worker(game, 1, site.id)
    {:ok, game} = Game.place_worker(game, 2, site.id)
    {_reports, game} = EngineFixtures.run_weeks(game, 2)
    market = List.last(game.places)
    {:ok, game} = Game.place_worker(game, 3, market.id)
    {:ok, report, _game} = Game.run_week(game)

    assert report.week == 4
    assert report.production.gold > 0
  end

  test "a culture demand: violet workers on its project deliver it before the deadline" do
    # violet leads, so the week-1 demand is for culture; 1 week of travel
    config =
      EngineFixtures.config(
        travel_weeks: 1,
        manameter_start: %Manameter{green: 100, yellow: 50, blue: 50, red: 100, violet: 700}
      )

    game = %{Game.new(config, 1) | demand_weeks: [1]}
    bards = for id <- 3..4, do: %Worker{id: id, colour: :violet}
    game = %{game | workers: game.workers ++ bards}
    {:ok, report, game} = Game.run_week(game)

    assert %{product: :culture, due_week: 9, project_id: project_id} = report.demand
    {:ok, game} = Game.place_worker(game, 3, project_id)
    {:ok, game} = Game.place_worker(game, 4, project_id)
    {reports, game} = EngineFixtures.run_weeks(game, 4)

    # week 2 travel; from week 3, 2 × 3 culture a week into the project (amount 9.6)
    assert Enum.map(reports, & &1.demand_progress) == [0, 6_000, 9_600, nil]
    assert Enum.map(reports, & &1.demand_outcome) == [nil, nil, :delivered, nil]
    assert game.misses == 0
    assert game.stocks.culture == 0
    refute Enum.any?(game.places, &(&1.id == project_id))
    # released at the end of week 4, back unplaced and travelling
    assert %Worker{place: nil} = find_worker(game, 3)
    assert %Worker{place: nil} = find_worker(game, 4)
    assert Enum.at(reports, 2).travelling == 2
  end

  defp find_worker(game, id), do: Enum.find(game.workers, &(&1.id == id))

  # week 1 brings a newborn (id 3), unplaced
  defp after_week_1(config) do
    {:ok, _report, game} = config |> Game.new(1) |> Game.run_week()
    game
  end
end
