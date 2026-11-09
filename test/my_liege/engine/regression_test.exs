defmodule MyLiege.Engine.RegressionTest do
  @moduledoc """
  Guards refactors of the weekly step: one year with fixed values and seed 42 must export
  exactly `test/fixtures/regression_seed_42.csv`.

  If it fails after a deliberate rule change, re-record the fixture in the same commit and say
  so in the commit message. Never re-record it in a refactor commit.
  """
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Game
  alias MyLiege.EngineFixtures
  alias MyLiege.Reporting

  @fixture "test/fixtures/regression_seed_42.csv"

  test "one year with seed 42 exports the recorded CSV" do
    # the one soldier protects 600 gold, so the bandits raid once in the year; no tavern, so
    # happiness is at −3 after the grace period and cuts food and defence by 30%
    config =
      EngineFixtures.config(
        years_per_game: 1,
        starting_gold: 1000,
        starting_food: 10_000,
        bandit_threshold: 10,
        bandit_warning_weeks: 4,
        bandit_cover_weeks: 200,
        grace_weeks: 4,
        happiness_steps: %{1 => 100, 2 => 200, 3 => 300}
      )

    {reports, game} = EngineFixtures.run_weeks(Game.new(config, 42), 48)

    assert game.week == 48
    refute game.game_over
    assert Enum.any?(reports, &(&1.tax == :paid))
    assert Enum.any?(reports, & &1.demand)
    assert Enum.any?(reports, & &1.demand_outcome)
    assert Enum.any?(reports, &(&1.bandit_raid == :robbed))
    assert Enum.map(Enum.take(reports, 5), & &1.happiness.step) == [0, 0, 0, 0, -3]

    csv = Reporting.to_csv([Game.report(Game.new(config, 42)) | reports])
    assert csv == File.read!(@fixture)
  end
end
