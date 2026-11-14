defmodule MyLiege.Engine.Rules.Inventions do
  @moduledoc """
  R15, inventions: a way (R13) that is a project, not a building; for now the improved plough
  I (`:plough`) and II (`:plough_2`), blue's ways to food. Plough II needs two books of each
  colour (`way.plough_2.books`) and plough I invented (`Rules.Ways`).

  - Once unlocked (`Rules.Ways`), the player may start one at no cost, unless a project for
    it is already open or it is already invented: each is invented only once. It is a
    `Place.Project` giving `{:invention, type}` with the catalogue's blueprint, and needs
    `target/2` knowledge (`way_plough_work`, `way_plough_2_work`).
  - Up to `capacity/2` workers of any colour; travel and leaving as for books. Each
    writes as in a blue building (`Rules.Production`), times the experience factor of the
    colour of the good's home place (green for food; Manameter share ÷ 200, as for books,
    `Rules.Books.written/3`). Output beyond the target is lost.
  - Once done (at the end of the week), the type joins `inventions`, the project disappears
    and its workers are released, travelling.
  - Each invention has an effect (`effect/2`), for the rest of the game once invented. The
    ploughs: `{:farm_output, bonus}`; the bonuses of all ploughs invented add up, and every
    farm worker's output is × (1000 + their sum) ÷ 1000, rounded down per worker, after the
    colour factors and before happiness (`farm_output/3`).

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{Config, Fixed, Manameter, Place}
  alias MyLiege.Engine.Place.{Blueprint, Project}
  alias MyLiege.Engine.Rules.{Books, Placement, Ways}

  @types for %Blueprint{engine: :project, type: type} <- Blueprint.ways(), do: type

  @doc "The types that can be invented, in catalogue order."
  def types, do: @types

  @type state :: :invented | :open | :startable | :locked

  @doc """
  Whether the player may start inventing `type`: `:ok`, or `{:error, reason}` with reason
  `:unknown_invention`, `:locked`, `:already_invented` or `:already_open`, in this order.
  """
  def check_start(type, places, inventions, books, %Config{} = config) do
    cond do
      type not in @types -> {:error, :unknown_invention}
      Ways.check(Blueprint.fetch!(type), books, inventions, config) != :ok -> {:error, :locked}
      type in inventions -> {:error, :already_invented}
      open?(places, type) -> {:error, :already_open}
      true -> :ok
    end
  end

  @doc "Whether a project inventing `type` is among `places`."
  def open?(places, type),
    do: Enum.any?(places, &match?(%Project{gives: {:invention, ^type}}, &1))

  @doc """
  The state of `type` for the overview: `:invented`, `:open` (a project for it is among
  `places`), `:startable` or `:locked`.
  """
  @spec state(atom(), list(), [atom()], map(), Config.t()) :: state()
  def state(type, places, inventions, books, %Config{} = config) do
    case check_start(type, places, inventions, books, config) do
      :ok -> :startable
      {:error, :already_invented} -> :invented
      {:error, :already_open} -> :open
      {:error, :locked} -> :locked
    end
  end

  @doc "The project inventing `type` among `places`, or `nil`."
  def project(places, type),
    do: Enum.find(places, &match?(%Project{gives: {:invention, ^type}}, &1))

  @doc "Appends a new project inventing `type` to `places`, with the next free id."
  def new_invention(places, type, %Config{} = config) when type in @types do
    project = %Project{
      id: Place.next_id(places),
      blueprint: Blueprint.fetch!(type),
      target: target(type, config),
      gives: {:invention, type}
    }

    places ++ [project]
  end

  @doc "The knowledge (thousandths) inventing `type` needs."
  def target(:plough, %Config{} = config), do: Fixed.from(config.way_plough_work)
  def target(:plough_2, %Config{} = config), do: Fixed.from(config.way_plough_2_work)

  @doc "How many workers a project inventing `type` takes."
  def capacity(:plough, %Config{} = config), do: config.way_plough_capacity
  def capacity(:plough_2, %Config{} = config), do: config.way_plough_2_capacity

  @doc """
  What `type` does once invented: `{:farm_output, bonus}` (per mille added to every farm
  worker's output). A later invention adds a clause with its own effect.
  """
  def effect(:plough, %Config{} = config), do: {:farm_output, config.way_plough_bonus}
  def effect(:plough_2, %Config{} = config), do: {:farm_output, config.way_plough_2_bonus}

  @doc "The farm output bonus (per mille) of all `inventions` together: their bonuses added."
  def farm_bonus(inventions, %Config{} = config) do
    for type <- inventions, {:farm_output, bonus} <- [effect(type, config)], reduce: 0 do
      total -> total + bonus
    end
  end

  @doc "The inventions among `inventions` whose effect is on farm output, in catalogue order."
  def farm_inventions(inventions, %Config{} = config),
    do:
      for(
        type <- @types,
        type in inventions,
        match?({:farm_output, _}, effect(type, config)),
        do: type
      )

  @doc "How many ploughs are invented: 0, 1 or 2 (the export's `plough_level`)."
  def plough_level(inventions), do: Enum.count([:plough, :plough_2], &(&1 in inventions))

  @doc """
  Scales a worker's `output` (thousandths) on an invention by the experience factor of the
  colour of its good's home place, rounded down.
  """
  def written(output, %Manameter{} = manameter, %Project{gives: {:invention, _}} = project),
    do: Books.written(output, manameter, project |> Place.good() |> Blueprint.home_colour())

  @doc """
  A farm worker's `output` × (1000 + the farm bonus of `inventions`) ÷ 1000, rounded down;
  unchanged without one.
  """
  def farm_output(output, inventions, %Config{} = config),
    do: div(output * (1000 + farm_bonus(inventions, config)), 1000)

  @doc """
  For every finished invention: adds its type to `inventions`, removes the project and
  releases its workers. Returns `{places, workers, inventions, finished_types}`.
  """
  def finish(places, workers, inventions, %Config{} = config) do
    finished = for %Project{gives: {:invention, _}} = p <- places, Project.done?(p), do: p
    finished_ids = MapSet.new(finished, & &1.id)

    places = Enum.reject(places, &MapSet.member?(finished_ids, &1.id))
    workers = Enum.reduce(finished, workers, &Placement.release(&2, &1.id, config))
    types = Enum.map(finished, fn %Project{gives: {:invention, type}} -> type end)

    {places, workers, inventions ++ types, types}
  end
end
