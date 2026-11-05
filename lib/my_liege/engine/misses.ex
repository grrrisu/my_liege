defmodule MyLiege.Engine.Misses do
  @moduledoc """
  Missed taxes, refused and missed demands share one count; more than `tax_misses_forgiven`
  misses end the game.
  """

  alias MyLiege.Engine.{Game, Taxes}

  @doc "Adds a miss and sets `game_over` once the misses exceed `tax_misses_forgiven`."
  def record(%Game{} = game) do
    misses = game.misses + 1
    game_over = game.game_over or Taxes.game_over?(misses, game.config)
    %{game | misses: misses, game_over: game_over}
  end
end
