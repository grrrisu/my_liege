defmodule MyLiege.Engine.Rules.Mana do
  @moduledoc """
  R3: mana per worker per week. Untrained: 2 in the building's colour and 1 in their own;
  trained: 1 and 2. Same colour gives 3 of that colour. Unplaced workers make no mana. A
  worker on a king's demand project (R7) makes mana as in a building of the project's colour,
  a worker on a book (R12) as in a blue building.
  """

  alias MyLiege.Engine.{Config, Pentagon, Place, Worker}
  alias MyLiege.Engine.Place.{Building, Project}
  alias MyLiege.Engine.Rules.Staffing

  @doc "One worker's mana per week in a building or on a demand project, per colour."
  def worker_mana(%Worker{} = worker, place, %Config{} = config)
      when is_struct(place, Building) or is_struct(place, Project) do
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
