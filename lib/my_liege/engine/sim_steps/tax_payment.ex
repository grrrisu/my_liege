defmodule MyLiege.Engine.SimSteps.TaxPayment do
  @moduledoc """
  Step 10 of the week, R7 tax payment: in a due week, pays or skips the counted tax, or misses
  it. On a skip or a miss the king takes the gold there is, up to the tax, in `report.king_took`.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.{Misses, Taxes}

  @impl true
  def run(%{tax_due: due} = game, report) when is_integer(due) do
    if Taxes.due_week?(game.week, game.config) do
      {outcome, gold, taken} = Taxes.settle(game.stocks.gold, due, game.pay_tax)
      game = %{game | stocks: %{game.stocks | gold: gold}, tax_due: nil, pay_tax: nil}
      game = if outcome == :paid, do: game, else: add_miss(game)
      king_took = Map.update!(report.king_took, :gold, &(&1 + taken))
      {game, %{report | tax: outcome, king_took: king_took}}
    else
      {game, report}
    end
  end

  def run(game, report), do: {game, report}

  defp add_miss(game) do
    {misses, over?} = Misses.add(game.misses, game.config)
    %{game | misses: misses, game_over: game.game_over or over?}
  end
end
