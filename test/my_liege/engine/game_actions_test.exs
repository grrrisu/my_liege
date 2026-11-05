defmodule MyLiege.Engine.GameActionsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Building, Game, Worker}
  alias MyLiege.EngineFixtures

  setup do
    config = EngineFixtures.config()
    %{config: config, game: after_week_1(config)}
  end

  describe "placing workers" do
    test "workers have ids; a newborn gets the next one", %{game: game} do
      assert Enum.map(game.workers, & &1.id) == [1, 2, 3]
      assert %Worker{id: 3, building: nil} = List.last(game.workers)
    end

    test "an unplaced worker can be placed and works from the next week", context do
      %{game: game} = context
      {:ok, game} = Game.place_worker(game, 3, 1)
      {:ok, report, _game} = Game.run_week(game)

      assert %Worker{building: 1} = find_worker(game, 3)
      assert report.production.food > 9_000
    end

    test "a placed worker can be moved, free", context do
      %{game: game} = context
      {:ok, moved} = Game.place_worker(game, 1, 2)

      assert %Worker{building: 2} = find_worker(moved, 1)
      assert moved.stocks.gold == game.stocks.gold
    end

    test "a worker can be taken out of its building", %{game: game} do
      {:ok, game} = Game.unplace_worker(game, 1)

      assert %Worker{building: nil} = find_worker(game, 1)
    end

    test "a full building takes no more workers" do
      game =
        after_week_1(
          EngineFixtures.config(
            capacity: %{farm: 1, monastery: 4, watchtower: 4, market: 4, tavern: 4}
          )
        )

      assert Game.place_worker(game, 3, 1) == {:error, :full}
    end

    test "placing a worker where it already is changes nothing" do
      game =
        after_week_1(
          EngineFixtures.config(
            capacity: %{farm: 1, monastery: 4, watchtower: 4, market: 4, tavern: 4}
          )
        )

      assert Game.place_worker(game, 1, 1) == {:ok, game}
    end

    test "unknown workers and buildings are refused", %{game: game} do
      assert Game.place_worker(game, 99, 1) == {:error, :unknown_worker}
      assert Game.place_worker(game, 3, 99) == {:error, :unknown_building}
      assert Game.unplace_worker(game, 99) == {:error, :unknown_worker}
    end
  end

  describe "R2 building costs" do
    test "the starting farm and tower are free", %{config: config} do
      game = Game.new(config, 1)

      assert game.stocks.gold == 100_000
      assert game.report.gold_spent_buildings == 0
    end

    test "ordering pays build_cost_gold from the gold stock at once", context do
      %{game: game} = context
      {:ok, game} = Game.construct(game, :market)

      assert game.stocks.gold == 70_000
    end

    test "every type costs the same, the guildhouse included", context do
      %{game: game} = context

      for type <- Building.types() do
        {:ok, built} = Game.construct(game, type)
        assert built.stocks.gold == game.stocks.gold - 30_000
      end
    end

    test "ordering with exactly the price is possible", %{game: game} do
      game = %{game | stocks: %{game.stocks | gold: 30_000}}

      assert {:ok, %{stocks: %{gold: 0}}} = Game.construct(game, :farm)
    end

    test "ordering with less gold than the price is refused and changes nothing", context do
      %{game: game} = context
      game = %{game | stocks: %{game.stocks | gold: 29_999}}

      refute Game.can_afford_building?(game)
      assert Game.construct(game, :farm) == {:error, :not_enough_gold}
    end

    test "the gold spent is added to the current week's report", context do
      %{game: game} = context
      {:ok, game} = Game.construct(game, :market)
      {:ok, game} = Game.construct(game, :tavern)

      assert Game.report(game).week == 1
      assert Game.report(game).gold_spent_buildings == 60_000
      assert Game.report(game).gold == 100_000
    end

    test "the gold is gone before the next week's production", context do
      %{game: game} = context
      {:ok, game} = Game.construct(game, :market)
      {:ok, report, _game} = Game.run_week(game)

      assert report.gold == 70_000 + report.production.gold
      assert report.gold_spent_buildings == 0
    end
  end

  describe "building" do
    test "any number of buildings can be ordered", %{game: game} do
      {:ok, game} = Game.construct(game, :market)
      {:ok, game} = Game.construct(game, :market)

      assert Enum.map(game.buildings, & &1.type) == [:farm, :watchtower, :market, :market]
    end

    test "unknown building types are refused", %{game: game} do
      assert Game.construct(game, :castle) == {:error, :unknown_type}
    end

    test "a finished building takes workers who produce from the next week", context do
      %{game: game} = context
      # no builders needed: ordered at week 1, built in weeks 2 and 3, produces from week 4
      {:ok, game} = Game.construct(game, :market)
      market = List.last(game.buildings)
      {_reports, game} = EngineFixtures.run_weeks(game, 2)
      {:ok, game} = Game.place_worker(game, 3, market.id)
      {:ok, report, _game} = Game.run_week(game)

      assert report.week == 4
      assert report.production.gold > 0
    end
  end

  defp find_worker(game, id), do: Enum.find(game.workers, &(&1.id == id))

  # week 1 brings a newborn (id 3), unplaced
  defp after_week_1(config) do
    {:ok, _report, game} = config |> Game.new(1) |> Game.run_week()
    game
  end
end
