defmodule MyLiege.Engine.SimSteps.EndOfWeek do
  @moduledoc """
  Runs last: fills the report with the end-of-week state and cleans up (`start: nil`).
  It contains no game rules; anything that changes the village is its own step before it.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.{Construction, Travel}

  @impl true
  def run(game, report) do
    report = %{
      report
      | manameter: game.manameter,
        food_left: game.stocks.food,
        gold: game.stocks.gold,
        builders: Construction.arrived_builders(game.workers, game.buildings),
        travelling: Enum.count(game.workers, &Travel.travelling?/1),
        game_over: game.game_over,
        start: nil
    }

    {game, report}
  end
end
