defmodule MyLiege.Engine.Place.Building do
  @moduledoc """
  A building that exists in the game, one kind of `Place`. It produces from `ready_week` on.

  An ordered building is a site until it is finished: `ready_week` is `nil` and `progress`
  counts its weeks of construction (see `Rules.Construction`).
  """

  alias MyLiege.Engine.Place.Blueprint

  @enforce_keys [:id, :blueprint]
  defstruct [:id, :blueprint, ready_week: 0, progress: 0]

  @type t :: %__MODULE__{
          id: pos_integer(),
          blueprint: Blueprint.t(),
          ready_week: non_neg_integer() | nil,
          progress: non_neg_integer()
        }

  @doc "Whether the building is finished by `week`."
  def ready?(%__MODULE__{ready_week: nil}, _week), do: false
  def ready?(%__MODULE__{ready_week: ready_week}, week), do: week >= ready_week

  @doc "Whether the building is still a site, i.e. not finished."
  def site?(%__MODULE__{ready_week: ready_week}), do: is_nil(ready_week)

  @doc "The buildings standing at the start of the game: the farm and the tower (a watchtower)."
  def starting do
    [
      %__MODULE__{id: 1, blueprint: Blueprint.fetch!(:farm)},
      %__MODULE__{id: 2, blueprint: Blueprint.fetch!(:watchtower)}
    ]
  end

  @doc """
  Appends a new site of `type` to `places`, with the next free id, without builders and
  progress.
  """
  def add_site(places, type) do
    last_id = places |> Enum.map(& &1.id) |> Enum.max(fn -> 0 end)
    site = %__MODULE__{id: last_id + 1, blueprint: Blueprint.fetch!(type), ready_week: nil}
    places ++ [site]
  end
end
