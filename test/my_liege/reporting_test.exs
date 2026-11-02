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
               "food_left,newborn,trained,gold,tax_due,tax,game_over"

    assert week_0 == "0,0,0,0,0,0,0,0,0,0,0,800,50,100,50,0,24000,,,100000,,,false"
    # seed 1 draws a yellow newborn in week 1
    assert week_1 == "1,9000,0,3000,0,0,3,0,3,0,0,799,50,101,50,0,27000,yellow,,100000,,,false"
    # the unplaced newborn makes no mana but eats: 27 + 9 - 3 × 3
    assert week_2 == "2,9000,0,3000,0,0,3,0,3,0,0,798,50,102,50,0,27000,,,100000,,,false"
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
