defmodule MyLiege.Engine.Actions.RefuseProjectTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.RefuseProject
  alias MyLiege.Engine.Worker
  alias MyLiege.EngineFixtures

  # an open knowledge project (id 3) with worker 1 on it; 1 week of travel
  setup do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(travel_weeks: 1), 1)
    game = EngineFixtures.open_demand(game, :knowledge, 7_000, 8)
    workers = Enum.map(game.workers, &if(&1.id == 1, do: %{&1 | place: 3}, else: &1))
    %{game: %{game | workers: workers}}
  end

  test "refuses the open project", %{game: game} do
    assert {:ok, %{deliver_demand: false}} = RefuseProject.run(game)
  end

  test "removes the project and releases its workers at once", %{game: game} do
    {:ok, game} = RefuseProject.run(game)

    assert EngineFixtures.demand_project(game) == nil
    refute Enum.any?(game.places, &(&1.id == 3))

    assert [%Worker{id: 1, place: nil, travel: 1}, %Worker{id: 2, place: 2, travel: 0}] =
             game.workers
  end

  test "a project can be refused only once", %{game: game} do
    {:ok, game} = RefuseProject.run(game)

    assert RefuseProject.run(game) == {:error, :no_project}
  end

  test "refused without a demand", %{game: game} do
    assert RefuseProject.run(%{game | demand: nil}) == {:error, :no_project}
  end

  test "refused for a demand from the stock", %{game: game} do
    food = %{product: :food, amount: 1_000, due_week: 8, project_id: nil}

    assert RefuseProject.run(%{game | demand: food}) == {:error, :no_project}
  end
end
