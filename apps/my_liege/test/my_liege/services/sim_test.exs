defmodule MyLiege.Service.SimTest do
  use ExUnit.Case, async: true

  alias MyLiege.Service.Sim
  alias MyLiege.Game.{Board, Pawn, Workplace}

  describe "workplaces produced event" do
    test "no workplaces" do
      assert [{:workplaces_produced, :time_unit}] == Sim.workplace_events([])
    end

    test "one farm" do
      events = Sim.workplace_events([%Workplace{type: :farm, pawn: %Pawn{}}])

      assert [
               {:workplaces_produced, :time_unit},
               {:command, {:sim, :add_inventory, %{food: 5}}}
             ] == events
    end

    test "two farms" do
      events =
        Sim.workplace_events([
          %Workplace{type: :farm, pawn: %Pawn{}},
          %Workplace{type: :farm, pawn: %Pawn{}}
        ])

      assert [
               {:workplaces_produced, :time_unit},
               {:command, {:sim, :add_inventory, %{food: 10}}}
             ] == events
    end
  end

  describe "needed food" do
    test "pawns in workplaces and pawn_pool" do
      data = %Board{workplaces: %{1 => %Workplace{id: 1, pawn: %Pawn{}}}, pawn_pool: %{normal: 2}}
      assert 3 == Sim.needed_food(data)
    end
  end

  describe "pawn poverty" do
    test "no food and poverty" do
      {data, _events} = Sim.pawn_poverty(%Board{inventory: %{food: 0}, poverty: %{normal: 5}})
      assert 4 == Board.get_in(data, [:poverty, :normal])
    end

    test "no food and free pawns" do
      {data, _events} = Sim.pawn_poverty(%Board{inventory: %{food: 0}, pawn_pool: %{normal: 5}})
      assert 1 == Board.get_in(data, [:poverty, :normal])
      assert 4 == Board.get_in(data, [:pawn_pool, :normal])
    end

    test "food available and poverty" do
      {data, _events} = Sim.pawn_poverty(%Board{inventory: %{food: 5}, poverty: %{normal: 5}})
      assert 4 == Board.get_in(data, [:poverty, :normal])
      assert 1 == Board.get_in(data, [:pawn_pool, :normal])
    end

    test "food available and no poverty" do
      {data, _events} = Sim.pawn_poverty(%Board{inventory: %{food: 5}, pawn_pool: %{normal: 5}})
      assert 5 == Board.get_in(data, [:pawn_pool, :normal])
    end
  end
end
