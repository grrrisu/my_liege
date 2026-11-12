defmodule MyLiege.Engine.Pentagon do
  @moduledoc """
  The five colours and how they relate: neighbours on the pentagon are allies, non-neighbours
  opponents. The one place the pentagon order is defined.
  """

  # each colour neighbours the next, and the last neighbours the first
  @colours [:green, :yellow, :blue, :red, :violet]

  @doc "The five colours in pentagon order: Growth – Wealth – Wisdom – Strength – Culture."
  def colours, do: @colours

  @doc "All relations, closest first."
  def relations, do: [:same, :neighbour, :opposite]

  @doc "Returns `:same`, `:neighbour` or `:opposite`."
  def relation(colour, colour), do: :same

  def relation(colour, other_colour) do
    position = Enum.find_index(@colours, &(&1 == colour))
    other_position = Enum.find_index(@colours, &(&1 == other_colour))
    distance = abs(position - other_position)
    if distance in [1, length(@colours) - 1], do: :neighbour, else: :opposite
  end
end
