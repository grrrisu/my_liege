defmodule MyLiege.Engine.GameActionsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Building, Game, Worker}
  alias MyLiege.EngineFixtures

  setup do
    config = EngineFixtures.config()
    # week 1 brings a newborn (id 3), unplaced
    {:ok, _report, game} = config |> Game.new(1) |> Game.run_week(config)
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
      {:ok, report, _game} = Game.run_week(game, config)

      assert %Worker{building: 1} = find_worker(game, 3)
      assert report.production.food > 9_000
    end

    test "a placed worker can be moved, free", context do
      %{config: config, game: game} = context
      {:ok, moved} = Game.place_worker(game, 1, 2, config)

      assert %Worker{building: 2} = find_worker(moved, 1)
      assert moved.stocks.gold == game.stocks.gold
    end

    test "a worker can be taken out of its building", %{config: config, game: game} do
      {:ok, game} = Game.unplace_worker(game, 1, config)

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
      assert Game.unplace_worker(game, 99, config) == {:error, :unknown_worker}
    end
  end

  describe "R2 building costs" do
    test "the starting farm and tower are free", %{config: config} do
      game = Game.new(config, 1)

      assert game.stocks.gold == 100_000
      assert game.report.gold_spent_buildings == 0
    end

    test "ordering pays build_cost_gold from the gold stock at once", context do
      %{config: config, game: game} = context
      {:ok, game} = Game.construct(game, :market, config)

      assert game.stocks.gold == 70_000
    end

    test "every type costs the same, the guildhouse included", context do
      %{config: config, game: game} = context

      for type <- Building.types() do
        {:ok, built} = Game.construct(game, type, config)
        assert built.stocks.gold == game.stocks.gold - 30_000
      end
    end

    test "ordering with exactly the price is possible", %{config: config, game: game} do
      game = %{game | stocks: %{game.stocks | gold: 30_000}}

      assert {:ok, %{stocks: %{gold: 0}}} = Game.construct(game, :farm, config)
    end

    test "ordering with less gold than the price is refused and changes nothing", context do
      %{config: config, game: game} = context
      game = %{game | stocks: %{game.stocks | gold: 29_999}}

      refute Game.can_afford_building?(game, config)
      assert Game.construct(game, :farm, config) == {:error, :not_enough_gold}
    end

    test "the gold spent is added to the current week's report", context do
      %{config: config, game: game} = context
      {:ok, game} = Game.construct(game, :market, config)
      {:ok, game} = Game.construct(game, :tavern, config)

      assert Game.report(game).week == 1
      assert Game.report(game).gold_spent_buildings == 60_000
      assert Game.report(game).gold == 100_000
    end

    test "the gold is gone before the next week's production", context do
      %{config: config, game: game} = context
      {:ok, game} = Game.construct(game, :market, config)
      {:ok, report, _game} = Game.run_week(game, config)

      assert report.gold == 70_000 + report.production.gold
      assert report.gold_spent_buildings == 0
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

    test "a finished building takes workers who produce from the next week", context do
      %{config: config, game: game} = context
      # no builders needed: ordered at week 1, built in weeks 2 and 3, produces from week 4
      {:ok, game} = Game.construct(game, :market, config)
      market = List.last(game.buildings)
      {_reports, game} = EngineFixtures.run_weeks(game, 2, config)
      {:ok, game} = Game.place_worker(game, 3, market.id, config)
      {:ok, report, _game} = Game.run_week(game, config)

      assert report.week == 4
      assert report.production.gold > 0
    end
  end

  defp find_worker(game, id), do: Enum.find(game.workers, &(&1.id == id))
end
