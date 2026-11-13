defmodule MyLiege.Engine.Actions.ConstructTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Actions.Construct
  alias MyLiege.Engine.Place.{Blueprint, Project}
  alias MyLiege.EngineFixtures

  # 100 gold, build_cost_gold 30
  setup do
    %{game: EngineFixtures.game_without_demands(EngineFixtures.config(), 1)}
  end

  test "adds a site with the next id", %{game: game} do
    assert {:ok, game} = Construct.run(game, :market)

    assert %Project{id: 3, gives: {:building, :market}, progress: 0} = List.last(game.places)
  end

  test "pays build_cost_gold at once and adds it to the current report", %{game: game} do
    assert {:ok, game} = Construct.run(game, :market)
    assert {:ok, game} = Construct.run(game, :tavern)

    assert game.stocks.gold == 40_000
    assert game.report.gold_spent_buildings == 60_000
    # the report stays the current week's; its end-of-week gold is not rewritten
    assert game.report.week == 0
    assert game.report.gold == 100_000
  end

  test "every type costs the same, the guildhouse included", %{game: game} do
    # every way unlocked: a book of each colour
    game = %{game | books: Map.new(game.books, fn {colour, _} -> {colour, 1} end)}

    for type <- Blueprint.building_types() do
      assert {:ok, built} = Construct.run(game, type)
      assert built.stocks.gold == 70_000
    end
  end

  test "R13: a granary is locked without a violet and a green book; locked costs nothing",
       %{game: game} do
    assert Construct.run(game, :granary) == {:error, :locked}

    assert Construct.run(%{game | books: %{game.books | violet: 1}}, :granary) ==
             {:error, :locked}

    unlocked = %{game | books: %{game.books | violet: 1, green: 1}}
    assert {:ok, built} = Construct.run(unlocked, :granary)
    assert %Project{gives: {:building, :granary}} = List.last(built.places)
    assert built.stocks.gold == 70_000
  end

  test "an invention is not a building", %{game: game} do
    game = %{game | books: %{game.books | blue: 1, green: 1}}
    assert Construct.run(game, :plough) == {:error, :unknown_type}
  end

  test "any number of buildings can be ordered, also of the same type", %{game: game} do
    {:ok, game} = Construct.run(game, :market)
    {:ok, game} = Construct.run(game, :market)

    assert [
             _farm,
             _watchtower,
             %Project{gives: {:building, :market}, id: 3},
             %Project{gives: {:building, :market}, id: 4}
           ] = game.places
  end

  test "exactly the price is enough", %{game: game} do
    game = %{game | stocks: %{game.stocks | gold: 30_000}}

    assert {:ok, %{stocks: %{gold: 0}}} = Construct.run(game, :farm)
  end

  test "less gold than the price is refused", %{game: game} do
    game = %{game | stocks: %{game.stocks | gold: 29_999}}

    assert Construct.run(game, :farm) == {:error, :not_enough_gold}
  end

  test "an unknown type is refused", %{game: game} do
    assert Construct.run(game, :castle) == {:error, :unknown_type}
  end
end
