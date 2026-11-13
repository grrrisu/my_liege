defmodule MyLiege.BotTest do
  use ExUnit.Case, async: true

  alias MyLiege.Bot
  alias MyLiege.Engine.{Game, Manameter, Pentagon, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Building}
  alias MyLiege.EngineFixtures

  setup do
    %{config: EngineFixtures.config()}
  end

  describe "Test A: Stay" do
    test "reports every week from 0 to the last week of the game", %{config: config} do
      # enough gold and no king's demands, so nothing ends the run early
      config = %{config | start_gold: 1_000_000, king_demand_population_share: 0}
      {reports, _game} = Bot.run(:stay, config, 1)

      assert Enum.map(reports, & &1.week) == Enum.to_list(0..144)
    end

    test "always tries to pay; the run ends at game over", %{config: config} do
      # free buildings, so the missing gold only affects taxes
      config = %{config | start_gold: 0, build_cost_gold: 0}
      {reports, game} = Bot.run(:stay, config, 1)

      assert Enum.map(reports, & &1.tax) |> Enum.reject(&is_nil/1) == [:missed, :missed]
      assert List.last(reports).week == 48
      assert game.game_over
    end

    test "without gold for a building, workers wait unplaced", %{config: config} do
      config = %{config | start_gold: 0, king_demand_population_share: 0}
      {reports, game} = Bot.run(:stay, config, 1)

      assert Enum.map(game.places, &Place.type/1) == [:farm, :watchtower]
      assert Enum.all?(reports, &(&1.gold_spent_buildings == 0))
      assert Enum.any?(game.workers, &is_nil(&1.place))
    end

    test "reports the gold spent on buildings in the week they were ordered", %{config: config} do
      config = %{config | start_gold: 1_000_000, king_demand_population_share: 0}
      {reports, game} = Bot.run(:stay, config, 1)
      ordered = length(game.places) - 2

      assert ordered > 0
      assert Enum.sum_by(reports, & &1.gold_spent_buildings) == ordered * 30_000
    end

    test "every placed worker is in a building of their own colour", %{config: config} do
      {_reports, game} = Bot.run(:stay, config, 1)
      buildings = Map.new(game.places, &{&1.id, &1})

      for worker <- game.workers, worker.place do
        assert buildings |> Map.fetch!(worker.place) |> Place.colour() == worker.colour
      end
    end

    test "orders only as many buildings as the workers need", %{config: config} do
      # enough gold, so what the king takes on a miss never stops an order
      config = %{config | start_gold: 1_000_000}
      {_reports, game} = Bot.run(:stay, config, 1)

      for type <- Blueprint.types() do
        workers = Enum.count(game.workers, &(Blueprint.home_type(&1.colour) == type))
        buildings = Enum.count(game.places, &(Place.type(&1) == type))

        assert buildings == max(ceil(workers / config.place_capacity[type]), starting(type)),
               "#{type}: #{workers} workers, #{buildings} buildings"
      end
    end

    test "takes workers of the project's colour out of buildings for a king's demand project; it is delivered",
         %{config: config} do
      # blue leads, so the year-1 demand is for knowledge; with plenty of gold every blue
      # newborn gets a monastery. Food runs out after week 7, so no worker is born after
      # it: when the demand opens in week 12, every blue worker is in the monastery, and
      # DemandProject moves as many of them to the project as it needs
      config = %{
        config
        | game_years: 1,
          start_gold: 1_000_000,
          manameter_start: %Manameter{green: 50, yellow: 50, blue: 800, red: 50, violet: 50}
      }

      {reports, _game} = Bot.run(:stay, config, 1, weeks: 24)

      assert [%{product: :knowledge, due_week: due_week, project_id: id}] =
               reports |> Enum.map(& &1.demand) |> Enum.reject(&is_nil/1)

      assert id != nil

      progress = for %{demand_progress: p} <- reports, p, do: p
      assert progress == Enum.sort(progress) and List.last(progress) > 0

      delivered = Enum.find(reports, &(&1.demand_outcome == :delivered))
      assert delivered.week <= due_week
    end

    test "unplaced workers of the project's colour go to a king's demand project; it is delivered",
         %{config: config} do
      # as above, but without gold no monastery is built: the blue newborns wait unplaced,
      # so when the knowledge demand opens they go to its project
      config = %{
        config
        | game_years: 1,
          start_gold: 0,
          manameter_start: %Manameter{green: 50, yellow: 50, blue: 800, red: 50, violet: 50}
      }

      {reports, _game} = Bot.run(:stay, config, 1, weeks: 24)

      assert [%{product: :knowledge, due_week: due_week}] =
               reports |> Enum.map(& &1.demand) |> Enum.reject(&is_nil/1)

      progress = for %{demand_progress: p} <- reports, p, do: p
      assert progress == Enum.sort(progress) and List.last(progress) > 0

      delivered = Enum.find(reports, &(&1.demand_outcome == :delivered))
      assert delivered.week <= due_week
    end

    test "the same seed replays the same run", %{config: config} do
      assert Bot.run(:stay, config, 7) == Bot.run(:stay, config, 7)
    end
  end

  describe "Test A: Pivot" do
    test "workers born from the pivot week go to a watchtower", %{config: config} do
      {_reports, game} = Bot.run(:pivot, config, 1)
      buildings = Map.new(game.places, &{&1.id, &1})

      for worker <- game.workers, worker.place do
        expected =
          if worker.born_week && worker.born_week >= 48,
            do: :red,
            else: worker.colour

        assert buildings |> Map.fetch!(worker.place) |> Place.colour() == expected
      end
    end

    test "before the pivot week it plays like Stay", %{config: config} do
      {stay, _} = Bot.run(:stay, config, 3)
      {pivot, _} = Bot.run(:pivot, config, 3)

      assert Enum.take(stay, 48) == Enum.take(pivot, 48)
    end
  end

  describe "Test A: Feed" do
    test "while food is short, newborns go to a farm whatever their colour" do
      # 1 farmer makes 3, 2 workers eat 6: food is short from week 1 on
      config =
        EngineFixtures.config(
          start_food: 0,
          place_output_per_worker: %{farm: 3, monastery: 3, watchtower: 3, market: 3, tavern: 3}
        )

      {_reports, game} = Bot.run(:feed, config, 1)
      farm_ids = for b <- game.places, Place.type(b) == :farm, do: b.id

      for worker <- game.workers, worker.born_week do
        assert worker.place in farm_ids
      end
    end

    test "a newborn goes to a farm when last week's surplus can't feed one more worker" do
      # 1 farmer makes 4, 2 workers eat 6: the balance is -2 although the stock is large
      config =
        EngineFixtures.config(
          start_food: 1000,
          place_output_per_worker: %{farm: 4, monastery: 3, watchtower: 3, market: 3, tavern: 3}
        )

      {_reports, game} = Bot.run(:feed, config, 1)
      first_newborn = Enum.find(game.workers, &(&1.born_week == 1))
      farm_ids = for b <- game.places, Place.type(b) == :farm, do: b.id

      assert first_newborn.place in farm_ids
      assert game.stocks.food > 0
    end

    test "with a large food surplus and enough gold it plays like Stay" do
      config =
        EngineFixtures.config(
          start_gold: 1_000_000,
          place_output_per_worker: %{
            farm: 1000,
            monastery: 3,
            watchtower: 3,
            market: 3,
            tavern: 3
          }
        )

      assert Bot.run(:feed, config, 2) == Bot.run(:stay, config, 2)
    end

    test "with enough food, newborns go to a market while gold is below the next tax" do
      config =
        EngineFixtures.config(
          start_gold: 0,
          # free buildings, so a market can be built without gold
          build_cost_gold: 0,
          place_output_per_worker: %{
            farm: 1000,
            monastery: 3,
            watchtower: 3,
            market: 3,
            tavern: 3
          }
        )

      {_reports, game} = Bot.run(:feed, config, 1)
      first_newborn = Enum.find(game.workers, &(&1.born_week == 1))
      market_ids = for b <- game.places, Place.type(b) == :market, do: b.id

      assert first_newborn.place in market_ids
    end
  end

  describe "Test A: Feed then Pivot" do
    test "while food is short, newborns go to a farm, even after the pivot week" do
      config =
        EngineFixtures.config(
          start_food: 0,
          place_output_per_worker: %{farm: 3, monastery: 3, watchtower: 3, market: 3, tavern: 3}
        )

      assert Bot.run(:feed_pivot, config, 1) == Bot.run(:feed, config, 1)
    end

    test "with a large food surplus and enough gold it plays like Pivot" do
      config =
        EngineFixtures.config(
          start_gold: 1_000_000,
          place_output_per_worker: %{
            farm: 1000,
            monastery: 3,
            watchtower: 3,
            market: 3,
            tavern: 3
          }
        )

      assert Bot.run(:feed_pivot, config, 2) == Bot.run(:pivot, config, 2)
    end

    test "after the pivot week, newborns go to a watchtower even while gold is low" do
      config =
        EngineFixtures.config(
          # free buildings, so new watchtowers can be built while gold is low
          build_cost_gold: 0,
          place_output_per_worker: %{
            farm: 1000,
            monastery: 3,
            watchtower: 3,
            market: 3,
            tavern: 3
          }
        )

      {_reports, game} = Bot.run(:feed_pivot, config, 1, pivot_week: 1)
      buildings = Map.new(game.places, &{&1.id, &1})

      for worker <- game.workers, worker.born_week, worker.place do
        assert buildings |> Map.fetch!(worker.place) |> Place.type() == :watchtower
      end
    end
  end

  describe "Test A: Feed, save for tax" do
    test "when gold never leaves the stock and enough is left, it plays like Feed" do
      # tax 0, no demands, no spoilage and no robbery: nothing takes gold away
      config =
        EngineFixtures.config(
          start_gold: 1_000_000,
          king_tax_per_worker: 0,
          king_demand_population_share: 0
        )

      {reports, _game} = feed = Bot.run(:feed, config, 2)

      assert Enum.any?(reports, &(&1.gold_spent_buildings > 0))
      assert Bot.run(:feed_save_tax, config, 2) == feed
    end

    test "doesn't order a building that would leave too little for the next tax" do
      # full buildings, so the newborn of week 1 needs a new one; 30 gold covers either the
      # building or the tax of 3 workers, not both
      config =
        EngineFixtures.config(
          place_capacity: %{
            farm: 1,
            monastery: 1,
            watchtower: 1,
            market: 1,
            tavern: 1,
            guildhouse: 1
          },
          start_gold: 30,
          king_tax_per_worker: 10,
          king_demand_population_share: 0
        )

      {feed, _} = Bot.run(:feed, config, 1, weeks: 2)
      {save, _} = Bot.run(:feed_save_tax, config, 1, weeks: 2)

      assert Enum.at(feed, 1).gold_spent_buildings == 30_000
      assert Enum.at(save, 1).gold_spent_buildings == 0
    end
  end

  describe "Test A: tax_safe_to_build?/1" do
    test "in week 0 the gold now minus the price must cover the next tax" do
      # 2 workers × 10 = 20 tax, the building costs 30
      enough = Game.new(EngineFixtures.config(start_gold: 50, king_tax_per_worker: 10), 1)
      short = Game.new(EngineFixtures.config(start_gold: 49, king_tax_per_worker: 10), 1)

      assert Bot.tax_safe_to_build?(enough)
      refute Bot.tax_safe_to_build?(short)
    end

    test "not after a week in which gold left the stock, but again in the week after" do
      config = EngineFixtures.config(start_gold: 1000, king_demand_population_share: 0)
      {_reports, game} = config |> Game.new(1) |> EngineFixtures.run_weeks(24)

      assert game.report.tax == :paid
      refute Bot.tax_safe_to_build?(game)

      {_reports, game} = EngineFixtures.run_weeks(game, 1)
      assert Bot.tax_safe_to_build?(game)
    end

    test "always when no tax is left in the game" do
      config =
        EngineFixtures.config(start_gold: 0, game_years: 1, king_tax_interval_weeks: 100)

      assert config |> Game.new(1) |> Bot.tax_safe_to_build?()
    end
  end

  describe "Test A: Feed, defend" do
    test "while bandits never set out, it plays like Feed", %{config: config} do
      assert Bot.run(:feed_defend, config, 3) == Bot.run(:feed, config, 3)
    end

    test "moves unplaced workers to a watchtower until the raid's gold is protected" do
      # the soldier protects 3 × 20 = 60 gold; a blue worker adds 2.4 × 20 = 48 > 100 - 60
      game = on_their_way(EngineFixtures.config(), raid_week: 5)

      game = %{
        game
        | workers: game.workers ++ [%Worker{id: 3, colour: :blue}, %Worker{id: 4, colour: :blue}]
      }

      game = Bot.defend(game)

      assert Enum.map(game.workers, & &1.place) == [1, 2, 2, nil]
    end

    test "moves nobody when the gold is already protected" do
      game = on_their_way(EngineFixtures.config(start_gold: 10), raid_week: 5)
      game = %{game | workers: game.workers ++ [%Worker{id: 3, colour: :red}]}

      assert Bot.defend(game) == game
    end

    test "moves nobody who couldn't arrive before the raid" do
      game = on_their_way(EngineFixtures.config(travel_weeks: 1), raid_week: 1)
      game = %{game | workers: game.workers ++ [%Worker{id: 3, colour: :red}]}

      assert Bot.defend(game) == game
    end

    test "takes a worker from a building only while its product keeps a surplus" do
      game = on_their_way(EngineFixtures.config(), raid_week: 5)
      # the farmer makes 9 food a week
      with_surplus = last_change(game, food: 10_000)
      without = last_change(game, food: 8_000)

      assert hd(Bot.defend(with_surplus).workers).place == 2
      assert hd(Bot.defend(without).workers).place == 1
    end
  end

  describe "Test A: Feed, invest and defend" do
    test "with plenty of gold it plays like Feed, defend" do
      config = EngineFixtures.config(start_gold: 1_000_000)

      assert Bot.run(:feed_invest_defend, config, 2) == Bot.run(:feed_defend, config, 2)
    end

    test "a market's expected gold until the tax week counts" do
      # 40 gold - 30 for the building leaves 10 for a tax of 20; a yellow worker in a market
      # earns 3 a week from week 3 to the tax week 24
      game = Game.new(EngineFixtures.config(start_gold: 40, king_tax_per_worker: 10), 1)
      waiting = [%Worker{id: 3, colour: :yellow}]

      assert Bot.invest_allowed?(game, :market, waiting)
      refute Bot.invest_allowed?(game, :monastery, waiting)
    end

    test "a farm is always allowed while food is low" do
      game = Game.new(EngineFixtures.config(start_gold: 0), 1)
      hungry = %{game | stocks: %{game.stocks | food: -1}}

      assert Bot.invest_allowed?(hungry, :farm, [])
      refute Bot.invest_allowed?(game, :farm, [])
    end

    test "always when no tax is left in the game" do
      config =
        EngineFixtures.config(start_gold: 0, game_years: 1, king_tax_interval_weeks: 100)

      assert config |> Game.new(1) |> Bot.invest_allowed?(:tavern, [])
    end
  end

  # a new game (gold 100, a farmer and a soldier) with bandits raiding in `raid_week`
  defp on_their_way(config, raid_week: raid_week) do
    game = Game.new(config, 1)
    %{game | bandits: %{threat: 0, raid_week: raid_week}}
  end

  defp last_change(game, changes) do
    change = Map.merge(Map.new(Blueprint.goods(), &{&1, 0}), Map.new(changes))
    %{game | report: %{game.report | stock_change: change}}
  end

  describe "Test A: summary" do
    test "a run stops after `weeks`", %{config: config} do
      {reports, game} = Bot.run(:feed, config, 1, weeks: 10)

      assert Enum.map(reports, & &1.week) == Enum.to_list(0..10)
      assert game.week == 10
    end

    test "one row per pattern and seed, then the totals per pattern", %{config: config} do
      csv = Bot.summary_csv([:feed, :feed_save_tax], config, 1..2, weeks: 30)
      [header | rows] = csv |> String.split("\n", trim: true) |> Enum.map(&String.split(&1, ","))

      assert header == ~w(pattern seed first_tax_week first_tax_paid first_tax_missed
                          first_tax_gold_difference buildings_ordered weeks_food_below_0
                          gold_robbed book_week_green book_week_yellow book_week_blue
                          book_week_red book_week_violet)

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
          pattern
          |> String.to_existing_atom()
          |> Bot.run(config, String.to_integer(seed), weeks: 30)

        assert parse(row) == expected_row(pattern, seed, reports)
      end

      for [pattern, "total" | _] = total <- rows do
        seeds = for [^pattern, seed | _] = row <- rows, seed != "total", do: parse(row)
        [_, _, first_tax_week | sums] = parse(total)

        {sums, book_weeks} = Enum.split(sums, 6)

        # first_tax_week and the book weeks aren't summed
        assert first_tax_week == nil
        assert Enum.all?(book_weeks, &is_nil/1)

        for {sum, column} <- Enum.with_index(sums, 3) do
          assert sum == seeds |> Enum.map(&Enum.at(&1, column)) |> Enum.sum()
        end
      end
    end
  end

  describe "Test A: Feed, books" do
    test "writes red and green books from week 25; the summary has the week each was finished",
         %{config: config} do
      # a book needs 1 knowledge, so it is finished in the first week it is written
      config = %{config | book_work: 1}
      {reports, _game} = Bot.run(:feed_books, config, 1, weeks: 40)

      finished = for r <- reports, colour <- r.books_finished, do: {colour, r.week}
      assert Enum.sort(Keyword.keys(finished)) == [:green, :red]
      assert Enum.all?(finished, fn {_colour, week} -> week > 25 end)

      csv = Bot.summary_csv([:feed_books], config, [1], weeks: 40)

      [header, row | _] =
        csv |> String.split("\n", trim: true) |> Enum.map(&String.split(&1, ","))

      weeks = header |> Enum.zip(row) |> Map.new()

      assert weeks["book_week_red"] == to_string(finished[:red])
      assert weeks["book_week_green"] == to_string(finished[:green])
      assert weeks["book_week_blue"] == ""
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
    ] ++
      for colour <- Pentagon.colours() do
        with %{week: week} <- Enum.find(reports, &(colour in &1.books_finished)), do: week
      end
  end

  describe "Test A: records" do
    test "leading colour and share at the end of each year", %{config: config} do
      reports = for week <- 0..144, do: report(week, if(week >= 96, do: 300, else: 100))

      assert Bot.leading(reports, config) ==
               [{48, :green, 900}, {96, :green, 700}, {144, :green, 700}]
    end

    test "weeks red needs to gain 20 points after the pivot" do
      # red is 100 up to week 47, then gains 10 a week
      reports = for week <- 0..144, do: report(week, 100 + max(week - 47, 0) * 10)

      assert Bot.pivot_weeks(reports) == 20
    end

    test "no pivot result when red never gains 20 points" do
      reports = for week <- 0..144, do: report(week, 100)

      assert Bot.pivot_weeks(reports) == nil
    end

    test "spread between runs per colour" do
      runs = [[report(48, 100)], [report(48, 250)]]

      assert Bot.spread(runs, 48) == %{
               green: {750, 900},
               blue: {0, 0},
               red: {100, 250},
               yellow: {0, 0},
               violet: {0, 0}
             }
    end
  end

  defp starting(type), do: Enum.count(Building.starting(), &(Place.type(&1) == type))

  defp report(week, red) do
    %{
      week: week,
      manameter: %Manameter{green: 1000 - red, blue: 0, red: red, yellow: 0, violet: 0}
    }
  end
end
