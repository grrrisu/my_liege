defmodule MyLiege.Engine.Place.Trade do
  @moduledoc """
  A trade, one kind of `Place` (R16): one trader is away from the week after it starts until
  `return_week`, at whose end it gives its goods and disappears. Its blueprint is its way's
  entry in the catalogue (`engine: :trade`), e.g. the grain trade (yellow, food). The trader
  is the worker whose `place` is the trade's id.
  """

  alias MyLiege.Engine.Place.Blueprint

  @enforce_keys [:id, :blueprint, :return_week]
  defstruct @enforce_keys

  @type t :: %__MODULE__{id: pos_integer(), blueprint: Blueprint.t(), return_week: pos_integer()}

  @doc "Whether the trade returns at the end of `week`."
  def returns?(%__MODULE__{return_week: return_week}, week), do: return_week == week
end
