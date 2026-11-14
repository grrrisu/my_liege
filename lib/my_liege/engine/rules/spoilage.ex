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
  Returns `{stocks, spoiled}`, both maps of product => amount. `granary_working?`: whether a
  granary was working this week.
  """
  def spoil(stocks, %Config{} = config, granary_working? \\ false) do
    rates = %{config.good_spoilage | food: Granary.food_spoilage(granary_working?, config)}

    spoiled =
      Map.new(stocks, fn {product, stock} ->
        {product, spoiled(stock, Map.fetch!(rates, product))}
      end)

    {Map.merge(stocks, spoiled, fn _product, stock, lost -> stock - lost end), spoiled}
  end

  defp spoiled(stock, rate) when stock > 0, do: div(stock * rate, 1000)
  defp spoiled(_stock, _rate), do: 0
end
