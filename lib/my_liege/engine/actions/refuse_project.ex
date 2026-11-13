defmodule MyLiege.Engine.Actions.RefuseProject do
  @moduledoc """
  Refuses the open project at once: the project leaves the places and its workers are
  released (unplaced, travelling), and the next week's run settles the demand as refused,
  which counts as a miss. This is only possible when `Game.project_refusable?/1`; otherwise it
  returns `{:error, :no_project}`. Success returns `{:ok, game}`.
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.Placement

  def run(%Game{} = game) do
    if Game.project_refusable?(game) do
      id = game.demand.project_id

      {:ok,
       %{
         game
         | deliver_demand: false,
           places: Enum.reject(game.places, &(&1.id == id)),
           workers: Placement.release(game.workers, id, game.config)
       }}
    else
      {:error, :no_project}
    end
  end
end
