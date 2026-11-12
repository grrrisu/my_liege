defmodule MyLiege.Engine.Actions.UnplaceWorker do
  @moduledoc """
  Takes a worker out of its building; it travels `travel_weeks` before it can be placed
  again. A trainee loses its progress; a builder resets the site's progress to 0. An unknown
  worker returns `{:error, :unknown_worker}`; a worker that is already unplaced stays as it is.
  It returns `{:ok, game}` on success, and the change takes effect in the next week.
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.{Construction, Travel}

  def run(%Game{} = game, worker_id) do
    with {:ok, worker} <- Game.fetch_worker(game, worker_id) do
      if is_nil(worker.building),
        do: {:ok, game},
        else: {:ok, move(game, worker)}
    end
  end

  defp move(game, worker) do
    moved = Travel.depart(%{worker | training_started: nil}, nil, game.config)
    buildings = Construction.leave_site(game.buildings, worker.building)
    Game.put_worker(%{game | buildings: buildings}, moved)
  end
end
