defmodule MyLiege.Engine.SimSteps.InventionsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.SimSteps.Inventions
  alias MyLiege.Engine.{WeeklyReport, Worker}
  alias MyLiege.EngineFixtures

  # worker 2 works on a done improved plough (id 3); 1 week of travel
  setup do
    config = EngineFixtures.config(travel_weeks: 1)
    game = EngineFixtures.game_without_demands(config, 1)
    plough = EngineFixtures.new_invention(3, :plough, progress: 96_000)
    workers = Enum.map(game.workers, &if(&1.id == 2, do: %{&1 | place: 3}, else: &1))
    %{game: %{game | week: 1, places: game.places ++ [plough], workers: workers}}
  end

  test "a finished invention is invented, its project removed, its workers travel back",
       %{game: game} do
    {game, report} = Inventions.run(game, WeeklyReport.new(1, game))

    assert report.inventions_finished == [:plough]
    assert game.inventions == [:plough]
    refute Enum.any?(game.places, &(&1.id == 3))
    assert %Worker{place: nil, travel: 1} = Enum.find(game.workers, &(&1.id == 2))
  end

  test "an unfinished invention stays", %{game: game} do
    game = %{
      game
      | places: Enum.map(game.places, &if(&1.id == 3, do: %{&1 | progress: 1}, else: &1))
    }

    {after_step, report} = Inventions.run(game, WeeklyReport.new(1, game))

    assert report.inventions_finished == []
    assert after_step == game
  end
end
