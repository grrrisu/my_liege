defmodule MyLiege.Bot.PlacingTest do
  use ExUnit.Case, async: true

  alias MyLiege.Bot.BotActions.{DemandProject, Feed, PayAndDeliver, PlaceOwn, StaffSites}
  alias MyLiege.Bot.Placing
  alias MyLiege.Engine.{Game, Worker}
  alias MyLiege.Engine.Place.Project
  alias MyLiege.EngineFixtures

  # a new game (farm 1 with the farmer, watchtower 2 with the soldier) with two unplaced
  # workers: 3 green (home: farm), 4 red (home: watchtower)
  defp game(config \\ EngineFixtures.config()) do
    game = Game.new(config, 1)

    %{
      game
      | workers: game.workers ++ [%Worker{id: 3, colour: :green}, %Worker{id: 4, colour: :red}]
    }
  end

  defp hungry(game), do: %{game | report: %{game.report | food_short: true}}

  defp places(game), do: Enum.map(game.workers, & &1.place)

  test "group/1 merges consecutive placing actions into one pass" do
    actions =
      for action <- [StaffSites, Feed, PlaceOwn, PayAndDeliver], do: {action, build: :always}

    assert Placing.group(actions) == [
             {StaffSites, build: :always},
             {Placing,
              rules: [{Feed, build: :always}, {PlaceOwn, build: :always}], build: :always},
             {PayAndDeliver, build: :always}
           ]
  end

  describe "run/2" do
    test "the first rule that names a type gets the worker" do
      rules = [{Feed, []}, {PlaceOwn, []}]

      assert game() |> Placing.run(rules: rules, build: :always) |> places() == [1, 2, 1, 2]

      assert game() |> hungry() |> Placing.run(rules: rules, build: :always) |> places() == [
               1,
               2,
               1,
               1
             ]
    end

    test "a worker without room waits for its type; a later rule doesn't take it" do
      config = EngineFixtures.config()
      config = %{config | place_capacity: %{config.place_capacity | farm: 1}}

      game =
        config
        |> game()
        |> hungry()
        |> Placing.run(rules: [{Feed, []}, {PlaceOwn, []}], build: :always)

      # worker 3 waits and a farm site is ordered; worker 4 joins it as a builder instead of
      # going to its own watchtower
      assert [%Project{id: 3, gives: {:building, :farm}}] =
               Enum.filter(game.places, &match?(%Project{}, &1))

      assert places(game) == [1, 2, nil, 3]
    end

    test "a {:place, id} target places the worker on that place; type targets as before" do
      game =
        %{game() | workers: game().workers ++ [%Worker{id: 5, colour: :violet}]}
        |> EngineFixtures.open_demand(:culture, 10_000, 8)

      project_id = EngineFixtures.demand_project(game).id

      placed =
        Placing.run(game, rules: [{DemandProject, []}, {PlaceOwn, []}], build: :always)

      assert places(placed) == [1, 2, 1, 2, project_id]
    end

    test "orders no building when the build condition doesn't allow it" do
      config = EngineFixtures.config(start_gold: 50)
      config = %{config | place_capacity: %{config.place_capacity | farm: 1}}
      # 50 gold minus the price of 30 leaves less than the next tax of 4 × 10
      game = config |> game() |> hungry()

      waited = Placing.run(game, rules: [{Feed, []}], build: :tax_safe)

      assert waited.places == game.places
      refute Placing.run(game, rules: [{Feed, []}], build: :always).places == game.places
    end
  end
end
