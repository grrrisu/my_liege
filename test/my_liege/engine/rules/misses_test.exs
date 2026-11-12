defmodule MyLiege.Engine.Rules.MissesTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Rules.Misses
  alias MyLiege.EngineFixtures

  # king_misses_forgiven: 1
  setup do
    %{config: EngineFixtures.config()}
  end

  describe "R7: misses" do
    test "the first miss is forgiven, the second ends the game", %{config: config} do
      refute Misses.game_over?(1, config)
      assert Misses.game_over?(2, config)
    end

    test "add counts one more miss and says whether the game is over", %{config: config} do
      assert Misses.add(0, config) == {1, false}
      assert Misses.add(1, config) == {2, true}
      assert Misses.add(2, config) == {3, true}
    end
  end
end
