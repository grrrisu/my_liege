defmodule MyLiege.Engine.Production do
  @moduledoc """
  R2: production = base production × colour factor (in per mille).

  Amounts are in thousandths (see `Fixed`), so the result is exact.
  """

  alias MyLiege.Engine.{Building, Config, Fixed, Pentagon, Worker}

  @doc "One worker's output per week in the given building."
  def worker_output(%Worker{} = worker, %Building{} = building, %Config{} = config) do
    training = if worker.trained, do: :trained, else: :untrained
    relation = Pentagon.relation(worker.colour, Building.colour(building))
    factor_per_mille = config.colour_factors[training][relation]
    base = config.base_production |> Map.fetch!(building.type) |> Fixed.from()
    div(base * factor_per_mille, 1000)
  end

  @doc "Total output per product in `week`, from placed workers in ready buildings."
  def week(workers, buildings, week, %Config{} = config) do
    totals = Map.new(Building.products(), &{&1, 0})

    workers
    |> Building.staffed(buildings, week)
    |> Enum.reduce(totals, fn {worker, building}, totals ->
      Map.update!(
        totals,
        Building.product(building),
        &(&1 + worker_output(worker, building, config))
      )
    end)
  end
end
