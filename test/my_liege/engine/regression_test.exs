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
    config = EngineFixtures.config(years_per_game: 1, starting_gold: 1000, starting_food: 10_000)
    {reports, game} = EngineFixtures.run_weeks(Game.new(config, 42), 48)

    assert game.week == 48
    refute game.game_over
    assert Enum.any?(reports, &(&1.tax == :paid))
    assert Enum.any?(reports, & &1.demand)
    assert Enum.any?(reports, & &1.demand_outcome)

    csv = Reporting.to_csv([Game.report(Game.new(config, 42)) | reports])
    assert csv == File.read!(@fixture)
  end
end
