defmodule MyLiege.Engine.Rules.Production do
  @moduledoc """
  R2: production = base production × colour factor (in per mille).

  A worker on a king's demand project (R7) produces as in a building of the project's colour
  and good; that output goes into the project (`project_output/4`), not to the stock
  (`output/4`). A worker on a book (R12) writes as in a blue building, times the book colour's
  experience factor (`Rules.Books`), into the book. Amounts are in thousandths (see `Fixed`),
  so the result is exact.
  """

  alias MyLiege.Engine.{Config, Fixed, Manameter, Pentagon, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Building, Project}
  alias MyLiege.Engine.Rules.{Books, Staffing}

  @doc """
  One worker's output per week in a building or on a project of a colour (a demand project, a
  book's blue method), before a book's experience factor.
  """
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
  Output in `week` of the workers on projects that take output (demand projects and books),
  `%{project_id => amount}` (thousandths); a project without working workers is left out.
  `manameter` is the one at the start of the week, for the books' experience factor.
  """
  def project_output(workers, places, week, %Manameter{} = manameter, %Config{} = config) do
    workers
    |> Staffing.working(places, week)
    |> Enum.filter(fn {_worker, place} -> match?(%Project{}, place) end)
    |> Enum.reduce(%{}, fn {worker, place}, totals ->
      made = project_worker_output(worker, place, manameter, config)
      Map.update(totals, place.id, made, &(&1 + made))
    end)
  end

  defp project_worker_output(worker, %Project{gives: {:book, colour}} = book, manameter, config),
    do: worker |> worker_output(book, config) |> Books.written(manameter, colour)

  defp project_worker_output(worker, %Project{gives: {:demand, _}} = project, _manameter, config),
    do: worker_output(worker, project, config)

  # the type whose base output applies: the building's, or that of the project's home place
  defp base_type(%Building{} = building), do: Place.type(building)

  defp base_type(%Project{gives: {kind, _}} = project) when kind in [:demand, :book],
    do: Blueprint.home_type(Place.colour(project))
end
