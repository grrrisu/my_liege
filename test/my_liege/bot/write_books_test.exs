defmodule MyLiege.Bot.WriteBooksTest do
  use ExUnit.Case, async: true

  alias MyLiege.Bot.BotActions.{DemandProject, WriteBooks}
  alias MyLiege.Bot.Placing
  alias MyLiege.Engine.Place.Project
  alias MyLiege.Engine.Worker
  alias MyLiege.EngineFixtures

  # a new game without demands (farm 1 with the farmer, watchtower 2 with the soldier), with
  # `workers` added
  defp game(workers \\ []) do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
    %{game | workers: game.workers ++ workers}
  end

  defp write(game, colours),
    do: WriteBooks.run(game, colours: colours, from_week: 0, build: :always)

  defp books(game),
    do: for(%Project{gives: {:book, colour}} = b <- game.places, do: {colour, b.id})

  defp place_of(game, id), do: Enum.find(game.workers, &(&1.id == id)).place

  test "starts nothing before from_week" do
    game = game([%Worker{id: 3, colour: :blue}])

    assert WriteBooks.run(game, colours: [:red], from_week: 1, build: :always) == game
  end

  test "with no colours it does nothing" do
    game = game([%Worker{id: 3, colour: :blue}])

    assert write(game, []) == game
  end

  test "starts one book per listed colour with none held and none in progress" do
    game = write(game(), [:red, :green])

    assert [red: _, green: _] = books(game)
    assert books(write(game, [:red, :green])) == books(game)

    held = %{game() | books: %{game().books | red: 1}}
    assert [green: _] = books(write(held, [:red, :green]))
  end

  test "an unplaced, arrived blue worker writes, even after another one in worker order" do
    game = write(game([%Worker{id: 3, colour: :green}, %Worker{id: 4, colour: :blue}]), [:red])
    [red: book_id] = books(game)

    assert place_of(game, 4) == book_id
    assert place_of(game, 3) == nil
  end

  test "else a worker from a monastery, blue ones first; unplaced others are left alone" do
    game = EngineFixtures.add_building(game(), :monastery)
    monastery = List.last(game.places)

    game = %{
      game
      | workers:
          game.workers ++
            [
              %Worker{id: 3, colour: :violet, place: monastery.id},
              %Worker{id: 4, colour: :blue, place: monastery.id},
              %Worker{id: 5, colour: :green}
            ]
    }

    game = write(game, [:red])
    [red: book_id] = books(game)

    assert Enum.map(3..5, &place_of(game, &1)) == [monastery.id, book_id, nil]
  end

  test "a worker of any colour from a monastery when no blue one is there" do
    game = EngineFixtures.add_building(game(), :monastery)
    monastery = List.last(game.places)

    game = %{
      game
      | workers: game.workers ++ [%Worker{id: 3, colour: :violet, place: monastery.id}]
    }

    game = write(game, [:red])

    assert [red: book_id] = books(game)
    assert place_of(game, 3) == book_id
  end

  test "else any unplaced, arrived worker; not one still travelling" do
    game =
      write(game([%Worker{id: 3, colour: :green, travel: 1}, %Worker{id: 4, colour: :yellow}]), [
        :red
      ])

    [red: book_id] = books(game)

    assert place_of(game, 3) == nil
    assert place_of(game, 4) == book_id
  end

  test "one writer per book" do
    workers = for id <- 3..5, do: %Worker{id: id, colour: :blue}
    game = write(game(workers), [:red, :green])
    [red: red_id, green: green_id] = books(game)

    assert Enum.map(3..5, &place_of(game, &1)) == [red_id, green_id, nil]
  end

  test "only workers the earlier actions leave alone count" do
    # DemandProject takes the blue worker for the knowledge project: the green one writes
    game =
      game([%Worker{id: 3, colour: :blue}, %Worker{id: 4, colour: :green}])
      |> EngineFixtures.open_demand(:knowledge, 10_000, 8)

    project_id = EngineFixtures.demand_project(game).id
    rules = [{DemandProject, []}, {WriteBooks, colours: [:red], from_week: 0}]

    game = Placing.run(game, rules: rules, build: :always)
    [red: book_id] = books(game)

    assert place_of(game, 3) == project_id
    assert place_of(game, 4) == book_id
  end
end
