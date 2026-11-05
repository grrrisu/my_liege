defmodule MyLiege.Engine.SimSteps.Mana do
  @moduledoc "Step 2 of the week, R3 mana: from the same workers as production."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Mana

  @impl true
  def run(game, report) do
    mana = Mana.produced(report.start.workers, game.buildings, game.week, game.config)
    {game, %{report | mana: mana}}
  end
end
