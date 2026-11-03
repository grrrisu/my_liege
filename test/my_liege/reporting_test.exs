defmodule MyLiege.ReportingTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Game
  alias MyLiege.EngineFixtures
  alias MyLiege.Reporting

  test "one row per week, starting with week 0" do
    config = EngineFixtures.config()
    game = Game.new(config, 1)

    {reports, _game} = EngineFixtures.run_weeks(game, 2, config)

    [header, week_0, week_1, week_2] =
      [Game.report(game) | reports] |> Reporting.to_csv() |> String.split("\n", trim: true)

    assert header ==
             "week,production_food,production_knowledge,production_defence," <>
               "production_gold,production_entertainment," <>
               "mana_green,mana_blue,mana_red,mana_yellow,mana_violet," <>
               "manameter_green,manameter_blue,manameter_red,manameter_yellow,manameter_violet," <>
               "food_left,newborn,trained,gold,tax_due,tax," <>
               "demand_product,demand_amount,demand_outcome," <>
               "spoiled_food,spoiled_knowledge,spoiled_defence,spoiled_gold,spoiled_entertainment," <>
               "game_over"

    assert week_0 ==
             "0,0,0,0,0,0,0,0,0,0,0,800,50,100,50,0,24000,,,100000,,,,,,0,0,0,0,0,false"

    # seed 1 draws a green newborn in week 1
    assert week_1 ==
             "1,9000,0,3000,0,0,3,0,3,0,0,799,50,101,50,0,27000,green,,100000,,,,,,0,0,0,0,0,false"

    # the unplaced newborn makes no mana but eats: 27 + 9 - 3 × 3
    assert week_2 ==
             "2,9000,0,3000,0,0,3,0,3,0,0,798,50,102,50,0,27000,,,100000,,,,,,0,0,0,0,0,false"
  end

  test "the spoiled columns show what each stock lost; food_left and gold are after spoilage" do
    config =
      EngineFixtures.config(spoilage_rates: Map.merge(no_spoilage(), %{food: 50, gold: 10}))

    {:ok, report, _game} = config |> Game.new(1) |> Game.run_week(config)

    [_header, row] = [report] |> Reporting.to_csv() |> String.split("\n", trim: true)
    columns = String.split(row, ",")

    # food 27 - 1.35 spoiled, gold 100 - 1 spoiled
    assert Enum.at(columns, 16) == "25650"
    assert Enum.at(columns, 19) == "99000"
    assert Enum.slice(columns, 25..29) == ["1350", "0", "0", "1000", "0"]
  end

  defp no_spoilage, do: EngineFixtures.config().spoilage_rates

  test "the demand columns show the demand when made and its outcome at the deadline" do
    config = EngineFixtures.config(starting_food: 1000)
    game = Game.new(config, 1)
    [first | _] = game.demand_weeks
    {reports, _game} = EngineFixtures.run_weeks(game, first + 8, config)
    made = Enum.find(reports, &(&1.week == first))

    rows =
      reports
      |> Reporting.to_csv()
      |> String.split("\n", trim: true)
      |> tl()
      |> Map.new(&{&1 |> String.split(",") |> hd() |> String.to_integer(), String.split(&1, ",")})

    assert Enum.slice(rows[first], 22..24) == ["food", "#{made.demand.amount}", ""]
    assert Enum.slice(rows[first + 8], 22..24) == ["", "", "delivered"]
  end

  test "the trained column lists the colours of workers who finished training" do
    config = EngineFixtures.config()
    {:ok, game} = config |> Game.new(1) |> Game.construct(:guildhouse, config)
    {_reports, game} = EngineFixtures.run_weeks(game, 2, config)
    guildhouse = Enum.find(game.buildings, &(&1.type == :guildhouse))
    {:ok, game} = Game.place_worker(game, 1, guildhouse.id, config)
    {reports, _game} = EngineFixtures.run_weeks(game, 4, config)

    rows = reports |> Reporting.to_csv() |> String.split("\n", trim: true) |> tl()
    trained = Enum.map(rows, &(&1 |> String.split(",") |> Enum.at(18)))

    assert trained == ["", "", "", "green"]
  end

  test "no reports gives only the header" do
    assert Reporting.to_csv([]) |> String.split("\n", trim: true) |> length() == 1
  end
end
