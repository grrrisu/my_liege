defmodule MyLiege.Engine.Pentagon do
  @moduledoc "How two colours relate on the pentagon: neighbours are allies, non-neighbours opponents."

  alias MyLiege.Engine.Manameter

  @doc "Returns `:same`, `:neighbour` or `:opposite`."
  def relation(colour, colour), do: :same

  def relation(colour, other_colour) do
    colours = Manameter.colours()
    position = Enum.find_index(colours, &(&1 == colour))
    other_position = Enum.find_index(colours, &(&1 == other_colour))
    distance = abs(position - other_position)
    if distance in [1, length(colours) - 1], do: :neighbour, else: :opposite
  end
end
