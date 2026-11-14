defmodule MyLiege.Engine.SimSteps.Bandits do
  @moduledoc """
  Step 14 of the week, R10 bandits: from week 1, grace period or not. Uses the gold after
  taxes, demands and the trade route (R16), before spoilage, and this week's defence
  production; changes the threat, sends bandits out, or in the raid week robs the gold above
  the protected gold.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.Bandits

  @impl true
  def run(game, report) do
    {bandits, gold, result} =
      Bandits.run(
        game.bandits,
        game.week,
        game.stocks.gold,
        report.production.defence,
        Game.weeks_per_year(),
        game.config
      )

    report = %{
      report
      | bandit_pressure: result.pressure,
        bandit_protected: result.protected,
        bandit_threat_change: bandits.threat - game.bandits.threat,
        bandit_raid: result.raid,
        gold_robbed: result.robbed
    }

    {%{game | bandits: bandits, stocks: %{game.stocks | gold: gold}}, report}
  end
end
