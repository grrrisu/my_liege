defmodule MyLiege.Engine.Place.Blueprint do
  @moduledoc """
  The catalogue of places: one blueprint per type of place, saying what the type is (its
  colour, the good it makes, and which kind of place it becomes, its `engine`). A place in
  the game points to its blueprint (see `Place`).

  The five home places, one per colour, come first in pentagon order; then the neutral ones.
  The catalogue is read at compile time, also by the loading of the designer's inputs, so this
  module depends on nothing but `Pentagon`.
  """

  alias MyLiege.Engine.Pentagon

  @enforce_keys [:type, :colour, :good, :engine]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          type: atom(),
          colour: atom() | nil,
          good: atom() | nil,
          engine: :building
        }

  @homes %{
    green: {:farm, :food},
    yellow: {:market, :gold},
    blue: {:monastery, :knowledge},
    red: {:watchtower, :defence},
    violet: {:tavern, :culture}
  }

  # the five home places in pentagon order, from the order in `Pentagon.colours/0`; plain
  # maps, as the struct can't be built while this module compiles
  @home_entries Enum.map(Pentagon.colours(), fn colour ->
                  {type, good} = Map.fetch!(@homes, colour)
                  %{type: type, colour: colour, good: good, engine: :building}
                end)

  @entries @home_entries ++
             [
               # v2: blue's culture way (concept, "The grid", decided 2026-11-11)
               %{type: :guildhouse, colour: nil, good: nil, engine: :building}
             ]

  @doc "All blueprints: the home places in pentagon order, then the guildhouse."
  def all, do: Enum.map(@entries, &struct!(__MODULE__, &1))

  @doc "The blueprint of `type`. Raises on an unknown type."
  def fetch!(type) do
    case Enum.find(@entries, &(&1.type == type)) do
      nil -> raise ArgumentError, "unknown place type #{inspect(type)}"
      entry -> struct!(__MODULE__, entry)
    end
  end

  @doc "All place types, in the order of `all/0`."
  def types, do: Enum.map(@entries, & &1.type)

  @doc "The type of a colour's home place, e.g. `:green` -> `:farm`."
  def home_type(colour), do: Enum.find_value(@home_entries, &(&1.colour == colour && &1.type))

  @doc "The goods in pentagon order of their home places."
  def goods, do: Enum.map(@home_entries, & &1.good)
end
