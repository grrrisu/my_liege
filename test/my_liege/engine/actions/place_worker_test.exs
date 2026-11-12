defmodule MyLiege.Engine.Actions.PlaceWorkerTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.PlaceWorker
  alias MyLiege.Engine.{Game, Worker}
  alias MyLiege.Engine.Place.Building
  alias MyLiege.EngineFixtures

  # worker 1 (green) on the farm (1), worker 2 (red) in the watchtower (2)
  setup do
    config = EngineFixtures.config(travel_weeks: 2)
    %{config: config, game: EngineFixtures.game_without_demands(config, 1)}
  end

  test "moves a worker for free; it starts travelling", %{game: game} do
    assert {:ok, moved} = PlaceWorker.run(game, 1, 2)
    assert %Worker{place: 2, travel: 2, training_started: nil} = find_worker(moved, 1)
    assert moved.stocks == game.stocks
  end

  test "places an unplaced worker that has arrived", %{game: game} do
    game = update_worker(game, 1, &%{&1 | place: nil})

    assert {:ok, game} = PlaceWorker.run(game, 1, 2)
    assert %Worker{place: 2, travel: 2} = find_worker(game, 1)
  end

  test "placing a worker where it already is changes nothing", %{game: game} do
    assert PlaceWorker.run(game, 1, 1) == {:ok, game}
  end

  test "unknown workers and buildings are refused", %{game: game} do
    assert PlaceWorker.run(game, 99, 1) == {:error, :unknown_worker}
    assert PlaceWorker.run(game, 1, 99) == {:error, :unknown_place}
  end

  test "an unplaced worker that is still travelling can't be placed", %{game: game} do
    game = update_worker(game, 1, &%{&1 | place: nil, travel: 1})

    assert PlaceWorker.run(game, 1, 2) == {:error, :travelling}
  end

  test "a placed worker that is still travelling can be moved", %{game: game} do
    game = update_worker(game, 1, &%{&1 | travel: 1})

    assert {:ok, game} = PlaceWorker.run(game, 1, 2)
    assert %Worker{place: 2, travel: 2} = find_worker(game, 1)
  end

  test "a finished building not ready next week is refused", %{game: game} do
    game = update_building(game, 2, &%{&1 | ready_week: game.week + 2})

    assert PlaceWorker.run(game, 1, 2) == {:error, :not_ready}
  end

  test "a full building is refused" do
    config =
      EngineFixtures.config(
        place_capacity: %{farm: 4, monastery: 4, watchtower: 1, market: 4, tavern: 4}
      )

    game = EngineFixtures.game_without_demands(config, 1)

    assert PlaceWorker.run(game, 1, 2) == {:error, :full}
  end

  test "a site takes up to build_builders builders" do
    config = EngineFixtures.config(build_builders: 1)
    {:ok, game} = config |> EngineFixtures.game_without_demands(1) |> Game.construct(:market)
    site = List.last(game.places)

    assert {:ok, game} = PlaceWorker.run(game, 1, site.id)
    assert PlaceWorker.run(game, 2, site.id) == {:error, :full}
  end

  test "moving a builder off a site resets its progress", %{game: game} do
    {:ok, game} = Game.construct(game, :market)
    site = List.last(game.places)
    game = update_building(game, site.id, &%{&1 | progress: 1})
    game = update_worker(game, 1, &%{&1 | place: site.id})

    assert {:ok, game} = PlaceWorker.run(game, 1, 2)
    assert %Building{progress: 0} = find_place(game, site.id)
  end

  test "in a finished guildhouse the worker starts training after its travel", context do
    %{config: config, game: game} = context
    game = with_guildhouse(game)

    assert {:ok, game} = PlaceWorker.run(game, 1, 3)
    assert %Worker{place: 3, training_started: started} = find_worker(game, 1)
    assert started == game.week + 1 + config.travel_weeks
  end

  test "training needs the worker's colour share and an untrained worker", %{game: game} do
    game = with_guildhouse(game)

    # red has 100 of 1000, below training_min_share
    assert PlaceWorker.run(game, 2, 3) == {:error, :below_threshold}

    game = update_worker(game, 1, &%{&1 | trained: true})
    assert PlaceWorker.run(game, 1, 3) == {:error, :already_trained}
  end

  test "moving a trainee out loses its progress", %{game: game} do
    game = with_guildhouse(game)
    {:ok, game} = PlaceWorker.run(game, 1, 3)

    assert {:ok, game} = PlaceWorker.run(game, 1, 1)
    assert %Worker{place: 1, training_started: nil} = find_worker(game, 1)
  end

  # a finished guildhouse with id 3
  defp with_guildhouse(game) do
    {:ok, game} = Game.construct(game, :guildhouse)
    update_building(game, 3, &%{&1 | ready_week: 0})
  end

  defp update_worker(game, id, fun),
    do: %{game | workers: Enum.map(game.workers, &if(&1.id == id, do: fun.(&1), else: &1))}

  defp update_building(game, id, fun),
    do: %{game | places: Enum.map(game.places, &if(&1.id == id, do: fun.(&1), else: &1))}

  defp find_worker(game, id), do: Enum.find(game.workers, &(&1.id == id))
  defp find_place(game, id), do: Enum.find(game.places, &(&1.id == id))
end
