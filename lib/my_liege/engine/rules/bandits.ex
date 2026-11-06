defmodule MyLiege.Engine.Rules.Bandits do
  @moduledoc """
  R10, bandits (robbery only): gold the village can't protect draws bandits, who rob it.

  - Protected gold = defence production of the week × `bandit_cover_weeks`.
  - Pressure (per mille) = gold ÷ protected gold. Gold at or below 0 gives 0. Without defence
    production, any gold above 0 gives `:unbounded`.
  - The threat (in thousandths, so `bandit_threshold` 10 is 10 000) changes each week by
    pressure − 1000 and never falls below the floor (`floor/3`). An `:unbounded` pressure sets
    it to `bandit_threshold` at once.
  - When the threat reaches `bandit_threshold` and no bandits are on their way, they set out
    and raid `bandit_warning_weeks` later. While they are on their way, the threat doesn't
    change.
  - The raid: with a pressure of 1000 or less they are repelled; otherwise they take the gold
    above the protected gold. Afterwards, repelled or not, the threat drops to the floor.

  `bandit_threshold`, `bandit_cover_weeks` and `bandit_floor_step` are whole numbers in the
  config; this module converts them.
  """

  alias MyLiege.Engine.{Config, Fixed}

  @half_years_per_year 2
  # half years with a floor of 0 (year 1)
  @floorless_half_years 2

  @type state :: %{threat: integer(), raid_week: pos_integer() | nil}
  @type pressure :: non_neg_integer() | :unbounded

  @doc "The state at the start of a game: threat 0, no bandits on their way."
  def starting, do: %{threat: 0, raid_week: nil}

  @doc "Gold protected by `defence` (thousandths of defence produced in a week)."
  def protected(defence, %Config{} = config), do: defence * config.bandit_cover_weeks

  @doc "Gold ÷ protected gold, in per mille, rounded down; `:unbounded` without protection."
  def pressure(gold, _protected) when gold <= 0, do: 0
  def pressure(_gold, 0), do: :unbounded
  def pressure(gold, protected), do: div(gold * 1000, protected)

  @doc """
  The lowest threat in `week`: 0 in year 1, then `bandit_floor_step` more at the start of
  every later half year.
  """
  def floor(week, weeks_per_year, %Config{} = config) do
    half_year = div(week - 1, div(weeks_per_year, @half_years_per_year))
    Fixed.from(max(half_year - @floorless_half_years + 1, 0) * config.bandit_floor_step)
  end

  @doc "The threat at which bandits set out, in thousandths."
  def threshold(%Config{} = config), do: Fixed.from(config.bandit_threshold)

  @doc "Whether bandits are on their way."
  def on_their_way?(%{raid_week: raid_week}), do: is_integer(raid_week)

  @doc "Weeks left until the raid as seen at the end of `week`; `nil` if none are on their way."
  def weeks_to_raid(%{raid_week: nil}, _week), do: nil
  def weeks_to_raid(%{raid_week: raid_week}, week), do: raid_week - week

  @doc """
  One week of bandits in `week`, with the gold in stock and the week's defence production.
  Returns `{state, gold, result}`; `result` has `protected`, `pressure`, `robbed` (gold taken,
  0 if no raid or repelled) and `raid` (`nil`, `:repelled` or `:robbed`).
  """
  def run(state, week, gold, defence, weeks_per_year, %Config{} = config) do
    protected = protected(defence, config)
    pressure = pressure(gold, protected)
    floor = floor(week, weeks_per_year, config)
    result = %{protected: protected, pressure: pressure, robbed: 0, raid: nil}

    state =
      if on_their_way?(state), do: state, else: advance(state, week, pressure, floor, config)

    if state.raid_week == week,
      do: raid(gold, protected, pressure, floor, result),
      else: {state, gold, result}
  end

  # the threat moves; at the threshold the bandits set out (a raid in this week with no warning)
  defp advance(state, week, pressure, floor, config) do
    threat = next_threat(state.threat, pressure, floor, config)

    if threat >= threshold(config),
      do: %{threat: threat, raid_week: week + config.bandit_warning_weeks},
      else: %{threat: threat, raid_week: nil}
  end

  defp next_threat(_threat, :unbounded, _floor, config), do: threshold(config)
  defp next_threat(threat, pressure, floor, _config), do: max(threat + pressure - 1000, floor)

  defp raid(gold, protected, pressure, floor, result) do
    state = %{threat: floor, raid_week: nil}

    if repelled?(pressure) do
      {state, gold, %{result | raid: :repelled}}
    else
      robbed = gold - protected
      {state, protected, %{result | robbed: robbed, raid: :robbed}}
    end
  end

  defp repelled?(:unbounded), do: false
  defp repelled?(pressure), do: pressure <= 1000
end
