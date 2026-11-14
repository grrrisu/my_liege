defmodule MyLiege.Engine.SimSteps.Books do
  @moduledoc """
  Step 8 of the week, R12 books finished: every book that reached its target is held by the
  village, its project disappears and its writer is released, travelling. A trade route (R16)
  and the hunting camp (R17) that the books held now unlock open as places (`Ways.open/4`).
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.{Books, Ways}

  @impl true
  def run(game, report) do
    {places, workers, books, finished} =
      Books.finish(game.places, game.workers, game.books, game.config)

    {places, opened} = Ways.open(places, books, game.inventions, game.config)

    {%{game | places: places, workers: workers, books: books},
     %{report | books_finished: finished, ways_opened: opened}}
  end
end
