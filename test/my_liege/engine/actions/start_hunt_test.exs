defmodule MyLiege.Engine.Actions.StartHuntTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.StartHunt
  alias MyLiege.Engine.Place.Expedition
  alias MyLiege.EngineFixtures

  # worker 1 green on the farm (1), worker 2 red in the tower (2)
  setup do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
    %{game: game, unlocked: %{game | books: %{game.books | red: 1, green: 1}}}
  end

  test "appends the hunt, puts the party on it away at once, at no cost; suspicion rises",
       %{unlocked: game} do
    assert {:ok, started} = StartHunt.run(game, [1, 2])

    assert %Expedition{id: 3, return_week: 18} = List.last(started.places)
    assert Enum.all?(started.workers, &(&1.place == 3 and &1.travel == 0))
    assert started.stocks == game.stocks
    assert started.suspicion == 1
    assert started.report == game.report
  end

  test "a trainee taken out for a hunt loses his training", %{unlocked: game} do
    game = %{
      game
      | workers:
          Enum.map(game.workers, &if(&1.id == 1, do: %{&1 | training_started: 2}, else: &1))
    }

    {:ok, started} = StartHunt.run(game, [1])
    assert Enum.find(started.workers, &(&1.id == 1)).training_started == nil
  end

  test "several hunts at once, each adding suspicion; a hunter can't set out again",
       %{unlocked: game} do
    {:ok, game} = StartHunt.run(game, [1])
    assert StartHunt.run(game, [1]) == {:error, :away}
    {:ok, game} = StartHunt.run(game, [2])

    assert [%Expedition{id: 3}, %Expedition{id: 4}] = for(%Expedition{} = e <- game.places, do: e)
    assert game.suspicion == 2
  end

  test "errors", %{game: game, unlocked: unlocked} do
    assert StartHunt.run(game, [1]) == {:error, :locked}
    assert StartHunt.run(unlocked, []) == {:error, :party_size}
    assert StartHunt.run(unlocked, [1, 1]) == {:error, :duplicate}
    assert StartHunt.run(unlocked, [1, 99]) == {:error, :unknown_worker}

    travelling = %{unlocked | workers: Enum.map(unlocked.workers, &%{&1 | travel: 1})}
    assert StartHunt.run(travelling, [1]) == {:error, :travelling}
  end
end
