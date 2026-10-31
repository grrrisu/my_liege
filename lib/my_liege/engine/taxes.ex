defmodule MyLiege.Engine.Taxes do
  @moduledoc """
  R7, taxes: twice a year, per head. The village is counted at the start of the count week,
  `tax_count_lead_weeks` before each payment, and the amount is fixed then. In the due week
  the player pays in full or the payment is missed; no partial payments. More misses than
  `tax_misses_forgiven` end the game.

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{Config, Fixed}

  @doc "Payments are due in weeks `tax_interval_weeks`, 2 × `tax_interval_weeks`, …"
  def due_week?(week, %Config{} = config),
    do: week > 0 and rem(week, config.tax_interval_weeks) == 0

  @doc "The first due week after `week`."
  def next_due_week(week, %Config{} = config),
    do: (div(week, config.tax_interval_weeks) + 1) * config.tax_interval_weeks

  @doc "The village is counted `tax_count_lead_weeks` before each due week."
  def count_week?(week, %Config{} = config),
    do: due_week?(week + config.tax_count_lead_weeks, config)

  @doc "The amount fixed at the count: `tax_per_worker` for every worker."
  def assess(workers, %Config{} = config), do: Fixed.from(config.tax_per_worker * length(workers))

  @doc """
  Settles a due payment. Returns `{outcome, gold}`: `:paid` takes the full amount,
  `:skipped` is a miss by the player's choice, `:missed` means the gold was not enough.
  """
  def settle(gold, due, pay?) do
    cond do
      not pay? -> {:skipped, gold}
      gold >= due -> {:paid, gold - due}
      true -> {:missed, gold}
    end
  end

  @doc "Whether this many misses end the game."
  def game_over?(misses, %Config{} = config), do: misses > config.tax_misses_forgiven
end
