defmodule MyLiege.AutoRunTest do
  use ExUnit.Case, async: true

  alias MyLiege.AutoRun
  alias MyLiege.Engine.{Building, Game, Manameter}
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
      # enough gold, so what the king takes on a miss never stops an order
      config = %{config | starting_gold: 1_000_000}
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

  describe "Test A: Feed, save for tax" do
    test "when gold never leaves the stock and enough is left, it plays like Feed" do
      # tax 0, no demands, no spoilage and no robbery: nothing takes gold away
      config =
        EngineFixtures.config(
          starting_gold: 1_000_000,
          tax_per_worker: 0,
          demand_population_share: 0
        )

      {reports, _game} = feed = AutoRun.run(:feed, config, 2)

      assert Enum.any?(reports, &(&1.gold_spent_buildings > 0))
      assert AutoRun.run(:feed_save_tax, config, 2) == feed
    end

    test "doesn't order a building that would leave too little for the next tax" do
      # full buildings, so the newborn of week 1 needs a new one; 30 gold covers either the
      # building or the tax of 3 workers, not both
      config =
        EngineFixtures.config(
          capacity: %{farm: 1, monastery: 1, watchtower: 1, market: 1, tavern: 1, guildhouse: 1},
          starting_gold: 30,
          tax_per_worker: 10,
          demand_population_share: 0
        )

      {feed, _} = AutoRun.run(:feed, config, 1, weeks: 2)
      {save, _} = AutoRun.run(:feed_save_tax, config, 1, weeks: 2)

      assert Enum.at(feed, 1).gold_spent_buildings == 30_000
      assert Enum.at(save, 1).gold_spent_buildings == 0
    end
  end

  describe "Test A: tax_safe_to_build?/1" do
    test "in week 0 the gold now minus the price must cover the next tax" do
      # 2 workers × 10 = 20 tax, the building costs 30
      enough = Game.new(EngineFixtures.config(starting_gold: 50, tax_per_worker: 10), 1)
      short = Game.new(EngineFixtures.config(starting_gold: 49, tax_per_worker: 10), 1)

      assert AutoRun.tax_safe_to_build?(enough)
      refute AutoRun.tax_safe_to_build?(short)
    end

    test "not after a week in which gold left the stock, but again in the week after" do
      config = EngineFixtures.config(starting_gold: 1000, demand_population_share: 0)
      {_reports, game} = EngineFixtures.run_weeks(Game.new(config, 1), 24)

      assert game.report.tax == :paid
      refute AutoRun.tax_safe_to_build?(game)

      {_reports, game} = EngineFixtures.run_weeks(game, 1)
      assert AutoRun.tax_safe_to_build?(game)
    end

    test "always when no tax is left in the game" do
      config =
        EngineFixtures.config(starting_gold: 0, years_per_game: 1, tax_interval_weeks: 100)

      assert AutoRun.tax_safe_to_build?(Game.new(config, 1))
    end
  end

  describe "Test A: summary" do
    test "a run stops after `weeks`", %{config: config} do
      {reports, game} = AutoRun.run(:feed, config, 1, weeks: 10)

      assert Enum.map(reports, & &1.week) == Enum.to_list(0..10)
      assert game.week == 10
    end

    test "one row per pattern and seed, then the totals per pattern", %{config: config} do
      csv = AutoRun.summary_csv([:feed, :feed_save_tax], config, 1..2, weeks: 30)
      [header | rows] = csv |> String.split("\n", trim: true) |> Enum.map(&String.split(&1, ","))

      assert header == ~w(pattern seed first_tax_week first_tax_paid first_tax_missed
                          first_tax_gold_difference buildings_ordered weeks_food_below_0
                          gold_robbed)

      assert Enum.map(rows, &Enum.take(&1, 2)) == [
               ["feed", "1"],
               ["feed", "2"],
               ["feed", "total"],
               ["feed_save_tax", "1"],
               ["feed_save_tax", "2"],
               ["feed_save_tax", "total"]
             ]

      for [pattern, seed | _] = row <- rows, seed != "total" do
        {reports, _game} =
          AutoRun.run(String.to_existing_atom(pattern), config, String.to_integer(seed),
            weeks: 30
          )

        assert parse(row) == expected_row(pattern, seed, reports)
      end

      for [pattern, "total" | _] = total <- rows do
        seeds = for [^pattern, seed | _] = row <- rows, seed != "total", do: parse(row)
        [_, _, first_tax_week | sums] = parse(total)

        # first_tax_week isn't summed
        assert first_tax_week == nil

        for {sum, column} <- Enum.with_index(sums, 3) do
          assert sum == seeds |> Enum.map(&Enum.at(&1, column)) |> Enum.sum()
        end
      end
    end
  end

  # gold columns (5 and 8) are whole gold in the CSV; compared in thousandths
  defp parse([pattern, seed | values]) do
    values =
      values
      |> Enum.with_index(2)
      |> Enum.map(fn
        {"", _} ->
          nil

        {value, column} when column in [5, 8] ->
          value |> Float.parse() |> elem(0) |> Kernel.*(1000) |> round()

        {value, _} ->
          String.to_integer(value)
      end)

    [pattern, seed | values]
  end

  # the summary row computed from the reports
  defp expected_row(pattern, seed, reports) do
    first_tax = Enum.find(reports, & &1.tax)
    before = Enum.find(reports, &(&1.week == first_tax.week - 1))
    counted = reports |> Enum.filter(&(&1.week < first_tax.week and &1.tax_due)) |> List.last()

    ordered =
      reports |> Enum.filter(&(&1.week in 1..48)) |> Enum.sum_by(& &1.gold_spent_buildings)

    [
      pattern,
      seed,
      first_tax.week,
      if(first_tax.tax == :paid, do: 1, else: 0),
      if(first_tax.tax == :missed, do: 1, else: 0),
      before.gold - counted.tax_due,
      div(ordered, 30_000),
      Enum.count(reports, &(&1.food_left < 0)),
      Enum.sum_by(reports, & &1.gold_robbed)
    ]
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
