defmodule MyLiege.Game.Board do
  alias MyLiege.Game.{Board, Workplace}

  defstruct workplaces: %{}, pawn_pool: %{}, poverty: %{}, inventory: %{}

  def create("one") do
    %Board{
      workplaces: %{1 => %Workplace{id: 1, type: :farm}},
      pawn_pool: %{normal: 3},
      inventory: %{}
    }
  end

  def create("test") do
    %Board{}
  end
end
