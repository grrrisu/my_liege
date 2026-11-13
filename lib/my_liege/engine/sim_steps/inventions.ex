defmodule MyLiege.Engine.SimSteps.Inventions do
  @moduledoc """
  Step 8 of the week, after the books, R15 inventions finished: every invention that reached
  its target is invented for good, its project disappears and its workers are released,
  travelling. Its effect starts with the next week's production.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Inventions

  @impl true
  def run(game, report) do
    {places, workers, inventions, finished} =
      Inventions.finish(game.places, game.workers, game.inventions, game.config)

    {%{game | places: places, workers: workers, inventions: inventions},
     %{report | inventions_finished: finished}}
  end
end
