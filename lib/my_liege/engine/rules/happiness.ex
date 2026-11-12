defmodule MyLiege.Engine.Rules.Happiness do
  @moduledoc """
  R11, happiness: the week's culture production against the population sets a step from
  −3 to +3, which changes the week's food and defence production.

  - Ratio (per mille, rounded down) = culture production ÷ (population ×
    `happiness_need_per_worker`). The production counts whether it goes to the stock or
    into a project; the stock plays no part. Population is every worker. A population of 0
    raises.
  - Step: below `happiness.level3.penalty_below_permille` −3, below level 2 −2, below level 1 −1;
    from `happiness.level3.bonus_from_permille` +3, from level 2 +2, from level 1 +1; otherwise 0.
  - In the grace period (`Grace`) the step applied is 0; the step it would have is still known.
  - Food and defence production × (1000 ± `happiness.level<n>.change_permille`) per mille,
    rounded down, on each product's total. Nothing else changes.

  Production is in thousandths (see `Fixed`); `happiness_need_per_worker` is per mille of a
  unit, so population × it is already in thousandths.
  """

  alias MyLiege.Engine.Config
  alias MyLiege.Engine.Rules.Grace

  @changed_products [:food, :defence]

  @type step :: -3..3

  @doc "Culture production ÷ what `population` needs, per mille, rounded down."
  def ratio(_culture, 0, _config),
    do: raise(ArgumentError, "happiness: population is 0, the ratio is undefined")

  def ratio(culture, population, %Config{} = config)
      when is_integer(population) and population > 0,
      do: div(culture * 1000, population * config.happiness_need_per_worker)

  @doc "The step a ratio gives, grace period aside."
  def step_for(ratio, %Config{} = config) do
    below = config.happiness_penalty_below
    from = config.happiness_bonus_from

    cond do
      ratio < below.level3 -> -3
      ratio < below.level2 -> -2
      ratio < below.level1 -> -1
      ratio >= from.level3 -> 3
      ratio >= from.level2 -> 2
      ratio >= from.level1 -> 1
      true -> 0
    end
  end

  @doc """
  The ratio and steps in `week`: `ratio`, `step` (applied: 0 in the grace period) and
  `step_without_grace` (the step the ratio gives).
  """
  def assess(culture, population, week, %Config{} = config) do
    ratio = ratio(culture, population, config)
    step = step_for(ratio, config)
    applied = if Grace.in_grace?(week, config), do: 0, else: step
    %{ratio: ratio, step: applied, step_without_grace: step}
  end

  @doc "Production with food and defence changed by `step`; other products unchanged."
  def apply_step(production, 0, _config), do: production

  def apply_step(production, step, %Config{} = config) do
    factor = 1000 + sign(step) * Map.fetch!(config.happiness_change, level(step))

    Enum.reduce(@changed_products, production, fn product, production ->
      Map.update!(production, product, &div(&1 * factor, 1000))
    end)
  end

  defp level(step), do: :"level#{abs(step)}"

  defp sign(step) when step > 0, do: 1
  defp sign(step) when step < 0, do: -1
end
