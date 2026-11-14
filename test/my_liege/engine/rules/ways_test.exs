defmodule MyLiege.Engine.Rules.WaysTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place.{Blueprint, Building, Expedition, Trade}
  alias MyLiege.Engine.Rules.{Books, Ways}

  describe "R13: one unlock rule for every way" do
    test "a way needs a book of its colour and one of its good's home colour" do
      granary = Blueprint.fetch!(:granary)

      assert Ways.missing(granary, Books.none()) == [:violet, :green]
      assert Ways.missing(granary, books(violet: 1)) == [:green]
      assert Ways.missing(granary, books(green: 1)) == [:violet]
      assert Ways.missing(granary, books(violet: 1, green: 3)) == []
      assert Ways.unlocked?(granary, books(violet: 1, green: 1))
      refute Ways.unlocked?(granary, books(violet: 5, blue: 5))
    end

    test "the improved plough needs a blue and a green book" do
      plough = Blueprint.fetch!(:plough)

      assert Ways.missing(plough, Books.none()) == [:blue, :green]
      assert Ways.check(plough, books(blue: 1)) == {:error, :locked}
      assert Ways.check(plough, books(blue: 1, green: 1)) == :ok
    end

    test "home places and the guildhouse are never locked" do
      for type <- Blueprint.home_types() ++ [:guildhouse] do
        assert Ways.missing(Blueprint.fetch!(type), Books.none()) == []
        assert Ways.check(Blueprint.fetch!(type), Books.none()) == :ok
      end
    end
  end

  describe "R16, R17: standing ways open by themselves" do
    test "each once its books are held, with the next free id, empty, in catalogue order" do
      farm = %Building{id: 1, blueprint: Blueprint.fetch!(:farm)}

      assert Ways.open([farm], Books.none()) == {[farm], []}

      assert {[^farm, %Expedition{id: 2, bag: 0, weeks: 0}], [:hunting]} =
               Ways.open([farm], books(red: 1, green: 1))

      assert {[^farm, %Trade{id: 2, traders: []}, %Expedition{id: 3}], [:grain_trade, :hunting]} =
               Ways.open([farm], books(yellow: 1, red: 1, green: 1))
    end

    test "only once" do
      {places, _} = Ways.open([], books(yellow: 1, red: 1, green: 1))

      assert Ways.open(places, books(yellow: 1, red: 1, green: 1)) == {places, []}
    end
  end

  defp books(held), do: Map.merge(Books.none(), Map.new(held))
end
