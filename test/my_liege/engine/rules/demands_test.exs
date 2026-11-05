defmodule MyLiege.Engine.Rules.DemandsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, Manameter, Random}
  alias MyLiege.Engine.Rules.Demands
  alias MyLiege.EngineFixtures

  setup do
    %{config: EngineFixtures.config()}
  end

  describe "R7: the king's demands" do
    test "one week per half year, leaving room for the deadline", %{config: config} do
      {weeks, _rand} = Demands.schedule(48, config, 7 |> Random.new() |> elem(1))

      assert length(weeks) == 6

      for {week, h} <- Enum.with_index(weeks) do
        assert week in (h * 24 + 1)..(h * 24 + 24 - config.demand_deadline_weeks)
      end
    end

    test "the same seed draws the same weeks", %{config: config} do
      rand = 3 |> Random.new() |> elem(1)
      assert Demands.schedule(48, config, rand) == Demands.schedule(48, config, rand)
    end

    test "colour by year: biggest share, then middle, then smallest; ties in pentagon order" do
      manameter = %Manameter{green: 400, blue: 100, red: 200, yellow: 100, violet: 200}

      assert Demands.colour(manameter, 1) == :green
      # red and violet tie at 200: red comes first in pentagon order
      assert Demands.colour(manameter, 2) == :violet
      assert Demands.colour(manameter, 3) == :yellow
    end

    test "amount: population × share × base production × production weeks", %{config: config} do
      manameter = %Manameter{green: 400, blue: 100, red: 300, yellow: 100, violet: 100}

      # week 30 is in year 1: green, food; 12 workers × 10% × 9 wheat × 8 weeks = 86.4
      assert Demands.make(30, 48, manameter, 12, config) ==
               %{product: :food, amount: 86_400, due_week: 38}
    end

    test "no demand when the amount would be 0", %{config: config} do
      manameter = %Manameter{green: 400, blue: 100, red: 300, yellow: 100, violet: 100}

      assert Demands.make(30, 48, manameter, 0, config) == nil
    end

    test "delivered, refused, or missed when the stock is short" do
      demand = %{product: :food, amount: 10_000, due_week: 38}
      stocks = %{food: 15_000}

      assert Demands.settle(demand, stocks, true) == {:delivered, %{food: 5_000}}
      assert Demands.settle(demand, stocks, false) == {:refused, stocks}
      assert Demands.settle(demand, %{food: 5_000}, true) == {:missed, %{food: 5_000}}
    end
  end

  describe "R7: demands in the week" do
    setup do
      # plenty of food, so the first demand (year 1: green, food) is not 0
      config = EngineFixtures.config(starting_food: 1000)
      game = Game.new(config, 1)
      [first | _] = game.demand_weeks
      {reports, game} = EngineFixtures.run_weeks(game, first)
      %{config: config, game: game, demand: List.last(reports).demand, made: List.last(reports)}
    end

    test "announced at the end of its week, for the leading colour's product", context do
      %{game: game, demand: demand, made: made} = context

      assert %{product: :food} = demand
      assert game.demand == demand
      assert demand.due_week == game.week + 8
      # counted at the start of the week, so this week's newborn is not included
      population = length(game.workers) - if(made.newborn, do: 1, else: 0)
      assert demand.amount == population * 7_200
    end

    test "the deadline week waits for the player's decision", %{game: game} do
      {_reports, game} = EngineFixtures.run_weeks(game, 7)

      assert Game.demand_decision_due?(game)
      assert Game.run_week(game) == {:error, :demand_undecided}
    end

    test "delivering takes the amount from the stock", %{game: game} do
      {reports, game} = EngineFixtures.run_weeks(game, 8)

      assert List.last(reports).demand_outcome == :delivered
      assert game.demand == nil
      assert game.misses == 0
    end

    test "a refusal counts as a miss", %{game: game} do
      {_reports, game} = EngineFixtures.run_weeks(game, 7)
      {:ok, game} = Game.decide_demand(game, false)
      {:ok, report, game} = Game.run_week(game)

      assert report.demand_outcome == :refused
      assert game.misses == 1
    end

    test "no decision outside the week before a deadline", %{game: game} do
      assert Game.decide_demand(game, true) == {:error, :no_demand_due}
    end
  end
end
