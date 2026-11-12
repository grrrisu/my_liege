defmodule MyLiege.Engine.Rules.Mana do
  @moduledoc """
  R3: mana per worker per week. Untrained: 2 in the building's colour and 1 in their own;
  trained: 1 and 2. Same colour gives 3 of that colour. Unplaced workers make no mana.
  """

  alias MyLiege.Engine.{Config, Pentagon, Place, Worker}
  alias MyLiege.Engine.Place.Building
  alias MyLiege.Engine.Rules.Staffing

  @doc "One worker's mana per week in the given place, per colour."
  def worker_mana(%Worker{} = worker, %Building{} = place, %Config{} = config) do
    training = if worker.trained, do: :trained, else: :untrained
    amounts = config.mana[training]

    %{Place.colour(place) => amounts.place_colour}
    |> Map.update(worker.colour, amounts.worker_colour, &(&1 + amounts.worker_colour))
  end

  @doc "Total mana per colour in `week`, from placed workers in ready buildings."
  def produced(workers, places, week, %Config{} = config) do
    totals = Map.new(Pentagon.colours(), &{&1, 0})

    workers
    |> Staffing.working(places, week)
    |> Enum.reduce(totals, fn {worker, place}, totals ->
      Map.merge(totals, worker_mana(worker, place, config), fn _colour, total, mana ->
        total + mana
      end)
    end)
  end
end
