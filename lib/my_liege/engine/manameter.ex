defmodule MyLiege.Engine.Manameter do
  @moduledoc "The society's mana shares per colour, summing to 100."

  @enforce_keys [:green, :blue, :red, :yellow, :violet]
  defstruct @enforce_keys

  @doc "The five colours in pentagon order: Growth – Wisdom – Strength – Wealth – Culture."
  def colours, do: @enforce_keys
end
