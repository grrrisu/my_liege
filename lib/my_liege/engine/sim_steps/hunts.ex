defmodule MyLiege.Engine.SimSteps.Hunts do
  @moduledoc """
  Step 8 of the week, after the inventions, R17 hunts return: every hunt whose return week this
  is draws its luck from `game.rand`, brings its haul into the food stock, disappears and
  releases its party, travelling. The draw comes after the week's birth (step 6). The food
  is in the stock for taxes, demands and spoilage of this week, not for its eating or birth.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Hunting

  @impl true
  def run(game, report) do
    {places, workers, food, results, rand} =
      Hunting.return(game.places, game.workers, game.week, game.config, game.rand)

    stocks = %{game.stocks | food: game.stocks.food + food}

    {%{game | places: places, workers: workers, stocks: stocks, rand: rand},
     %{report | food_from_hunting: food, hunts_returned: results}}
  end
end
