defmodule MyLiege.Engine.Worker do
  @moduledoc "A worker: colour fixed from birth, untrained or trained, placed in a building or not."

  @enforce_keys [:colour]
  defstruct colour: nil, trained: false, building: nil
end
