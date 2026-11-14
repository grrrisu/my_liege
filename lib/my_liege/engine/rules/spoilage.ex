defmodule MyLiege.Engine.Rules.Spoilage do
  @moduledoc """
  R9, spoilage: each week, every stock above 0 loses its product's
  `good_spoilage` share (per mille) of itself, rounded down, so the stock keeps the
  remainder. An empty stock doesn't spoil. While a granary is
  working (R14), food spoils at the granary's rate instead (`Granary.food_spoilage/2`).

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.Config
  alias MyLiege.Engine.Rules.Granary

  @doc """
  Returns `{stocks, spoiled}`, both maps of product => amount. `food_protected`: the food the
  working granaries protect (R14, `Granary.protected/3`), 0 without one.
  """
  def spoil(stocks, %Config{} = config, food_protected \\ 0) do
    spoiled =
      Map.new(stocks, fn
        {:food, stock} -> {:food, Granary.food_spoiled(stock, food_protected, config)}
        {product, stock} -> {product, spoiled(stock, Map.fetch!(config.good_spoilage, product))}
      end)

    {Map.merge(stocks, spoiled, fn _product, stock, lost -> stock - lost end), spoiled}
  end

  defp spoiled(stock, rate) when stock > 0, do: div(stock * rate, 1000)
  defp spoiled(_stock, _rate), do: 0
end
