defmodule MyLiege.Engine.Rules.Staffing do
  @moduledoc """
  R2, staffing: which workers work in a week. A placed worker works once it has arrived
  (travel 0) and its place is a ready path building. Workers in the neutral guildhouse or on
  sites produce nothing and make no mana.
  """

  alias MyLiege.Engine.Place
  alias MyLiege.Engine.Place.Building

  @doc """
  Pairs each placed worker who has arrived with its place, if that place works in `week`.
  Returns `[{worker, place}]` in the order of `workers`.
  """
  def working(workers, places, week) do
    working_places =
      for place <- places, works?(place, week), into: %{}, do: {place.id, place}

    for %{place: place_id, travel: 0} = worker <- workers,
        Map.has_key?(working_places, place_id) do
      {worker, Map.fetch!(working_places, place_id)}
    end
  end

  defp works?(%Building{} = place, week),
    do: Building.ready?(place, week) and not Place.neutral?(place)
end
