defmodule MyLiege.Engine.Actions.StartInvention do
  @moduledoc """
  Starts inventing `type` (R15), e.g. `:plough`: appends its project to the places, at no
  cost. Workers can be placed on it at once and write once they have arrived. Returns
  `{:ok, game}`, or `{:error, reason}` with reason `:unknown_invention`, `:locked` (R13),
  `:already_invented` or `:already_open` (see `Rules.Inventions.check_start/5`).
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.Inventions

  def run(%Game{} = game, type) do
    with :ok <-
           Inventions.check_start(type, game.places, game.inventions, game.books, game.config) do
      {:ok, %{game | places: Inventions.new_invention(game.places, type, game.config)}}
    end
  end
end
