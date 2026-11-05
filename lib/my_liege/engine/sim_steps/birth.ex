defmodule MyLiege.Engine.SimSteps.Birth do
  @moduledoc "Step 6 of the week, R1 birth: from the food left and the updated Manameter; the newborn is unplaced."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Births
  alias MyLiege.Engine.Worker

  @impl true
  def run(game, report) do
    {newborn, rand} =
      Births.attempt(game.week, game.stocks.food, game.manameter, game.config, game.rand)

    newborn = newborn && %{newborn | id: Worker.next_id(game.workers), born_week: game.week}
    workers = if newborn, do: game.workers ++ [newborn], else: game.workers
    {%{game | workers: workers, rand: rand}, %{report | newborn: newborn}}
  end
end
