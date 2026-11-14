defmodule MyLiege.Engine.Actions.StartTradeTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.StartTrade
  alias MyLiege.Engine.Place.Trade
  alias MyLiege.EngineFixtures

  # 1000 gold; worker 1 green on the farm (1), worker 2 red in the tower (2)
  setup do
    config = EngineFixtures.config(start_gold: 1000)
    game = EngineFixtures.game_without_demands(config, 1)
    %{game: game, unlocked: %{game | books: %{game.books | yellow: 1, green: 1}}}
  end

  test "pays the gold, appends the trade and puts the trader on it, away at once",
       %{unlocked: game} do
    assert {:ok, started} = StartTrade.run(game, 1, :grain_trade)

    assert %Trade{id: 3, return_week: 18} = List.last(started.places)
    # green is yellow's neighbour: 144 × 1000 ÷ 750
    assert started.stocks.gold == 1_000_000 - 192_000
    assert %{place: 3, travel: 0} = Enum.find(started.workers, &(&1.id == 1))
    assert started.report == game.report
  end

  test "a trainee taken out for a trade loses his training", %{unlocked: game} do
    game = %{
      game
      | workers:
          Enum.map(game.workers, &if(&1.id == 1, do: %{&1 | training_started: 2}, else: &1))
    }

    {:ok, started} = StartTrade.run(game, 1, :grain_trade)
    assert Enum.find(started.workers, &(&1.id == 1)).training_started == nil
  end

  test "is locked without a yellow and a green book", %{game: game} do
    assert StartTrade.run(game, 1, :grain_trade) == {:error, :locked}
  end

  test "several trades at once, one trader each; a trader can't start another",
       %{unlocked: game} do
    {:ok, game} = StartTrade.run(game, 1, :grain_trade)
    assert StartTrade.run(game, 1, :grain_trade) == {:error, :away}
    {:ok, game} = StartTrade.run(game, 2, :grain_trade)

    assert [%Trade{id: 3}, %Trade{id: 4}] = for(%Trade{} = t <- game.places, do: t)
    # red is yellow's opposite: 288
    assert game.stocks.gold == 1_000_000 - 192_000 - 288_000
  end

  test "not without enough gold, nor with a travelling or unknown worker", %{unlocked: game} do
    poor = %{game | stocks: %{game.stocks | gold: 191_999}}
    assert StartTrade.run(poor, 1, :grain_trade) == {:error, :not_enough_gold}

    travelling = %{game | workers: Enum.map(game.workers, &%{&1 | travel: 1})}
    assert StartTrade.run(travelling, 1, :grain_trade) == {:error, :travelling}

    assert StartTrade.run(game, 99, :grain_trade) == {:error, :unknown_worker}
    assert StartTrade.run(game, 1, :granary) == {:error, :unknown_trade}
  end
end
