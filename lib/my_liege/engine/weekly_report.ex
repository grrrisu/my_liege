defmodule MyLiege.Engine.WeeklyReport do
  @moduledoc """
  What happened in one week (see `Game.run_week/1`), and for week 0 the starting state.

  `start` holds the game as it was when the week began, for the steps of that week. It is not
  exported and is `nil` in every report that leaves `Game.run_week/1`.

  `demand_progress` is a king's project's total at the end of the week, in every week it is
  open (the week it is made and its deadline week included); `nil` otherwise.

  `king_took` is the food and gold the king took that week on a skipped or missed tax and on a
  refused or missed demand.

  R10 bandits: `bandit_pressure` (per mille, `:unbounded` without defence production, `nil` in
  week 0), `bandit_protected` (the week's defence production × `bandit_cover_weeks`), `bandit_threat`
  (thousandths, end of week), `bandit_threat_change` (the threat at the end of the week minus at
  the end of the week before), `bandits_weeks_to_raid` (end of week, `nil` if none are on their way),
  `bandit_raid` (`:repelled` or `:robbed` in a raid week) and `gold_robbed`.

  For the forecasts (`Forecast`): `stock_change` is every stock at the end of the week minus at
  its start (one-off payments, the king's takings and robbery included; gold spent on buildings
  between weeks is not), `nil` in week 0. `project_change` is what an open king's project gained
  in the week; `nil` if no project was open both at the start and at the end of the week.
  Neither is exported.
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
    king_took: %{food: 0, gold: 0},
    spoiled: %{},
    gold_spent_buildings: 0,
    bandit_pressure: nil,
    bandit_protected: 0,
    bandit_threat_change: 0,
    bandit_threat: nil,
    bandits_weeks_to_raid: nil,
    bandit_raid: nil,
    gold_robbed: 0,
    stock_change: nil,
    project_change: nil,
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
          king_took: %{food: integer(), gold: integer()},
          spoiled: %{atom() => integer()},
          gold_spent_buildings: integer(),
          bandit_pressure: non_neg_integer() | :unbounded | nil,
          bandit_protected: integer(),
          bandit_threat: integer() | nil,
          bandit_threat_change: integer(),
          bandits_weeks_to_raid: non_neg_integer() | nil,
          bandit_raid: :repelled | :robbed | nil,
          gold_robbed: integer(),
          stock_change: %{atom() => integer()} | nil,
          project_change: integer() | nil,
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
