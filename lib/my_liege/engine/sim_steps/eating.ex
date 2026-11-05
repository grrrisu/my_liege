defmodule MyLiege.Engine.SimSteps.Eating do
  @moduledoc "Step 5 of the week, R8 eating: all workers eat from the food stock after production."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Food

  @impl true
  def run(game, report) do
    food_left = Food.eat(game.stocks.food, game.workers, game.config)
    {%{game | stocks: %{game.stocks | food: food_left}}, report}
  end
end
