defmodule MyLiege.Engine.Actions.RefuseProjectTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.RefuseProject
  alias MyLiege.EngineFixtures

  # an open knowledge project
  setup do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
    project = %{product: :knowledge, amount: 7_000, due_week: 8, progress: 0}
    %{game: %{game | demand: project}}
  end

  test "refuses the open project", %{game: game} do
    assert {:ok, %{deliver_demand: false}} = RefuseProject.run(game)
  end

  test "a project can be refused only once", %{game: game} do
    {:ok, game} = RefuseProject.run(game)

    assert RefuseProject.run(game) == {:error, :no_project}
  end

  test "refused without a demand", %{game: game} do
    assert RefuseProject.run(%{game | demand: nil}) == {:error, :no_project}
  end

  test "refused for a demand from the stock", %{game: game} do
    food = %{product: :food, amount: 1_000, due_week: 8, progress: nil}

    assert RefuseProject.run(%{game | demand: food}) == {:error, :no_project}
  end
end
