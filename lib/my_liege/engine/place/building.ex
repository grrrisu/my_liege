defmodule MyLiege.Engine.Place.Building do
  @moduledoc """
  A building that stands in the game, one kind of `Place`. A building is always finished: an
  ordered building is a `Place.Project` (a site) until it is done.
  """

  alias MyLiege.Engine.Place.Blueprint

  @enforce_keys [:id, :blueprint]
  defstruct @enforce_keys

  @type t :: %__MODULE__{id: pos_integer(), blueprint: Blueprint.t()}

  @doc "The buildings standing at the start of the game: the farm and the tower (a watchtower)."
  def starting do
    [
      %__MODULE__{id: 1, blueprint: Blueprint.fetch!(:farm)},
      %__MODULE__{id: 2, blueprint: Blueprint.fetch!(:watchtower)}
    ]
  end
end
