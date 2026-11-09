defmodule MyLiege.Engine.Rules.Happiness do
  @moduledoc """
  R11, happiness: the week's entertainment production against the population sets a step from
  −3 to +3, which changes the week's food and defence production.

  - Ratio (per mille, rounded down) = entertainment production ÷ (population ×
    `happiness_culture_per_worker`). The production counts whether it goes to the stock or
    into a project; the stock plays no part. Population is every worker. A population of 0
    raises.
  - Step: below `happiness_penalty_3_below` −3, below `_2_below` −2, below `_1_below` −1;
    from `happiness_bonus_3_from` +3, from `_2_from` +2, from `_1_from` +1; otherwise 0.
  - In the grace period (`Grace`) the step applied is 0; the step it would have is still known.
  - Food and defence production × (1000 ± `happiness_step_<n>`) per mille, rounded down, on
    each product's total. Nothing else changes.

  Production is in thousandths (see `Fixed`); `happiness_culture_per_worker` is per mille of a
  unit, so population × it is already in thousandths.
  """

  alias MyLiege.Engine.Config
  alias MyLiege.Engine.Rules.Grace

  @changed_products [:food, :defence]

  @type step :: -3..3

  @doc "Entertainment production ÷ what `population` needs, per mille, rounded down."
  def ratio(_entertainment, 0, _config),
    do: raise(ArgumentError, "happiness: population is 0, the ratio is undefined")

  def ratio(entertainment, population, %Config{} = config)
      when is_integer(population) and population > 0,
      do: div(entertainment * 1000, population * config.happiness_culture_per_worker)

  @doc "The step a ratio gives, grace period aside."
  def step_for(ratio, %Config{} = config) do
    below = config.happiness_penalty_below
    from = config.happiness_bonus_from

    cond do
      ratio < below[3] -> -3
      ratio < below[2] -> -2
      ratio < below[1] -> -1
      ratio >= from[3] -> 3
      ratio >= from[2] -> 2
      ratio >= from[1] -> 1
      true -> 0
    end
  end

  @doc """
  The ratio and steps in `week`: `ratio`, `step` (applied: 0 in the grace period) and
  `step_without_grace` (the step the ratio gives).
  """
  def assess(entertainment, population, week, %Config{} = config) do
    ratio = ratio(entertainment, population, config)
    step = step_for(ratio, config)
    applied = if Grace.in_grace?(week, config), do: 0, else: step
    %{ratio: ratio, step: applied, step_without_grace: step}
  end

  @doc "Production with food and defence changed by `step`; other products unchanged."
  def apply_step(production, 0, _config), do: production

  def apply_step(production, step, %Config{} = config) do
    factor = 1000 + sign(step) * Map.fetch!(config.happiness_steps, abs(step))

    Enum.reduce(@changed_products, production, fn product, production ->
      Map.update!(production, product, &div(&1 * factor, 1000))
    end)
  end

  defp sign(step) when step > 0, do: 1
  defp sign(step) when step < 0, do: -1
end
