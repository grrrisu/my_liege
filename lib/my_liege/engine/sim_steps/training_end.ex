defmodule MyLiege.Engine.SimSteps.TrainingEnd do
  @moduledoc "Step 8 of the week, R5 training ends: finished trainees are trained, unplaced and travelling."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Training

  @impl true
  def run(game, report) do
    {workers, trained} = Training.finish(game.workers, game.places, game.week, game.config)
    {%{game | workers: workers}, %{report | trained: trained}}
  end
end
