defmodule MyLiege.Engine.Rules.Travel do
  @moduledoc """
  R2, travel: a worker that is placed, moved, unplaced or released gets `travel_weeks` of
  travel. It is at its destination at once, but while travel is above 0 it produces nothing,
  makes no mana, doesn't build and doesn't train; it still eats and counts for taxes.
  Travel goes down by 1 each week.
  """

  alias MyLiege.Engine.{Config, Worker}

  @doc "Sends `worker` to `place_id` (`nil` for unplaced), starting its travel."
  def depart(%Worker{} = worker, place_id, %Config{} = config),
    do: %{worker | place: place_id, travel: config.travel_weeks}

  def travelling?(%Worker{travel: travel}), do: travel > 0

  @doc "Counts down one week of travel for every worker still on the way, not below 0."
  def count_down(workers), do: Enum.map(workers, &%{&1 | travel: max(&1.travel - 1, 0)})
end
