defmodule MyLiege.Engine.Rules.InventionsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Manameter, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Project}
  alias MyLiege.Engine.Rules.{Books, Inventions}
  alias MyLiege.EngineFixtures

  @unlocked %{Books.none() | blue: 1, green: 1}

  describe "R15: starting an invention" do
    test "the improved plough is the only invention" do
      assert Inventions.types() == [:plough]
    end

    test "needs the way unlocked, at most one open, and only once" do
      plough = EngineFixtures.new_invention(3, :plough)

      assert Inventions.check_start(:granary, [], [], @unlocked) == {:error, :unknown_invention}
      assert Inventions.check_start(:plough, [], [], Books.none()) == {:error, :locked}
      assert Inventions.check_start(:plough, [], [], %{@unlocked | green: 0}) == {:error, :locked}
      assert Inventions.check_start(:plough, [], [], @unlocked) == :ok
      assert Inventions.check_start(:plough, [plough], [], @unlocked) == {:error, :already_open}

      assert Inventions.check_start(:plough, [], [:plough], @unlocked) ==
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
  end

  describe "R15: writing an invention" do
    test "× the experience factor of green, the colour of food's home place" do
      plough = EngineFixtures.new_invention(3, :plough)
      manameter = %Manameter{green: 400, yellow: 150, blue: 150, red: 150, violet: 150}

      assert Inventions.written(3_000, manameter, plough) == 6_000
      assert Inventions.written(3_000, %{manameter | green: 100, blue: 450}, plough) == 1_500
    end
  end

  describe "R15: the improved plough's bonus" do
    test "farm output × (1000 + way.plough.bonus_permille) ÷ 1000 once invented, rounded down" do
      config = EngineFixtures.config()

      assert Inventions.farm_output(9_000, [], config) == 9_000
      assert Inventions.farm_output(9_000, [:plough], config) == 11_250
      assert Inventions.farm_output(6_751, [:plough], config) == 8_438
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
