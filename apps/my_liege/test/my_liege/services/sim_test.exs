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
end
