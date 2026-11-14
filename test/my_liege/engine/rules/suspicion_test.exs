defmodule MyLiege.Engine.Rules.SuspicionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Rules.Suspicion
  alias MyLiege.EngineFixtures

  setup do
    %{config: EngineFixtures.config()}
  end

  test "starts at 0" do
    assert Suspicion.none() == 0
  end

  describe "R18: hauls" do
    test "2 to 4 hunters: + low, mid, high by the luck", %{config: config} do
      assert Suspicion.after_haul(5, 2, :low, config) == {5, 0}
      assert Suspicion.after_haul(5, 3, :mid, config) == {6, 1}
      assert Suspicion.after_haul(5, 4, :high, config) == {7, 2}
    end

    test "1 hunter: − decay whatever the luck, not below 0", %{config: config} do
      assert Suspicion.after_haul(5, 1, :high, config) == {4, -1}
      assert Suspicion.after_haul(0, 1, :low, config) == {0, 0}
    end
  end

  describe "R18: idle blocks" do
    test "blocks of haul_weeks game weeks from week 1 end at weeks 6, 12, …", %{config: config} do
      assert Enum.filter(1..18, &Suspicion.block_end?(&1, config)) == [6, 12, 18]
    end

    test "decay never below 0", %{config: config} do
      assert Suspicion.decay(3, config) == 2
      assert Suspicion.decay(0, config) == 0
    end
  end

  describe "R18: threshold" do
    test "at the threshold or more: halved, rounded down, and a miss", %{config: config} do
      assert Suspicion.check_threshold(11, config) == {11, false}
      assert Suspicion.check_threshold(12, config) == {6, true}
      assert Suspicion.check_threshold(13, config) == {6, true}
    end
  end
end
