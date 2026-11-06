defmodule MyLiege.Engine.WeeklyReport do
  @moduledoc """
  What happened in one week (see `Game.run_week/1`), and for week 0 the starting state.

  `start` holds the game as it was when the week began, for the steps of that week. It is not
  exported and is `nil` in every report that leaves `Game.run_week/1`.

  `demand_progress` is a king's project's total at the end of the week, in every week it is
  open (the week it is made and its deadline week included); `nil` otherwise.
  """

  alias MyLiege.Engine.{Building, Game, Manameter, Worker}

  @enforce_keys [:week]
  defstruct [
    :week,
    :start,
    production: %{},
    mana: %{},
    manameter: nil,
    food_left: nil,
    newborn: nil,
    trained: [],
    builders: nil,
    travelling: nil,
    gold: nil,
    tax_due: nil,
    tax: nil,
    demand: nil,
    demand_outcome: nil,
    demand_progress: nil,
    spoiled: %{},
    gold_spent_buildings: 0,
    game_over: false
  ]

  @type t :: %__MODULE__{
          week: non_neg_integer(),
          start: %Game{} | nil,
          production: %{atom() => integer()},
          mana: %{atom() => integer()},
          manameter: %Manameter{} | nil,
          food_left: integer() | nil,
          newborn: %Worker{} | nil,
          trained: [%Worker{}],
          builders: non_neg_integer() | nil,
          travelling: non_neg_integer() | nil,
          gold: integer() | nil,
          tax_due: integer() | nil,
          tax: atom() | nil,
          demand: map() | nil,
          demand_outcome: atom() | nil,
          demand_progress: integer() | nil,
          spoiled: %{atom() => integer()},
          gold_spent_buildings: integer(),
          game_over: boolean()
        }

  @doc "An empty report for `week`, with `start` the game as it was when the week began."
  def new(week, %Game{} = start) do
    %__MODULE__{
      week: week,
      start: start,
      production: zeros(Building.products()),
      mana: zeros(Manameter.colours()),
      spoiled: zeros(Building.products())
    }
  end

  defp zeros(keys), do: Map.new(keys, &{&1, 0})
end
