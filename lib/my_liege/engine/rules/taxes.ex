defmodule MyLiege.Engine.Rules.Taxes do
  @moduledoc """
  R7, taxes: twice a year, per head. The village is counted in the count week,
  `tax_count_lead_weeks` before each payment, and the amount is fixed then. No payment is due
  inside the grace period (`Grace`); the first is the first regular due week after it. In the
  due week the player pays in full or the payment is missed; no partial payments. A skipped or
  missed payment is a miss (`Misses`), and the king takes the gold there is, up to the amount
  due.

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{Config, Fixed}
  alias MyLiege.Engine.Rules.Grace

  @doc """
  Payments are due in weeks `tax_interval_weeks`, 2 × `tax_interval_weeks`, …, except inside
  the grace period.
  """
  def due_week?(week, %Config{} = config),
    do:
      week > 0 and rem(week, config.tax_interval_weeks) == 0 and not Grace.in_grace?(week, config)

  @doc "The first due week after `week`."
  def next_due_week(week, %Config{} = config) do
    next = (div(week, config.tax_interval_weeks) + 1) * config.tax_interval_weeks
    if due_week?(next, config), do: next, else: next_due_week(next, config)
  end

  @doc "The village is counted `tax_count_lead_weeks` before each due week."
  def count_week?(week, %Config{} = config),
    do: due_week?(week + config.tax_count_lead_weeks, config)

  @doc "The amount fixed at the count: `tax_per_worker` for every worker."
  def assess(workers, %Config{} = config), do: Fixed.from(config.tax_per_worker * length(workers))

  @doc """
  Settles a due payment. Returns `{outcome, gold, taken}`: `:paid` takes the full amount,
  `:skipped` is a miss by the player's choice, `:missed` means the gold was not enough. On
  `:skipped` and `:missed` the king takes the gold there is, up to `due`; `taken` is that
  amount, 0 when paid.
  """
  def settle(gold, due, pay?) do
    cond do
      pay? and gold >= due -> {:paid, gold - due, 0}
      pay? -> take(:missed, gold, due)
      true -> take(:skipped, gold, due)
    end
  end

  defp take(outcome, gold, due) do
    taken = gold |> max(0) |> min(due)
    {outcome, gold - taken, taken}
  end
end
