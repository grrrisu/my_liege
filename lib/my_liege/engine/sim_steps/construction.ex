defmodule MyLiege.Engine.SimSteps.Construction do
  @moduledoc "Step 7 of the week, R2 construction: sites advance with the builders as at the start of the week."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Construction

  @impl true
  def run(game, report) do
    {places, workers, _finished} =
      Construction.advance_sites(
        game.places,
        report.start.workers,
        game.workers,
        game.week,
        game.config
      )

    {%{game | places: places, workers: workers}, report}
  end
end
