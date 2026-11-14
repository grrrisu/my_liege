defmodule MyLiege.Engine.Rules.Travel do
  @moduledoc """
  R2, travel: a worker that is placed, moved, unplaced or released gets `travel_weeks` of
  travel; on the way to or from a trade route (R16) or the hunting camp (R17), its own
  travel weeks instead (`weeks/3`). It is at its destination at once, but while travel is above 0 it produces nothing,
  makes no mana, doesn't build and doesn't train; it still eats and counts for taxes.
  Travel goes down by 1 each week.
  """

  alias MyLiege.Engine.{Config, Place, Worker}
  alias MyLiege.Engine.Place.{Expedition, Trade}
  alias MyLiege.Engine.Rules.{Hunting, Trades}

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
  if either is a trade route (R16) or the hunting camp (R17), its own travel weeks instead of
  `travel_weeks` (the larger, if both are); else `travel_weeks`.
  """
  def weeks(from, to, %Config{} = config) do
    case Enum.reject([own_weeks(from, config), own_weeks(to, config)], &is_nil/1) do
      [] -> config.travel_weeks
      own -> Enum.max(own)
    end
  end

  defp own_weeks(%Trade{} = route, config),
    do: route |> Place.type() |> Trades.travel_weeks(config)

  defp own_weeks(%Expedition{}, config), do: Hunting.travel_weeks(config)
  defp own_weeks(_place, _config), do: nil

  def travelling?(%Worker{travel: travel}), do: travel > 0

  @doc """
  `workers` with each one's travel as it was in `start_workers` (the workers at the start of
  the week, before step 3 counted travel down); a worker not among them keeps his own. Used by
  the steps after step 3 that, like production, go by the travel at the start of the week.
  """
  def as_at_start(workers, start_workers) do
    start_travel = Map.new(start_workers, &{&1.id, &1.travel})
    Enum.map(workers, &%{&1 | travel: Map.get(start_travel, &1.id, &1.travel)})
  end

  @doc "Counts down one week of travel for every worker still on the way, not below 0."
  def count_down(workers), do: Enum.map(workers, &%{&1 | travel: max(&1.travel - 1, 0)})
end
