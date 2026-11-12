defmodule MyLiege.Engine.Actions.UnplaceWorker do
  @moduledoc """
  Takes a worker out of its place; it travels `travel_weeks` before it can be placed
  again. A trainee loses its progress; a builder resets the site's progress to 0
  (`Rules.Placement.leave/1`). An unknown worker returns `{:error, :unknown_worker}`; a worker
  that is already unplaced stays as it is. It returns `{:ok, game}` on success, and the change
  takes effect in the next week.
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.{Placement, Travel}

  def run(%Game{} = game, worker_id) do
    with {:ok, worker} <- Game.fetch_worker(game, worker_id) do
      if is_nil(worker.place),
        do: {:ok, game},
        else: {:ok, move(game, worker)}
    end
  end

  defp move(game, worker) do
    moved = Travel.depart(%{worker | training_started: nil}, nil, game.config)
    {:ok, place} = Game.fetch_place(game, worker.place)

    game
    |> Game.put_place(Placement.leave(place))
    |> Game.put_worker(moved)
  end
end
