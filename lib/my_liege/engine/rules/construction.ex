defmodule MyLiege.Engine.Rules.Construction do
  @moduledoc """
  R2, builders: a site needs `build_builders` builders. It advances one week in every
  week in which all of them are on it and had arrived (travel 0) in `start_workers`, and is
  finished after `build_weeks` such weeks: it produces from the next week and its
  builders return unplaced, travelling. A builder leaving early resets the progress to 0
  (`Placement.leave/1`).
  """

  alias MyLiege.Engine.{Config, Place, Worker}
  alias MyLiege.Engine.Place.Building
  alias MyLiege.Engine.Rules.Travel

  @doc "The workers placed on the place with id `site_id`."
  def builders(workers, site_id), do: Place.workers_at(workers, site_id)

  @doc "The builders on the site who have arrived."
  def arrived(workers, site_id),
    do: workers |> builders(site_id) |> Enum.reject(&Travel.travelling?/1)

  @doc "How many builders on all sites have arrived."
  def arrived_builders(workers, places) do
    sites = for place <- places, Building.site?(place), into: MapSet.new(), do: place.id

    Enum.count(workers, &(MapSet.member?(sites, &1.place) and not Travel.travelling?(&1)))
  end

  @doc """
  Advances every site by one week of construction in `week`. `start_workers` are the workers as they were when the week
  started, before travel went down; `workers` are the current ones, whose finished builders
  are released. Returns `{places, workers, finished_places}`.
  """
  def advance_sites(places, start_workers, workers, week, %Config{} = config) do
    {places, finished} =
      Enum.map_reduce(places, [], fn place, finished ->
        case advance(place, start_workers, week, config) do
          {:finished, place} -> {place, finished ++ [place]}
          {:as_is, place} -> {place, finished}
        end
      end)

    finished_ids = MapSet.new(finished, & &1.id)

    workers =
      Enum.map(workers, fn %Worker{} = worker ->
        if MapSet.member?(finished_ids, worker.place),
          do: Travel.depart(worker, nil, config),
          else: worker
      end)

    {places, workers, finished}
  end

  defp advance(%Building{} = place, start_workers, week, config) do
    cond do
      not Building.site?(place) or not working?(place, start_workers, config) ->
        {:as_is, place}

      place.progress + 1 >= config.build_weeks ->
        {:finished, %{place | progress: place.progress + 1, ready_week: week + 1}}

      true ->
        {:as_is, %{place | progress: place.progress + 1}}
    end
  end

  defp working?(place, start_workers, config),
    do: length(arrived(start_workers, place.id)) == config.build_builders
end
