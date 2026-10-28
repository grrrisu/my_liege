defmodule MyLiege.Engine.Production do
  @moduledoc """
  R2: production = base production × colour factor.

  Amounts are kept as decimals for now; the designer will decide how to handle fractions.
  """

  alias MyLiege.Engine.{Building, Config, Pentagon, Worker}

  @doc "One worker's output per week in the given building."
  def worker_output(%Worker{} = worker, %Building{} = building, %Config{} = config) do
    training = if worker.trained, do: :trained, else: :untrained
    relation = Pentagon.relation(worker.colour, Building.colour(building))
    factor = config.colour_factors[training][relation]
    Map.fetch!(config.base_production, building.type) * factor
  end

  @doc "Total output per product in `week`, from placed workers in ready buildings."
  def week(workers, buildings, week, %Config{} = config) do
    ready_buildings =
      for building <- buildings, Building.ready?(building, week), into: %{} do
        {building.id, building}
      end

    totals = Map.new(Building.products(), &{&1, 0.0})

    Enum.reduce(workers, totals, fn worker, totals ->
      case Map.fetch(ready_buildings, worker.building) do
        {:ok, building} ->
          Map.update!(
            totals,
            Building.product(building),
            &(&1 + worker_output(worker, building, config))
          )

        :error ->
          totals
      end
    end)
  end
end
