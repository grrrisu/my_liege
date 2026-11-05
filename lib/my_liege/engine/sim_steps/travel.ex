defmodule MyLiege.Engine.SimSteps.Travel do
  @moduledoc "Step 3 of the week, R2 travel: every travelling worker gets one week closer."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Travel

  @impl true
  def run(game, report), do: {%{game | workers: Travel.count_down(game.workers)}, report}
end
