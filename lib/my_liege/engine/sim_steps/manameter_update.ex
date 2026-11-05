defmodule MyLiege.Engine.SimSteps.ManameterUpdate do
  @moduledoc "Step 4 of the week, R4 Manameter update: from this week's mana."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.ManameterUpdate

  @impl true
  def run(game, report) do
    manameter = ManameterUpdate.update(game.manameter, report.mana, game.config)
    {%{game | manameter: manameter}, report}
  end
end
