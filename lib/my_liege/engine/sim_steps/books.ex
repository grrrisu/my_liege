defmodule MyLiege.Engine.SimSteps.Books do
  @moduledoc """
  Step 8 of the week, R12 books finished: every book that reached its target is held by the
  village, its project disappears and its writer is released, travelling. A trade route (R16)
  that the books held now unlock opens as a place (`Trades.open/2`).
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.{Books, Trades}

  @impl true
  def run(game, report) do
    {places, workers, books, finished} =
      Books.finish(game.places, game.workers, game.books, game.config)

    {places, opened} = Trades.open(places, books)

    {%{game | places: places, workers: workers, books: books},
     %{report | books_finished: finished, routes_opened: opened}}
  end
end
