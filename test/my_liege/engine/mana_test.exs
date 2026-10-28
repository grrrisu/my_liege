defmodule MyLiege.Engine.ManaTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Building, Mana, Worker}
  alias MyLiege.EngineFixtures

  describe "R3: mana per worker" do
    setup do
      config = EngineFixtures.config()
      buildings = Building.starting()
      buildings_by_type = Map.new(buildings, &{&1.type, &1})
      %{config: config, buildings: buildings, buildings_by_type: buildings_by_type}
    end

    test "untrained: 2 in the building's colour, 1 in their own", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Mana.worker_mana(worker(:red), farm, config) == %{green: 2, red: 1}
    end

    test "trained: 1 in the building's colour, 2 in their own", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Mana.worker_mana(worker(:red, true), farm, config) == %{green: 1, red: 2}
    end

    test "same colour gives 3 of that colour, trained or not", context do
      %{config: config, buildings_by_type: %{farm: farm}} = context

      assert Mana.worker_mana(worker(:green), farm, config) == %{green: 3}
      assert Mana.worker_mana(worker(:green, true), farm, config) == %{green: 3}
    end

    test "weekly totals per colour; unplaced workers make no mana", context do
      %{config: config, buildings: buildings, buildings_by_type: buildings_by_type} = context

      workers = [
        worker(:green, false, buildings_by_type.farm.id),
        worker(:red, false, buildings_by_type.farm.id),
        worker(:blue, true, buildings_by_type.watchtower.id),
        worker(:violet)
      ]

      assert Mana.week(workers, buildings, 0, config) ==
               %{green: 5, blue: 2, red: 2, yellow: 0, violet: 0}
    end

    test "a worker can only be placed in a finished building with room", context do
      %{config: config, buildings: buildings, buildings_by_type: %{farm: farm}} = context
      buildings = Building.construct(buildings, :tavern, 5, config)
      new_tavern = List.last(buildings)
      full_farm = for _ <- 1..config.capacity.farm, do: worker(:green, false, farm.id)

      refute Building.can_place?(new_tavern, [], 6, config)
      assert Building.can_place?(new_tavern, [], 7, config)
      assert Building.can_place?(farm, [], 0, config)
      refute Building.can_place?(farm, full_farm, 0, config)
    end
  end

  defp worker(colour, trained \\ false, building_id \\ nil),
    do: %Worker{colour: colour, trained: trained, building: building_id}
end
