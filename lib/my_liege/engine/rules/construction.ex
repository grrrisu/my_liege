defmodule MyLiege.Engine.Rules.Construction do
  @moduledoc """
  R2, builders: an ordered building is a site, a `Place.Project` that needs `build_work`
  work and gives the building. Up to `build_capacity` builders of any colour work on it. Each
  week, every builder on the site who had arrived (travel 0) in `start_workers` adds 1 to its
  progress. Once the progress reaches the target, the site is replaced by its building, with a
  new id, and its builders return unplaced, travelling. A builder leaving keeps the progress.
  """

  alias MyLiege.Engine.{Config, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Building, Project}
  alias MyLiege.Engine.Rules.Travel

  @doc "Appends a new site for a building of `type` to `places`, with the next free id."
  def new_site(places, type, %Config{} = config) do
    site = %Project{
      id: Place.next_id(places),
      blueprint: Project.site_blueprint(),
      target: config.build_work,
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
  Adds this week's work to every site. `start_workers` are the workers as they were when the
  week started, before travel went down; `workers` are the current ones, whose finished
  builders are released. A finished site is replaced, in its position, by its building with
  the next free id. Returns `{places, workers, finished_buildings}`.
  """
  def advance_sites(places, start_workers, workers, %Config{} = config) do
    {places, {_next_id, finished}} =
      Enum.map_reduce(places, {Place.next_id(places), []}, fn place, {next_id, finished} ->
        case advance(place, start_workers, next_id) do
          {:finished, site_id, building} ->
            {building, {next_id + 1, finished ++ [{site_id, building}]}}

          {:as_is, place} ->
            {place, {next_id, finished}}
        end
      end)

    finished_sites = MapSet.new(finished, fn {site_id, _building} -> site_id end)

    workers =
      Enum.map(workers, fn %Worker{} = worker ->
        if MapSet.member?(finished_sites, worker.place),
          do: Travel.depart(worker, nil, config),
          else: worker
      end)

    {places, workers, Enum.map(finished, fn {_site_id, building} -> building end)}
  end

  defp advance(%Project{gives: {:building, type}} = site, start_workers, next_id) do
    site = %{site | progress: site.progress + length(arrived(start_workers, site.id))}

    if Project.done?(site),
      do: {:finished, site.id, %Building{id: next_id, blueprint: Blueprint.fetch!(type)}},
      else: {:as_is, site}
  end

  defp advance(place, _start_workers, _next_id), do: {:as_is, place}
end
