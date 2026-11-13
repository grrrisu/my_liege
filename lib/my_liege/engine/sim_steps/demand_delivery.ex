defmodule MyLiege.Engine.SimSteps.DemandDelivery do
  @moduledoc """
  Step 10 of the week, R7 demand delivery: settles the open demand in its deadline week; a
  project demand also as soon as its project is done (delivered), and in the week after the
  player refused it (refused, whatever its deadline). Settling a project demand removes the
  project from the places, if still there, and releases its workers. On a refused or missed
  food or gold demand the king takes the stock there is, up to the amount, added to
  `report.king_took`.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Place.Project
  alias MyLiege.Engine.Rules.{Demands, Misses, Placement}

  @impl true
  def run(%{demand: demand} = game, report) when demand != nil do
    project = Demands.project(demand, game.places)

    if settle?(game, project) do
      deliver? = game.deliver_demand != false
      {outcome, stocks, taken} = Demands.settle(demand, project, game.stocks, deliver?)
      game = game |> close_project(project) |> Map.put(:stocks, stocks)
      game = %{game | demand: nil, deliver_demand: nil}
      game = if outcome == :delivered, do: game, else: add_miss(game)
      king_took = Map.merge(report.king_took, taken, fn _product, a, b -> a + b end)
      {game, %{report | demand_outcome: outcome, king_took: king_took}}
    else
      {game, report}
    end
  end

  def run(game, report), do: {game, report}

  defp settle?(game, project) do
    game.demand.due_week == game.week or
      (Demands.project?(game.demand) and game.deliver_demand == false) or
      (project != nil and Project.done?(project))
  end

  defp close_project(game, nil), do: game

  defp close_project(game, %Project{id: id}) do
    %{
      game
      | places: Enum.reject(game.places, &(&1.id == id)),
        workers: Placement.release(game.workers, id, game.config)
    }
  end

  defp add_miss(game) do
    {misses, over?} = Misses.add(game.misses, game.config)
    %{game | misses: misses, game_over: game.game_over or over?}
  end
end
