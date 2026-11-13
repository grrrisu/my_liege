defmodule MyLiege.AutoRun.BotActionsTest do
  use ExUnit.Case, async: true

  alias MyLiege.AutoRun.BotActions.{Feed, PayAndDeliver, Pivot, PlaceOwn, SaveGold}
  alias MyLiege.Engine.{Game, Worker}
  alias MyLiege.EngineFixtures

  setup do
    %{game: Game.new(EngineFixtures.config(), 1)}
  end

  test "Feed sends to a farm only while food is low", %{game: game} do
    worker = %Worker{id: 3, colour: :red}

    assert Feed.target(worker, game, []) == nil
    assert Feed.target(worker, %{game | stocks: %{game.stocks | food: -1}}, []) == :farm
  end

  test "SaveGold sends to a market only while gold is below the next tax", %{game: game} do
    worker = %Worker{id: 3, colour: :red}
    broke = %{game | stocks: %{game.stocks | gold: 0}}

    assert SaveGold.target(worker, game, []) == nil
    assert SaveGold.target(worker, broke, []) == :market
  end

  test "SaveGold with born_before leaves workers born from that week", %{game: game} do
    broke = %{game | stocks: %{game.stocks | gold: 0}}

    assert SaveGold.target(%Worker{colour: :red, born_week: nil}, broke, born_before: 5) ==
             :market

    assert SaveGold.target(%Worker{colour: :red, born_week: 4}, broke, born_before: 5) == :market
    assert SaveGold.target(%Worker{colour: :red, born_week: 5}, broke, born_before: 5) == nil
  end

  test "Pivot sends workers born from from_week to `to`", %{game: game} do
    opts = [to: :watchtower, from_week: 5]

    assert Pivot.target(%Worker{colour: :red, born_week: nil}, game, opts) == nil
    assert Pivot.target(%Worker{colour: :red, born_week: 4}, game, opts) == nil
    assert Pivot.target(%Worker{colour: :red, born_week: 5}, game, opts) == :watchtower
  end

  test "PlaceOwn sends to the worker's home type", %{game: game} do
    assert PlaceOwn.target(%Worker{colour: :green}, game, []) == :farm
    assert PlaceOwn.target(%Worker{colour: :red}, game, []) == :watchtower
  end

  test "PayAndDeliver changes nothing when no decision is due", %{game: game} do
    assert PayAndDeliver.run(game, []) == game
  end
end
