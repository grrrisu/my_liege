defmodule MyLiege.Engine.Place.Project do
  @moduledoc """
  A project, one kind of `Place`: it collects `progress` until it reaches its `target`, then
  gives something once, `gives`. For a construction site `gives` is `{:building, type}`: once
  done, the site is replaced by a building of that type (see `Rules.Construction`).

  A project's blueprint is not in the catalogue; the project builds its own (`site_blueprint/0`
  for a construction site).
  """

  alias MyLiege.Engine.Place.Blueprint

  @enforce_keys [:id, :blueprint, :target, :gives]
  defstruct [:id, :blueprint, :target, :gives, progress: 0]

  @type t :: %__MODULE__{
          id: pos_integer(),
          blueprint: Blueprint.t(),
          target: pos_integer(),
          gives: {:building, atom()},
          progress: non_neg_integer()
        }

  @doc "Whether the project has reached its target."
  def done?(%__MODULE__{progress: progress, target: target}), do: progress >= target

  @doc "The blueprint of a construction site: no colour, no good."
  def site_blueprint, do: %Blueprint{type: :site, colour: nil, good: nil, engine: :project}
end
