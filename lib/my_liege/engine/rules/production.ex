defmodule MyLiege.Engine.Rules.Production do
  @moduledoc """
  R2: production = base production × colour factor (in per mille).

  A worker on a king's demand project (R7) produces as in a building of the project's colour
  and good; that output goes into the project (`project_output/4`), not to the stock
  (`output/4`). Amounts are in thousandths (see `Fixed`), so the result is exact.
  """

  alias MyLiege.Engine.{Config, Fixed, Pentagon, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Building, Project}
  alias MyLiege.Engine.Rules.Staffing

  @doc "One worker's output per week in a building or on a demand project."
  def worker_output(%Worker{} = worker, place, %Config{} = config) do
    training = if worker.trained, do: :trained, else: :untrained
    relation = Pentagon.relation(worker.colour, Place.colour(place))
    factor_per_mille = config.efficiency[training][relation]
    base = config.place_output_per_worker |> Map.fetch!(base_type(place)) |> Fixed.from()
    div(base * factor_per_mille, 1000)
  end

  @doc "Total output per product in `week` that goes to the stock: from workers in buildings."
  def output(workers, places, week, %Config{} = config) do
    totals = Map.new(Blueprint.goods(), &{&1, 0})

    workers
    |> Staffing.working(places, week)
    |> Enum.filter(fn {_worker, place} -> match?(%Building{}, place) end)
    |> Enum.reduce(totals, fn {worker, place}, totals ->
      Map.update!(
        totals,
        Place.good(place),
        &(&1 + worker_output(worker, place, config))
      )
    end)
  end

  @doc """
  Output in `week` of the workers on demand projects, `%{project_id => amount}` (thousandths);
  a project without working workers is left out.
  """
  def project_output(workers, places, week, %Config{} = config) do
    workers
    |> Staffing.working(places, week)
    |> Enum.filter(fn {_worker, place} -> match?(%Project{gives: {:demand, _}}, place) end)
    |> Enum.reduce(%{}, fn {worker, place}, totals ->
      Map.update(totals, place.id, worker_output(worker, place, config), fn total ->
        total + worker_output(worker, place, config)
      end)
    end)
  end

  # the type whose base output applies: the building's, or that of the project's home place
  defp base_type(%Building{} = building), do: Place.type(building)

  defp base_type(%Project{gives: {:demand, _}} = project),
    do: Blueprint.home_type(Place.colour(project))
end
