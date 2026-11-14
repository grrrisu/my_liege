defmodule MyLiege.Engine.Actions.UnplaceWorker do
  @moduledoc """
  Takes a worker out of its place; it travels `travel_weeks` (from a trade route or the
  hunting camp, their own travel weeks, R16, R17) before it can be placed again. A trainee
  loses its progress; a builder leaves the site's progress as it is; a hunting camp left
  empty loses its bag. An unknown worker returns `{:error, :unknown_worker}`; a worker that
  is already unplaced stays as it is. It returns `{:ok, game}` on success, and the change
  takes effect in the next week.
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.{Hunting, Travel}

  def run(%Game{} = game, worker_id) do
    with {:ok, worker} <- Game.fetch_worker(game, worker_id) do
      if is_nil(worker.place),
        do: {:ok, game},
        else: {:ok, move(game, worker, Enum.find(game.places, &(&1.id == worker.place)))}
    end
  end

  defp move(game, worker, place) do
    moved = Travel.depart(%{worker | training_started: nil}, place, nil, game.config)
    game = Game.put_worker(game, moved)
    %{game | places: Hunting.abandon_empty(game.places, game.workers)}
  end
end
