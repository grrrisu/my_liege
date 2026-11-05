defmodule MyLiege.Engine.SimSteps.TrainingEnd do
  @moduledoc "Training ends (R5): finished trainees are trained, unplaced and travelling."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Training

  @impl true
  def run(game, report) do
    {workers, trained} = Training.finish(game.workers, game.buildings, game.week, game.config)
    {%{game | workers: workers}, %{report | trained: trained}}
  end
end
