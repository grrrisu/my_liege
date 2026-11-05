defmodule MyLiege.Engine.SimSteps.TaxPayment do
  @moduledoc "Tax payment (R7), due weeks only: pays or skips the counted tax, or misses it."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.{Misses, Taxes}

  @impl true
  def run(%{tax_due: due} = game, report) when is_integer(due) do
    if Taxes.due_week?(game.week, game.config) do
      {outcome, gold} = Taxes.settle(game.stocks.gold, due, game.pay_tax)
      game = %{game | stocks: %{game.stocks | gold: gold}, tax_due: nil, pay_tax: nil}
      game = if outcome == :paid, do: game, else: Misses.record(game)
      {game, %{report | tax: outcome}}
    else
      {game, report}
    end
  end

  def run(game, report), do: {game, report}
end
