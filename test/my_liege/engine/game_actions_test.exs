defmodule MyLiege.Engine.GameActionsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, Worker}
  alias MyLiege.EngineFixtures

  setup do
    config = EngineFixtures.config()
    # week 1 brings a newborn (id 3), unplaced
    {_report, game} = config |> Game.new(1) |> Game.run_week(config)
    %{config: config, game: game}
  end

  describe "placing workers" do
    test "workers have ids; a newborn gets the next one", %{game: game} do
      assert Enum.map(game.workers, & &1.id) == [1, 2, 3]
      assert %Worker{id: 3, building: nil} = List.last(game.workers)
    end

    test "an unplaced worker can be placed and works from the next week", context do
      %{config: config, game: game} = context
      {:ok, game} = Game.place_worker(game, 3, 1, config)
      {report, _game} = Game.run_week(game, config)

      assert %Worker{building: 1} = find_worker(game, 3)
      assert report.production.food > 9_000
    end

    test "a placed worker can be moved, free and immediate", context do
      %{config: config, game: game} = context
      {:ok, game} = Game.place_worker(game, 1, 2, config)

      assert %Worker{building: 2} = find_worker(game, 1)
    end

    test "a worker can be taken out of its building", %{game: game} do
      {:ok, game} = Game.unplace_worker(game, 1)

      assert %Worker{building: nil} = find_worker(game, 1)
    end

    test "a full building takes no more workers", %{game: game} do
      config =
        EngineFixtures.config(
          capacity: %{farm: 1, monastery: 4, watchtower: 4, market: 4, tavern: 4}
        )

      assert Game.place_worker(game, 3, 1, config) == {:error, :full}
    end

    test "placing a worker where it already is changes nothing", context do
      %{game: game} = context

      config =
        EngineFixtures.config(
          capacity: %{farm: 1, monastery: 4, watchtower: 4, market: 4, tavern: 4}
        )

      assert Game.place_worker(game, 1, 1, config) == {:ok, game}
    end

    test "unknown workers and buildings are refused", %{config: config, game: game} do
      assert Game.place_worker(game, 99, 1, config) == {:error, :unknown_worker}
      assert Game.place_worker(game, 3, 99, config) == {:error, :unknown_building}
      assert Game.unplace_worker(game, 99) == {:error, :unknown_worker}
    end
  end

  describe "building" do
    test "any number of buildings can be ordered", %{config: config, game: game} do
      {:ok, game} = Game.construct(game, :market, config)
      {:ok, game} = Game.construct(game, :market, config)

      assert Enum.map(game.buildings, & &1.type) == [:farm, :watchtower, :market, :market]
    end

    test "unknown building types are refused", %{config: config, game: game} do
      assert Game.construct(game, :castle, config) == {:error, :unknown_type}
    end

    test "a worker can be placed before the first week the building produces", context do
      %{config: config, game: game} = context
      # ordered at week 1 with 2 construction weeks: produces from week 3
      {:ok, game} = Game.construct(game, :market, config)
      market = List.last(game.buildings)

      assert Game.place_worker(game, 3, market.id, config) == {:error, :not_ready}

      {_report, game} = Game.run_week(game, config)
      {:ok, game} = Game.place_worker(game, 3, market.id, config)
      {report, _game} = Game.run_week(game, config)

      assert report.week == 3
      assert report.production.gold > 0
    end
  end

  defp find_worker(game, id), do: Enum.find(game.workers, &(&1.id == id))
end
