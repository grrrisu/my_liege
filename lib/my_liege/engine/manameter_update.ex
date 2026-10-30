defmodule MyLiege.Engine.ManameterUpdate do
  @moduledoc """
  R4: each week `manameter_points_per_week` points are removed in proportion to the current
  shares and added in proportion to the week's mana per colour.

  Shares are in per mille. Each new share is rounded down and the leftover units go to the
  colours with the largest remainders (ties in pentagon order), so the total never changes.
  """

  alias MyLiege.Engine.{Config, Manameter}

  @doc "Returns the new Manameter; unchanged in a week without mana."
  def update(%Manameter{} = manameter, mana, %Config{} = config) do
    total_mana = Manameter.total(mana)

    if total_mana == 0 do
      manameter
    else
      points = config.manameter_points_per_week
      rounded_down = rounded_down_shares(manameter, mana, total_mana, points)
      leftover = Manameter.total(manameter) - Enum.reduce(rounded_down, 0, &(elem(&1, 1) + &2))
      distribute_leftover(manameter, rounded_down, leftover)
    end
  end

  # new share = share - points * share / total_share + points * mana / total_mana
  defp rounded_down_shares(manameter, mana, total_mana, points) do
    total_share = Manameter.total(manameter)
    denominator = total_share * total_mana

    Enum.map(Manameter.colours(), fn colour ->
      numerator =
        Map.fetch!(manameter, colour) * (total_share - points) * total_mana +
          points * Map.fetch!(mana, colour) * total_share

      {colour, div(numerator, denominator), rem(numerator, denominator)}
    end)
  end

  # sort_by is stable, so ties keep pentagon order
  defp distribute_leftover(manameter, rounded_down, leftover) do
    rounded_down
    |> Enum.sort_by(fn {_, _, remainder} -> -remainder end)
    |> Enum.with_index()
    |> Enum.reduce(manameter, fn {{colour, share, _}, rank}, new_manameter ->
      extra = if rank < leftover, do: 1, else: 0
      Map.put(new_manameter, colour, share + extra)
    end)
  end
end
