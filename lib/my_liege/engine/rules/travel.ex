defmodule MyLiege.Engine.Rules.Travel do
  @moduledoc """
  R2, travel: a worker that is placed, moved, unplaced or released gets `travel_weeks` of
  travel; on the way to or from a trade route (R16), the route's travel weeks instead
  (`weeks/3`). It is at its destination at once, but while travel is above 0 it produces nothing,
  makes no mana, doesn't build and doesn't train; it still eats and counts for taxes.
  Travel goes down by 1 each week.
  """

  alias MyLiege.Engine.{Config, Place, Worker}
  alias MyLiege.Engine.Place.Trade
  alias MyLiege.Engine.Rules.Trades

  @doc "Sends `worker` to `place_id` (`nil` for unplaced), starting its travel."
  def depart(%Worker{} = worker, place_id, %Config{} = config),
    do: %{worker | place: place_id, travel: config.travel_weeks}

  @doc """
  Sends `worker` from the place `from` to the place `to` (either `nil` for unplaced),
  starting its travel of `weeks/3`.
  """
  def depart(%Worker{} = worker, from, to, %Config{} = config),
    do: %{worker | place: to && to.id, travel: weeks(from, to, config)}

  @doc """
  The weeks of travel from the place `from` to the place `to` (either `nil` for unplaced):
  the route's travel weeks if either is a trade route (R16), else `travel_weeks`.
  """
  def weeks(%Trade{} = route, _to, %Config{} = config), do: route_weeks(route, config)
  def weeks(_from, %Trade{} = route, %Config{} = config), do: route_weeks(route, config)
  def weeks(_from, _to, %Config{} = config), do: config.travel_weeks

  defp route_weeks(route, config), do: route |> Place.type() |> Trades.travel_weeks(config)

  def travelling?(%Worker{travel: travel}), do: travel > 0

  @doc "Counts down one week of travel for every worker still on the way, not below 0."
  def count_down(workers), do: Enum.map(workers, &%{&1 | travel: max(&1.travel - 1, 0)})
end
