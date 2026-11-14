defmodule MyLiege.Engine.Actions.PlaceWorker do
  @moduledoc """
  Places or moves a worker. It takes its place at once but travels `travel_weeks` first
  (see `Rules.Travel`), also when it was still travelling. Whether it may enter is decided by
  `Rules.Placement.check_enter/3`. In the guildhouse the worker starts training after its
  travel (see `Rules.Training`). Moving a trainee out loses its progress; moving a builder
  off a site leaves the site's progress as it is.

  Returns `{:ok, game}` on success, or `{:error, reason}` with reason `:unknown_worker`,
  `:unknown_place`, `:away` (a trader can't leave his trade, R16), `:travelling`, `:full`,
  `:already_trained` or `:below_threshold`. The placement takes effect in the next week.
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.{Placement, Training, Travel}

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

      {:ok, move(game, worker, place.id, training_started)}
    end
  end

  defp current_place(game, worker), do: Enum.find(game.places, &(&1.id == worker.place))

  defp move(game, worker, place_id, training_started) do
    worker = %{worker | training_started: training_started}
    moved = Travel.depart(worker, place_id, game.config)
    Game.put_worker(game, moved)
  end
end
