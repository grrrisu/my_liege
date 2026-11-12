defmodule MyLiege.Engine.SimSteps.EndOfWeek do
  @moduledoc """
  Last step of the week: fills the report with the end-of-week state and cleans up
  (`start: nil`). It contains no game rules; anything that changes the village is its own
  step before it.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.{Bandits, Construction, Demands, Travel}

  @impl true
  def run(game, report) do
    report = %{
      report
      | manameter: game.manameter,
        food_left: game.stocks.food,
        gold: game.stocks.gold,
        builders: Construction.arrived_builders(game.workers, game.places),
        travelling: Enum.count(game.workers, &Travel.travelling?/1),
        bandit_threat: game.bandits.threat,
        bandits_weeks_to_raid: Bandits.weeks_to_raid(game.bandits, game.week),
        stock_change: stock_change(report, game),
        project_change: project_change(report.start.demand, game.demand),
        game_over: game.game_over,
        start: nil
    }

    {game, report}
  end

  # week 0 is the starting state: no week before it
  defp stock_change(%{week: 0}, _game), do: nil

  defp stock_change(report, game),
    do:
      Map.new(game.stocks, fn {product, stock} ->
        {product, stock - report.start.stocks[product]}
      end)

  # the same project open at the start and at the end of the week
  defp project_change(
         %{progress: before, due_week: due_week} = start,
         %{due_week: due_week} = now
       )
       when is_integer(before),
       do: if(Demands.project?(now) and start.product == now.product, do: now.progress - before)

  defp project_change(_start, _now), do: nil
end
