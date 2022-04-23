defmodule MyLiege.Game do
  @moduledoc """
  MyLiege.Game keeps the contexts that defines the game logic.
  """

  alias MyLiege.Game.Board

  def create(name) do
    Board.create(name)
  end

  def send_command(command) do
    MyLiege.send_command(command)
  end
end
