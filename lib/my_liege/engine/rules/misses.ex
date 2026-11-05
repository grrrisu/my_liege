defmodule MyLiege.Engine.Rules.Misses do
  @moduledoc """
  R7, misses: missed taxes, refused and missed demands share one count; more than
  `tax_misses_forgiven` misses end the game.
  """

  alias MyLiege.Engine.Config

  @doc "Adds a miss. Returns `{misses, game_over?}`."
  def add(misses, %Config{} = config) do
    misses = misses + 1
    {misses, game_over?(misses, config)}
  end

  @doc "Whether `misses` exceeds `tax_misses_forgiven`."
  def game_over?(misses, %Config{} = config), do: misses > config.tax_misses_forgiven
end
