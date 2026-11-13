defmodule MyLiege.Engine.Rules.Granary do
  @moduledoc """
  R14, granary: violet's way to food, a building ordered and built like any other. Its keeper
  produces nothing (`Rules.Production`) but makes mana (`Rules.Mana`). A granary is working
  while a keeper works there (arrived, travel 0; `Staffing.working/3`).

  - While at least one granary is working, food spoils at `place_granary_food_spoilage` per
    mille instead of `good_spoilage.food`; more granaries don't lower it further.
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

  @doc "The food spoilage per mille: the granary's while one is working, else the good's."
  def food_spoilage(true = _working?, %Config{} = config), do: config.place_granary_food_spoilage
  def food_spoilage(false, %Config{} = config), do: Map.fetch!(config.good_spoilage, :food)
end
