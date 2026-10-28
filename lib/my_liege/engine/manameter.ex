defmodule MyLiege.Engine.Manameter do
  @moduledoc "The society's mana shares per colour in per mille, summing to 1000."

  @enforce_keys [:green, :blue, :red, :yellow, :violet]
  defstruct @enforce_keys

  @doc "The five colours in pentagon order: Growth – Wisdom – Strength – Wealth – Culture."
  def colours, do: @enforce_keys

  def total_shares, do: 1000

  @doc "Sum of the amounts per colour in a Manameter or a per-colour mana map."
  def total(amounts), do: Enum.reduce(@enforce_keys, 0, &(Map.fetch!(amounts, &1) + &2))
end
