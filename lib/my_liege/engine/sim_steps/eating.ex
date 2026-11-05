defmodule MyLiege.Engine.SimSteps.Eating do
  @moduledoc "Eating (R8): all workers eat from the food stock after production."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Food

  @impl true
  def run(game, report) do
    food_left = Food.eat(game.stocks.food, game.workers, game.config)
    {%{game | stocks: %{game.stocks | food: food_left}}, report}
  end
end
