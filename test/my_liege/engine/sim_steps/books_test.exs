defmodule MyLiege.Engine.SimSteps.BooksTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.SimSteps.Books
  alias MyLiege.Engine.{WeeklyReport, Worker}
  alias MyLiege.EngineFixtures

  # worker 1 writes a done green book (id 3); 1 week of travel
  setup do
    config = EngineFixtures.config(travel_weeks: 1)
    game = EngineFixtures.game_without_demands(config, 1)
    book = EngineFixtures.new_book(3, :green, progress: 96_000)
    workers = Enum.map(game.workers, &if(&1.id == 1, do: %{&1 | place: 3}, else: &1))
    %{game: %{game | week: 1, places: game.places ++ [book], workers: workers}}
  end

  test "a finished book is held, its project removed, its writer travels back", %{game: game} do
    {game, report} = Books.run(game, WeeklyReport.new(1, game))

    assert report.books_finished == [:green]
    assert game.books.green == 1
    refute Enum.any?(game.places, &(&1.id == 3))
    assert %Worker{place: nil, travel: 1} = Enum.find(game.workers, &(&1.id == 1))
  end

  test "an unfinished book stays", %{game: game} do
    game = %{
      game
      | places: Enum.map(game.places, &if(&1.id == 3, do: %{&1 | progress: 1}, else: &1))
    }

    {after_step, report} = Books.run(game, WeeklyReport.new(1, game))

    assert report.books_finished == []
    assert after_step == game
  end
end
