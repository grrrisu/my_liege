defmodule MyLiege.Engine.Rules.SuspicionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Rules.Suspicion
  alias MyLiege.EngineFixtures

  test "R18: starts at 0; every expedition adds king.suspicion.per_expedition" do
    config = EngineFixtures.config(king_suspicion_per_expedition: 2)

    assert Suspicion.none() == 0
    assert Suspicion.add_expedition(0, config) == 2
    assert Suspicion.add_expedition(3, config) == 5
  end
end
