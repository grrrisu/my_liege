defmodule MyLiege.Engine.SimSteps.Books do
  @moduledoc """
  Step 8 of the week, R12 books finished: every book that reached its target is held by the
  village, its project disappears and its writer is released, travelling.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Books

  @impl true
  def run(game, report) do
    {places, workers, books, finished} =
      Books.finish(game.places, game.workers, game.books, game.config)

    {%{game | places: places, workers: workers, books: books},
     %{report | books_finished: finished}}
  end
end
