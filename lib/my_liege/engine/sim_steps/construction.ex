defmodule MyLiege.Engine.SimSteps.Construction do
  @moduledoc "Construction (R2): sites advance with the builders as at the start of the week."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Construction

  @impl true
  def run(game, report) do
    {buildings, workers, _finished} =
      Construction.week(
        game.buildings,
        report.start.workers,
        game.workers,
        game.week,
        game.config
      )

    {%{game | buildings: buildings, workers: workers}, report}
  end
end
