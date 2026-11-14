defmodule MyLiege.Engine.Rules.Production do
  @moduledoc """
  R2: production = base production × colour factor (in per mille).

  A worker on a king's demand project (R7) produces as in a building of the project's colour
  and good; that output goes into the project (`project_output/4`), not to the stock
  (`output/5`). A worker on a book (R12) writes as in a blue building, times the book colour's
  experience factor (`Rules.Books`), into the book; a worker on an invention (R15) the same,
  times the experience factor of the colour of its good's home place (`Rules.Inventions`).
  A way building (R13, the granary) produces nothing. With the improved plough invented, each
  farm worker's output gets its bonus (`Rules.Inventions.farm_output/3`). Amounts are in
  thousandths (see `Fixed`), so the result is exact.
  """

  alias MyLiege.Engine.{Config, Fixed, Manameter, Pentagon, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Building, Project, Trade}
  alias MyLiege.Engine.Rules.{Books, Inventions, Staffing}

  @doc """
  One worker's output per week in a building or on a project of a colour (a demand project, a
  book's blue method), before a book's experience factor.
  """
  def worker_output(%Worker{} = worker, place, %Config{} = config) do
    factor_per_mille = efficiency(worker, Place.colour(place), config)
    base = config.place_output_per_worker |> Map.fetch!(base_type(place)) |> Fixed.from()
    div(base * factor_per_mille, 1000)
  end

  @doc "A worker's colour factor (per mille) against `colour`, untrained or trained."
  def efficiency(%Worker{} = worker, colour, %Config{} = config) do
    training = if worker.trained, do: :trained, else: :untrained
    config.efficiency[training][Pentagon.relation(worker.colour, colour)]
  end

  @doc """
  Total output per product in `week` that goes to the stock: from workers in home buildings,
  with the bonuses of `inventions` (the types invented, R15).
  """
  def output(workers, places, week, %Config{} = config, inventions \\ []) do
    totals = Map.new(Blueprint.goods(), &{&1, 0})

    workers
    |> Staffing.working(places, week)
    |> Enum.filter(fn {_worker, place} -> produces?(place) end)
    |> Enum.reduce(totals, fn {worker, place}, totals ->
      made = worker |> worker_output(place, config) |> with_bonus(place, inventions, config)
      Map.update!(totals, Place.good(place), &(&1 + made))
    end)
  end

  @doc "Whether working workers at `place` produce into the stock: in a building that is no way."
  def produces?(%Building{blueprint: blueprint}), do: not Blueprint.way?(blueprint)
  def produces?(%Project{}), do: false
  def produces?(%Trade{}), do: false

  defp with_bonus(output, place, inventions, config) do
    if Place.type(place) == :farm,
      do: Inventions.farm_output(output, inventions, config),
      else: output
  end

  @doc """
  Output in `week` of the workers on projects that take output (demand projects, books and
  inventions),
  `%{project_id => amount}` (thousandths); a project without working workers is left out.
  `manameter` is the one at the start of the week, for the experience factor.
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

  defp project_worker_output(worker, %Project{gives: {:invention, _}} = p, manameter, config),
    do: worker |> worker_output(p, config) |> Inventions.written(manameter, p)

  defp project_worker_output(worker, %Project{gives: {:demand, _}} = project, _manameter, config),
    do: worker_output(worker, project, config)

  # the type whose base output applies: the building's, or that of the home place of the
  # project's colour (blue for books and inventions)
  defp base_type(%Building{} = building), do: Place.type(building)

  defp base_type(%Project{gives: {kind, _}} = project) when kind in [:demand, :book, :invention],
    do: project |> Place.colour() |> Blueprint.home_type()
end
