defmodule MyLiege.Engine.Place.Expedition do
  @moduledoc """
  An expedition, one kind of `Place` (R17): a party of workers is away from the week after it
  sets out until `return_week`, at whose end it brings its haul and disappears. Its blueprint
  is its way's entry in the catalogue (`engine: :expedition`), e.g. hunting (red, food). The
  party are the workers whose `place` is the expedition's id.
  """

  alias MyLiege.Engine.Place.Blueprint

  @enforce_keys [:id, :blueprint, :return_week]
  defstruct @enforce_keys

  @type t :: %__MODULE__{id: pos_integer(), blueprint: Blueprint.t(), return_week: pos_integer()}

  @doc "Whether the expedition returns at the end of `week`."
  def returns?(%__MODULE__{return_week: return_week}, week), do: return_week == week
end
