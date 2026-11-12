defmodule MyLiege.Engine.Actions.DecideTax do
  @moduledoc """
  Decides whether to pay (`true`) or skip (`false`) the tax due next week. This is only
  possible when `Game.tax_decision_due?/1`; otherwise it returns `{:error, :no_tax_due}`.
  Success returns `{:ok, game}` and the decision takes effect in the next week.
  """

  alias MyLiege.Engine.Game

  def run(%Game{} = game, pay?) when is_boolean(pay?) do
    if Game.tax_decision_due?(game),
      do: {:ok, %{game | pay_tax: pay?}},
      else: {:error, :no_tax_due}
  end
end
