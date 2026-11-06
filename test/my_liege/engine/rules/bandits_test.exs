defmodule MyLiege.Engine.Rules.BanditsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Rules.Bandits
  alias MyLiege.EngineFixtures

  @weeks_per_year 48

  # 3 defence a week protects 60 gold
  defp config(overrides \\ []) do
    EngineFixtures.config(
      [
        bandit_threshold: 10,
        bandit_warning_weeks: 4,
        bandit_cover_weeks: 20,
        bandit_floor_step: 2
      ] ++ overrides
    )
  end

  defp run(state, week, gold, defence \\ 3_000, config \\ config()),
    do: Bandits.run(state, week, gold, defence, @weeks_per_year, config)

  describe "pressure" do
    test "is gold ÷ protected gold in per mille, rounded down" do
      assert Bandits.protected(3_000, config()) == 60_000
      assert Bandits.pressure(100_000, 60_000) == 1666
      assert Bandits.pressure(60_000, 60_000) == 1000
    end

    test "is 0 without gold, also without defence" do
      assert Bandits.pressure(0, 60_000) == 0
      assert Bandits.pressure(0, 0) == 0
      assert Bandits.pressure(-1, 0) == 0
    end

    test "is unbounded with gold and no defence" do
      assert Bandits.pressure(1, 0) == :unbounded
    end
  end

  describe "floor" do
    test "is 0 in year 1 and rises by bandit_floor_step at each later half year" do
      floors = Enum.map([1, 24, 25, 48, 49, 72, 73, 96, 97, 120, 121, 144], &floor_at/1)
      assert floors == [0, 0, 0, 0, 2_000, 2_000, 4_000, 4_000, 6_000, 6_000, 8_000, 8_000]
    end

    defp floor_at(week), do: Bandits.floor(week, @weeks_per_year, config())
  end

  describe "threat" do
    test "rises each week by pressure − 1000" do
      {state, gold, result} = run(Bandits.starting(), 1, 100_000)

      assert state == %{threat: 666, raid_week: nil}
      assert gold == 100_000
      assert result == %{protected: 60_000, pressure: 1666, robbed: 0, raid: nil}
    end

    test "never falls on its own: with a pressure of 1000 or less it stays" do
      for gold <- [60_000, 30_000, 0] do
        {state, _gold, _result} = run(%{threat: 5_000, raid_week: nil}, 2, gold)
        assert state.threat == 5_000
      end
    end

    test "is raised to the floor" do
      # week 49: floor 2
      {state, _gold, _result} = run(%{threat: 0, raid_week: nil}, 49, 30_000)
      assert state.threat == 2_000
    end
  end

  describe "setting out" do
    test "bandits set out when the threat reaches the threshold and raid warning weeks later" do
      {state, gold, result} = run(%{threat: 9_500, raid_week: nil}, 10, 90_000)

      assert state == %{threat: 10_000, raid_week: 14}
      assert gold == 90_000
      assert result.raid == nil
      assert Bandits.weeks_to_raid(state, 10) == 4
    end

    test "while they are on their way the threat doesn't change" do
      on_their_way = %{threat: 10_000, raid_week: 14}

      assert {^on_their_way, 0, _} = run(on_their_way, 11, 0)
      assert {^on_their_way, 1_000_000, _} = run(on_their_way, 13, 1_000_000)
    end

    test "without defence and with gold, the threat jumps to the threshold and they set out" do
      {state, _gold, result} = run(Bandits.starting(), 1, 1_000, 0)

      assert result.pressure == :unbounded
      assert state == %{threat: 10_000, raid_week: 5}
    end

    test "without defence and without gold, the threat stays" do
      {state, _gold, result} = run(%{threat: 3_000, raid_week: nil}, 1, 0, 0)

      assert result.pressure == 0
      assert state == %{threat: 3_000, raid_week: nil}
    end
  end

  describe "the raid" do
    test "takes the gold above the protected gold; the threat drops to the floor" do
      {state, gold, result} = run(%{threat: 10_000, raid_week: 14}, 14, 100_000)

      assert gold == 60_000
      assert result.robbed == 40_000
      assert result.raid == :robbed
      assert state == %{threat: 0, raid_week: nil}
    end

    test "is repelled with a pressure of 1000 or less; the threat still drops to the floor" do
      {state, gold, result} = run(%{threat: 10_000, raid_week: 60}, 60, 60_000)

      assert gold == 60_000
      assert result.robbed == 0
      assert result.raid == :repelled
      assert state == %{threat: 2_000, raid_week: nil}
    end

    test "without defence takes all the gold" do
      {_state, gold, result} = run(%{threat: 10_000, raid_week: 5}, 5, 45_000, 0)

      assert gold == 0
      assert result.robbed == 45_000
    end

    test "without gold and defence is repelled" do
      {_state, gold, result} = run(%{threat: 10_000, raid_week: 5}, 5, 0, 0)

      assert gold == 0
      assert result.raid == :repelled
    end

    test "with no warning weeks happens in the week they set out" do
      config = config(bandit_warning_weeks: 0)
      {state, gold, result} = run(%{threat: 9_500, raid_week: nil}, 3, 90_000, 3_000, config)

      assert result.raid == :robbed
      assert gold == 60_000
      assert state == %{threat: 0, raid_week: nil}
    end
  end
end
