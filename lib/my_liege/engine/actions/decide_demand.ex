defmodule MyLiege.Engine.Actions.DecideDemand do
  @moduledoc """
  Decides whether to deliver (`true`) or refuse (`false`) the demand due next week. This is
  only possible when `Game.demand_decision_due?/1`; otherwise it returns
  `{:error, :no_demand_due}`. Success returns `{:ok, game}` and the decision takes effect in
  the next week.
  """

  alias MyLiege.Engine.Game

  def run(%Game{} = game, deliver?) when is_boolean(deliver?) do
    if Game.demand_decision_due?(game),
      do: {:ok, %{game | deliver_demand: deliver?}},
      else: {:error, :no_demand_due}
  end
end
