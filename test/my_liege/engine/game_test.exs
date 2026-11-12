defmodule MyLiege.Engine.GameTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, Manameter, SimSteps, WeeklyReport, Worker}
  alias MyLiege.EngineFixtures

  describe "a new game" do
    test "starts in week 0 with the farm, the tower, their workers and starting stocks" do
      config = EngineFixtures.config()
      game = Game.new(config, 1)

      assert game.seed == 1
      assert game.week == 0
      assert Enum.map(game.buildings, & &1.type) == [:farm, :watchtower]
      assert Enum.map(game.workers, & &1.colour) == [:green, :red]
      assert game.manameter == config.manameter_start

      assert game.stocks ==
               %{food: 24_000, gold: 100_000, knowledge: 0, defence: 0, culture: 0}
    end

    test "its report shows week 0 as the starting state" do
      config = EngineFixtures.config()

      assert Game.report(Game.new(config, 1)) == %WeeklyReport{
               week: 0,
               production: %{food: 0, knowledge: 0, defence: 0, gold: 0, culture: 0},
               mana: %{green: 0, blue: 0, red: 0, yellow: 0, violet: 0},
               manameter: config.manameter_start,
               food_left: 24_000,
               newborn: nil,
               trained: [],
               builders: 0,
               travelling: 0,
               gold: 100_000,
               tax_due: nil,
               tax: nil,
               demand: nil,
               demand_outcome: nil,
               spoiled: %{food: 0, knowledge: 0, defence: 0, gold: 0, culture: 0},
               gold_spent_buildings: 0,
               bandit_threat: 0,
               game_over: false
             }
    end

    test "after a week, its report is the one run_week returned" do
      config = EngineFixtures.config()
      {:ok, report, game} = config |> Game.new(1) |> Game.run_week()

      assert Game.report(game) == report
    end

    test "no report keeps the start of its week" do
      game = Game.new(EngineFixtures.config(), 1)
      {:ok, report, _game} = Game.run_week(game)

      assert Game.report(game).start == nil
      assert report.start == nil
    end
  end

  describe "pipeline" do
    test "runs the steps in the weekly order" do
      assert Game.pipeline() == [
               SimSteps.TaxCount,
               SimSteps.Production,
               SimSteps.Mana,
               SimSteps.Travel,
               SimSteps.ManameterUpdate,
               SimSteps.Eating,
               SimSteps.Birth,
               SimSteps.Construction,
               SimSteps.TrainingEnd,
               SimSteps.TaxPayment,
               SimSteps.DemandDelivery,
               SimSteps.DemandMade,
               SimSteps.Bandits,
               SimSteps.Spoilage,
               SimSteps.EndOfWeek
             ]
    end

    test "every step implements SimStep" do
      for step <- Game.pipeline() do
        assert Code.ensure_loaded?(step)
        assert function_exported?(step, :run, 2)
        behaviours = step.module_info(:attributes) |> Keyword.get_values(:behaviour)
        assert MyLiege.Engine.SimStep in List.flatten(behaviours)
      end
    end
  end

  describe "weekly order: production, Manameter update, eating, birth" do
    setup do
      %{config: EngineFixtures.config()}
    end

    test "week 1 with the starting workers", %{config: config} do
      {:ok, report, game} = config |> Game.new(1) |> Game.run_week()

      assert report.week == 1
      assert report.production.food == 9_000
      assert report.production.defence == 3_000
      assert report.mana == %{green: 3, blue: 0, red: 3, yellow: 0, violet: 0}
      # exact: 799.1, 49.85, 101.2, 49.85, 0
      assert game.manameter == %Manameter{green: 799, blue: 50, red: 101, yellow: 50, violet: 0}
      # 24 + 9 produced - 2 workers × 3 eaten
      assert report.food_left == 27_000
      assert %Worker{id: 3, trained: false, building: nil} = report.newborn
      assert Enum.map(game.workers, & &1.id) == [1, 2, 3]
      assert game.week == 1
    end

    test "every product's stock accumulates", %{config: config} do
      game = run_weeks(Game.new(config, 1), 2)

      assert game.stocks.defence == 6_000
      assert game.stocks.gold == 100_000
    end

    test "a newborn eats from the following week", %{config: config} do
      game = run_weeks(Game.new(config, 1), 1)
      {:ok, report, _game} = Game.run_week(game)

      # 27 + 9 produced - 3 workers × 3 eaten; no birth in week 2
      assert report.food_left == 27_000
      assert report.newborn == nil
    end

    test "the newborn's colour is drawn from the updated Manameter" do
      config =
        EngineFixtures.config(
          birth_interval_weeks: 1,
          start_farmers: 0,
          manameter_start: %Manameter{green: 1000, blue: 0, red: 0, yellow: 0, violet: 0},
          manameter_points_per_week: 1000
        )

      {:ok, report, game} = config |> Game.new(1) |> Game.run_week()

      assert game.manameter == %Manameter{green: 0, blue: 0, red: 1000, yellow: 0, violet: 0}
      assert report.newborn.colour == :red
    end

    test "no birth in a short week" do
      config =
        EngineFixtures.config(birth_interval_weeks: 1, start_farmers: 0, start_food: 0)

      {:ok, report, game} = config |> Game.new(1) |> Game.run_week()

      assert report.food_left < 0
      assert report.newborn == nil
      assert length(game.workers) == 1
    end

    test "the same seed replays the same run", %{config: config} do
      assert run_weeks(Game.new(config, 5), 20) ==
               run_weeks(Game.new(config, 5), 20)
    end
  end

  describe "building price" do
    test "every building costs build_cost_gold; the stock must cover it" do
      game = Game.new(EngineFixtures.config(), 1)

      assert Game.build_cost(game) == 30_000
      assert Game.can_afford_building?(%{game | stocks: %{game.stocks | gold: 30_000}})
      refute Game.can_afford_building?(%{game | stocks: %{game.stocks | gold: 29_999}})
    end
  end

  describe "end of the game" do
    test "the last week is the end of year game_years" do
      assert Game.last_week(Game.new(EngineFixtures.config())) == 144
      assert Game.last_week(Game.new(EngineFixtures.config(game_years: 1))) == 48
    end

    test "the game keeps the config it was created with" do
      # enough gold and food to pay every tax and deliver every demand
      config = EngineFixtures.config(start_gold: 1000, start_food: 10_000)
      game = Game.new(%{config | game_years: 1}, 1)

      assert Game.last_week(game) == 48

      game = run_weeks(game, 48)

      assert game.week == 48
      assert Game.run_week(game) == {:error, :finished}
    end

    test "reaching the last week without game over wins; no week runs after it" do
      config = EngineFixtures.config(game_years: 1, start_gold: 1000)
      game = run_weeks(EngineFixtures.game_without_demands(config, 1), 48)

      assert Game.won?(game)
      assert Game.run_week(game) == {:error, :finished}
    end

    test "not won before the last week" do
      config = EngineFixtures.config(game_years: 1, start_gold: 1000)
      game = run_weeks(EngineFixtures.game_without_demands(config, 1), 47)

      refute Game.won?(game)
    end

    test "game over in the last week is not a win" do
      config = EngineFixtures.config(game_years: 1, start_gold: 0)
      game = run_weeks(EngineFixtures.game_without_demands(config, 1), 48)

      assert game.game_over
      refute Game.won?(game)
    end
  end

  defp run_weeks(game, count) do
    game |> EngineFixtures.run_weeks(count) |> elem(1)
  end
end
