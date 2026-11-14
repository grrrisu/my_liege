defmodule MyLiege.Engine.Place.Trade do
  @moduledoc """
  A trade route, one kind of `Place` (R16): workers are placed on it as in a building and
  trade every week until moved. Its blueprint is its way's entry in the catalogue
  (`engine: :trade`), e.g. the grain trade (yellow, food). The traders are the workers whose
  `place` is the route's id; `traders` keeps their ids in the order they were placed on it,
  the order in which they pay (`Rules.Trades.settle/4`). An id may stay in `traders` after
  its worker left; only workers still placed on the route count.
  """

  alias MyLiege.Engine.Place.Blueprint

  @enforce_keys [:id, :blueprint]
  defstruct @enforce_keys ++ [traders: []]

  @type t :: %__MODULE__{
          id: pos_integer(),
          blueprint: Blueprint.t(),
          traders: [pos_integer()]
        }
end
