defmodule MyLiege.Game do
  @moduledoc """
  MyLiege.Game keeps the contexts that defines the game logic.
  """

  alias MyLiege.Game.Board

  def create(name) do
    Board.create(name)
  end
end
