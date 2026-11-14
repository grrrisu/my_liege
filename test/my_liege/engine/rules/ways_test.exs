defmodule MyLiege.Engine.Rules.WaysTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place.{Blueprint, Building, Expedition, Trade}
  alias MyLiege.Engine.Rules.{Books, Ways}
  alias MyLiege.EngineFixtures

  setup do
    %{config: EngineFixtures.config()}
  end

  describe "R13: one unlock rule for every way" do
    test "a way needs a book of its colour and one of its good's home colour", %{config: c} do
      granary = Blueprint.fetch!(:granary)

      assert Ways.missing(granary, Books.none(), [], c) == [
               {:book, :violet, 1},
               {:book, :green, 1}
             ]

      assert Ways.missing(granary, books(violet: 1), [], c) == [{:book, :green, 1}]
      assert Ways.missing(granary, books(green: 1), [], c) == [{:book, :violet, 1}]
      assert Ways.missing(granary, books(violet: 1, green: 3), [], c) == []
      assert Ways.unlocked?(granary, books(violet: 1, green: 1), [], c)
      refute Ways.unlocked?(granary, books(violet: 5, blue: 5), [], c)
    end

    test "plough I needs a blue and a green book", %{config: c} do
      plough = Blueprint.fetch!(:plough)

      assert Ways.check(plough, books(blue: 1), [], c) == {:error, :locked}
      assert Ways.check(plough, books(blue: 1, green: 1), [], c) == :ok
    end

    test "plough II needs way.plough_2.books of each colour and plough I invented", %{config: c} do
      plough_2 = Blueprint.fetch!(:plough_2)

      assert Ways.books_needed(plough_2, c) == 2

      assert Ways.missing(plough_2, books(blue: 1), [], c) ==
               [{:book, :blue, 1}, {:book, :green, 2}, {:invention, :plough}]

      assert Ways.missing(plough_2, books(blue: 2, green: 2), [], c) == [{:invention, :plough}]
      assert Ways.missing(plough_2, books(blue: 1, green: 2), [:plough], c) == [{:book, :blue, 1}]
      assert Ways.check(plough_2, books(blue: 2, green: 3), [:plough], c) == :ok

      three = EngineFixtures.config(way_books: %{plough_2: 3})

      assert Ways.missing(plough_2, books(blue: 2, green: 2), [:plough], three) ==
               [{:book, :blue, 1}, {:book, :green, 1}]
    end

    test "home places and the guildhouse are never locked", %{config: c} do
      for type <- Blueprint.home_types() ++ [:guildhouse] do
        assert Ways.missing(Blueprint.fetch!(type), Books.none(), [], c) == []
        assert Ways.check(Blueprint.fetch!(type), Books.none(), [], c) == :ok
      end
    end
  end

  describe "R16, R17: standing ways open by themselves" do
    test "each once its books are held, with the next free id, empty, in catalogue order",
         %{config: c} do
      farm = %Building{id: 1, blueprint: Blueprint.fetch!(:farm)}

      assert Ways.open([farm], Books.none(), [], c) == {[farm], []}

      assert {[^farm, %Expedition{id: 2, bag: 0, weeks: 0}], [:hunting]} =
               Ways.open([farm], books(red: 1, green: 1), [], c)

      assert {[^farm, %Trade{id: 2, traders: []}, %Expedition{id: 3}], [:grain_trade, :hunting]} =
               Ways.open([farm], books(yellow: 1, red: 1, green: 1), [], c)
    end

    test "only once", %{config: c} do
      held = books(yellow: 1, red: 1, green: 1)
      {places, _} = Ways.open([], held, [], c)

      assert Ways.open(places, held, [], c) == {places, []}
    end
  end

  defp books(held), do: Map.merge(Books.none(), Map.new(held))
end
