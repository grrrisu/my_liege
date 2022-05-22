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

    test "not enough material in inventory" do
      {%{1 => workplace}, events} =
        WorkplaceProduction.workplaces_production(%{
          1 => %Workplace{
            id: 1,
            type: :farm,
            inventory: %{tools: 1},
            input: %{tools: 2},
            pawn: %Pawn{}
          }
        })

      assert Map.get(workplace.inventory, :manpower) |> is_nil()
      assert [{:command, {:user, :transport_to_workplace, [goods: %{tools: 1}]}}] == events
    end

    test "starting work" do
      {%{1 => workplace}, events} =
        WorkplaceProduction.workplaces_production(%{
          1 => %Workplace{
            id: 1,
            type: :farm,
            pawn: %Pawn{},
            inventory: %{tools: 2},
            input: %{tools: 2}
          }
        })

      assert workplace.inventory.manpower == 1
      assert workplace.inventory.tools == 2
      assert [{:workplaces_updated, ids: [1]}] == events
    end

    test "ongoing work" do
      {%{1 => workplace}, events} =
        WorkplaceProduction.workplaces_production(%{
          1 => %Workplace{
            id: 1,
            type: :farm,
            inventory: %{manpower: 2, tools: 2},
            input: %{tools: 2},
            pawn: %Pawn{}
          }
        })

      assert workplace.inventory.manpower == 3
      assert workplace.inventory.tools == 2
      assert [{:workplaces_updated, ids: [1]}] == events
    end

    test "finished work" do
      {%{1 => workplace}, events} =
        WorkplaceProduction.workplaces_production(%{
          1 => %Workplace{
            id: 1,
            type: :farm,
            inventory: %{manpower: 3, tools: 2},
            input: %{manpower: 3, tools: 2},
            output: %{food: 5},
            pawn: %Pawn{}
          }
        })

      assert workplace.inventory.manpower == 0
      assert workplace.inventory.tools == 0

      assert [{:workplaces_updated, [ids: [1]]}, {:command, {:sim, :add_inventory, %{food: 5}}}] ==
               events
    end
  end

  describe "construction site" do
    test "finnished work" do
      {%{1 => workplace}, events} =
        WorkplaceProduction.workplaces_production(%{
          1 => %Workplace{
            id: 1,
            type: :construction_site,
            inventory: %{manpower: 3, wood: 5},
            input: %{manpower: 3, wood: 5},
            pawn: %Pawn{},
            output: %Workplace{type: :farm}
          }
        })

      assert %Workplace{id: 1, type: :farm, pawn: %Pawn{}, inventory: %{wood: 0, manpower: 0}} =
               workplace

      assert [
               {:workplaces_updated, [ids: [1]]},
               {:command, {:user, :remove_pawn_from_workplace, [workplace_id: 1]}}
             ] == events
    end
  end
end
