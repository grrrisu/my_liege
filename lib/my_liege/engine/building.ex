defmodule MyLiege.Engine.Building do
  @moduledoc "A path building. Workers refer to it by `id`; it produces from `ready_week` on."

  alias MyLiege.Engine.{Config, Worker}

  @enforce_keys [:id, :type]
  defstruct id: nil, type: nil, ready_week: 0

  @colours %{farm: :green, monastery: :blue, watchtower: :red, market: :yellow, tavern: :violet}
  @products %{
    farm: :food,
    monastery: :knowledge,
    watchtower: :defence,
    market: :gold,
    tavern: :entertainment
  }

  def colour(%__MODULE__{type: type}), do: Map.fetch!(@colours, type)

  def product(%__MODULE__{type: type}), do: Map.fetch!(@products, type)

  def products, do: Map.values(@products)

  def ready?(%__MODULE__{ready_week: ready_week}, week), do: week >= ready_week

  @doc "The buildings standing at the start of the game."
  def starting(%Config{} = config) do
    config.starting_buildings
    |> Enum.with_index(1)
    |> Enum.map(fn {type, id} -> %__MODULE__{id: id, type: type} end)
  end

  @doc "Orders a new building in `week`; it is free and produces after `construction_weeks`."
  def construct(buildings, type, week, %Config{} = config) when is_map_key(@colours, type) do
    last_id = buildings |> Enum.map(& &1.id) |> Enum.max(fn -> 0 end)

    building = %__MODULE__{
      id: last_id + 1,
      type: type,
      ready_week: week + config.construction_weeks
    }

    buildings ++ [building]
  end

  def has_room?(%__MODULE__{id: id}, workers, %Config{} = config) do
    Enum.count(workers, fn %Worker{building: building} -> building == id end) <
      config.building_capacity
  end
end
