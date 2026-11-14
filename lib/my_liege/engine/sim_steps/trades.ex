defmodule MyLiege.Engine.SimSteps.Trades do
  @moduledoc """
  Step 8 of the week, after the books and inventions, R16 trades return: every trade whose
  return week this is brings its food into the stock, disappears and releases its trader,
  travelling. The food is in the stock for taxes, demands and spoilage of this week, not for
  its eating or birth.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Trades

  @impl true
  def run(game, report) do
    {places, workers, food, _returned} =
      Trades.return(game.places, game.workers, game.week, game.config)

    stocks = %{game.stocks | food: game.stocks.food + food}

    {%{game | places: places, workers: workers, stocks: stocks},
     %{report | food_from_trade: food}}
  end
end
