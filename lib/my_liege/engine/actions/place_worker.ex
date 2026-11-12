defmodule MyLiege.Engine.Actions.PlaceWorker do
  @moduledoc """
  Places or moves a worker. It takes its place at once but travels `travel_weeks` first
  (see `Rules.Travel`), also when it was still travelling. An unplaced worker can only be
  placed once it has arrived. A finished building must have room; a site takes up to
  `build_builders` builders. In the guildhouse the worker starts training after its travel
  (see `Rules.Training.check/3`). Moving a trainee out loses its progress; moving a builder
  off a site resets the site's progress to 0 (`Rules.Construction.leave_site/2`).

  Returns `{:ok, game}` on success, or `{:error, reason}` with reason `:unknown_worker`,
  `:unknown_building`, `:travelling`, `:not_ready`, `:full`, `:already_trained` or
  `:below_threshold`. The placement takes effect in the next week.
  """

  alias MyLiege.Engine.{Building, Game}
  alias MyLiege.Engine.Rules.{Construction, Training, Travel}

  def run(%Game{} = game, worker_id, building_id) do
    with {:ok, worker} <- Game.fetch_worker(game, worker_id),
         {:ok, building} <- Game.fetch_building(game, building_id) do
      cond do
        worker.building == building_id ->
          {:ok, game}

        error = placement_error(game, worker, building) ->
          {:error, error}

        trains?(building) ->
          start_training(game, worker, building_id)

        true ->
          {:ok, move(game, worker, building_id, nil)}
      end
    end
  end

  defp placement_error(game, worker, building) do
    others = Enum.reject(game.workers, &(&1.id == worker.id))

    cond do
      is_nil(worker.building) and Travel.travelling?(worker) -> :travelling
      not Building.site?(building) and not Building.ready?(building, game.week + 1) -> :not_ready
      not Building.has_room?(building, others, game.config) -> :full
      true -> nil
    end
  end

  defp trains?(building), do: building.type == :guildhouse and not Building.site?(building)

  defp start_training(game, worker, building_id) do
    with :ok <- Training.check(worker, game.manameter, game.config) do
      started = Training.first_week(game.week, game.config)
      {:ok, move(game, worker, building_id, started)}
    end
  end

  defp move(game, worker, building_id, training_started) do
    worker = %{worker | training_started: training_started}
    moved = Travel.depart(worker, building_id, game.config)
    buildings = Construction.leave_site(game.buildings, worker.building)
    Game.put_worker(%{game | buildings: buildings}, moved)
  end
end
