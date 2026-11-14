defmodule MyLiege.Engine.Rules.InventionsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Manameter, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Project}
  alias MyLiege.Engine.Rules.{Books, Inventions}
  alias MyLiege.EngineFixtures

  @unlocked %{Books.none() | blue: 1, green: 1}

  describe "R15: starting an invention" do
    test "the improved ploughs I and II are the inventions" do
      assert Inventions.types() == [:plough, :plough_2]
    end

    test "needs the way unlocked, at most one open, and only once" do
      config = EngineFixtures.config()
      plough = EngineFixtures.new_invention(3, :plough)

      assert Inventions.check_start(:granary, [], [], @unlocked, config) ==
               {:error, :unknown_invention}

      assert Inventions.check_start(:plough, [], [], Books.none(), config) == {:error, :locked}

      assert Inventions.check_start(:plough, [], [], %{@unlocked | green: 0}, config) ==
               {:error, :locked}

      assert Inventions.check_start(:plough, [], [], @unlocked, config) == :ok

      assert Inventions.check_start(:plough, [plough], [], @unlocked, config) ==
               {:error, :already_open}

      assert Inventions.check_start(:plough, [], [:plough], @unlocked, config) ==
               {:error, :already_invented}
    end

    test "a new invention is a project with the catalogue's blueprint and way.plough.work" do
      config = EngineFixtures.config(way_plough_work: 50)
      places = Inventions.new_invention([EngineFixtures.new_building(1, :farm)], :plough, config)

      assert %Project{id: 2, gives: {:invention, :plough}, target: 50_000, progress: 0} =
               project = List.last(places)

      assert project.blueprint == Blueprint.fetch!(:plough)
    end

    test "takes way.plough.capacity workers" do
      assert Inventions.capacity(:plough, EngineFixtures.config(way_plough_capacity: 3)) == 3
    end

    test "plough II: two books of each colour and plough I invented; its own work and capacity" do
      config = EngineFixtures.config(way_plough_2_work: 70, way_plough_2_capacity: 2)
      two = %{Books.none() | blue: 2, green: 2}

      assert Inventions.check_start(:plough_2, [], [:plough], @unlocked, config) ==
               {:error, :locked}

      assert Inventions.check_start(:plough_2, [], [], two, config) == {:error, :locked}
      assert Inventions.check_start(:plough_2, [], [:plough], two, config) == :ok

      assert %Project{gives: {:invention, :plough_2}, target: 70_000} =
               [] |> Inventions.new_invention(:plough_2, config) |> List.last()

      assert Inventions.capacity(:plough_2, config) == 2
    end

    test "one project per invention: plough I open doesn't block another type" do
      config = EngineFixtures.config()
      plough = EngineFixtures.new_invention(3, :plough)
      two = %{Books.none() | blue: 2, green: 2}

      assert Inventions.check_start(:plough_2, [plough], [:plough], two, config) == :ok
    end

    test "the state for the overview" do
      config = EngineFixtures.config()
      plough = EngineFixtures.new_invention(3, :plough)

      assert Inventions.state(:plough, [], [], Books.none(), config) == :locked
      assert Inventions.state(:plough, [], [], @unlocked, config) == :startable
      assert Inventions.state(:plough, [plough], [], @unlocked, config) == :open
      assert Inventions.state(:plough, [], [:plough], @unlocked, config) == :invented
      assert Inventions.project([plough], :plough) == plough
    end
  end

  describe "R15: writing an invention" do
    test "× the experience factor of green, the colour of food's home place" do
      plough = EngineFixtures.new_invention(3, :plough)
      manameter = %Manameter{green: 400, yellow: 150, blue: 150, red: 150, violet: 150}

      assert Inventions.written(3_000, manameter, plough) == 6_000
      assert Inventions.written(3_000, %{manameter | green: 100, blue: 450}, plough) == 1_500
    end
  end

  describe "R15: the ploughs' bonus" do
    test "farm output × (1000 + the bonuses of the ploughs invented) ÷ 1000, rounded down" do
      config = EngineFixtures.config()

      assert Inventions.farm_output(9_000, [], config) == 9_000
      assert Inventions.farm_output(9_000, [:plough], config) == 10_125
      assert Inventions.farm_output(9_000, [:plough, :plough_2], config) == 11_250
      assert Inventions.farm_output(6_751, [:plough], config) == 7_594
    end

    test "effects, the total farm bonus, the farm inventions and the plough level" do
      config = EngineFixtures.config(way_plough_2_bonus: 100)

      assert Inventions.effect(:plough, config) == {:farm_output, 125}
      assert Inventions.effect(:plough_2, config) == {:farm_output, 100}
      assert Inventions.farm_bonus([:plough_2, :plough], config) == 225
      assert Inventions.farm_inventions([:plough_2, :plough], config) == [:plough, :plough_2]

      assert Enum.map([[], [:plough], [:plough, :plough_2]], &Inventions.plough_level/1) ==
               [0, 1, 2]
    end
  end

  describe "R15: finishing" do
    test "a done invention is invented, its project removed, its workers released" do
      config = EngineFixtures.config(travel_weeks: 1)
      done = EngineFixtures.new_invention(3, :plough, progress: 96_000)
      workers = [%Worker{id: 1, colour: :blue, place: 3}, %Worker{id: 2, colour: :red, place: 3}]

      assert {[], released, [:plough], [:plough]} =
               Inventions.finish([done], workers, [], config)

      assert Enum.all?(released, &(&1.place == nil and &1.travel == 1))
    end

    test "an unfinished invention stays" do
      config = EngineFixtures.config()
      open = EngineFixtures.new_invention(3, :plough, progress: 95_999)

      assert Inventions.finish([open], [], [], config) == {[open], [], [], []}
    end
  end
end
