defmodule MyLiege.Engine.Rules.Training do
  @moduledoc """
  R5, training in the guildhouse: an untrained worker can start training only while its
  colour has at least `training_threshold` of the Manameter (checked once, when placed).
  Training starts once it has arrived (`first_week/2`); after `training_weeks` in the
  guildhouse it is trained and returns unplaced, travelling. The colour never changes;
  training costs nothing but the worker's time. A trainee produces no goods and no mana, but
  still eats and counts for taxes.
  """

  alias MyLiege.Engine.{Building, Config, Manameter, Worker}
  alias MyLiege.Engine.Rules.Travel

  @doc "Whether `worker` may start training now. Returns `:ok` or `{:error, reason}`."
  def check(%Worker{} = worker, %Manameter{} = manameter, %Config{} = config) do
    cond do
      worker.trained ->
        {:error, :already_trained}

      Map.fetch!(manameter, worker.colour) < config.training_threshold ->
        {:error, :below_threshold}

      true ->
        :ok
    end
  end

  @doc """
  The first training week of a worker placed in the guildhouse while the game stands at
  `week`: the week after its travel.
  """
  def first_week(week, %Config{} = config), do: week + 1 + config.travel_weeks

  @doc "The last week of training for a worker that starts in `first_week`."
  def last_week(first_week, %Config{} = config), do: first_week + config.training_weeks - 1

  @doc """
  At the end of `week`, trainees whose last training week it is become trained and unplaced,
  with `travel_weeks` of travel.
  Returns `{workers, newly_trained}`.
  """
  def finish(workers, buildings, week, %Config{} = config) do
    # workers on a guildhouse site are builders, not trainees
    guildhouses =
      for %Building{type: :guildhouse, id: id} = building <- buildings,
          not Building.site?(building),
          into: MapSet.new(),
          do: id

    Enum.map_reduce(workers, [], fn worker, trained ->
      if MapSet.member?(guildhouses, worker.building) and
           last_week(worker.training_started, config) <= week do
        done = Travel.depart(%{worker | trained: true, training_started: nil}, nil, config)
        {done, trained ++ [done]}
      else
        {worker, trained}
      end
    end)
  end
end
