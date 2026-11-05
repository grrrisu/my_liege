defmodule MyLiege.Engine.SimSteps.DemandMade do
  @moduledoc """
  Demand made (R7), demand weeks only: the amount uses the workers at the start of the week.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.{Demands, Game}

  @impl true
  def run(game, report) do
    if game.week in game.demand_weeks do
      population = length(report.start.workers)

      demand =
        Demands.make(game.week, Game.weeks_per_year(), game.manameter, population, game.config)

      {%{game | demand: demand}, %{report | demand: demand}}
    else
      {game, report}
    end
  end
end
