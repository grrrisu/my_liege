defmodule MyLiege.Engine.Mana do
  @moduledoc """
  R3: mana per worker per week. Untrained: 2 in the building's colour and 1 in their own;
  trained: 1 and 2. Same colour gives 3 of that colour. Unplaced workers make no mana.
  """

  alias MyLiege.Engine.{Building, Config, Manameter, Worker}

  @doc "One worker's mana per week in the given building, per colour."
  def worker_mana(%Worker{} = worker, %Building{} = building, %Config{} = config) do
    training = if worker.trained, do: :trained, else: :untrained
    amounts = config.mana_per_worker[training]

    %{Building.colour(building) => amounts.building_colour}
    |> Map.update(worker.colour, amounts.own_colour, &(&1 + amounts.own_colour))
  end

  @doc "Total mana per colour in `week`, from placed workers in ready buildings."
  def week(workers, buildings, week, %Config{} = config) do
    totals = Map.new(Manameter.colours(), &{&1, 0})

    workers
    |> Building.staffed(buildings, week)
    |> Enum.reduce(totals, fn {worker, building}, totals ->
      Map.merge(totals, worker_mana(worker, building, config), fn _colour, total, mana ->
        total + mana
      end)
    end)
  end
end
