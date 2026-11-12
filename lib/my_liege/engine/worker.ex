defmodule MyLiege.Engine.Worker do
  @moduledoc """
  A worker: colour fixed from birth, untrained or trained, placed at a place or not.
  `training_started` is the first training week while it is in the guildhouse.
  `travel` is the weeks it still needs to reach where it is (R2): above 0 it is already counted
  there but does nothing, and an unplaced worker can't be placed yet.
  """

  alias MyLiege.Engine.{Config, Place}

  @enforce_keys [:colour]
  defstruct id: nil,
            colour: nil,
            trained: false,
            place: nil,
            born_week: nil,
            training_started: nil,
            travel: 0

  @type t :: %__MODULE__{}

  @doc "All training levels: `:untrained`, then `:trained`."
  def trainings, do: [:untrained, :trained]

  @doc "The starting workers: `start_farmers` green on the farm, `start_soldiers` red in the tower."
  def starting(places, %Config{} = config) do
    farm = Enum.find(places, &(Place.type(&1) == :farm))
    tower = Enum.find(places, &(Place.type(&1) == :watchtower))

    (List.duplicate(%__MODULE__{colour: :green, place: farm.id}, config.start_farmers) ++
       List.duplicate(%__MODULE__{colour: :red, place: tower.id}, config.start_soldiers))
    |> Enum.with_index(1)
    |> Enum.map(fn {worker, id} -> %{worker | id: id} end)
  end

  @doc "The next free worker id."
  def next_id(workers), do: workers |> Enum.map(& &1.id) |> Enum.max(fn -> 0 end) |> Kernel.+(1)
end
