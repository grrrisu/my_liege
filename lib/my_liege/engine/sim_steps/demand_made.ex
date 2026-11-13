defmodule MyLiege.Engine.SimSteps.DemandMade do
  @moduledoc """
  Step 11 of the week, R7 demand made: in a demand week, the amount uses the workers at the
  start of the week. A knowledge or culture demand opens its project among the places
  (`Demands.open_project/2`), at progress 0, shown in the report.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.Demands

  @impl true
  def run(game, report) do
    if game.week in game.demand_weeks do
      population = length(report.start.workers)

      demand =
        Demands.make(game.week, Game.weeks_per_year(), game.manameter, population, game.config)

      {places, demand} = Demands.open_project(game.places, demand)
      progress = with %{progress: progress} <- Demands.project(demand, places), do: progress

      {%{game | places: places, demand: demand},
       %{report | demand: demand, demand_progress: progress}}
    else
      {game, report}
    end
  end
end
