defmodule MyLiege.Engine.Rules.Placement do
  @moduledoc """
  R2, placement: who may enter a place and how many it takes.

  An unplaced worker can only be placed once it has arrived. A building takes workers up to
  its capacity; a site (a `Place.Project`) takes up to `build_capacity` builders of any
  colour. Entering the guildhouse starts training, which the worker must be allowed (see
  `Training.check/3`). Leaving a place changes no place.
  """

  alias MyLiege.Engine.{Config, Manameter, Place, Worker}
  alias MyLiege.Engine.Place.{Building, Project}
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
  Returns `:ok` or `{:error, reason}`. On a site the reason is `:travelling` or `:full`; in a
  building one of `:travelling`, `:full`, `:already_trained` and `:below_threshold`, checked
  in this order.
  """
  @spec check_enter(Place.t(), Worker.t(), facts()) :: :ok | {:error, atom()}
  def check_enter(%Project{} = site, %Worker{} = worker, facts) do
    %{workers: workers, config: config} = facts

    cond do
      is_nil(worker.place) and Travel.travelling?(worker) -> {:error, :travelling}
      not room?(site, workers, config) -> {:error, :full}
      true -> :ok
    end
  end

  def check_enter(%Building{} = building, %Worker{} = worker, facts) do
    %{workers: workers, manameter: manameter, config: config} = facts

    cond do
      is_nil(worker.place) and Travel.travelling?(worker) -> {:error, :travelling}
      not room?(building, workers, config) -> {:error, :full}
      trains?(building) -> Training.check(worker, manameter, config)
      true -> :ok
    end
  end

  @doc "Whether a worker entering `place` starts training there: in the guildhouse."
  def trains?(%Project{}), do: false
  def trains?(%Building{} = building), do: Place.type(building) == :guildhouse

  @doc "How many workers the place takes: `build_capacity` on a site, else its capacity."
  def capacity(%Project{}, %Config{} = config), do: config.build_capacity

  def capacity(%Building{} = building, %Config{} = config),
    do: Map.fetch!(config.place_capacity, Place.type(building))

  defp room?(place, workers, config),
    do: length(Place.workers_at(workers, place.id)) < capacity(place, config)
end
