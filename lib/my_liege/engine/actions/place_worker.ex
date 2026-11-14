defmodule MyLiege.Engine.Actions.PlaceWorker do
  @moduledoc """
  Places or moves a worker. It takes its place at once but travels `travel_weeks` first
  (to or from a trade route, the route's travel weeks; see `Rules.Travel`), also when it was
  still travelling. On a trade route (R16) it goes last in the route's queue. Whether it may enter is decided by
  `Rules.Placement.check_enter/3`. In the guildhouse the worker starts training after its
  travel (see `Rules.Training`). Moving a trainee out loses its progress; moving a builder
  off a site leaves the site's progress as it is.

  Returns `{:ok, game}` on success, or `{:error, reason}` with reason `:unknown_worker`,
  `:unknown_place`, `:away` (a hunter can't leave his hunt, R17), `:travelling`, `:full`,
  `:already_trained` or `:below_threshold`. The placement takes effect in the next week.
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.{Placement, Trades, Training, Travel}

  def run(%Game{} = game, worker_id, place_id) do
    with {:ok, worker} <- Game.fetch_worker(game, worker_id),
         {:ok, place} <- Game.fetch_place(game, place_id) do
      if worker.place == place_id,
        do: {:ok, game},
        else: enter(game, worker, place)
    end
  end

  defp enter(game, worker, place) do
    facts = %{
      week: game.week,
      workers: Enum.reject(game.workers, &(&1.id == worker.id)),
      manameter: game.manameter,
      config: game.config
    }

    with :ok <- game |> current_place(worker) |> Placement.check_leave(),
         :ok <- Placement.check_enter(place, worker, facts) do
      training_started =
        if Placement.trains?(place), do: Training.first_week(game.week, game.config)

      {:ok, move(game, worker, place, training_started)}
    end
  end

  defp current_place(game, worker), do: Enum.find(game.places, &(&1.id == worker.place))

  defp move(game, worker, place, training_started) do
    from = current_place(game, worker)
    worker = %{worker | training_started: training_started}
    moved = Travel.depart(worker, from, place, game.config)

    %{game | places: Trades.join(game.places, worker.id, place.id)}
    |> Game.put_worker(moved)
  end
end
