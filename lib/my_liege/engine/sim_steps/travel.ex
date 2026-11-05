defmodule MyLiege.Engine.SimSteps.Travel do
  @moduledoc "Travel (R2): every travelling worker gets one week closer."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Travel

  @impl true
  def run(game, report), do: {%{game | workers: Travel.week(game.workers)}, report}
end
