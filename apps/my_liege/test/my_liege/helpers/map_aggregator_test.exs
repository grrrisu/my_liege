defmodule MyLiege.MapAggregatorTest do
  use ExUnit.Case, async: true

  alias MyLiege.Game.Board
  alias MyLiege.MapAggregator

  describe "aggregate map" do
    test "map to map" do
      assert %{a: 5, b: 10} = MapAggregator.aggregate_map(%{a: 2, b: 7}, %{a: 3, b: 3})
    end

    test "board to board" do
      assert %Board{pawn_pool: %{normal: 3}, poverty: %{normal: 2}} ==
               MapAggregator.aggregate_map(
                 %Board{pawn_pool: %{normal: 1}, poverty: %{normal: 1}},
                 %{
                   pawn_pool: %{normal: 2},
                   poverty: %{normal: 1}
                 }
               )
    end

    test "incomplete board to board" do
      assert %Board{pawn_pool: %{normal: 2}, poverty: %{normal: 1}} ==
               MapAggregator.aggregate_map(%Board{}, %{
                 pawn_pool: %{normal: 2},
                 poverty: %{normal: 1}
               })
    end

    test "board to board with zero limit" do
      assert %Board{pawn_pool: %{normal: 0}, poverty: %{normal: 0}} ==
               MapAggregator.aggregate_map_min_zero(
                 %Board{pawn_pool: %{normal: 1}, poverty: %{}},
                 %{
                   pawn_pool: %{normal: -2},
                   poverty: %{normal: -1}
                 }
               )
    end
  end
end
