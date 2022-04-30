defmodule MyLiege.Game.BoardTest do
  use ExUnit.Case, async: true

  alias MyLiege.Game.{Board, Pawn, Workplace}

  describe "employed_pawns" do
    test "has one pawns" do
      assert 1 ==
               Board.employed_pawns(%Board{workplaces: %{1 => %Workplace{id: 1, pawn: %Pawn{}}}})
    end

    test "has no pawns" do
      assert 0 == Board.employed_pawns(%Board{})
    end
  end
end
