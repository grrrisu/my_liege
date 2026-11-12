defmodule MyLiege.Engine.Rules.Construction do
  @moduledoc """
  R2, builders: a site needs `build_builders` builders. It advances one week in every
  week in which all of them are on it and had arrived (travel 0) in `start_workers`, and is
  finished after `build_weeks` such weeks: it produces from the next week and its
  builders return unplaced, travelling. A builder leaving early resets the progress to 0.
  """

  alias MyLiege.Engine.{Building, Config, Worker}
  alias MyLiege.Engine.Rules.Travel

  @doc "The workers placed on the building with id `site_id`."
  def builders(workers, site_id), do: Enum.filter(workers, &(&1.building == site_id))

  @doc "The builders on the site who have arrived."
  def arrived(workers, site_id),
    do: workers |> builders(site_id) |> Enum.reject(&Travel.travelling?/1)

  @doc "How many builders on all sites have arrived."
  def arrived_builders(workers, buildings) do
    sites =
      for building <- buildings, Building.site?(building), into: MapSet.new(), do: building.id

    Enum.count(workers, &(MapSet.member?(sites, &1.building) and not Travel.travelling?(&1)))
  end

  @doc """
  Advances every site by one week of construction in `week`. `start_workers` are the workers as they were when the week
  started, before travel went down; `workers` are the current ones, whose finished builders
  are released. Returns `{buildings, workers, finished_buildings}`.
  """
  def advance_sites(buildings, start_workers, workers, week, %Config{} = config) do
    {buildings, finished} =
      Enum.map_reduce(buildings, [], fn building, finished ->
        case advance(building, start_workers, week, config) do
          {:finished, building} -> {building, finished ++ [building]}
          {:as_is, building} -> {building, finished}
        end
      end)

    finished_ids = MapSet.new(finished, & &1.id)

    workers =
      Enum.map(workers, fn %Worker{} = worker ->
        if MapSet.member?(finished_ids, worker.building),
          do: Travel.depart(worker, nil, config),
          else: worker
      end)

    {buildings, workers, finished}
  end

  defp advance(%Building{} = building, start_workers, week, config) do
    cond do
      not Building.site?(building) or not working?(building, start_workers, config) ->
        {:as_is, building}

      building.progress + 1 >= config.build_weeks ->
        {:finished, %{building | progress: building.progress + 1, ready_week: week + 1}}

      true ->
        {:as_is, %{building | progress: building.progress + 1}}
    end
  end

  defp working?(building, start_workers, config),
    do: length(arrived(start_workers, building.id)) == config.build_builders
end
