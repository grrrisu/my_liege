defmodule MyLiege.AutoRunTest do
  use ExUnit.Case, async: true

  alias MyLiege.AutoRun
  alias MyLiege.Engine.{Building, Manameter}
  alias MyLiege.EngineFixtures

  setup do
    %{config: EngineFixtures.config()}
  end

  describe "Test A: Stay" do
    test "reports every week from 0 to the last week of the game", %{config: config} do
      # enough gold and no king's demands, so nothing ends the run early
      config = %{config | starting_gold: 1_000_000, demand_population_share: 0}
      {reports, _game} = AutoRun.run(:stay, config, 1)

      assert Enum.map(reports, & &1.week) == Enum.to_list(0..144)
    end

    test "always tries to pay; the run ends at game over", %{config: config} do
      # free buildings, so the missing gold only affects taxes
      config = %{config | starting_gold: 0, build_cost_gold: 0}
      {reports, game} = AutoRun.run(:stay, config, 1)

      assert Enum.map(reports, & &1.tax) |> Enum.reject(&is_nil/1) == [:missed, :missed]
      assert List.last(reports).week == 48
      assert game.game_over
    end

    test "without gold for a building, workers wait unplaced", %{config: config} do
      config = %{config | starting_gold: 0, demand_population_share: 0}
      {reports, game} = AutoRun.run(:stay, config, 1)

      assert Enum.map(game.buildings, & &1.type) == [:farm, :watchtower]
      assert Enum.all?(reports, &(&1.gold_spent_buildings == 0))
      assert Enum.any?(game.workers, &is_nil(&1.building))
    end

    test "reports the gold spent on buildings in the week they were ordered", %{config: config} do
      config = %{config | starting_gold: 1_000_000, demand_population_share: 0}
      {reports, game} = AutoRun.run(:stay, config, 1)
      ordered = length(game.buildings) - 2

      assert ordered > 0
      assert Enum.sum_by(reports, & &1.gold_spent_buildings) == ordered * 30_000
    end

    test "every placed worker is in a building of their own colour", %{config: config} do
      {_reports, game} = AutoRun.run(:stay, config, 1)
      buildings = Map.new(game.buildings, &{&1.id, &1})

      for worker <- game.workers, worker.building do
        assert Building.colour(Map.fetch!(buildings, worker.building)) == worker.colour
      end
    end

    test "orders only as many buildings as the workers need", %{config: config} do
      {_reports, game} = AutoRun.run(:stay, config, 1)

      for type <- Building.types() do
        workers = Enum.count(game.workers, &(Building.type_of_colour(&1.colour) == type))
        buildings = Enum.count(game.buildings, &(&1.type == type))

        assert buildings == max(ceil(workers / config.capacity[type]), starting(type)),
               "#{type}: #{workers} workers, #{buildings} buildings"
      end
    end

    test "the same seed replays the same run", %{config: config} do
      assert AutoRun.run(:stay, config, 7) == AutoRun.run(:stay, config, 7)
    end
  end

  describe "Test A: Pivot" do
    test "workers born from the pivot week go to a watchtower", %{config: config} do
      {_reports, game} = AutoRun.run(:pivot, config, 1)
      buildings = Map.new(game.buildings, &{&1.id, &1})

      for worker <- game.workers, worker.building do
        expected =
          if worker.born_week && worker.born_week >= 48,
            do: :red,
            else: worker.colour

        assert Building.colour(Map.fetch!(buildings, worker.building)) == expected
      end
    end

    test "before the pivot week it plays like Stay", %{config: config} do
      {stay, _} = AutoRun.run(:stay, config, 3)
      {pivot, _} = AutoRun.run(:pivot, config, 3)

      assert Enum.take(stay, 48) == Enum.take(pivot, 48)
    end
  end

  describe "Test A: Feed" do
    test "while food is short, newborns go to a farm whatever their colour" do
      # 1 farmer makes 3, 2 workers eat 6: food is short from week 1 on
      config =
        EngineFixtures.config(
          starting_food: 0,
          base_production: %{farm: 3, monastery: 3, watchtower: 3, market: 3, tavern: 3}
        )

      {_reports, game} = AutoRun.run(:feed, config, 1)
      farm_ids = for b <- game.buildings, b.type == :farm, do: b.id

      for worker <- game.workers, worker.born_week do
        assert worker.building in farm_ids
      end
    end

    test "a newborn goes to a farm when last week's surplus can't feed one more worker" do
      # 1 farmer makes 4, 2 workers eat 6: the balance is -2 although the stock is large
      config =
        EngineFixtures.config(
          starting_food: 1000,
          base_production: %{farm: 4, monastery: 3, watchtower: 3, market: 3, tavern: 3}
        )

      {_reports, game} = AutoRun.run(:feed, config, 1)
      first_newborn = Enum.find(game.workers, &(&1.born_week == 1))
      farm_ids = for b <- game.buildings, b.type == :farm, do: b.id

      assert first_newborn.building in farm_ids
      assert game.stocks.food > 0
    end

    test "with a large food surplus and enough gold it plays like Stay" do
      config =
        EngineFixtures.config(
          starting_gold: 1_000_000,
          base_production: %{farm: 1000, monastery: 3, watchtower: 3, market: 3, tavern: 3}
        )

      assert AutoRun.run(:feed, config, 2) == AutoRun.run(:stay, config, 2)
    end

    test "with enough food, newborns go to a market while gold is below the next tax" do
      config =
        EngineFixtures.config(
          starting_gold: 0,
          # free buildings, so a market can be built without gold
          build_cost_gold: 0,
          base_production: %{farm: 1000, monastery: 3, watchtower: 3, market: 3, tavern: 3}
        )

      {_reports, game} = AutoRun.run(:feed, config, 1)
      first_newborn = Enum.find(game.workers, &(&1.born_week == 1))
      market_ids = for b <- game.buildings, b.type == :market, do: b.id

      assert first_newborn.building in market_ids
    end
  end

  describe "Test A: Feed then Pivot" do
    test "while food is short, newborns go to a farm, even after the pivot week" do
      config =
        EngineFixtures.config(
          starting_food: 0,
          base_production: %{farm: 3, monastery: 3, watchtower: 3, market: 3, tavern: 3}
        )

      assert AutoRun.run(:feed_pivot, config, 1) == AutoRun.run(:feed, config, 1)
    end

    test "with a large food surplus and enough gold it plays like Pivot" do
      config =
        EngineFixtures.config(
          starting_gold: 1_000_000,
          base_production: %{farm: 1000, monastery: 3, watchtower: 3, market: 3, tavern: 3}
        )

      assert AutoRun.run(:feed_pivot, config, 2) == AutoRun.run(:pivot, config, 2)
    end

    test "after the pivot week, newborns go to a watchtower even while gold is low" do
      config =
        EngineFixtures.config(
          # free buildings, so new watchtowers can be built while gold is low
          build_cost_gold: 0,
          base_production: %{farm: 1000, monastery: 3, watchtower: 3, market: 3, tavern: 3}
        )

      {_reports, game} = AutoRun.run(:feed_pivot, config, 1, pivot_week: 1)
      buildings = Map.new(game.buildings, &{&1.id, &1})

      for worker <- game.workers, worker.born_week, worker.building do
        assert Map.fetch!(buildings, worker.building).type == :watchtower
      end
    end
  end

  describe "Test A: records" do
    test "leading colour and share at the end of each year", %{config: config} do
      reports = for week <- 0..144, do: report(week, if(week >= 96, do: 300, else: 100))

      assert AutoRun.leading(reports, config) ==
               [{48, :green, 900}, {96, :green, 700}, {144, :green, 700}]
    end

    test "weeks red needs to gain 20 points after the pivot" do
      # red is 100 up to week 47, then gains 10 a week
      reports = for week <- 0..144, do: report(week, 100 + max(week - 47, 0) * 10)

      assert AutoRun.pivot_weeks(reports) == 20
    end

    test "no pivot result when red never gains 20 points" do
      reports = for week <- 0..144, do: report(week, 100)

      assert AutoRun.pivot_weeks(reports) == nil
    end

    test "spread between runs per colour" do
      runs = [[report(48, 100)], [report(48, 250)]]

      assert AutoRun.spread(runs, 48) == %{
               green: {750, 900},
               blue: {0, 0},
               red: {100, 250},
               yellow: {0, 0},
               violet: {0, 0}
             }
    end
  end

  defp starting(type), do: Enum.count(Building.starting(), &(&1.type == type))

  defp report(week, red) do
    %{
      week: week,
      manameter: %Manameter{green: 1000 - red, blue: 0, red: red, yellow: 0, violet: 0}
    }
  end
end
