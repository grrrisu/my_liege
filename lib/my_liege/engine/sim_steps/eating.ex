defmodule MyLiege.Engine.SimSteps.Eating do
  @moduledoc """
  Step 5 of the week, R8 eating: all workers eat from the food stock after production; a
  short week leaves 0 food and is reported as `food_short`.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Food

  @impl true
  def run(game, report) do
    {food_left, short?} = Food.eat(game.stocks.food, game.workers, game.config)
    {%{game | stocks: %{game.stocks | food: food_left}}, %{report | food_short: short?}}
  end
end
