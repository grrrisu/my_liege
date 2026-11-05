defmodule MyLiege.Engine.Rules.Spoilage do
  @moduledoc """
  R9, spoilage: each week, every stock above 0 loses its product's
  `spoilage_rates` share (per mille) of itself, rounded down, so the stock keeps the
  remainder. Stocks at or below 0 (a short week's -1 food) don't spoil.

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.Config

  @doc "Returns `{stocks, spoiled}`, both maps of product => amount."
  def spoil(stocks, %Config{} = config) do
    spoiled =
      Map.new(stocks, fn {product, stock} ->
        {product, spoiled(stock, Map.fetch!(config.spoilage_rates, product))}
      end)

    {Map.merge(stocks, spoiled, fn _product, stock, lost -> stock - lost end), spoiled}
  end

  defp spoiled(stock, rate) when stock > 0, do: div(stock * rate, 1000)
  defp spoiled(_stock, _rate), do: 0
end
