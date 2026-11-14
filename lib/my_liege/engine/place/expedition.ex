defmodule MyLiege.Engine.Place.Expedition do
  @moduledoc """
  A hunting camp, one kind of `Place` (R17): workers are placed on it as in a building and
  hunt every week until moved. Its blueprint is its way's entry in the catalogue
  (`engine: :expedition`), hunting (red, food). The hunters are the workers whose `place` is
  the camp's id.

  - `bag`: the food hunted since the last haul (thousandths), not yet in the stock.
  - `weeks`: the weeks since the last haul in which at least one hunter had arrived.
  - `hunted_in_block`: whether a hunter had arrived in some week of the current block of
    `way_hunting_haul_weeks` game weeks (R18, the idle decay).
  """

  alias MyLiege.Engine.Place.Blueprint

  @enforce_keys [:id, :blueprint]
  defstruct @enforce_keys ++ [bag: 0, weeks: 0, hunted_in_block: false]

  @type t :: %__MODULE__{
          id: pos_integer(),
          blueprint: Blueprint.t(),
          bag: non_neg_integer(),
          weeks: non_neg_integer(),
          hunted_in_block: boolean()
        }
end
