defmodule MyLiege.Engine.Building do
  @moduledoc """
  A building. Workers refer to it by `id`; it produces from `ready_week` on.
  Path buildings have a colour and a product; the guildhouse is neutral and has neither.

  An ordered building is a site until it is finished: `ready_week` is `nil` and `progress`
  counts its weeks of construction (see `Construction`). Workers placed on a site are its
  builders, at most `builders_per_building`.
  """

  alias MyLiege.Engine.{Config, Worker}

  @enforce_keys [:id, :type]
  defstruct id: nil, type: nil, ready_week: 0, progress: 0

  @colours %{farm: :green, monastery: :blue, watchtower: :red, market: :yellow, tavern: :violet}
  @products %{
    farm: :food,
    monastery: :knowledge,
    watchtower: :defence,
    market: :gold,
    tavern: :entertainment
  }
  @path_types [:farm, :monastery, :watchtower, :market, :tavern]
  @types @path_types ++ [:guildhouse]

  @doc "The building's path colour, or `nil` for the neutral guildhouse."
  def colour(%__MODULE__{type: type}), do: Map.get(@colours, type)

  @doc "The building type of a path colour, e.g. `:green` -> `:farm`."
  def type_of_colour(colour), do: Enum.find(@path_types, &(Map.fetch!(@colours, &1) == colour))

  @doc "All building types: the path buildings in pentagon order, then the guildhouse."
  def types, do: @types

  def neutral?(%__MODULE__{type: type}), do: not Map.has_key?(@colours, type)

  def product(%__MODULE__{type: type}), do: Map.fetch!(@products, type)

  @doc "The products in pentagon order of their buildings."
  def products, do: [:food, :knowledge, :defence, :gold, :entertainment]

  def ready?(%__MODULE__{ready_week: nil}, _week), do: false
  def ready?(%__MODULE__{ready_week: ready_week}, week), do: week >= ready_week

  @doc "Whether the building is still a site, i.e. not finished."
  def site?(%__MODULE__{ready_week: ready_week}), do: is_nil(ready_week)

  @doc "The buildings standing at the start of the game: the farm and the tower (a watchtower)."
  def starting do
    [%__MODULE__{id: 1, type: :farm}, %__MODULE__{id: 2, type: :watchtower}]
  end

  @doc """
  Orders a new building: it starts as a site without builders and progress. The price is paid
  in `Game.construct/2`.
  """
  def construct(buildings, type) when type in @types do
    last_id = buildings |> Enum.map(& &1.id) |> Enum.max(fn -> 0 end)
    buildings ++ [%__MODULE__{id: last_id + 1, type: type, ready_week: nil, progress: 0}]
  end

  @doc "How many workers the building takes: `builders_per_building` on a site, else its capacity."
  def capacity(%__MODULE__{} = building, %Config{} = config) do
    if site?(building),
      do: config.builders_per_building,
      else: Map.fetch!(config.capacity, building.type)
  end

  def has_room?(%__MODULE__{id: id} = building, workers, %Config{} = config) do
    Enum.count(workers, fn %Worker{building: building} -> building == id end) <
      capacity(building, config)
  end

  @doc "A worker can only be placed in a finished building with room."
  def can_place?(%__MODULE__{} = building, workers, week, %Config{} = config) do
    ready?(building, week) and has_room?(building, workers, config)
  end

  @doc """
  Pairs each placed worker who has arrived (travel 0) with its path building, if that building
  is ready in `week`. Workers in the neutral guildhouse or on sites produce nothing and are
  left out.
  """
  def staffed(workers, buildings, week) do
    ready_buildings =
      for building <- buildings, ready?(building, week), not neutral?(building), into: %{} do
        {building.id, building}
      end

    for %Worker{building: building_id, travel: 0} = worker <- workers,
        Map.has_key?(ready_buildings, building_id) do
      {worker, Map.fetch!(ready_buildings, building_id)}
    end
  end
end
