defmodule MyLiege.Engine.Actions.DecideDemandTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.DecideDemand
  alias MyLiege.EngineFixtures

  # a food demand due next week
  setup do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
    demand = %{product: :food, amount: 1_000, due_week: game.week + 1, progress: nil}
    %{game: %{game | demand: demand}}
  end

  test "stores the decision to deliver", %{game: game} do
    assert {:ok, %{deliver_demand: true}} = DecideDemand.run(game, true)
  end

  test "stores the decision to refuse", %{game: game} do
    assert {:ok, %{deliver_demand: false}} = DecideDemand.run(game, false)
  end

  test "refused without a demand", %{game: game} do
    assert DecideDemand.run(%{game | demand: nil}, true) == {:error, :no_demand_due}
  end

  test "refused before the week before the deadline", %{game: game} do
    game = %{game | demand: %{game.demand | due_week: game.week + 2}}

    assert DecideDemand.run(game, true) == {:error, :no_demand_due}
  end

  test "refused for a project", %{game: game} do
    game = %{game | demand: %{game.demand | product: :knowledge, progress: 0}}

    assert DecideDemand.run(game, true) == {:error, :no_demand_due}
  end
end
