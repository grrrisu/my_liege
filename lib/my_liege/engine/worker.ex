defmodule MyLiege.Engine.Worker do
  @moduledoc "A worker: colour fixed from birth, untrained or trained, placed in a building or not."

  alias MyLiege.Engine.Config

  @enforce_keys [:colour]
  defstruct colour: nil, trained: false, building: nil

  @doc "The starting workers: `starting_farmers` green on the farm, `starting_soldiers` red in the tower."
  def starting(buildings, %Config{} = config) do
    farm = Enum.find(buildings, &(&1.type == :farm))
    tower = Enum.find(buildings, &(&1.type == :watchtower))

    List.duplicate(%__MODULE__{colour: :green, building: farm.id}, config.starting_farmers) ++
      List.duplicate(%__MODULE__{colour: :red, building: tower.id}, config.starting_soldiers)
  end
end
