defmodule MyLiege.Engine.SimSteps.ManameterUpdate do
  @moduledoc "Manameter update (R4) from this week's mana."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.ManameterUpdate

  @impl true
  def run(game, report) do
    manameter = ManameterUpdate.update(game.manameter, report.mana, game.config)
    {%{game | manameter: manameter}, report}
  end
end
