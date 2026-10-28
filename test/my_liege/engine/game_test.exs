defmodule MyLiege.Engine.GameTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, Manameter, Worker}
  alias MyLiege.EngineFixtures

  describe "a new game" do
    test "starts in week 0 with the farm, the tower, their workers and starting stocks" do
      config = EngineFixtures.config()
      game = Game.new(config, 1)

      assert game.seed == 1
      assert game.week == 0
      assert Enum.map(game.buildings, & &1.type) == [:farm, :watchtower]
      assert Enum.map(game.workers, & &1.colour) == [:green, :red]
      assert game.manameter == config.starting_manameter

      assert game.stocks ==
               %{food: 24_000, gold: 100_000, knowledge: 0, defence: 0, entertainment: 0}
    end

    test "its report shows week 0 as the starting state" do
      config = EngineFixtures.config()

      assert Game.report(Game.new(config, 1)) == %{
               week: 0,
               production: %{food: 0, knowledge: 0, defence: 0, gold: 0, entertainment: 0},
               mana: %{green: 0, blue: 0, red: 0, yellow: 0, violet: 0},
               manameter: config.starting_manameter,
               food_left: 24_000,
               newborn: nil
             }
    end

    test "after a week, its report is the one run_week returned" do
      config = EngineFixtures.config()
      {report, game} = config |> Game.new(1) |> Game.run_week(config)

      assert Game.report(game) == report
    end
  end

  describe "weekly order: production, Manameter update, eating, birth" do
    setup do
      %{config: EngineFixtures.config()}
    end

    test "week 1 with the starting workers", %{config: config} do
      {report, game} = config |> Game.new(1) |> Game.run_week(config)

      assert report.week == 1
      assert report.production.food == 9_000
      assert report.production.defence == 3_000
      assert report.mana == %{green: 3, blue: 0, red: 3, yellow: 0, violet: 0}
      # exact: 799.1, 49.85, 101.2, 49.85, 0
      assert game.manameter == %Manameter{green: 799, blue: 50, red: 101, yellow: 50, violet: 0}
      # 24 + 9 produced - 2 workers × 3 eaten
      assert report.food_left == 27_000
      assert %Worker{trained: false, building: nil} = report.newborn
      assert length(game.workers) == 3
      assert game.week == 1
    end

    test "every product's stock accumulates", %{config: config} do
      game = run_weeks(Game.new(config, 1), 2, config)

      assert game.stocks.defence == 6_000
      assert game.stocks.gold == 100_000
    end

    test "a newborn eats from the following week", %{config: config} do
      game = run_weeks(Game.new(config, 1), 1, config)
      {report, _game} = Game.run_week(game, config)

      # 27 + 9 produced - 3 workers × 3 eaten; no birth in week 2
      assert report.food_left == 27_000
      assert report.newborn == nil
    end

    test "the newborn's colour is drawn from the updated Manameter" do
      config =
        EngineFixtures.config(
          birth_interval_weeks: 1,
          starting_farmers: 0,
          starting_manameter: %Manameter{green: 1000, blue: 0, red: 0, yellow: 0, violet: 0},
          manameter_points_per_week: 1000
        )

      {report, game} = config |> Game.new(1) |> Game.run_week(config)

      assert game.manameter == %Manameter{green: 0, blue: 0, red: 1000, yellow: 0, violet: 0}
      assert report.newborn.colour == :red
    end

    test "no birth in a short week" do
      config =
        EngineFixtures.config(birth_interval_weeks: 1, starting_farmers: 0, starting_food: 0)

      {report, game} = config |> Game.new(1) |> Game.run_week(config)

      assert report.food_left < 0
      assert report.newborn == nil
      assert length(game.workers) == 1
    end

    test "the same seed replays the same run", %{config: config} do
      assert run_weeks(Game.new(config, 5), 20, config) ==
               run_weeks(Game.new(config, 5), 20, config)
    end
  end

  defp run_weeks(game, count, config) do
    {_reports, game} = Enum.map_reduce(1..count, game, fn _, g -> Game.run_week(g, config) end)
    game
  end
end
