defmodule MyLiege.Engine.Food do
  @moduledoc """
  R8: every worker, placed or not, eats `food_eaten_per_worker` each week. Leftover food
  carries over with no limit. In a week without enough food the missing food is forgotten
  and the stock is set to -1, so `Births.attempt/5` blocks the birth and the week can be
  logged as short (`food_left < 0`).

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{Config, Fixed}

  @short -1

  def starting(%Config{} = config), do: Fixed.from(config.starting_food)

  @doc "Eats from `food` (the stock after production). Returns the food left, or -1 if short."
  def eat(food, workers, %Config{} = config) do
    needed = Fixed.from(config.food_eaten_per_worker * length(workers))

    # first-test rule only; revisit when hunger and starvation (T65) are introduced
    if food >= needed, do: food - needed, else: @short
  end
end
