defmodule MyLiege.Engine.SimSteps.Mana do
  @moduledoc "Mana (R3): the same workers as production."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Mana

  @impl true
  def run(game, report) do
    mana = Mana.week(report.start.workers, game.buildings, game.week, game.config)
    {game, %{report | mana: mana}}
  end
end
