defmodule MyLiege.Bot.DemandProjectTest do
  use ExUnit.Case, async: true

  alias MyLiege.Bot.BotActions.DemandProject
  alias MyLiege.Engine.{Place, Worker}
  alias MyLiege.EngineFixtures

  # a new game (farm 1 with the farmer, watchtower 2 with the soldier) with `workers` added
  defp game(workers) do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
    %{game | workers: game.workers ++ workers}
  end

  # the same with an open culture demand; returns the game and the project's id
  defp with_culture_project(workers) do
    game = workers |> game() |> EngineFixtures.open_demand(:culture, 10_000, 8)
    {game, EngineFixtures.demand_project(game).id}
  end

  defp place_of(game, id), do: Enum.find(game.workers, &(&1.id == id)).place

  test "an unplaced, arrived violet worker goes to an open culture project; a green one doesn't" do
    violet = %Worker{id: 3, colour: :violet}
    green = %Worker{id: 4, colour: :green}
    {game, project_id} = with_culture_project([violet, green])

    assert DemandProject.target(violet, game, []) == {:place, project_id}
    assert DemandProject.target(green, game, []) == nil

    game = DemandProject.run(game, build: :always)

    assert place_of(game, 3) == project_id
    assert place_of(game, 4) == nil
  end

  test "a travelling violet worker is not placed" do
    {game, _project_id} = with_culture_project([%Worker{id: 3, colour: :violet, travel: 1}])

    assert DemandProject.run(game, build: :always) == game
  end

  # a culture project of `amount` due in week 8, with a finished tavern and `in_tavern`
  # violet workers in it (ids from 3); returns the game, the project's and the tavern's id
  defp taverns(in_tavern, amount, config \\ EngineFixtures.config()) do
    game =
      config |> EngineFixtures.game_without_demands(1) |> EngineFixtures.add_building(:tavern)

    tavern = List.last(game.places)

    workers =
      for id <- 3..(2 + in_tavern)//1, do: %Worker{id: id, colour: :violet, place: tavern.id}

    game =
      %{game | workers: game.workers ++ workers}
      |> EngineFixtures.open_demand(:culture, amount, 8)

    {game, EngineFixtures.demand_project(game).id, tavern.id}
  end

  test "a violet worker in a tavern moves to the project while it is short" do
    # a violet worker makes 3 culture a week in weeks 1 to 8: 24 cover 10
    {game, project_id, _tavern_id} = taverns(1, 10_000)

    assert place_of(DemandProject.run(game, build: :always), 3) == project_id
  end

  test "moves only as many workers from buildings as needed" do
    # 1 worker makes 24 by week 8, 2 make 48: 30 need 2 of the 3
    {game, project_id, tavern_id} = taverns(3, 30_000)
    game = DemandProject.run(game, build: :always)

    assert Enum.map(3..5, &place_of(game, &1)) == [project_id, project_id, tavern_id]
  end

  test "unplaced workers go first; then nobody moves from a building if they cover the need" do
    {game, project_id, tavern_id} = taverns(1, 10_000)
    game = %{game | workers: game.workers ++ [%Worker{id: 4, colour: :violet}]}
    game = DemandProject.run(game, build: :always)

    assert place_of(game, 4) == project_id
    assert place_of(game, 3) == tavern_id
  end

  test "takes nobody from a watchtower, the guildhouse or a site, nor a travelling worker" do
    {game, _project_id, tavern_id} = taverns(0, 10_000)
    game = EngineFixtures.add_building(game, :guildhouse)
    guildhouse = List.last(game.places)
    site = EngineFixtures.new_site(Place.next_id(game.places), :tavern)

    workers = [
      %Worker{id: 3, colour: :violet, place: 2},
      %Worker{id: 4, colour: :violet, place: guildhouse.id},
      %Worker{id: 5, colour: :violet, place: site.id},
      %Worker{id: 6, colour: :violet, place: tavern_id, travel: 1}
    ]

    game = %{game | places: game.places ++ [site], workers: game.workers ++ workers}

    assert DemandProject.run(game, build: :always) == game
  end

  test "moves nobody who couldn't work on the project before the due week" do
    # moved now, a worker works from week 1 + 8 = 9, after the due week 8
    {game, _project_id, _tavern_id} = taverns(1, 10_000, EngineFixtures.config(travel_weeks: 8))

    assert DemandProject.run(game, build: :always) == game
  end

  test "with no open demand project it changes nothing" do
    game = game([%Worker{id: 3, colour: :violet}, %Worker{id: 4, colour: :blue}])

    assert DemandProject.target(%Worker{id: 3, colour: :violet}, game, []) == nil
    assert DemandProject.run(game, build: :always) == game
  end

  test "several unplaced violet workers all go to the project" do
    violets = for id <- 3..9, do: %Worker{id: id, colour: :violet}
    {game, project_id} = with_culture_project(violets)

    game = DemandProject.run(game, build: :always)

    for id <- 3..9, do: assert(place_of(game, id) == project_id)
  end
end
