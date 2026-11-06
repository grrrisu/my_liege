defmodule MyLiege.Engine.SimSteps.DemandMade do
  @moduledoc """
  Step 11 of the week, R7 demand made: in a demand week, the amount uses the workers at the
  start of the week. A project starts at progress 0, shown in the report.
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

      progress = if Demands.project?(demand), do: demand.progress

      {%{game | demand: demand}, %{report | demand: demand, demand_progress: progress}}
    else
      {game, report}
    end
  end
end
