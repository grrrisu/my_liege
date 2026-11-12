defmodule MyLiege.Engine.Rules.Placement do
  @moduledoc """
  R2, placement: who may enter a place, how many it takes, and what leaving does to it.

  An unplaced worker can only be placed once it has arrived. A finished building takes
  workers from its `ready_week` up to its capacity; a site takes up to `build_builders`
  builders, and a builder leaving a site resets its progress to 0. Entering the guildhouse
  starts training, which the worker must be allowed (see `Training.check/3`).
  """

  alias MyLiege.Engine.{Config, Manameter, Place, Worker}
  alias MyLiege.Engine.Place.Building
  alias MyLiege.Engine.Rules.{Training, Travel}

  @type facts :: %{
          week: non_neg_integer(),
          workers: [Worker.t()],
          manameter: %Manameter{},
          config: %Config{}
        }

  @doc """
  Whether `worker` may enter `place` while the game stands at `week`; the worker arrives at
  the earliest the week after. `workers` in `facts` are the others, without `worker` itself.
  Returns `:ok` or `{:error, reason}`, the reason one of `:travelling`, `:not_ready`, `:full`,
  `:already_trained` and `:below_threshold`, checked in this order.
  """
  @spec check_enter(Place.t(), Worker.t(), facts()) :: :ok | {:error, atom()}
  def check_enter(%Building{} = place, %Worker{} = worker, facts) do
    %{week: week, workers: workers, manameter: manameter, config: config} = facts

    cond do
      is_nil(worker.place) and Travel.travelling?(worker) -> {:error, :travelling}
      not Building.site?(place) and not Building.ready?(place, week + 1) -> {:error, :not_ready}
      not room?(place, workers, config) -> {:error, :full}
      trains?(place) -> Training.check(worker, manameter, config)
      true -> :ok
    end
  end

  @doc "Whether a worker entering `place` starts training there: in a finished guildhouse."
  def trains?(%Building{} = place),
    do: Place.type(place) == :guildhouse and not Building.site?(place)

  @doc "How many workers the place takes: `build_builders` on a site, else its capacity."
  def capacity(%Building{} = place, %Config{} = config) do
    if Building.site?(place),
      do: config.build_builders,
      else: Map.fetch!(config.place_capacity, Place.type(place))
  end

  @doc "A worker leaves `place`: a site's progress goes back to 0; a finished building is unchanged."
  def leave(%Building{} = place) do
    if Building.site?(place), do: %{place | progress: 0}, else: place
  end

  defp room?(place, workers, config),
    do: length(Place.workers_at(workers, place.id)) < capacity(place, config)
end
