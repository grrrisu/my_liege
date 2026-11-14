defmodule MyLiege.Engine.ForecastTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Forecast, Game}
  alias MyLiege.EngineFixtures

  defp week_1(config \\ EngineFixtures.config()) do
    {:ok, _report, game} = config |> Game.new(1) |> Game.run_week()
    game
  end

  # the game after a week whose stocks changed by `changes`, with `stocks` now
  defp after_change(game, changes, stocks \\ %{}) do
    stock_change = game.stocks |> Map.new(fn {p, _} -> {p, 0} end) |> Map.merge(changes)

    %{
      game
      | stocks: Map.merge(game.stocks, stocks),
        report: %{game.report | stock_change: stock_change}
    }
  end

  describe "the week's change" do
    test "is each stock at the end of the week minus at its start" do
      start = Game.new(EngineFixtures.config(), 1)
      {:ok, report, game} = Game.run_week(start)

      for {product, stock} <- game.stocks do
        assert report.stock_change[product] == stock - start.stocks[product]
      end
    end

    test "a project open all week: its gain; none in the week it is made" do
      start = Game.new(EngineFixtures.config(), 1)
      start = EngineFixtures.open_demand(start, :knowledge, 10_000, 8)
      {:ok, report, _game} = Game.run_week(start)

      # no one on it: no gain
      assert report.project_change == 0
      assert Game.report(start).project_change == nil

      # the farmer (worker 1) moves onto it and makes 4.5 knowledge (green on blue: opposite)
      start = %{
        start
        | workers: Enum.map(start.workers, &if(&1.id == 1, do: %{&1 | place: 3}, else: &1))
      }

      {:ok, report, _game} = Game.run_week(start)
      assert report.project_change == 1_500
    end

    test "is unknown in week 0, so there are no forecasts" do
      game = Game.new(EngineFixtures.config(), 1)

      assert game.report.stock_change == nil
      assert Forecast.food(game) == nil
      assert Forecast.gold(game) == nil
      assert Forecast.bandits(game) == nil
    end

    test "a forecast doesn't change the game" do
      game = week_1()

      for forecast <- [
            &Forecast.food/1,
            &Forecast.gold/1,
            &Forecast.next_tax/1,
            &Forecast.demand/1,
            &Forecast.bandits/1
          ] do
        forecast.(game)
      end

      assert {:ok, _report, _} = Game.run_week(game)
      assert game == week_1()
    end
  end

  describe "food" do
    test "rising: no week it runs out" do
      game = after_change(week_1(), %{food: 2_000})
      assert Forecast.food(game) == %{change: 2_000, direction: :rising, weeks_left: nil}
    end

    test "falling: the weeks until the stock goes below 0" do
      # 10 food, −3 a week: 7, 4, 1 left, below 0 in the 4th week
      game = after_change(week_1(), %{food: -3_000}, %{food: 10_000})
      assert %{direction: :falling, weeks_left: 4} = Forecast.food(game)

      game = after_change(week_1(), %{food: -3_000}, %{food: 9_000})
      assert %{weeks_left: 4} = Forecast.food(game)
    end

    test "already short of food last week: 0 weeks" do
      game = after_change(week_1(), %{food: -3_000}, %{food: 0})
      game = %{game | report: %{game.report | food_short: true}}
      assert %{weeks_left: 0} = Forecast.food(game)
    end

    test "0 food after a week that was just enough: short next week" do
      game = after_change(week_1(), %{food: -3_000}, %{food: 0})
      assert %{weeks_left: 1} = Forecast.food(game)
    end
  end

  describe "gold" do
    test "the last week's change, steady at 0" do
      assert %{change: -500, direction: :falling} =
               Forecast.gold(after_change(week_1(), %{gold: -500}))

      assert %{direction: :steady} = Forecast.gold(after_change(week_1(), %{gold: 0}))
    end
  end

  describe "next tax" do
    test "before the count: king_tax_per_worker for every current worker" do
      game = after_change(week_1(), %{gold: 2_000}, %{gold: 50_000})
      tax = Forecast.next_tax(game)

      assert tax.amount == 10_000 * length(game.workers)
      assert tax.due_week == 24
      refute tax.counted?
      # 23 weeks until and including the due week
      assert tax.expected_gold == 50_000 + 23 * 2_000
      assert tax.shortfall == 0
      assert Forecast.tax_amount(game) == tax.amount
    end

    test "after the count: the counted amount, and the shortfall" do
      game = %{after_change(week_1(), %{gold: -1_000}, %{gold: 30_000}) | tax_due: 40_000}
      tax = Forecast.next_tax(game)

      assert tax.counted?
      assert tax.amount == 40_000
      assert tax.expected_gold == 30_000 - 23 * 1_000
      assert tax.shortfall == 40_000 - 7_000
    end

    test "known in week 0, without expected gold" do
      tax = Forecast.next_tax(Game.new(EngineFixtures.config(), 1))
      assert %{due_week: 24, expected_gold: nil, shortfall: nil} = tax
    end

    test "none after the last payment of the game" do
      game = %{week_1() | week: 144}
      assert Forecast.next_tax(game) == nil
    end
  end

  describe "demand" do
    test "from the stock: the stock plus its change for every week left" do
      game = after_change(week_1(), %{food: 1_000}, %{food: 20_000})
      game = EngineFixtures.open_demand(game, :food, 25_000, 6)

      assert %{expected: 25_000, met?: true} = Forecast.demand(game)

      assert %{expected: 24_000, met?: false} =
               Forecast.demand(%{game | demand: %{game.demand | due_week: 5}})
    end

    test "a project: progress plus last week's gain, at most the amount" do
      game = EngineFixtures.open_demand(week_1(), :knowledge, 10_000, 5)
      game = with_progress(game, 2_000)
      game = %{game | report: %{game.report | project_change: 1_500}}

      assert %{expected: 8_000, met?: false} = Forecast.demand(game)

      game = %{game | report: %{game.report | project_change: 3_000}}
      assert %{expected: 10_000, met?: true} = Forecast.demand(game)
    end

    test "a project made in the last week has no forecast yet; a refused one none" do
      game = EngineFixtures.open_demand(week_1(), :knowledge, 10_000, 5)

      assert %{expected: nil, met?: nil} = Forecast.demand(game)
      assert Forecast.demand(%{game | deliver_demand: false}) == nil
    end
  end

  defp with_progress(game, progress) do
    id = game.demand.project_id

    %{
      game
      | places: Enum.map(game.places, &if(&1.id == id, do: %{&1 | progress: progress}, else: &1))
    }
  end

  describe "bandits" do
    defp with_pressure(pressure, threat, change \\ 0) do
      game = week_1(EngineFixtures.config(bandit_threshold: 10))

      %{
        game
        | bandits: %{threat: threat, raid_week: nil},
          report: %{game.report | bandit_pressure: pressure, bandit_threat_change: change}
      }
    end

    test "weeks until the threshold at the last week's pressure" do
      # 10 000 missing, +1 500 a week: 7 weeks
      assert %{weeks_to_threshold: 7, direction: :rising} =
               Forecast.bandits(with_pressure(2_500, 0, 1_500))

      assert %{weeks_to_threshold: 1} = Forecast.bandits(with_pressure(2_500, 9_000))
    end

    test "never at a pressure of 1000 or less; next week when unbounded" do
      assert %{weeks_to_threshold: :never, direction: :steady} =
               Forecast.bandits(with_pressure(1_000, 3_000))

      assert %{weeks_to_threshold: 1} = Forecast.bandits(with_pressure(:unbounded, 0))
    end

    test "none while bandits are on their way" do
      game = with_pressure(2_500, 10_000)
      assert Forecast.bandits(%{game | bandits: %{threat: 10_000, raid_week: 5}}) == nil
    end
  end
end
