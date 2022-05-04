defmodule MyLiege.Service.Sim.WorkplaceProductionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Service.Sim.WorkplaceProduction
  alias MyLiege.Game.{Pawn, Workplace}

  describe "workplaces_production" do
    test "no worker" do
      {%{1 => workplace}, events} =
        WorkplaceProduction.workplaces_production(%{
          1 => %Workplace{id: 1, type: :farm}
        })

      assert map_size(workplace.inventory) == 0
      assert Enum.count(events) == 0
    end

    test "starting work" do
      {%{1 => workplace}, events} =
        WorkplaceProduction.workplaces_production(%{
          1 => %Workplace{id: 1, type: :farm, pawn: %Pawn{}}
        })

      assert workplace.inventory.manpower == 1
      assert [{:workplaces_updated, ids: [1]}] == events
    end

    test "ongoing work" do
      {%{1 => workplace}, events} =
        WorkplaceProduction.workplaces_production(%{
          1 => %Workplace{id: 1, type: :farm, inventory: %{manpower: 2}, pawn: %Pawn{}}
        })

      assert workplace.inventory.manpower == 3
      assert [{:workplaces_updated, ids: [1]}] == events
    end

    test "finished work" do
      {%{1 => workplace}, events} =
        WorkplaceProduction.workplaces_production(%{
          1 => %Workplace{
            id: 1,
            type: :farm,
            inventory: %{manpower: 3},
            input: %{manpower: 3},
            output: %{food: 5},
            pawn: %Pawn{}
          }
        })

      assert workplace.inventory.manpower == 0

      assert [{:command, {:sim, :add_inventory, %{food: 5}}}, {:workplaces_updated, [ids: [1]]}] ==
               events
    end
  end
end
