defmodule MyLiege.Engine.SimSteps.EndOfWeek do
  @moduledoc """
  Last step of the week: fills the report with the end-of-week state and cleans up
  (`start: nil`). It contains no game rules; anything that changes the village is its own
  step before it.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.{Bandits, Construction, Travel}

  @impl true
  def run(game, report) do
    report = %{
      report
      | manameter: game.manameter,
        food_left: game.stocks.food,
        gold: game.stocks.gold,
        builders: Construction.arrived_builders(game.workers, game.buildings),
        travelling: Enum.count(game.workers, &Travel.travelling?/1),
        bandit_threat: game.bandits.threat,
        bandits_weeks_to_raid: Bandits.weeks_to_raid(game.bandits, game.week),
        game_over: game.game_over,
        start: nil
    }

    {game, report}
  end
end
