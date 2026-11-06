defmodule MyLiege.ReportingTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Building, Game, Worker}
  alias MyLiege.EngineFixtures
  alias MyLiege.Reporting

  test "one row per week, starting with week 0" do
    config = EngineFixtures.config()
    game = Game.new(config, 1)

    {reports, _game} = EngineFixtures.run_weeks(game, 2)

    [header, week_0, week_1, week_2] =
      [Game.report(game) | reports] |> Reporting.to_csv() |> String.split("\n", trim: true)

    assert header ==
             "week,production_food,production_gold,production_knowledge," <>
               "production_defence,production_entertainment," <>
               "mana_green,mana_yellow,mana_blue,mana_red,mana_violet," <>
               "manameter_green,manameter_yellow,manameter_blue,manameter_red,manameter_violet," <>
               "food_left,newborn,trained,builders,travelling,gold,tax_due,tax," <>
               "demand_product,demand_amount,demand_outcome,demand_progress," <>
               "king_took_gold,king_took_food," <>
               "spoiled_food,spoiled_gold,spoiled_knowledge,spoiled_defence,spoiled_entertainment," <>
               "gold_spent_buildings,bandit_pressure,bandit_threat,bandits_weeks_to_raid," <>
               "gold_robbed,game_over"

    assert week_0 ==
             "0,0,0,0,0,0,0,0,0,0,0,800,50,50,100,0,24000,,,0,0,100000,,,,,,,0,0,0,0,0,0,0,0,,0,,0,false"

    # seed 1 draws a green newborn in week 1
    assert week_1 ==
             "1,9000,0,0,3000,0,3,0,0,3,0,799,50,50,101,0,27000,green,,0,0,100000,,,,,,,0,0,0,0,0,0,0,0,1666,666,,0,false"

    # the unplaced newborn makes no mana but eats: 27 + 9 - 3 × 3
    assert week_2 ==
             "2,9000,0,0,3000,0,3,0,0,3,0,798,50,50,102,0,27000,,,0,0,100000,,,,,,,0,0,0,0,0,0,0,0,1666,1332,,0,false"
  end

  test "the spoiled columns show what each stock lost; food_left and gold are after spoilage" do
    config =
      EngineFixtures.config(spoilage_rates: Map.merge(no_spoilage(), %{food: 50, gold: 10}))

    {:ok, report, _game} = config |> Game.new(1) |> Game.run_week()

    [_header, row] = [report] |> Reporting.to_csv() |> String.split("\n", trim: true)
    columns = String.split(row, ",")

    # food 27 - 1.35 spoiled, gold 100 - 1 spoiled
    assert Enum.at(columns, 16) == "25650"
    assert Enum.at(columns, 21) == "99000"
    assert Enum.slice(columns, 30..34) == ["1350", "1000", "0", "0", "0"]
  end

  defp no_spoilage, do: EngineFixtures.config().spoilage_rates

  test "the demand columns show the demand when made and its outcome at the deadline" do
    config = EngineFixtures.config(starting_food: 1000)
    game = Game.new(config, 1)
    [first | _] = game.demand_weeks
    {reports, _game} = EngineFixtures.run_weeks(game, first + 8)
    made = Enum.find(reports, &(&1.week == first))

    rows =
      reports
      |> Reporting.to_csv()
      |> String.split("\n", trim: true)
      |> tl()
      |> Map.new(&{&1 |> String.split(",") |> hd() |> String.to_integer(), String.split(&1, ",")})

    assert Enum.slice(rows[first], 24..27) == ["food", "#{made.demand.amount}", "", ""]
    assert Enum.slice(rows[first + 8], 24..27) == ["", "", "delivered", ""]
  end

  test "demand_progress shows a project's total in every week it is open" do
    game = EngineFixtures.game_without_demands(EngineFixtures.config(), 1)
    monastery = %Building{id: 3, type: :monastery}
    monk = %Worker{id: 3, colour: :blue, building: 3}
    project = %{product: :knowledge, amount: 9_000, due_week: 2, progress: 0}

    game = %{
      game
      | buildings: game.buildings ++ [monastery],
        workers: game.workers ++ [monk],
        demand: project
    }

    {reports, _game} = EngineFixtures.run_weeks(game, 3)

    progress =
      reports
      |> Reporting.to_csv()
      |> String.split("\n", trim: true)
      |> tl()
      |> Enum.map(&(&1 |> String.split(",") |> Enum.slice(26..27)))

    assert progress == [["", "3000"], ["missed", "6000"], ["", ""]]
  end

  test "the trained column lists the colours of workers who finished training" do
    config = EngineFixtures.config()
    {:ok, game} = config |> Game.new(1) |> Game.construct(:guildhouse)
    {_reports, game} = EngineFixtures.run_weeks(game, 2)
    guildhouse = Enum.find(game.buildings, &(&1.type == :guildhouse))
    {:ok, game} = Game.place_worker(game, 1, guildhouse.id)
    {reports, _game} = EngineFixtures.run_weeks(game, 4)

    rows = reports |> Reporting.to_csv() |> String.split("\n", trim: true) |> tl()
    trained = Enum.map(rows, &(&1 |> String.split(",") |> Enum.at(18)))

    assert trained == ["", "", "", "green"]
  end

  test "gold_spent_buildings shows the gold paid for orders made while the game stood at that week" do
    config = EngineFixtures.config()
    game = Game.new(config, 1)
    {:ok, game} = Game.construct(game, :market)
    {:ok, game} = Game.construct(game, :guildhouse)
    week_0 = Game.report(game)
    {[week_1], _game} = EngineFixtures.run_weeks(game, 1)

    rows = [week_0, week_1] |> Reporting.to_csv() |> String.split("\n", trim: true) |> tl()
    [spent_0, spent_1] = Enum.map(rows, &(&1 |> String.split(",") |> Enum.at(35)))
    [gold_0, gold_1] = Enum.map(rows, &(&1 |> String.split(",") |> Enum.at(21)))

    assert {spent_0, spent_1} == {"60000", "0"}
    # the row's gold is from before the orders; the next week starts with 100 - 60
    assert {gold_0, gold_1} == {"100000", "40000"}
  end

  test "the builders and travelling columns count arrived builders and travelling workers" do
    config = EngineFixtures.config(builders_per_building: 2, travel_weeks: 1)
    {:ok, game} = config |> Game.new(1) |> Game.construct(:market)
    site = List.last(game.buildings)
    {:ok, game} = Game.place_worker(game, 1, site.id)
    {:ok, game} = Game.place_worker(game, 2, site.id)
    {reports, _game} = EngineFixtures.run_weeks(game, 4)

    rows =
      [Game.report(game) | reports]
      |> Reporting.to_csv()
      |> String.split("
",
        trim: true
      )

    counts = rows |> tl() |> Enum.map(&(&1 |> String.split(",") |> Enum.slice(19..20)))

    # placed at week 0: on the way in week 1, building in weeks 2 and 3, back on the way after
    assert counts == [["0", "0"], ["2", "0"], ["2", "0"], ["0", "2"], ["0", "0"]]
  end

  test "king_took_gold and king_took_food show what the king took that week" do
    config = EngineFixtures.config(starting_gold: 1000)
    game = EngineFixtures.game_without_demands(config, 1)
    {_reports, game} = EngineFixtures.run_weeks(game, 23)
    due = game.tax_due
    {:ok, game} = Game.decide_tax(game, false)
    {:ok, week_24, game} = Game.run_week(game)
    {[week_25], _game} = EngineFixtures.run_weeks(game, 1)

    rows = [week_24, week_25] |> Reporting.to_csv() |> String.split("\n", trim: true) |> tl()
    took = Enum.map(rows, &(&1 |> String.split(",") |> Enum.slice(28..29)))

    assert took == [["#{due}", "0"], ["0", "0"]]
  end

  test "the bandit columns show pressure, threat, weeks to the raid and gold robbed" do
    # without its soldier the tower makes no defence: the bandits set out in week 1 and raid in 5
    config = EngineFixtures.config(bandit_threshold: 10, bandit_warning_weeks: 4)
    {:ok, game} = Game.unplace_worker(EngineFixtures.game_without_demands(config, 1), 2)
    {reports, _game} = EngineFixtures.run_weeks(game, 6)

    rows = reports |> Reporting.to_csv() |> String.split("\n", trim: true) |> tl()
    bandits = Enum.map(rows, &(&1 |> String.split(",") |> Enum.slice(36..39)))

    assert bandits == [
             ["inf", "10000", "4", "0"],
             ["inf", "10000", "3", "0"],
             ["inf", "10000", "2", "0"],
             ["inf", "10000", "1", "0"],
             ["inf", "0", "", "100000"],
             ["0", "0", "", "0"]
           ]
  end

  test "no reports gives only the header" do
    assert Reporting.to_csv([]) |> String.split("\n", trim: true) |> length() == 1
  end
end
