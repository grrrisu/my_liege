defmodule MyLiege.Engine.Rules.DemandsTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, Manameter, Place, Random, Worker}
  alias MyLiege.Engine.Place.{Building, Project}
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
        assert week in (h * 24 + 1)..(h * 24 + 24 - config.king_demand_deadline_weeks)
      end
    end

    test "grace period: no draw for a half year inside it", %{config: config} do
      rand = 7 |> Random.new() |> elem(1)
      {weeks, _rand} = Demands.schedule(48, %{config | king_grace_weeks: 24}, rand)

      assert length(weeks) == 5

      for {week, h} <- Enum.with_index(weeks, 1) do
        assert week in (h * 24 + 1)..(h * 24 + 24 - config.king_demand_deadline_weeks)
      end
    end

    test "grace period: a half year partly inside it draws from the weeks after it",
         %{config: config} do
      for seed <- 1..20 do
        rand = seed |> Random.new() |> elem(1)
        {[first | _], _rand} = Demands.schedule(48, %{config | king_grace_weeks: 30}, rand)
        assert first in 31..40
      end
    end

    test "grace period: a half year without room for the deadline after it has no demand",
         %{config: config} do
      rand = 7 |> Random.new() |> elem(1)
      {[first | _] = weeks, _rand} = Demands.schedule(48, %{config | king_grace_weeks: 41}, rand)

      assert length(weeks) == 4
      assert first in 49..64
    end

    test "the same seed draws the same weeks", %{config: config} do
      rand = 3 |> Random.new() |> elem(1)
      assert Demands.schedule(48, config, rand) == Demands.schedule(48, config, rand)
    end

    test "colour by year: biggest share, then middle, then smallest; ties in pentagon order" do
      manameter = %Manameter{green: 400, blue: 100, red: 200, yellow: 100, violet: 200}

      assert Demands.colour(manameter, 1) == :green
      # red and violet tie at 200: red comes first in pentagon order, so violet is 3rd
      assert Demands.colour(manameter, 2) == :violet
      # yellow and blue tie at 100: yellow comes first in pentagon order, so blue is last
      assert Demands.colour(manameter, 3) == :blue
    end

    test "amount: population × share × base production × production weeks", %{config: config} do
      manameter = %Manameter{green: 400, blue: 100, red: 300, yellow: 100, violet: 100}

      # week 30 is in year 1: green, food; 12 workers × 10% × 9 wheat × 8 weeks = 86.4
      assert Demands.make(30, 48, manameter, 12, config) ==
               %{product: :food, amount: 86_400, due_week: 38, project_id: nil}
    end

    test "no demand when the amount would be 0", %{config: config} do
      manameter = %Manameter{green: 400, blue: 100, red: 300, yellow: 100, violet: 100}

      assert Demands.make(30, 48, manameter, 0, config) == nil
    end

    test "a knowledge demand is made like any other; its project is opened next", context do
      manameter = %Manameter{green: 100, blue: 400, red: 300, yellow: 100, violet: 100}

      # year 1: blue, knowledge; 12 workers × 10% × 3 × 8 weeks = 28.8
      assert Demands.make(30, 48, manameter, 12, context.config) ==
               %{product: :knowledge, amount: 28_800, due_week: 38, project_id: nil}
    end

    test "open_project: knowledge and culture demands get a project among the places" do
      places = Building.starting()

      for {product, colour} <- [knowledge: :blue, culture: :violet] do
        demand = %{product: product, amount: 28_800, due_week: 38, project_id: nil}
        {opened, demand} = Demands.open_project(places, demand)

        assert demand.project_id == 3
        assert [_farm, _tower, %Project{} = project] = opened
        assert %Project{id: 3, target: 28_800, gives: {:demand, 38}, progress: 0} = project
        assert Place.colour(project) == colour
        assert Place.good(project) == product
        assert Demands.project?(demand)
        assert Demands.project(demand, opened) == project
      end
    end

    test "open_project: food, gold and defence demands stay as they are" do
      places = Building.starting()

      for product <- [:food, :gold, :defence] do
        demand = %{product: product, amount: 1_000, due_week: 38, project_id: nil}

        assert Demands.open_project(places, demand) == {places, demand}
        refute Demands.project?(demand)
      end

      refute Demands.project?(nil)
      assert Demands.open_project(places, nil) == {places, nil}
    end

    test "a project demand is delivered only if its project is done; never uses the stock" do
      demand = %{product: :knowledge, amount: 7_000, due_week: 9, project_id: 3}

      project = %Project{
        id: 3,
        blueprint: Project.demand_blueprint(:knowledge),
        target: 7_000,
        gives: {:demand, 9},
        progress: 7_000
      }

      stocks = %{knowledge: 50_000}
      nothing = %{food: 0, gold: 0}

      assert Demands.settle(demand, project, stocks, true) == {:delivered, stocks, nothing}

      assert Demands.settle(demand, %{project | progress: 6_999}, stocks, true) ==
               {:missed, stocks, nothing}

      assert Demands.settle(demand, project, stocks, false) == {:refused, stocks, nothing}
      # refused earlier: the project is gone already
      assert Demands.settle(demand, nil, stocks, false) == {:refused, stocks, nothing}
    end

    test "delivered, refused, or missed when the stock is short" do
      demand = %{product: :food, amount: 10_000, due_week: 38}

      assert {:delivered, %{food: 5_000}, %{food: 0, gold: 0}} =
               Demands.settle(demand, nil, %{food: 15_000}, true)

      assert {:refused, _stocks, _taken} = Demands.settle(demand, nil, %{food: 15_000}, false)
      assert {:missed, _stocks, _taken} = Demands.settle(demand, nil, %{food: 5_000}, true)
    end

    test "refused or missed food and gold: the king takes the stock there is, up to the amount" do
      food = %{product: :food, amount: 10_000, due_week: 38}
      gold = %{product: :gold, amount: 10_000, due_week: 38}

      assert Demands.settle(food, nil, %{food: 5_000}, true) ==
               {:missed, %{food: 0}, %{food: 5_000, gold: 0}}

      assert Demands.settle(food, nil, %{food: 15_000}, false) ==
               {:refused, %{food: 5_000}, %{food: 10_000, gold: 0}}

      assert Demands.settle(gold, nil, %{gold: 4_000}, true) ==
               {:missed, %{gold: 0}, %{food: 0, gold: 4_000}}

      # a short week's empty stock leaves nothing to take
      assert Demands.settle(food, nil, %{food: 0}, true) ==
               {:missed, %{food: 0}, %{food: 0, gold: 0}}
    end

    test "defence leaves nothing to take: a miss only" do
      defence = %{product: :defence, amount: 10_000, due_week: 38}
      stocks = %{defence: 4_000}

      assert Demands.settle(defence, nil, stocks, true) == {:missed, stocks, %{food: 0, gold: 0}}

      assert Demands.settle(defence, nil, stocks, false) ==
               {:refused, stocks, %{food: 0, gold: 0}}
    end
  end

  describe "R7: demands in the week" do
    setup do
      # plenty of food, so the first demand (year 1: green, food) is not 0
      config = EngineFixtures.config(start_food: 1000)
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

    test "a refusal of a food demand: the king takes the food, up to the amount", %{game: game} do
      {_reports, game} = EngineFixtures.run_weeks(game, 7)
      %{amount: amount} = game.demand
      {:ok, game} = Game.decide_demand(game, false)
      {:ok, report, _game} = Game.run_week(game)

      # starting food 1000, so there is more than enough
      assert report.king_took == %{food: amount, gold: 0}
    end

    test "no decision outside the week before a deadline", %{game: game} do
      assert Game.decide_demand(game, true) == {:error, :no_demand_due}
    end
  end

  describe "R7: projects in the week" do
    # a blue worker (id 3) makes 3 knowledge a week, in the monastery (id 3) or on the
    # project (id 4); no other demand; no travel
    setup do
      game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
      monastery = EngineFixtures.new_building(3, :monastery)
      monk = %Worker{id: 3, colour: :blue, place: 3}
      %{game: %{game | places: game.places ++ [monastery], workers: game.workers ++ [monk]}}
    end

    test "workers on it fill it; delivered in the week it reaches the target", %{game: game} do
      game = with_project(game, 7_000, 5)
      {:ok, game} = Game.place_worker(game, 3, 4)
      {reports, game} = EngineFixtures.run_weeks(game, 3)

      # 3 + 3 + 1 (2 lost beyond the target), delivered in week 3, before the deadline
      assert Enum.map(reports, & &1.demand_progress) == [3_000, 6_000, 7_000]
      assert Enum.map(reports, & &1.demand_outcome) == [nil, nil, :delivered]
      assert Enum.all?(reports, &(&1.production.knowledge == 0))
      assert game.stocks.knowledge == 0
      assert game.misses == 0
      assert game.demand == nil
      refute Enum.any?(game.places, &(&1.id == 4))
      assert %Worker{place: nil} = find_worker(game, 3)
    end

    test "the monastery's output goes to the stock, not into the project", %{game: game} do
      game = with_project(game, 7_000, 3)
      {reports, game} = EngineFixtures.run_weeks(game, 3)

      assert Enum.map(reports, & &1.demand_progress) == [0, 0, 0]
      assert List.last(reports).demand_outcome == :missed
      assert game.stocks.knowledge == 9_000
    end

    test "short of the target at the deadline it is missed; the stock is not used", context do
      game = with_project(context.game, 10_000, 3)
      game = %{game | stocks: %{game.stocks | knowledge: 50_000}}
      {:ok, game} = Game.place_worker(game, 3, 4)
      {reports, game} = EngineFixtures.run_weeks(game, 3)

      assert List.last(reports).demand_progress == 9_000
      assert List.last(reports).demand_outcome == :missed
      assert game.stocks.knowledge == 50_000
      assert List.last(reports).king_took == %{food: 0, gold: 0}
      assert game.misses == 1
      refute Enum.any?(game.places, &(&1.id == 4))
      assert %Worker{place: nil} = find_worker(game, 3)
    end

    test "the deadline doesn't wait for a decision", %{game: game} do
      {_reports, game} = game |> with_project(7_000, 2) |> EngineFixtures.run_weeks(1)

      refute Game.demand_decision_due?(game)
      assert {:ok, %{demand_outcome: :missed}, _game} = Game.run_week(game)
    end

    test "a worker on it makes the same mana as in the monastery", %{game: game} do
      {:ok, in_monastery, _game} = Game.run_week(game)
      {:ok, game} = game |> with_project(7_000, 3) |> Game.place_worker(3, 4)
      {:ok, on_project, _game} = Game.run_week(game)

      assert on_project.mana == in_monastery.mana
      assert on_project.mana.blue > 0
    end

    test "refused at any time: the project goes, its workers are released, the miss counts",
         %{game: game} do
      {:ok, game} = game |> with_project(7_000, 3) |> Game.place_worker(3, 4)
      {:ok, game} = Game.refuse_project(game)

      assert Game.refuse_project(game) == {:error, :no_project}
      refute Enum.any?(game.places, &(&1.id == 4))
      assert %Worker{place: nil} = find_worker(game, 3)

      {:ok, report, game} = Game.run_week(game)

      assert report.demand_outcome == :refused
      assert report.demand_progress == nil
      assert game.misses == 1
      assert game.demand == nil
    end

    test "only a project can be refused early", %{game: game} do
      food = EngineFixtures.open_demand(game, :food, 1_000, 3)

      assert Game.refuse_project(food) == {:error, :no_project}
      assert Game.refuse_project(game) == {:error, :no_project}
    end

    defp with_project(game, amount, due_week),
      do: EngineFixtures.open_demand(game, :knowledge, amount, due_week)

    defp find_worker(game, id), do: Enum.find(game.workers, &(&1.id == id))
  end
end
