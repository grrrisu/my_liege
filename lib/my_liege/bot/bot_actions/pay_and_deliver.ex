defmodule MyLiege.Bot.BotActions.PayAndDeliver do
  @moduledoc "Always pays the tax and delivers the king's demands when the decision is due."

  @behaviour MyLiege.Bot.BotAction

  alias MyLiege.Engine.Game

  @impl true
  def run(%Game{} = game, _opts) do
    game =
      if Game.tax_decision_due?(game),
        do: game |> Game.decide_tax(true) |> elem(1),
        else: game

    if Game.demand_decision_due?(game),
      do: game |> Game.decide_demand(true) |> elem(1),
      else: game
  end
end
