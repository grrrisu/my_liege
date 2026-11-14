defmodule MyLiege.Engine.Place.Blueprint do
  @moduledoc """
  The catalogue of places: one blueprint per type of place, saying what the type is (its
  colour, the good it makes, and which kind of place it becomes, its `engine`). A place in
  the game points to its blueprint (see `Place`). The catalogue lists the types that can stand
  and be ordered (`engine: :building`), the inventions that can be started
  (`engine: :project`), the trade routes (`engine: :trade`, see `Place.Trade`) and the expeditions
  (`engine: :expedition`, see `Place.Expedition`); other projects
  build their own blueprint (see `Place.Project`).

  The five home places, one per colour, come first in pentagon order: each makes the good of
  its own colour. Then the ways (R13): a colour and a good that are not each other's home
  (`way?/1`). Then the neutral ones. The catalogue is read at compile time, also by the
  loading of the designer's inputs, so this module depends on no other module.
  """

  @enforce_keys [:type, :colour, :good, :engine]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          type: atom(),
          colour: atom() | nil,
          good: atom() | nil,
          engine: :building | :project | :trade | :expedition
        }

  # plain maps, as the struct can't be built while this module compiles; the home places'
  # order must follow `Pentagon.colours/0` (checked in the blueprint test)
  @homes [
    %{type: :farm, colour: :green, good: :food, engine: :building},
    %{type: :market, colour: :yellow, good: :gold, engine: :building},
    %{type: :monastery, colour: :blue, good: :knowledge, engine: :building},
    %{type: :watchtower, colour: :red, good: :defence, engine: :building},
    %{type: :tavern, colour: :violet, good: :culture, engine: :building}
  ]

  # R13: violet's (R14), blue's (R15), yellow's (R16) and red's (R17) ways to food
  @ways [
    %{type: :granary, colour: :violet, good: :food, engine: :building},
    %{type: :plough, colour: :blue, good: :food, engine: :project},
    %{type: :grain_trade, colour: :yellow, good: :food, engine: :trade},
    %{type: :hunting, colour: :red, good: :food, engine: :expedition}
  ]

  @neutral [
    # v2: blue's culture way (concept, "The grid", decided 2026-11-11)
    %{type: :guildhouse, colour: nil, good: nil, engine: :building}
  ]

  @catalogue @homes ++ @ways ++ @neutral

  @doc "All blueprints: the home places in pentagon order, then the ways, then the guildhouse."
  def all, do: Enum.map(@catalogue, &struct!(__MODULE__, &1))

  @doc "The blueprint of `type`. Raises on an unknown type."
  def fetch!(type) do
    case Enum.find(@catalogue, &(&1.type == type)) do
      nil -> raise ArgumentError, "unknown place type #{inspect(type)}"
      entry -> struct!(__MODULE__, entry)
    end
  end

  @doc "All place types, in the order of `all/0`."
  def types, do: Enum.map(@catalogue, & &1.type)

  @doc "The types that stand as buildings and can be ordered (`engine: :building`), in catalogue order."
  def building_types, do: for(%{engine: :building, type: type} <- @catalogue, do: type)

  @doc "The types of the five home places, in pentagon order."
  def home_types, do: Enum.map(@homes, & &1.type)

  @doc "The types of the trade routes (`engine: :trade`), in catalogue order."
  def trade_types, do: for(%{engine: :trade, type: type} <- @catalogue, do: type)

  @doc "The types of the expeditions (`engine: :expedition`), in catalogue order."
  def expedition_types, do: for(%{engine: :expedition, type: type} <- @catalogue, do: type)

  @doc "The blueprints of the ways (R13), in catalogue order."
  def ways, do: Enum.map(@ways, &struct!(__MODULE__, &1))

  @doc """
  Whether a blueprint is a way (R13): it has a colour and a good, and the good's home place
  has another colour.
  """
  def way?(%__MODULE__{colour: nil}), do: false
  def way?(%__MODULE__{good: nil}), do: false
  def way?(%__MODULE__{colour: colour, good: good}), do: home_colour(good) != colour

  @doc "The type of a colour's home place, e.g. `:green` -> `:farm`."
  def home_type(colour), do: Enum.find_value(@homes, &(&1.colour == colour && &1.type))

  @doc "The colour whose home place makes `good`, e.g. `:culture` -> `:violet`."
  def home_colour(good), do: Enum.find_value(@homes, &(&1.good == good && &1.colour))

  @doc "The goods in pentagon order of their home places."
  def goods, do: Enum.map(@homes, & &1.good)
end
