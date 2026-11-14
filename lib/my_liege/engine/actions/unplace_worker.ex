defmodule MyLiege.Engine.Actions.UnplaceWorker do
  @moduledoc """
  Takes a worker out of its place; it travels `travel_weeks` (from a trade route, the route's
  travel weeks, R16) before it can be placed again. A trainee loses its progress; a builder
  leaves the site's progress as it is. An unknown worker returns `{:error, :unknown_worker}`,
  a hunter away on a hunt (R17) `{:error, :away}`; a worker
  that is already unplaced stays as it is. It returns `{:ok, game}` on success, and the change
  takes effect in the next week.
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.{Placement, Travel}

  def run(%Game{} = game, worker_id) do
    with {:ok, worker} <- Game.fetch_worker(game, worker_id),
         place = Enum.find(game.places, &(&1.id == worker.place)),
         :ok <- Placement.check_leave(place) do
      if is_nil(worker.place),
        do: {:ok, game},
        else: {:ok, move(game, worker, place)}
    end
  end

  defp move(game, worker, place) do
    moved = Travel.depart(%{worker | training_started: nil}, place, nil, game.config)
    Game.put_worker(game, moved)
  end
end
