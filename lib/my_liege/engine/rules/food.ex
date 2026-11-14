defmodule MyLiege.Engine.Rules.Food do
  @moduledoc """
  R8: every worker, placed or not, eats `good_food_eaten_per_worker` each week. Leftover food
  carries over with no limit. In a week without enough food (a short week) the missing food
  is forgotten and the stock stops at 0; the week is reported as short
  (`WeeklyReport.food_short`), which blocks its birth (R1).

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{Config, Fixed}

  def starting(%Config{} = config), do: Fixed.from(config.start_food)

  @doc """
  Eats from `food` (the stock after production). Returns `{food_left, short?}`: in a short
  week the food left is 0.
  """
  def eat(food, workers, %Config{} = config) do
    needed = Fixed.from(config.good_food_eaten_per_worker * length(workers))

    # first-test rule only; revisit when hunger and starvation (T65) are introduced
    if food >= needed, do: {food - needed, false}, else: {0, true}
  end
end
