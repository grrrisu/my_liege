defmodule MyLiege.Game.WorkplaceTest do
  use ExUnit.Case, async: true

  alias MyLiege.Game.Workplace

  describe "inc inventory" do
    test "has no material yet" do
      workplace = Workplace.inc_inventory(%Workplace{}, %{woods: 5})
      assert workplace.inventory.woods == 5
    end

    test "has material already" do
      workplace = Workplace.inc_inventory(%Workplace{inventory: %{woods: 2}}, %{woods: 5})
      assert workplace.inventory.woods == 7
    end
  end
end
