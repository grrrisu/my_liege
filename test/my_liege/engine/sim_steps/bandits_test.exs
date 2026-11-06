defmodule MyLiege.Engine.SimSteps.BanditsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, Worker}
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

  test "Game.next_threat_change/1 uses today's gold and next week's defence" do
    game = EngineFixtures.game_without_demands(config(starting_gold: 100), 1)
    {[report], game} = EngineFixtures.run_weeks(game, 1)

    # week 1: 100 gold against 60 protected, the threat rose
    assert report.bandit_threat == 666
    assert Game.next_threat_change(game) == 666

    # two more soldiers have arrived in the tower: 180 protected, so it will fall
    soldiers = for id <- [90, 91], do: %Worker{id: id, colour: :red, building: 2}
    game = %{game | workers: game.workers ++ soldiers}

    assert Game.protected_gold(game) == 180_000
    # pressure 100 ÷ 180 = 555 per mille
    assert Game.next_threat_change(game) == -445
  end

  test "Game.next_threat_change/1 is 0 while bandits are on their way" do
    game = EngineFixtures.game_without_demands(config([]), 1)
    assert Game.next_threat_change(%{game | bandits: %{threat: 10_000, raid_week: 3}}) == 0
  end

  test "Game.protected_gold/1 is next week's defence production × bandit_cover_weeks" do
    game = Game.new(config([]), 1)
    assert Game.protected_gold(game) == 60_000

    {:ok, game} = Game.unplace_worker(game, 2)
    assert Game.protected_gold(game) == 0
  end
end
