defmodule MyLiege.Engine.Rules.Granary do
  @moduledoc """
  R14, granary: violet's way to food, a building ordered and built like any other. Its keeper
  produces nothing (`Rules.Production`) but makes mana (`Rules.Mana`). A granary is working
  while its keeper works there (arrived, travel 0; `Staffing.working/3`).

  - Each working granary protects up to `place_granary_food_capacity` food: the protected
    food is their number × that, at most the food stock (`protected/3`). At spoilage (R9)
    the protected food spoils at `place_granary_food_spoilage` per mille, the rest of the
    stock at `good_spoilage.food`, each part rounded down (`food_spoiled/3`).
  - Each working granary costs `place_granary_culture_upkeep` culture a week, taken from the
    culture stock after the week's production, never below 0. What is taken is culture
    spent: the culture that counts for happiness (R11) is the culture made in buildings minus
    it, never below 0.

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{Config, Fixed, Place}
  alias MyLiege.Engine.Rules.Staffing

  @doc "How many granaries have a working keeper in `week`."
  def working(workers, places, week) do
    workers
    |> Staffing.working(places, week)
    |> Enum.filter(fn {_worker, place} -> Place.type(place) == :granary end)
    |> Enum.uniq_by(fn {_worker, place} -> place.id end)
    |> length()
  end

  @doc """
  The culture taken for the upkeep of `working` granaries from `culture` (the stock after the
  week's production): the upkeep owed, at most what there is above 0.
  """
  def upkeep(working, culture, %Config{} = config) do
    owed = working * Fixed.from(config.place_granary_culture_upkeep)
    min(owed, max(culture, 0))
  end

  @doc "The culture that counts for happiness: `made` minus `spent`, never below 0."
  def culture_for_happiness(made, spent), do: max(made - spent, 0)

  @doc """
  The food (thousandths) `working` granaries protect from a `food` stock: `working` ×
  `place_granary_food_capacity`, at most the stock, 0 for a stock at or below 0.
  """
  def protected(working, food, %Config{} = config),
    do: min(working * Fixed.from(config.place_granary_food_capacity), max(food, 0))

  @doc """
  The food that spoils from a `food` stock of which `protected` is protected: the protected
  part × `place_granary_food_spoilage` ÷ 1000 plus the rest × `good_spoilage.food` ÷ 1000,
  each rounded down; 0 for a stock at or below 0.
  """
  def food_spoiled(food, _protected, %Config{}) when food <= 0, do: 0

  def food_spoiled(food, protected, %Config{} = config) do
    div(protected * config.place_granary_food_spoilage, 1000) +
      div((food - protected) * Map.fetch!(config.good_spoilage, :food), 1000)
  end
end
