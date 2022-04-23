defmodule MyLiege.Game.Board do
  alias MyLiege.Game.Workplace

  def create("one") do
    %{workplaces: %{1 => %Workplace{id: 1, type: :farm}}, pawn_pool: %{normal: 3}, inventory: %{}}
  end

  def create("test") do
    %{workplaces: %{}, pawn_pool: %{}, inventory: %{}}
  end
end
