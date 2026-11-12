defmodule MyLiege.Engine.Rules.BooksTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Manameter, Pentagon, Place, Worker}
  alias MyLiege.Engine.Place.{Building, Project}
  alias MyLiege.Engine.Rules.Books
  alias MyLiege.EngineFixtures

  setup do
    %{config: EngineFixtures.config(book_work: 96, travel_weeks: 1)}
  end

  describe "R12: books" do
    test "a book of each colour is a project with the next id, book_work as target", context do
      %{config: config} = context

      for colour <- Pentagon.colours() do
        places = Books.new_book(Building.starting(), colour, config)

        assert [_farm, _tower, %Project{} = book] = places
        assert %Project{id: 3, target: 96_000, gives: {:book, ^colour}, progress: 0} = book
        # the method is blue, whatever the book's colour
        assert Place.colour(book) == :blue
        assert Place.good(book) == :knowledge
      end
    end

    test "several books at once, each with its own id", %{config: config} do
      places =
        Building.starting()
        |> Books.new_book(:green, config)
        |> Books.new_book(:green, config)
        |> Books.new_book(:red, config)

      assert Enum.map(places, & &1.id) == [1, 2, 3, 4, 5]
    end

    test "only the five colours" do
      assert Enum.all?(Pentagon.colours(), &Books.colour?/1)
      refute Books.colour?(:purple)
    end

    test "experience: the colour's share ÷ 200, in per mille" do
      manameter = %Manameter{green: 200, yellow: 300, blue: 100, red: 0, violet: 400}

      assert Books.experience(manameter, :green) == 1000
      assert Books.experience(manameter, :yellow) == 1500
      assert Books.experience(manameter, :blue) == 500
      assert Books.experience(manameter, :red) == 0
      assert Books.experience(manameter, :violet) == 2000
    end

    test "what is written: output × share ÷ 200, rounded down" do
      manameter = %Manameter{green: 200, yellow: 300, blue: 100, red: 101, violet: 299}

      assert Books.written(3_000, manameter, :green) == 3_000
      assert Books.written(3_000, manameter, :yellow) == 4_500
      assert Books.written(3_000, manameter, :blue) == 1_500
      # 3000 × 101 ÷ 200 = 1515; 1001 × 101 ÷ 200 = 505.5
      assert Books.written(3_000, manameter, :red) == 1_515
      assert Books.written(1_001, manameter, :red) == 505
    end

    test "finish: a done book is held, its project removed, its writer released", context do
      %{config: config} = context
      done = EngineFixtures.new_book(3, :green, progress: 96_000)
      open = EngineFixtures.new_book(4, :red, progress: 95_999)
      places = Building.starting() ++ [done, open]
      writer = %Worker{id: 1, colour: :blue, place: 3}
      other = %Worker{id: 2, colour: :red, place: 4}

      {places, workers, books, finished} =
        Books.finish(places, [writer, other], Books.none(), config)

      assert finished == [:green]
      assert books == %{green: 1, yellow: 0, blue: 0, red: 0, violet: 0}
      assert Enum.map(places, & &1.id) == [1, 2, 4]

      assert [%Worker{id: 1, place: nil, travel: 1}, %Worker{id: 2, place: 4, travel: 0}] =
               workers
    end

    test "a game starts with no books" do
      assert Books.none() == %{green: 0, yellow: 0, blue: 0, red: 0, violet: 0}
    end
  end
end
