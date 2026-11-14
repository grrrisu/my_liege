defmodule MyLiege.Engine.Config do
  @moduledoc """
  The single source of every game value. The config is fixed for a game when `Game.new/2` is
  called; tests can pass a modified copy to `Game.new/2`. `from_csv/0` is built at compile
  time from `priv/balance_inputs.csv`; a missing or unread key or a non-whole value fails the build.

  Each field is named after its CSV key: dots become underscores and `_permille` is dropped
  (`king.tax.per_worker` → `king_tax_per_worker`); keys that differ only by item are one map
  keyed by the item (`place.<type>.capacity` → `place_capacity`). Shares and factors are in
  per mille (`800` = 80%).
  """

  alias MyLiege.Engine.LoadConfig

  @enforce_keys [
    :birth_interval_weeks,
    :birth_min_food_left,
    :manameter_start,
    :start_farmers,
    :start_soldiers,
    :place_output_per_worker,
    :place_capacity,
    :efficiency,
    :build_work,
    :build_cost_gold,
    :build_capacity,
    :book_work,
    :place_granary_food_spoilage,
    :place_granary_culture_upkeep,
    :way_plough_work,
    :way_plough_capacity,
    :way_plough_bonus,
    :way_grain_trade_capacity,
    :way_grain_trade_gold_per_week,
    :way_grain_trade_food_per_week,
    :way_grain_trade_travel_weeks,
    :way_hunting_max_party,
    :way_hunting_travel_weeks,
    :way_hunting_hunt_weeks,
    :way_hunting_food_per_week,
    :way_hunting_luck,
    :way_hunting_party,
    :king_suspicion_per_expedition,
    :travel_weeks,
    :mana_place_colour,
    :mana_good_colour,
    :manameter_points_per_week,
    :start_food,
    :start_gold,
    :good_food_eaten_per_worker,
    :game_years,
    :king_tax_per_worker,
    :king_tax_interval_weeks,
    :king_tax_count_lead_weeks,
    :king_misses_forgiven,
    :king_grace_weeks,
    :training_min_share,
    :training_weeks,
    :king_demand_deadline_weeks,
    :king_demand_population_share,
    :king_demand_production_weeks,
    :good_spoilage,
    :bandit_threshold,
    :bandit_warning_weeks,
    :bandit_cover_weeks,
    :bandit_floor_step,
    :happiness_need_per_worker,
    :happiness_penalty_below,
    :happiness_bonus_from,
    :happiness_change
  ]
  defstruct @enforce_keys

  @csv_path Path.expand("../../../priv/balance_inputs.csv", __DIR__)
  # without this, editing the CSV would not recompile this module and the old values would stay
  @external_resource @csv_path
  # read once at compile time, so a bad CSV fails the build and releases don't need the file
  @from_csv LoadConfig.load!(@csv_path)

  @doc "The configuration read from `priv/balance_inputs.csv` when this module was compiled."
  def from_csv, do: struct!(__MODULE__, @from_csv)
end
