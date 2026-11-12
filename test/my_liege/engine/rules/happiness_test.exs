defmodule MyLiege.Engine.Rules.HappinessTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Rules.Happiness
  alias MyLiege.EngineFixtures

  defp config(overrides \\ []) do
    EngineFixtures.config(
      [king_grace_weeks: 4, happiness_change: %{level1: 100, level2: 200, level3: 300}] ++
        overrides
    )
  end

  describe "R11 ratio" do
    test "culture production ÷ (population × happiness_need_per_worker), per mille" do
      assert Happiness.ratio(3_000, 4, config()) == 750
      assert Happiness.ratio(3_000, 2, config(happiness_need_per_worker: 500)) == 3_000
    end

    test "rounds down" do
      assert Happiness.ratio(1_000, 3, config()) == 333
    end

    test "no culture: 0" do
      assert Happiness.ratio(0, 5, config()) == 0
    end

    test "a population of 0 raises" do
      assert_raise ArgumentError, fn -> Happiness.ratio(3_000, 0, config()) end
    end
  end

  describe "R11 step" do
    test "below the penalty thresholds, from the bonus thresholds, neutral in between" do
      steps =
        for ratio <- [0, 249, 250, 499, 500, 749, 750, 1_249],
            do: Happiness.step_for(ratio, config())

      assert steps == [-3, -3, -2, -2, -1, -1, 0, 0]

      steps =
        for ratio <- [1_250, 1_749, 1_750, 2_499, 2_500, 100_000],
            do: Happiness.step_for(ratio, config())

      assert steps == [1, 1, 2, 2, 3, 3]
    end

    test "0 in the grace period, which still knows the step the ratio gives" do
      assert Happiness.assess(0, 2, 4, config()) == %{ratio: 0, step: 0, step_without_grace: -3}
      assert Happiness.assess(0, 2, 5, config()) == %{ratio: 0, step: -3, step_without_grace: -3}
    end
  end

  describe "R11 effect" do
    @production %{
      food: 9_000,
      defence: 3_001,
      gold: 6_000,
      knowledge: 3_000,
      culture: 3_000
    }

    test "changes food and defence by happiness.level<n>.change_permille, rounded down, and nothing else" do
      assert Happiness.apply_step(@production, -1, config()) ==
               %{@production | food: 8_100, defence: 2_700}

      assert Happiness.apply_step(@production, -3, config()) ==
               %{@production | food: 6_300, defence: 2_100}

      assert Happiness.apply_step(@production, 2, config()) ==
               %{@production | food: 10_800, defence: 3_601}

      assert Happiness.apply_step(@production, 3, config()) ==
               %{@production | food: 11_700, defence: 3_901}
    end

    test "step 0 changes nothing" do
      assert Happiness.apply_step(@production, 0, config()) == @production
    end
  end
end
