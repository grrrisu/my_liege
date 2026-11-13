defmodule MyLiege.Engine.Actions.UnplaceWorkerTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.UnplaceWorker
  alias MyLiege.Engine.{Game, Worker}
  alias MyLiege.Engine.Place.Project
  alias MyLiege.EngineFixtures

  # worker 1 (green) on the farm (1), worker 2 (red) in the watchtower (2)
  setup do
    config = EngineFixtures.config(travel_weeks: 2)
    %{game: EngineFixtures.game_without_demands(config, 1)}
  end

  test "takes a worker out of its building; it starts travelling", %{game: game} do
    assert {:ok, game} = UnplaceWorker.run(game, 1)
    assert %Worker{place: nil, travel: 2} = find_worker(game, 1)
  end

  test "a worker that is already unplaced stays as it is", %{game: game} do
    game = update_worker(game, 1, &%{&1 | place: nil, travel: 1})

    assert UnplaceWorker.run(game, 1) == {:ok, game}
  end

  test "an unknown worker is refused", %{game: game} do
    assert UnplaceWorker.run(game, 99) == {:error, :unknown_worker}
  end

  test "a trainee loses its progress", %{game: game} do
    game = update_worker(game, 1, &%{&1 | training_started: 3})

    assert {:ok, game} = UnplaceWorker.run(game, 1)
    assert %Worker{place: nil, training_started: nil} = find_worker(game, 1)
  end

  test "a builder resets its site's progress", %{game: game} do
    {:ok, game} = Game.construct(game, :market)
    site = List.last(game.places)
    game = update_building(game, site.id, &%{&1 | progress: 1})
    game = update_worker(game, 1, &%{&1 | place: site.id})

    assert {:ok, game} = UnplaceWorker.run(game, 1)
    assert %Project{progress: 0} = find_place(game, site.id)
  end

  test "leaving a building leaves it unchanged", %{game: game} do
    assert {:ok, unplaced} = UnplaceWorker.run(game, 1)
    assert unplaced.places == game.places
  end

  defp update_worker(game, id, fun),
    do: %{game | workers: Enum.map(game.workers, &if(&1.id == id, do: fun.(&1), else: &1))}

  defp update_building(game, id, fun),
    do: %{game | places: Enum.map(game.places, &if(&1.id == id, do: fun.(&1), else: &1))}

  defp find_worker(game, id), do: Enum.find(game.workers, &(&1.id == id))
  defp find_place(game, id), do: Enum.find(game.places, &(&1.id == id))
end
