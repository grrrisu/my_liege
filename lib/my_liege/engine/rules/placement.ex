defmodule MyLiege.Engine.Rules.Placement do
  @moduledoc """
  R2, placement: who may enter a place, how many it takes, and releasing its workers.

  An unplaced worker can only be placed once it has arrived. A building takes workers up to
  its capacity; a site (a `Place.Project` giving a building) takes up to `build_capacity`
  builders of any colour; a king's demand project (R7) takes any number of workers of any
  colour; a book (R12) takes one writer of any colour; an invention (R15) up to its capacity
  (`Inventions.capacity/2`) of any colour; a trade route (R16) up to its capacity
  (`Trades.capacity/2`) and the hunting camp (R17) up to its capacity
  (`Hunting.capacity/1`), of any colour. Entering the guildhouse starts training, which the
  worker must be allowed (see `Training.check/3`). Any worker may leave any place.
  """

  alias MyLiege.Engine.{Config, Manameter, Place, Worker}
  alias MyLiege.Engine.Place.{Building, Expedition, Project, Trade}
  alias MyLiege.Engine.Rules.{Hunting, Inventions, Trades, Training, Travel}

  @type facts :: %{
          week: non_neg_integer(),
          workers: [Worker.t()],
          manameter: %Manameter{},
          config: %Config{}
        }

  @doc """
  Whether `worker` may enter `place` while the game stands at `week`; the worker arrives at
  the earliest the week after. `workers` in `facts` are the others, without `worker` itself.
  Returns `:ok` or `{:error, reason}`. On a demand project the reason can only be
  `:travelling`; on a site, a book or an invention `:travelling` or `:full`; in a building one of `:travelling`,
  `:full`, `:already_trained` and `:below_threshold`, checked in this order; on a trade route
  or the hunting camp `:travelling` or `:full`.
  """
  @spec check_enter(Place.t(), Worker.t(), facts()) :: :ok | {:error, atom()}
  def check_enter(%Project{gives: {:demand, _}}, %Worker{} = worker, _facts) do
    if is_nil(worker.place) and Travel.travelling?(worker),
      do: {:error, :travelling},
      else: :ok
  end

  def check_enter(%Project{gives: {kind, _}} = project, %Worker{} = worker, facts)
      when kind in [:building, :book, :invention],
      do: check_room(project, worker, facts)

  def check_enter(%Trade{} = route, %Worker{} = worker, facts),
    do: check_room(route, worker, facts)

  def check_enter(%Expedition{} = camp, %Worker{} = worker, facts),
    do: check_room(camp, worker, facts)

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
  def trains?(%Trade{}), do: false
  def trains?(%Expedition{}), do: false
  def trains?(%Building{} = building), do: Place.type(building) == :guildhouse

  @doc """
  How many workers the place takes: `:unlimited` on a demand project, `build_capacity` on a
  site, 1 on a book, the invention's capacity on an invention, the route's on a trade route
  (R16), else the building's capacity.
  """
  def capacity(%Project{gives: {:demand, _}}, %Config{}), do: :unlimited
  def capacity(%Project{gives: {:building, _}}, %Config{} = config), do: config.build_capacity
  def capacity(%Project{gives: {:book, _}}, %Config{}), do: 1

  def capacity(%Project{gives: {:invention, type}}, %Config{} = config),
    do: Inventions.capacity(type, config)

  def capacity(%Trade{} = route, %Config{} = config),
    do: route |> Place.type() |> Trades.capacity(config)

  def capacity(%Expedition{}, %Config{} = config), do: Hunting.capacity(config)

  def capacity(%Building{} = building, %Config{} = config),
    do: Map.fetch!(config.place_capacity, Place.type(building))

  @doc """
  Releases every worker at the place with id `place_id`: unplaced, travelling
  `travel_weeks`. Used when a place ends (a finished site, a settled or refused demand project,
  a finished book or invention).
  """
  def release(workers, place_id, %Config{} = config) do
    Enum.map(workers, fn %Worker{} = worker ->
      if worker.place == place_id,
        do: Travel.depart(worker, nil, config),
        else: worker
    end)
  end

  defp check_room(place, worker, %{workers: workers, config: config}) do
    cond do
      is_nil(worker.place) and Travel.travelling?(worker) -> {:error, :travelling}
      not room?(place, workers, config) -> {:error, :full}
      true -> :ok
    end
  end

  defp room?(place, workers, config) do
    case capacity(place, config) do
      :unlimited -> true
      capacity -> workers |> Place.workers_at(place.id) |> length() < capacity
    end
  end
end
