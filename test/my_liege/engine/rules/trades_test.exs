defmodule MyLiege.Engine.Rules.TradesTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place.{Blueprint, Trade}
  alias MyLiege.Engine.Rules.{Books, Trades}
  alias MyLiege.Engine.Worker
  alias MyLiege.EngineFixtures

  @unlocked %{Books.none() | yellow: 1, green: 1}

  setup do
    %{config: EngineFixtures.config()}
  end

  describe "R16: gold" do
    test "the trade's gold × 1000 ÷ the trader's factor against yellow", %{config: config} do
      assert Trades.cost(:grain_trade, worker(:yellow), config) == 144_000
      assert Trades.cost(:grain_trade, worker(:green), config) == 192_000
      assert Trades.cost(:grain_trade, worker(:blue), config) == 192_000
      assert Trades.cost(:grain_trade, worker(:red), config) == 288_000
      assert Trades.cost(:grain_trade, worker(:violet), config) == 288_000
    end

    test "a trained trader uses the trained factors", %{config: config} do
      assert Trades.cost(:grain_trade, worker(:yellow, true), config) == 96_000
      assert Trades.cost(:grain_trade, worker(:green, true), config) == 288_000
      assert Trades.cost(:grain_trade, worker(:red, true), config) == 576_000
    end
  end

  describe "R16: time and food" do
    test "away 3 + 12 + 3 weeks; brings 480 food", %{config: config} do
      assert Trades.weeks(:grain_trade, config) == 18
      assert Trades.food(:grain_trade, config) == 480_000
    end

    test "a trade started at week N returns at the end of week N + 18", %{config: config} do
      places = Trades.new_trade([EngineFixtures.new_building(1, :farm)], :grain_trade, 5, config)

      assert %Trade{id: 2, return_week: 23} = trade = List.last(places)
      assert trade.blueprint == Blueprint.fetch!(:grain_trade)
    end
  end

  describe "R16: starting" do
    test "needs the way unlocked, an arrived trader not already away, and the gold",
         %{config: config} do
      trade = %Trade{id: 9, blueprint: Blueprint.fetch!(:grain_trade), return_week: 20}
      farm = EngineFixtures.new_building(1, :farm)
      yellow = worker(:yellow)

      assert Trades.check_start(:plough, yellow, nil, 999_000, @unlocked, config) ==
               {:error, :unknown_trade}

      assert Trades.check_start(:grain_trade, yellow, nil, 999_000, Books.none(), config) ==
               {:error, :locked}

      assert Trades.check_start(:grain_trade, yellow, trade, 999_000, @unlocked, config) ==
               {:error, :away}

      assert Trades.check_start(
               :grain_trade,
               %{yellow | travel: 1},
               nil,
               999_000,
               @unlocked,
               config
             ) ==
               {:error, :travelling}

      assert Trades.check_start(:grain_trade, yellow, nil, 143_999, @unlocked, config) ==
               {:error, :not_enough_gold}

      assert Trades.check_start(:grain_trade, yellow, nil, 144_000, @unlocked, config) == :ok
      assert Trades.check_start(:grain_trade, yellow, farm, 144_000, @unlocked, config) == :ok
    end
  end

  describe "R16: return" do
    test "in its return week: food, the trade removed, the trader released" do
      config = EngineFixtures.config(travel_weeks: 1)
      trade = %Trade{id: 3, blueprint: Blueprint.fetch!(:grain_trade), return_week: 18}
      other = %{trade | id: 4, return_week: 19}
      workers = [%{worker(:yellow) | id: 1, place: 3}, %{worker(:red) | id: 2, place: 4}]

      assert {[^other], [trader, still_away], 480_000, [:grain_trade]} =
               Trades.return([trade, other], workers, 18, config)

      assert %Worker{place: nil, travel: 1} = trader
      assert still_away.place == 4

      assert {[^trade, ^other], ^workers, 0, []} =
               Trades.return([trade, other], workers, 17, config)
    end
  end

  defp worker(colour, trained \\ false), do: %Worker{id: 1, colour: colour, trained: trained}
end
