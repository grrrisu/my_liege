defmodule MyLiege.Engine.SimSteps.TradeRoute do
  @moduledoc """
  Step 13 of the week, after the king's demand is made and before the bandits, R16 trade
  routes: each arrived trader, in the order he was placed on the route, pays his price from
  the gold stock and brings the route's food, if the gold covers it (`Rules.Trades.settle/4`).
  As for production, a trader has arrived if his travel was 0 at the start of the week.
  Taxes and demands are settled before, so a route never makes them miss; the bandits see the
  gold after the trade, and the food spoils in this week's spoilage.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Place.Trade
  alias MyLiege.Engine.Rules.Trades

  @impl true
  def run(game, report) do
    workers = with_start_travel(game.workers, report.start.workers)

    {places, totals} =
      Enum.map_reduce(game.places, %{gold_paid: 0, food: 0, traders: 0}, fn
        %Trade{} = route, totals ->
          {route, result} =
            Trades.settle(route, workers, game.stocks.gold - totals.gold_paid, game.config)

          {route, Map.merge(totals, result, fn _key, a, b -> a + b end)}

        place, totals ->
          {place, totals}
      end)

    stocks = %{
      game.stocks
      | gold: game.stocks.gold - totals.gold_paid,
        food: game.stocks.food + totals.food
    }

    {%{game | places: places, stocks: stocks},
     %{
       report
       | gold_to_trade: totals.gold_paid,
         food_from_trade: totals.food,
         traders: totals.traders
     }}
  end

  # travel counts down in step 3; the trade uses each worker's travel at the start of the week
  defp with_start_travel(workers, start_workers) do
    start_travel = Map.new(start_workers, &{&1.id, &1.travel})
    Enum.map(workers, &%{&1 | travel: Map.get(start_travel, &1.id, &1.travel)})
  end
end
