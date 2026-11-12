defmodule MyLiege.Engine.Place do
  @moduledoc """
  What all kinds of place share: anything a worker is placed at. Every place has an `id`,
  which workers point to (`Worker.place`), and a `blueprint`, its entry in the catalogue
  (`Place.Blueprint`). For now every place is a `Place.Building`.

  The functions here only read the stored data; what a place allows or does is decided in the
  rules, with one clause per kind of place.
  """

  alias MyLiege.Engine.Place.Building

  @type t :: Building.t()

  @doc "The place's colour, or `nil` for a neutral place such as the guildhouse."
  def colour(%{blueprint: blueprint}), do: blueprint.colour

  @doc "The good the place makes, or `nil` for a neutral place."
  def good(%{blueprint: blueprint}), do: blueprint.good

  @doc "The place's type, e.g. `:farm`."
  def type(%{blueprint: blueprint}), do: blueprint.type

  @doc "Whether the place has no colour."
  def neutral?(place), do: is_nil(colour(place))

  @doc "The workers placed at the place with id `place_id`."
  def workers_at(workers, place_id), do: Enum.filter(workers, &(&1.place == place_id))
end
