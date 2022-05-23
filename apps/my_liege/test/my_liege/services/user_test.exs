defmodule MyLiege.Service.UserTest do
  use ExUnit.Case, async: true

  alias MyLiege.Service.User
  alias MyLiege.Game.{Board, Workplace}

  describe "add_pawn_to_workplace" do
    test "if pawn is available" do
      assert %Board{pawn_pool: %{normal: 1}, workplaces: %{1 => %Workplace{pawn: 1}}} ==
               User.add_pawn_to_workplace(
                 %Board{pawn_pool: %{normal: 2}, workplaces: %{1 => %Workplace{pawn: 0}}},
                 1
               )
    end

    test "if no pawn is available" do
      assert %Board{pawn_pool: %{normal: 0}, workplaces: %{1 => %Workplace{pawn: 0}}} ==
               User.add_pawn_to_workplace(
                 %Board{pawn_pool: %{normal: 0}, workplaces: %{1 => %Workplace{pawn: 0}}},
                 1
               )
    end
  end

  describe "remove_pawn_from_workplace" do
    test "if pawn is available" do
      assert %Board{pawn_pool: %{normal: 3}, workplaces: %{1 => %Workplace{pawn: nil}}} ==
               User.remove_pawn_from_workplace(
                 %Board{pawn_pool: %{normal: 2}, workplaces: %{1 => %Workplace{pawn: 1}}},
                 1
               )
    end

    test "if no pawn is available" do
      assert %Board{pawn_pool: %{normal: 1}, workplaces: %{1 => %Workplace{pawn: 0}}} ==
               User.remove_pawn_from_workplace(
                 %Board{pawn_pool: %{normal: 1}, workplaces: %{1 => %Workplace{pawn: 0}}},
                 1
               )
    end
  end

  describe "transport to workplace" do
    test "enough goods in inventory" do
      data = %Board{inventory: %{wood: 5}, workplaces: %{1 => %Workplace{}}}
      {data, events} = User.transport_to_workplace(data, %{wood: 3}, 1)

      assert data == %Board{
               inventory: %{wood: 4},
               workplaces: %{1 => %Workplace{inventory: %{wood: 1}}}
             }

      assert events == [
               {:workplace_updated, [id: 1]},
               {:inventory_updated, [removed: %{wood: 1}]}
             ]
    end
  end
end
