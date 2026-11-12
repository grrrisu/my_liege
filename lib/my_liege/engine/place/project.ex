defmodule MyLiege.Engine.Place.Project do
  @moduledoc """
  A project, one kind of `Place`: it collects `progress` until it reaches its `target`, then
  gives something once, `gives`. Projects are told apart by `gives`:

  - a construction site gives `{:building, type}`: once done, it is replaced by a building of
    that type (see `Rules.Construction`);
  - a king's demand project gives `{:demand, due_week}`: the king's knowledge or culture
    demand due that week, delivered once done (see `Rules.Demands`);
  - a book gives `{:book, colour}`: once done, a book of that colour joins the village's
    books (see `Rules.Books`).

  A project's blueprint is not in the catalogue; the project builds its own
  (`site_blueprint/0`, `demand_blueprint/1`, `book_blueprint/0`).
  """

  alias MyLiege.Engine.Place.Blueprint

  @enforce_keys [:id, :blueprint, :target, :gives]
  defstruct [:id, :blueprint, :target, :gives, progress: 0]

  @type t :: %__MODULE__{
          id: pos_integer(),
          blueprint: Blueprint.t(),
          target: pos_integer(),
          gives: {:building, atom()} | {:demand, pos_integer()} | {:book, atom()},
          progress: non_neg_integer()
        }

  @doc "Whether the project has reached its target."
  def done?(%__MODULE__{progress: progress, target: target}), do: progress >= target

  @doc "The blueprint of a construction site: no colour, no good."
  def site_blueprint, do: %Blueprint{type: :site, colour: nil, good: nil, engine: :project}

  @doc """
  The blueprint of a king's demand project for `good`: the colour of the good's home place, so
  workers on it produce as in that building.
  """
  def demand_blueprint(good),
    do: %Blueprint{
      type: :demand,
      colour: Blueprint.home_colour(good),
      good: good,
      engine: :project
    }

  @doc """
  The blueprint of a book: writing is blue work, knowledge as in a monastery, whatever the
  book's own colour (which is in `gives`).
  """
  def book_blueprint,
    do: %Blueprint{type: :book, colour: :blue, good: :knowledge, engine: :project}
end
