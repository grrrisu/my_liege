defmodule MyLiege.Engine.ManameterUpdate do
  @moduledoc """
  R4: each week `manameter_points_per_week` points are removed in proportion to the current
  shares and added in proportion to the week's mana per colour. Shares keep decimals.
  """

  alias MyLiege.Engine.{Config, Manameter}

  @doc "Returns the new Manameter; unchanged in a week without mana."
  def update(%Manameter{} = manameter, mana, %Config{} = config) do
    total_mana = Enum.reduce(Manameter.colours(), 0, &(Map.fetch!(mana, &1) + &2))

    if total_mana == 0 do
      manameter
    else
      points = config.manameter_points_per_week

      Enum.reduce(Manameter.colours(), manameter, fn colour, new_manameter ->
        share = Map.fetch!(manameter, colour)
        removed = points * share / 100
        added = points * Map.fetch!(mana, colour) / total_mana
        Map.put(new_manameter, colour, share - removed + added)
      end)
    end
  end
end
