defmodule MyLiege.Engine.Rules.WaysTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Place.Blueprint
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

  defp books(held), do: Map.merge(Books.none(), Map.new(held))
end
