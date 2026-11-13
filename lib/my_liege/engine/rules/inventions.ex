defmodule MyLiege.Engine.Rules.Inventions do
  @moduledoc """
  R15, inventions: a way (R13) that is a project, not a building; for now the improved plough,
  blue's way to food.

  - Once unlocked (`Rules.Ways`), the player may start it at no cost, unless it is already
    open or already invented: it is invented only once. It is a `Place.Project` giving
    `{:invention, type}` with the catalogue's blueprint, and needs `way_plough_work`
    knowledge.
  - Up to `way_plough_capacity` workers of any colour; travel and leaving as for books. Each
    writes as in a blue building (`Rules.Production`), times the experience factor of the
    colour of the good's home place (green for food; Manameter share ÷ 200, as for books,
    `Rules.Books.written/3`). Output beyond the target is lost.
  - Once done (at the end of the week), the type joins `inventions`, the project disappears
    and its workers are released, travelling.
  - The improved plough, once invented: every farm worker's output × (1000 +
    `way_plough_bonus`) ÷ 1000, rounded down per worker, after the colour factors and
    before happiness, for the rest of the game.

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{Config, Fixed, Manameter, Place}
  alias MyLiege.Engine.Place.{Blueprint, Project}
  alias MyLiege.Engine.Rules.{Books, Placement, Ways}

  @types for %Blueprint{engine: :project, type: type} <- Blueprint.ways(), do: type

  @doc "The types that can be invented, in catalogue order."
  def types, do: @types

  @doc """
  Whether the player may start inventing `type`: `:ok`, or `{:error, reason}` with reason
  `:unknown_invention`, `:locked`, `:already_invented` or `:already_open`, in this order.
  """
  def check_start(type, places, inventions, books) do
    cond do
      type not in @types -> {:error, :unknown_invention}
      Ways.check(Blueprint.fetch!(type), books) != :ok -> {:error, :locked}
      type in inventions -> {:error, :already_invented}
      open?(places, type) -> {:error, :already_open}
      true -> :ok
    end
  end

  @doc "Whether a project inventing `type` is among `places`."
  def open?(places, type),
    do: Enum.any?(places, &match?(%Project{gives: {:invention, ^type}}, &1))

  @doc "Appends a new project inventing `type` to `places`, with the next free id."
  def new_invention(places, :plough = type, %Config{} = config) do
    project = %Project{
      id: Place.next_id(places),
      blueprint: Blueprint.fetch!(type),
      target: Fixed.from(config.way_plough_work),
      gives: {:invention, type}
    }

    places ++ [project]
  end

  @doc "How many workers a project inventing `type` takes."
  def capacity(:plough, %Config{} = config), do: config.way_plough_capacity

  @doc """
  Scales a worker's `output` (thousandths) on an invention by the experience factor of the
  colour of its good's home place, rounded down.
  """
  def written(output, %Manameter{} = manameter, %Project{gives: {:invention, _}} = project),
    do: Books.written(output, manameter, project |> Place.good() |> Blueprint.home_colour())

  @doc """
  A farm worker's `output` with the improved plough's bonus if it is among `inventions`,
  rounded down; unchanged otherwise.
  """
  def farm_output(output, inventions, %Config{} = config) do
    if :plough in inventions,
      do: div(output * (1000 + config.way_plough_bonus), 1000),
      else: output
  end

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
