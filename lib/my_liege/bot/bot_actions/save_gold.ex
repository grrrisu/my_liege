defmodule MyLiege.Bot.BotActions.SaveGold do
  @moduledoc """
  While gold is below the next tax (`gold_low?/1`), unplaced workers go to a market.
  A placing action (`MyLiege.Bot.Placing`).

  Option `born_before: week`: only workers born before that week (and the starting
  workers) go.
  """

  @behaviour MyLiege.Bot.BotAction
  @behaviour MyLiege.Bot.Placing

  alias MyLiege.Bot.Placing
  alias MyLiege.Engine.{Forecast, Game}

  @impl MyLiege.Bot.BotAction
  def run(%Game{} = game, opts),
    do: Placing.run(game, Keyword.put(opts, :rules, [{__MODULE__, opts}]))

  @impl MyLiege.Bot.Placing
  def target(worker, game, opts) do
    if born_before?(worker, Keyword.get(opts, :born_before)) and gold_low?(game), do: :market
  end

  @doc """
  Whether gold is below the next tax: `Forecast.tax_amount/1`, the amount fixed at the
  count, or before the count `king_tax_per_worker` for every current worker.
  """
  def gold_low?(%Game{} = game), do: game.stocks.gold < Forecast.tax_amount(game)

  defp born_before?(_worker, nil), do: true
  defp born_before?(worker, week), do: worker.born_week == nil or worker.born_week < week
end
