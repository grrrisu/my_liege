defmodule MyLiege.Engine.Rules.Production do
  @moduledoc """
  R2: production = base production × colour factor (in per mille).

  Amounts are in thousandths (see `Fixed`), so the result is exact.
  """

  alias MyLiege.Engine.{Config, Fixed, Pentagon, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Building}
  alias MyLiege.Engine.Rules.Staffing

  @doc "One worker's output per week in the given place."
  def worker_output(%Worker{} = worker, %Building{} = place, %Config{} = config) do
    training = if worker.trained, do: :trained, else: :untrained
    relation = Pentagon.relation(worker.colour, Place.colour(place))
    factor_per_mille = config.efficiency[training][relation]
    base = config.place_output_per_worker |> Map.fetch!(Place.type(place)) |> Fixed.from()
    div(base * factor_per_mille, 1000)
  end

  @doc "Total output per product in `week`, from placed workers in ready buildings."
  def output(workers, places, week, %Config{} = config) do
    totals = Map.new(Blueprint.goods(), &{&1, 0})

    workers
    |> Staffing.working(places, week)
    |> Enum.reduce(totals, fn {worker, place}, totals ->
      Map.update!(
        totals,
        Place.good(place),
        &(&1 + worker_output(worker, place, config))
      )
    end)
  end
end
