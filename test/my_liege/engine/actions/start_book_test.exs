defmodule MyLiege.Engine.Actions.StartBookTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.StartBook
  alias MyLiege.Engine.Place.Project
  alias MyLiege.EngineFixtures

  setup do
    %{game: EngineFixtures.game_without_demands(EngineFixtures.config(), 1)}
  end

  test "adds a book project of the colour, at no cost", %{game: game} do
    assert {:ok, started} = StartBook.run(game, :violet)

    assert %Project{id: 3, gives: {:book, :violet}, target: 96_000, progress: 0} =
             List.last(started.places)

    assert started.stocks == game.stocks
    assert started.report == game.report
  end

  test "several books at once, also of the same colour", %{game: game} do
    {:ok, game} = StartBook.run(game, :green)
    {:ok, game} = StartBook.run(game, :green)
    {:ok, game} = StartBook.run(game, :red)

    assert [{:book, :green}, {:book, :green}, {:book, :red}] =
             for(%Project{gives: gives} <- game.places, do: gives)
  end

  test "an unknown colour is refused", %{game: game} do
    assert StartBook.run(game, :purple) == {:error, :unknown_colour}
    assert StartBook.run(game, "green") == {:error, :unknown_colour}
  end
end
