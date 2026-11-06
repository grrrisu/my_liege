defmodule MyLiege.Engine.SimSteps.BanditsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Worker
  alias MyLiege.EngineFixtures

  # the one soldier in the tower makes 3 defence a week: 60 gold protected
  defp config(overrides) do
    EngineFixtures.config(
      [bandit_threshold: 10, bandit_warning_weeks: 4, bandit_cover_weeks: 20] ++ overrides
    )
  end

  test "bandits run from week 1, also in the grace period" do
    # 1000 gold: pressure 16 666, so the threat passes 20 in week 2
    config = config(grace_weeks: 24, starting_gold: 1000, bandit_threshold: 20)
    {reports, game} = EngineFixtures.run_weeks(EngineFixtures.game_without_demands(config, 1), 2)

    assert Enum.map(reports, & &1.bandit_threat) == [15_666, 31_332]
    assert Enum.map(reports, & &1.bandits_weeks_to_raid) == [nil, 4]
    assert game.bandits == %{threat: 31_332, raid_week: 6}

    {reports, game} = EngineFixtures.run_weeks(game, 4)

    assert Enum.map(reports, & &1.bandits_weeks_to_raid) == [3, 2, 1, nil]
    assert List.last(reports).bandit_raid == :robbed
    assert List.last(reports).gold_robbed == 940_000
    assert game.stocks.gold == 60_000
    assert game.bandits == %{threat: 0, raid_week: nil}
  end

  test "the raid comes after the tax payment and before spoilage" do
    config =
      config(
        # enough to outlast 23 weeks of 10% spoilage and the tax
        starting_gold: 100_000,
        spoilage_rates: %{food: 0, knowledge: 0, defence: 0, gold: 100, entertainment: 0}
      )

    game = EngineFixtures.game_without_demands(config, 1)
    # the bandits are on their way and raid in the tax week (24)
    game = %{game | bandits: %{threat: 10_000, raid_week: 24}}
    {reports, game} = EngineFixtures.run_weeks(game, 24)
    report = List.last(reports)

    assert report.tax == :paid
    assert report.bandit_raid == :robbed
    # 60 protected gold left after the raid, then 10% spoils
    assert report.spoiled.gold == 6_000
    assert game.stocks.gold == 54_000
  end

  test "the report holds the week's protected gold and threat change, as the UI shows them" do
    game = EngineFixtures.game_without_demands(config(starting_gold: 100), 1)
    {[week_1], game} = EngineFixtures.run_weeks(game, 1)

    # 3 defence protects 60; 100 gold against 60: the threat rose by 0.666
    assert week_1.production.defence == 3_000
    assert week_1.bandit_protected == 60_000
    assert week_1.bandit_threat_change == 666

    # two more soldiers in the tower: 9 defence protects 180, so the threat stays
    soldiers = for id <- [90, 91], do: %Worker{id: id, colour: :red, building: 2}
    {[week_2], _game} = EngineFixtures.run_weeks(%{game | workers: game.workers ++ soldiers}, 1)

    assert week_2.production.defence == 9_000
    assert week_2.bandit_protected == 180_000
    assert week_2.bandit_threat_change == 0
    assert week_2.bandit_threat == 666
  end
end
