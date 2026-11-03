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
               newborn: nil,
               trained: [],
               gold: 100_000,
               tax_due: nil,
               tax: nil,
               demand: nil,
               demand_outcome: nil,
               spoiled: %{food: 0, knowledge: 0, defence: 0, gold: 0, entertainment: 0},
               game_over: false
             }
    end

    test "after a week, its report is the one run_week returned" do
      config = EngineFixtures.config()
      {:ok, report, game} = config |> Game.new(1) |> Game.run_week(config)

      assert Game.report(game) == report
    end
  end

  describe "weekly order: production, Manameter update, eating, birth" do
    setup do
      %{config: EngineFixtures.config()}
    end

    test "week 1 with the starting workers", %{config: config} do
      {:ok, report, game} = config |> Game.new(1) |> Game.run_week(config)

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
      {:ok, report, _game} = Game.run_week(game, config)

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

      {:ok, report, game} = config |> Game.new(1) |> Game.run_week(config)

      assert game.manameter == %Manameter{green: 0, blue: 0, red: 1000, yellow: 0, violet: 0}
      assert report.newborn.colour == :red
    end

    test "no birth in a short week" do
      config =
        EngineFixtures.config(birth_interval_weeks: 1, starting_farmers: 0, starting_food: 0)

      {:ok, report, game} = config |> Game.new(1) |> Game.run_week(config)

      assert report.food_left < 0
      assert report.newborn == nil
      assert length(game.workers) == 1
    end

    test "the same seed replays the same run", %{config: config} do
      assert run_weeks(Game.new(config, 5), 20, config) ==
               run_weeks(Game.new(config, 5), 20, config)
    end
  end

  describe "end of the game" do
    test "the last week is the end of year years_per_game" do
      assert Game.last_week(EngineFixtures.config()) == 144
      assert Game.last_week(EngineFixtures.config(years_per_game: 1)) == 48
    end

    test "reaching the last week without game over wins; no week runs after it" do
      config = EngineFixtures.config(years_per_game: 1, starting_gold: 1000)
      game = run_weeks(EngineFixtures.game_without_demands(config, 1), 48, config)

      assert Game.won?(game, config)
      assert Game.run_week(game, config) == {:error, :finished}
    end

    test "not won before the last week" do
      config = EngineFixtures.config(years_per_game: 1, starting_gold: 1000)
      game = run_weeks(EngineFixtures.game_without_demands(config, 1), 47, config)

      refute Game.won?(game, config)
    end

    test "game over in the last week is not a win" do
      config = EngineFixtures.config(years_per_game: 1, starting_gold: 0)
      game = run_weeks(EngineFixtures.game_without_demands(config, 1), 48, config)

      assert game.game_over
      refute Game.won?(game, config)
    end
  end

  defp run_weeks(game, count, config) do
    game |> EngineFixtures.run_weeks(count, config) |> elem(1)
  end
end
