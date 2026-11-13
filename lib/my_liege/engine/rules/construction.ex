defmodule MyLiege.Engine.Rules.Construction do
  @moduledoc """
  R2, builders: an ordered building is a site, a `Place.Project` that gives the building. A
  site needs `build_builders` builders. It advances one week in every week in which all of
  them are on it and had arrived (travel 0) in `start_workers`, and is finished after
  `build_weeks` such weeks: the building takes its place (same id) and produces from the next
  week, and its builders return unplaced, travelling. A builder leaving early resets the
  progress to 0 (`Placement.leave/1`).
  """

  alias MyLiege.Engine.{Config, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Building, Project}
  alias MyLiege.Engine.Rules.Travel

  @doc "Appends a new site for a building of `type` to `places`, with the next free id."
  def new_site(places, type, %Config{} = config) do
    site = %Project{
      id: Place.next_id(places),
      blueprint: Project.site_blueprint(),
      target: config.build_weeks,
      gives: {:building, type}
    }

    places ++ [site]
  end

  @doc "The workers placed on the place with id `site_id`."
  def builders(workers, site_id), do: Place.workers_at(workers, site_id)

  @doc "The builders on the site who have arrived."
  def arrived(workers, site_id),
    do: workers |> builders(site_id) |> Enum.reject(&Travel.travelling?/1)

  @doc "How many builders on all sites have arrived."
  def arrived_builders(workers, places) do
    sites = for %Project{id: id} <- places, into: MapSet.new(), do: id

    Enum.count(workers, &(MapSet.member?(sites, &1.place) and not Travel.travelling?(&1)))
  end

  @doc """
  Advances every site by one week of construction. `start_workers` are the workers as they
  were when the week started, before travel went down; `workers` are the current ones, whose
  finished builders are released. A finished site is replaced by its building.
  Returns `{places, workers, finished_buildings}`.
  """
  def advance_sites(places, start_workers, workers, %Config{} = config) do
    {places, finished} =
      Enum.map_reduce(places, [], fn place, finished ->
        case advance(place, start_workers, config) do
          {:finished, building} -> {building, finished ++ [building]}
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

  defp advance(%Project{gives: {:building, type}} = site, start_workers, config) do
    if working?(site, start_workers, config) do
      site = %{site | progress: site.progress + 1}

      if Project.done?(site),
        do: {:finished, %Building{id: site.id, blueprint: Blueprint.fetch!(type)}},
        else: {:as_is, site}
    else
      {:as_is, site}
    end
  end

  defp advance(place, _start_workers, _config), do: {:as_is, place}

  defp working?(site, start_workers, config),
    do: length(arrived(start_workers, site.id)) == config.build_builders
end
