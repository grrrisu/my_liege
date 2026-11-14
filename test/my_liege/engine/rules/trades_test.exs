defmodule MyLiege.Engine.Rules.TradesTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place.{Blueprint, Trade}
  alias MyLiege.Engine.Rules.Trades
  alias MyLiege.Engine.Worker
  alias MyLiege.EngineFixtures

  setup do
    %{config: EngineFixtures.config()}
  end

  defp worker(colour, trained \\ false), do: %Worker{colour: colour, trained: trained}

  defp route(traders \\ []),
    do: %Trade{id: 3, blueprint: Blueprint.fetch!(:grain_trade), traders: traders}

  defp trader(id, colour, travel \\ 0),
    do: %Worker{id: id, colour: colour, place: 3, travel: travel}

  describe "R16: price" do
    test "the weekly gold × 1000 ÷ the trader's factor against yellow", %{config: config} do
      assert Trades.price(:grain_trade, worker(:yellow), config) == 12_000
      assert Trades.price(:grain_trade, worker(:green), config) == 16_000
      assert Trades.price(:grain_trade, worker(:blue), config) == 16_000
      assert Trades.price(:grain_trade, worker(:red), config) == 24_000
      assert Trades.price(:grain_trade, worker(:violet), config) == 24_000
    end

    test "a trained trader uses the trained factor", %{config: config} do
      assert Trades.price(:grain_trade, worker(:yellow, true), config) == 8_000
    end

    test "rounded down", %{config: config} do
      config = %{config | way_grain_trade_gold_per_week: 1}
      factors = %{config.efficiency | untrained: %{config.efficiency.untrained | same: 3000}}

      assert Trades.price(:grain_trade, worker(:yellow), %{config | efficiency: factors}) == 333
    end

    test "capacity, travel and food come from the config", %{config: config} do
      assert Trades.capacity(:grain_trade, config) == 8
      assert Trades.travel_weeks(:grain_trade, config) == 3
      assert Trades.food(:grain_trade, config) == 40_000
    end
  end

  describe "R16: the queue" do
    test "a worker joining goes last; joining again moves him to the end" do
      places = [EngineFixtures.new_building(1, :farm), route()]

      places = places |> Trades.join(7, 3) |> Trades.join(8, 3) |> Trades.join(7, 3)

      assert %Trade{traders: [8, 7]} = Trades.route(places, :grain_trade)
    end

    test "joining another place changes no route" do
      places = [route([5])]
      assert Trades.join(places, 6, 1) == places
    end

    test "traders are the workers still on the route, in queue order" do
      workers = [trader(1, :green), %Worker{id: 2, colour: :red, place: 1}, trader(3, :yellow)]

      assert [%{id: 3}, %{id: 1}] = Trades.traders(route([3, 2, 1, 9]), workers)
    end
  end

  describe "R16: weekly settlement" do
    test "each arrived trader pays his price and brings the food", %{config: config} do
      workers = [trader(1, :yellow), trader(2, :red)]

      assert {_route, %{gold_paid: 36_000, food: 80_000, traders: 2}} =
               Trades.settle(route([1, 2]), workers, 100_000, config)
    end

    test "a travelling trader pays and brings nothing but counts", %{config: config} do
      workers = [trader(1, :yellow), trader(2, :yellow, 1)]

      assert {_route, %{gold_paid: 12_000, food: 40_000, traders: 2}} =
               Trades.settle(route([1, 2]), workers, 100_000, config)
    end

    test "in queue order; one the gold no longer covers pays nothing, a later cheaper one may",
         %{config: config} do
      # green 16, red 24, yellow 12: 30 gold pays green, not red (14 left), then yellow
      workers = [trader(1, :yellow), trader(2, :red), trader(3, :green)]

      assert {_route, %{gold_paid: 28_000, food: 80_000, traders: 3}} =
               Trades.settle(route([3, 2, 1]), workers, 30_000, config)
    end

    test "exactly the price is enough", %{config: config} do
      assert {_route, %{gold_paid: 12_000}} =
               Trades.settle(route([1]), [trader(1, :yellow)], 12_000, config)

      assert {_route, %{gold_paid: 0, food: 0, traders: 1}} =
               Trades.settle(route([1]), [trader(1, :yellow)], 11_999, config)
    end

    test "the queue drops workers who left", %{config: config} do
      workers = [trader(1, :yellow), %Worker{id: 2, colour: :red, place: nil}]

      assert {%Trade{traders: [1]}, _result} =
               Trades.settle(route([2, 1]), workers, 0, config)
    end
  end
end
