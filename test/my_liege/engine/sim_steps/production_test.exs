defmodule MyLiege.Engine.SimSteps.ProductionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.SimSteps.Production
  alias MyLiege.Engine.{WeeklyReport, Worker}
  alias MyLiege.EngineFixtures

  # a blue worker (id 3) makes 3 knowledge a week; the monastery has id 3, the knowledge
  # project (target 4, progress 2) id 4
  setup do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
    monastery = EngineFixtures.new_building(3, :monastery)
    monk = %Worker{id: 3, colour: :blue, place: 3}
    game = %{game | places: game.places ++ [monastery], workers: game.workers ++ [monk]}
    game = EngineFixtures.open_demand(game, :knowledge, 4_000, 5)
    %{game: update_project(game, &%{&1 | progress: 2_000})}
  end

  test "output on the project goes into it, not the stock, capped at the target", context do
    game = put_monk(context.game, 4)

    {game, report} = run(game)

    # 2 of 3 fill the project; the 3rd is lost
    assert EngineFixtures.demand_project(game).progress == 4_000
    assert report.demand_progress == 4_000
    assert report.production.knowledge == 0
    assert game.stocks.knowledge == 0
  end

  test "the monastery's output goes to the stock, not into the project", %{game: game} do
    {game, report} = run(game)

    assert EngineFixtures.demand_project(game).progress == 2_000
    assert report.demand_progress == 2_000
    assert report.production.knowledge == 3_000
    assert game.stocks.knowledge == 3_000
  end

  test "culture made on a project doesn't count toward happiness", %{game: game} do
    game = EngineFixtures.open_demand(game, :culture, 100_000, 5)
    bard = %Worker{id: 4, colour: :violet, place: game.demand.project_id}
    {_game, without} = run(game)
    {game, with_bard} = run(%{game | workers: game.workers ++ [bard]})

    assert with_bard.happiness == without.happiness
    assert with_bard.production.culture == 0
    assert EngineFixtures.demand_project(game).progress == 3_000
  end

  test "a writer's output goes into the book, not the stock, capped at the target", context do
    # green has 80% of the Manameter at the start: the monk writes 3 × 4 = 12 a week
    book = EngineFixtures.new_book(5, :green, target: 20_000, progress: 10_000)
    game = put_monk(%{context.game | places: context.game.places ++ [book]}, 5)

    {game, report} = run(game)

    assert Enum.find(game.places, &(&1.id == 5)).progress == 20_000
    assert report.production.knowledge == 0
    assert game.stocks.knowledge == 0
  end

  defp run(game), do: Production.run(%{game | week: 1}, WeeklyReport.new(1, game))

  defp put_monk(game, place_id),
    do: %{
      game
      | workers: Enum.map(game.workers, &if(&1.id == 3, do: %{&1 | place: place_id}, else: &1))
    }

  defp update_project(game, fun),
    do: %{game | places: Enum.map(game.places, &if(&1.id == 4, do: fun.(&1), else: &1))}
end
