defmodule MyLiege.Engine.Place.Blueprint do
  @moduledoc """
  The catalogue of places: one blueprint per type of place, saying what the type is (its
  colour, the good it makes, and which kind of place it becomes, its `engine`). A place in
  the game points to its blueprint (see `Place`). The catalogue lists the types that can stand
  and be ordered; a project builds its own blueprint (see `Place.Project`).

  The five home places, one per colour, come first in pentagon order; then the neutral ones.
  The catalogue is read at compile time, also by the loading of the designer's inputs, so this
  module depends on no other module.
  """

  @enforce_keys [:type, :colour, :good, :engine]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          type: atom(),
          colour: atom() | nil,
          good: atom() | nil,
          engine: :building | :project
        }

  # plain maps, as the struct can't be built while this module compiles; the home places'
  # order must follow `Pentagon.colours/0` (checked in the blueprint test)
  @catalogue [
    %{type: :farm, colour: :green, good: :food, engine: :building},
    %{type: :market, colour: :yellow, good: :gold, engine: :building},
    %{type: :monastery, colour: :blue, good: :knowledge, engine: :building},
    %{type: :watchtower, colour: :red, good: :defence, engine: :building},
    %{type: :tavern, colour: :violet, good: :culture, engine: :building},
    # v2: blue's culture way (concept, "The grid", decided 2026-11-11)
    %{type: :guildhouse, colour: nil, good: nil, engine: :building}
  ]

  @homes Enum.filter(@catalogue, & &1.colour)

  @doc "All blueprints: the home places in pentagon order, then the guildhouse."
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

  @doc "The type of a colour's home place, e.g. `:green` -> `:farm`."
  def home_type(colour), do: Enum.find_value(@homes, &(&1.colour == colour && &1.type))

  @doc "The colour whose home place makes `good`, e.g. `:culture` -> `:violet`."
  def home_colour(good), do: Enum.find_value(@homes, &(&1.good == good && &1.colour))

  @doc "The goods in pentagon order of their home places."
  def goods, do: Enum.map(@homes, & &1.good)
end
