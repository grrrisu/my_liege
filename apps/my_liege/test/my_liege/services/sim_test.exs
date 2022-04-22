defmodule MyLiege.Service.SimTest do
  use ExUnit.Case, async: true

  alias MyLiege.Service.Sim
  alias MyLiege.Game.{Pawn, Workplace}

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
end
