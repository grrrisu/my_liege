defmodule MyLiege.Engine.Rules.DemandsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Building, Game, Manameter, Random, Worker}
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
               %{product: :food, amount: 86_400, due_week: 38, progress: nil}
    end

    test "no demand when the amount would be 0", %{config: config} do
      manameter = %Manameter{green: 400, blue: 100, red: 300, yellow: 100, violet: 100}

      assert Demands.make(30, 48, manameter, 0, config) == nil
    end

    test "knowledge and entertainment demands are projects starting at 0", %{config: config} do
      manameter = %Manameter{green: 100, blue: 400, red: 300, yellow: 100, violet: 100}

      # year 1: blue, knowledge; 12 workers × 10% × 3 × 8 weeks = 28.8
      assert Demands.make(30, 48, manameter, 12, config) ==
               %{product: :knowledge, amount: 28_800, due_week: 38, progress: 0}

      assert Demands.project?(%{product: :knowledge, progress: 0})
      refute Demands.project?(%{product: :food, progress: nil})
      refute Demands.project?(nil)
    end

    test "a project takes the production it still lacks; the rest is left for the stock" do
      project = %{product: :knowledge, amount: 7_000, due_week: 9, progress: 6_000}
      production = %{food: 9_000, knowledge: 3_000}

      assert Demands.feed(project, production) ==
               {%{project | progress: 7_000}, %{food: 9_000, knowledge: 2_000}}

      assert Demands.feed(%{project | progress: 7_000}, production) ==
               {%{project | progress: 7_000}, production}
    end

    test "a project is delivered only if it reached its amount, and never uses the stock" do
      project = %{product: :knowledge, amount: 7_000, due_week: 9, progress: 7_000}
      stocks = %{knowledge: 50_000}

      assert Demands.settle(project, stocks, true) == {:delivered, stocks}
      assert Demands.settle(%{project | progress: 6_999}, stocks, true) == {:missed, stocks}
      assert Demands.settle(project, stocks, false) == {:refused, stocks}
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

  describe "R7: projects in the week" do
    # a blue worker in a monastery makes 3 knowledge a week; no other demand
    setup do
      game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
      monastery = %Building{id: 3, type: :monastery}
      monk = %Worker{id: 3, colour: :blue, building: 3}
      %{game: %{game | buildings: game.buildings ++ [monastery], workers: game.workers ++ [monk]}}
    end

    test "production goes into the project until the amount, then to the stock", %{game: game} do
      game = with_project(game, 7_000)
      {reports, game} = EngineFixtures.run_weeks(game, 3)

      assert Enum.map(reports, & &1.demand_progress) == [3_000, 6_000, 7_000]
      assert Enum.map(reports, & &1.production.knowledge) == [3_000, 3_000, 3_000]
      assert List.last(reports).demand_outcome == :delivered
      assert game.stocks.knowledge == 2_000
      assert game.misses == 0
      assert game.demand == nil
    end

    test "short of the amount at the deadline it is missed; the stock is not used", context do
      game = %{
        with_project(context.game, 10_000)
        | stocks: %{context.game.stocks | knowledge: 50_000}
      }

      {reports, game} = EngineFixtures.run_weeks(game, 3)

      assert List.last(reports).demand_progress == 9_000
      assert List.last(reports).demand_outcome == :missed
      assert game.stocks.knowledge == 50_000
      assert game.misses == 1
    end

    test "the deadline doesn't wait for a decision", %{game: game} do
      {_reports, game} = EngineFixtures.run_weeks(with_project(game, 7_000), 2)

      refute Game.demand_decision_due?(game)
      assert {:ok, %{demand_outcome: :delivered}, _game} = Game.run_week(game)
    end

    test "mana is produced as usual", %{game: game} do
      {:ok, with_project, _game} = Game.run_week(with_project(game, 7_000))
      {:ok, without, _game} = Game.run_week(game)

      assert with_project.mana == without.mana
      assert with_project.mana.blue > 0
    end

    test "refused at any time: the next week's production goes to the stock and the miss counts",
         %{game: game} do
      {:ok, game} = game |> with_project(7_000) |> Game.refuse_project()

      assert Game.refuse_project(game) == {:error, :no_project}
      {:ok, report, game} = Game.run_week(game)

      assert report.demand_outcome == :refused
      assert report.demand_progress == nil
      assert game.stocks.knowledge == 3_000
      assert game.misses == 1
      assert game.demand == nil
    end

    test "only a project can be refused early", %{game: game} do
      food = %{product: :food, amount: 1_000, due_week: 3, progress: nil}

      assert Game.refuse_project(%{game | demand: food}) == {:error, :no_project}
      assert Game.refuse_project(game) == {:error, :no_project}
    end

    defp with_project(game, amount),
      do: %{game | demand: %{product: :knowledge, amount: amount, due_week: 3, progress: 0}}
  end
end
