defmodule MyLiege.Engine.Rules.Staffing do
  @moduledoc """
  R2, staffing: which workers work in a week. A placed worker works once it has arrived
  (travel 0) and its place is a path building (one with a colour, a way such as the granary
  included), a king's demand project (R7), a book (R12), an invention (R15), a trade (R16) or
  an expedition (R17) (the last two: mana only, their whole time away), which work
  like a building of their colour (blue for a book or an invention). Workers in the neutral
  guildhouse or on sites produce nothing and make no mana. Whether a working worker produces
  into the stock is `Production.produces?/1`.
  """

  alias MyLiege.Engine.Place
  alias MyLiege.Engine.Place.{Building, Expedition, Project, Trade}

  @doc """
  Pairs each placed worker who has arrived with its place, if that place works.
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

  @doc """
  Whether workers at `place` produce and make mana: in a path building, on a demand project or
  on a book (R12) or an invention (R15), not on a site.
  """
  def works?(%Project{gives: {:demand, _}}, _week), do: true
  def works?(%Project{gives: {:book, _}}, _week), do: true
  def works?(%Project{gives: {:invention, _}}, _week), do: true
  def works?(%Trade{}, _week), do: true
  def works?(%Expedition{}, _week), do: true
  def works?(%Project{gives: {:building, _}}, _week), do: false
  def works?(%Building{} = building, _week), do: not Place.neutral?(building)
end
