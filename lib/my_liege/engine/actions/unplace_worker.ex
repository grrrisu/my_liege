defmodule MyLiege.Engine.Actions.UnplaceWorker do
  @moduledoc """
  Takes a worker out of its place; it travels `travel_weeks` before it can be placed
  again. A trainee loses its progress; a builder leaves the site's progress as it is. An
  unknown worker returns `{:error, :unknown_worker}`, a trader away on a trade (R16)
  `{:error, :away}`; a worker
  that is already unplaced stays as it is. It returns `{:ok, game}` on success, and the change
  takes effect in the next week.
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.{Placement, Travel}

  def run(%Game{} = game, worker_id) do
    with {:ok, worker} <- Game.fetch_worker(game, worker_id),
         :ok <- game.places |> Enum.find(&(&1.id == worker.place)) |> Placement.check_leave() do
      if is_nil(worker.place),
        do: {:ok, game},
        else: {:ok, move(game, worker)}
    end
  end

  defp move(game, worker) do
    moved = Travel.depart(%{worker | training_started: nil}, nil, game.config)
    Game.put_worker(game, moved)
  end
end
