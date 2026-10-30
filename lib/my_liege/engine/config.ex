defmodule MyLiege.Engine.Config do
  @moduledoc """
  The single source of every game value. Engine functions take this struct as an argument,
  so the settings panel and tests can pass their own copy. `from_csv/0` is built at compile
  time from `priv/balance_inputs.csv`; a missing key or non-whole value fails the build.

  Shares and factors are in per mille (`800` = 80%).
  """

  alias MyLiege.Engine.LoadConfig

  @enforce_keys [
    :birth_interval_weeks,
    :birth_min_food_left,
    :starting_manameter,
    :starting_farmers,
    :starting_soldiers,
    :base_production,
    :capacity,
    :colour_factors,
    :construction_weeks,
    :mana_per_worker,
    :manameter_points_per_week
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
