defmodule MyLiege.Engine.Actions.StartInventionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.StartInvention
  alias MyLiege.Engine.Place.Project
  alias MyLiege.EngineFixtures

  setup do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
    %{game: game, unlocked: %{game | books: %{game.books | blue: 1, green: 1}}}
  end

  test "adds the improved plough project, at no cost", %{unlocked: game} do
    assert {:ok, started} = StartInvention.run(game, :plough)

    assert %Project{id: 3, gives: {:invention, :plough}, target: 96_000, progress: 0} =
             List.last(started.places)

    assert started.stocks == game.stocks
    assert started.report == game.report
  end

  test "is locked without a blue and a green book", %{game: game} do
    assert StartInvention.run(game, :plough) == {:error, :locked}

    assert StartInvention.run(%{game | books: %{game.books | blue: 2}}, :plough) ==
             {:error, :locked}
  end

  test "only one at a time, and only once", %{unlocked: game} do
    {:ok, started} = StartInvention.run(game, :plough)
    assert StartInvention.run(started, :plough) == {:error, :already_open}

    invented = %{game | inventions: [:plough]}
    assert StartInvention.run(invented, :plough) == {:error, :already_invented}
  end

  test "an unknown invention is refused", %{unlocked: game} do
    assert StartInvention.run(game, :granary) == {:error, :unknown_invention}
    assert StartInvention.run(game, "plough") == {:error, :unknown_invention}
  end
end
