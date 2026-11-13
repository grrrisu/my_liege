defmodule MyLiege.Engine.Actions.StartBook do
  @moduledoc """
  Starts writing a book of `colour` (R12): appends the book project to the places, at no
  cost; several books may be written at once. A worker can be placed on it at once and writes
  once he has arrived. A colour that is not one of the five returns `{:error,
  :unknown_colour}`; success returns `{:ok, game}`.
  """

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.Books

  def run(%Game{} = game, colour) do
    if Books.colour?(colour),
      do: {:ok, %{game | places: Books.new_book(game.places, colour, game.config)}},
      else: {:error, :unknown_colour}
  end
end
