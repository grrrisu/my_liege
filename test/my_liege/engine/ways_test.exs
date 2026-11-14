defmodule MyLiege.Engine.WaysTest do
  @moduledoc "R13–R17 through `Game`: the granary and the improved plough over whole weeks."
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Forecast, Game, Worker}
  alias MyLiege.Engine.Place.{Expedition, Trade}
  alias MyLiege.Engine.Rules.{Books, Production, Trades}
  alias MyLiege.EngineFixtures
  alias MyLiege.Reporting

  # farm (1) with green worker 1, tower (2) with red worker 2; no travel; manameter green 800
  defp game(config_overrides) do
    config = EngineFixtures.config(config_overrides)
    game = EngineFixtures.game_without_demands(config, 1)
    %{game | books: Map.new(game.books, fn {colour, _} -> {colour, 1} end)}
  end

  defp spoiling_food,
    do: [good_spoilage: %{food: 50, knowledge: 0, defence: 0, gold: 0, culture: 0}]

  describe "R14: granary" do
    setup do
      game = spoiling_food() |> game() |> EngineFixtures.add_building(:granary)
      {:ok, game} = Game.place_worker(game, 2, 3)
      %{game: game}
    end

    test "its keeper produces nothing, makes 2 violet and 1 green mana, and food spoils at the granary's rate",
         %{game: game} do
      {:ok, report, game} = Game.run_week(game)

      assert report.granary_working
      assert report.production.food == 9_000
      assert report.production.defence == 0
      assert report.mana == %{green: 4, yellow: 0, blue: 0, red: 0, violet: 2}
      # 24 + 9 − 2 × 3 = 27 food; 10 per mille instead of 50
      assert report.spoiled.food == 270
      assert game.stocks.food == 26_730
    end

    test "an empty granary does nothing", %{game: game} do
      {:ok, game} = Game.unplace_worker(game, 2)
      {:ok, report, _game} = Game.run_week(game)

      refute report.granary_working
      assert report.culture_upkeep == 0
      assert report.spoiled.food == 1_350
    end

    test "more granaries don't lower spoilage further, but each costs upkeep", %{game: game} do
      game = EngineFixtures.add_building(game, :granary)
      {:ok, game} = Game.place_worker(game, 1, 4)
      game = %{game | stocks: %{game.stocks | culture: 20_000}}
      {:ok, report, game} = Game.run_week(game)

      # nobody farms: 24 − 6 = 18 food
      assert report.spoiled.food == 180
      assert report.culture_upkeep == 10_000
      assert game.stocks.culture == 10_000
    end

    test "the upkeep comes from the stock, never below 0, and is spent before happiness",
         %{game: game} do
      game = EngineFixtures.add_building(game, :tavern)
      # the farmer goes to the tavern: green in violet is a neighbour, 3 × 0.75 culture
      {:ok, game} = Game.place_worker(game, 1, 4)
      {:ok, report, game} = Game.run_week(game)

      assert report.production.culture == 2_250
      assert report.culture_upkeep == 2_250
      assert game.stocks.culture == 0
      assert report.happiness.ratio == 0

      {:ok, report, game} = Game.run_week(%{game | stocks: %{game.stocks | culture: 20_000}})
      assert report.culture_upkeep == 5_000
      assert game.stocks.culture == 17_250
      assert report.happiness.ratio == 0

      {:ok, game} = Game.unplace_worker(game, 2)
      {:ok, report, game} = Game.run_week(game)
      assert report.culture_upkeep == 0
      # all culture counts again; 3 workers since week 2's birth: 2.25 ÷ 3
      assert length(game.workers) == 3
      assert report.happiness.ratio == 750
    end

    test "exports granary_working and culture_upkeep", %{game: game} do
      game = %{game | stocks: %{game.stocks | culture: 20_000}}
      {:ok, report, _game} = Game.run_week(game)
      [_header, row] = [report] |> Reporting.to_csv() |> String.split("\n", trim: true)

      assert String.ends_with?(row, ",false,true,5000,0,0,0,0,0")
    end
  end

  describe "R15: improved plough" do
    setup do
      game = game(way_plough_work: 5)
      {:ok, game} = Game.start_invention(game, :plough)
      {:ok, game} = Game.place_worker(game, 2, 3)
      %{game: game}
    end

    test "is written as in a blue building × green's experience, makes 2 blue and 1 green mana",
         %{game: game} do
      {:ok, report, game} = Game.run_week(game)

      # red in blue is a neighbour: 3 × 0.75 = 2.25, × green 800 ÷ 200 = 9 ≥ 5: done
      assert report.mana == %{green: 4, yellow: 0, blue: 2, red: 0, violet: 0}
      assert report.inventions_finished == [:plough]
      assert game.inventions == [:plough]
      refute Enum.any?(game.places, &match?(%{gives: {:invention, _}}, &1))
      assert Enum.find(game.workers, &(&1.id == 2)).place == nil
      # the bonus starts with the next week
      assert report.production.food == 9_000
      assert report.production.knowledge == 0

      {:ok, report, game} = Game.run_week(game)
      assert report.production.food == 11_250
      assert Game.start_invention(game, :plough) == {:error, :already_invented}
    end

    test "only farm workers get the bonus" do
      config = EngineFixtures.config()
      places = [EngineFixtures.new_building(1, :farm), EngineFixtures.new_building(2, :tavern)]

      workers = [
        %Worker{id: 1, colour: :green, place: 1},
        %Worker{id: 2, colour: :violet, place: 2}
      ]

      assert %{food: 11_250, culture: 3_000} =
               Production.output(workers, places, 1, config, [:plough])
    end

    test "takes up to way.plough.capacity workers", %{game: game} do
      game = game |> with_unplaced(4)
      [a, b, c, d] = game.workers |> Enum.filter(&is_nil(&1.place)) |> Enum.map(& &1.id)

      {:ok, game} = Game.place_worker(game, a, 3)
      {:ok, game} = Game.place_worker(game, b, 3)
      {:ok, game} = Game.place_worker(game, c, 3)
      assert Game.place_worker(game, d, 3) == {:error, :full}
    end

    test "exports plough_done", %{game: game} do
      {:ok, report, _game} = Game.run_week(game)
      [_header, row] = [report] |> Reporting.to_csv() |> String.split("\n", trim: true)

      assert String.ends_with?(row, ",true,false,0,0,0,0,0,0")
    end
  end

  describe "R16: grain trade route" do
    # farm (1) with green worker 1, tower (2) with red worker 2; the route (3) open
    setup do
      game = game(start_gold: 1000, start_food: 1000)
      {places, [:grain_trade]} = Trades.open(game.places, game.books)
      %{game: %{game | places: places}}
    end

    defp trader_travel(game, id), do: Enum.find(game.workers, &(&1.id == id)).travel

    test "opens in the Books step once the books unlock it, once" do
      game = game([])
      {:ok, report, game} = Game.run_week(game)

      assert report.routes_opened == [:grain_trade]
      assert [%Trade{id: 3, traders: []}] = for(%Trade{} = t <- game.places, do: t)

      {:ok, report, game} = Game.run_week(game)
      assert report.routes_opened == []
      assert game.places |> Enum.count(&match?(%Trade{}, &1)) == 1
    end

    test "stays closed without the books" do
      game = %{game([]) | books: Books.none()}
      {_reports, game} = EngineFixtures.run_weeks(game, 2)

      refute Enum.any?(game.places, &match?(%Trade{}, &1))
      assert Game.place_worker(game, 1, 3) == {:error, :unknown_place}
    end

    test "travel there and away is way.grain_trade.travel_weeks, not travel.weeks", %{
      game: game
    } do
      {:ok, on_route} = Game.place_worker(game, 2, 3)
      assert trader_travel(on_route, 2) == 3

      {:ok, moved} = Game.place_worker(on_route, 2, 1)
      assert trader_travel(moved, 2) == 3

      {:ok, unplaced} = Game.unplace_worker(on_route, 2)
      assert trader_travel(unplaced, 2) == 3

      # between other places, travel.weeks (0 here)
      {:ok, farm_to_tower} = Game.place_worker(game, 1, 2)
      assert trader_travel(farm_to_tower, 1) == 0
    end

    test "takes way.grain_trade.capacity traders of any colour", %{game: game} do
      game = with_unplaced(game, 9)

      game =
        Enum.reduce(101..108, game, fn id, game ->
          {:ok, game} = Game.place_worker(game, id, 3)
          game
        end)

      assert Game.place_worker(game, 109, 3) == {:error, :full}
    end

    test "a trader travels 3 weeks, then trades every week: price paid, food in, mana, no production",
         %{game: game} do
      {:ok, game} = Game.place_worker(game, 2, 3)
      {reports, game} = EngineFixtures.run_weeks(game, 3)

      for report <- reports do
        assert report.traders == 1
        assert report.gold_to_trade == 0
        assert report.food_from_trade == 0
        assert report.mana == %{green: 3, yellow: 0, blue: 0, red: 0, violet: 0}
      end

      gold = game.stocks.gold
      food = game.stocks.food
      eaten = 3_000 * length(game.workers)
      {:ok, report, game} = Game.run_week(game)

      # red is opposite yellow: 12 × 1000 ÷ 500
      assert report.gold_to_trade == 24_000
      assert report.food_from_trade == 40_000
      assert report.traders == 1
      assert report.mana == %{green: 4, yellow: 2, blue: 0, red: 0, violet: 0}
      assert report.production.defence == 0
      assert game.stocks.gold == gold - 24_000
      # the farmer's food, minus what everyone eats, plus the route's 40
      assert game.stocks.food == food + report.production.food - eaten + 40_000

      # the forecasts repeat the change, the trade included
      assert Forecast.gold(game).change == -24_000
      assert Forecast.food(game).change == report.production.food - eaten + 40_000
    end

    test "the trade food is bought: happiness doesn't change it", %{game: game} do
      {:ok, game} = Game.place_worker(game, 2, 3)
      {_reports, game} = EngineFixtures.run_weeks(game, 3)
      {:ok, report, _game} = Game.run_week(game)

      assert report.happiness.step != 0
      assert report.food_from_trade == 40_000
    end

    test "short of gold: in the order placed; a trader who can't pay brings nothing and stays",
         %{game: game} do
      # red (24) placed first, then green (16): 30 gold pays red only
      game = %{game | stocks: %{game.stocks | gold: 30_000}}
      {:ok, game} = Game.place_worker(game, 2, 3)
      {:ok, game} = Game.place_worker(game, 1, 3)
      {_reports, game} = EngineFixtures.run_weeks(game, 3)
      {:ok, report, game} = Game.run_week(game)

      assert report.gold_to_trade == 24_000
      assert report.food_from_trade == 40_000
      assert report.traders == 2
      assert game.stocks.gold == 6_000

      {:ok, report, game} = Game.run_week(game)
      assert report.gold_to_trade == 0
      assert report.food_from_trade == 0
      assert game.workers |> Enum.filter(&(&1.id in [1, 2])) |> Enum.all?(&(&1.place == 3))
    end

    test "a trader who leaves and comes back goes to the end of the queue", %{game: game} do
      {:ok, game} = Game.place_worker(game, 2, 3)
      {:ok, game} = Game.place_worker(game, 1, 3)
      {:ok, game} = Game.unplace_worker(game, 2)
      game = %{game | workers: Enum.map(game.workers, &%{&1 | travel: 0})}
      {:ok, game} = Game.place_worker(game, 2, 3)

      assert %Trade{traders: [1, 2]} = Trades.route(game.places, :grain_trade)
    end

    test "exports gold_to_trade and traders, food_from_trade the route's food", %{game: game} do
      {:ok, game} = Game.place_worker(game, 2, 3)
      {reports, _game} = EngineFixtures.run_weeks(game, 4)
      rows = reports |> Reporting.to_csv() |> String.split("\n", trim: true) |> tl()

      assert rows |> Enum.at(2) |> String.ends_with?(",0,0,0,0,0,1")
      assert rows |> Enum.at(3) |> String.ends_with?(",40000,0,0,24000,1")
    end
  end

  describe "R17: hunting" do
    setup do
      %{game: game([])}
    end

    test "the party is away 18 weeks: eats, makes 2 red and 1 green mana each, produces and defends nothing; then the haul",
         %{game: game} do
      {:ok, game} = Game.start_hunt(game, [1, 2])
      assert game.suspicion == 1
      {reports, game} = EngineFixtures.run_weeks(game, 17)

      for report <- reports do
        assert report.mana == %{green: 2, yellow: 0, blue: 0, red: 4, violet: 0}
        assert report.production.food == 0
        assert report.production.defence == 0
        assert report.food_from_hunting == 0
        assert report.suspicion == 1
      end

      assert Game.unplace_worker(game, 2) == {:error, :away}
      {:ok, report, game} = Game.run_week(game)

      # green 90 + red 180 = 270 food at mid luck
      assert [%{hunters: 2, luck: luck, food: food}] = report.hunts_returned
      assert food == div(270_000 * Map.fetch!(game.config.way_hunting_luck, luck), 1000)
      assert report.food_from_hunting == food
      # every week short (nobody farms), so 0 after eating, then the haul
      assert report.food_short
      assert report.food_left == food
      assert Enum.all?(game.workers |> Enum.filter(&(&1.id in [1, 2])), &is_nil(&1.place))
      refute Enum.any?(game.places, &match?(%Expedition{}, &1))
    end

    test "the same seed and the same actions replay the same luck and births", %{game: game} do
      {:ok, game} = Game.start_hunt(game, [1])
      {first, _} = EngineFixtures.run_weeks(game, 30)
      {again, _} = EngineFixtures.run_weeks(game, 30)

      assert first == again
    end

    test "a hunt leaves the births before its return as they were" do
      # plenty of food, so taking the farmer blocks no birth: only the draws could differ
      game = game(start_food: 10_000)
      {:ok, hunting} = Game.start_hunt(game, [1])
      {with_hunt, _} = EngineFixtures.run_weeks(hunting, 18)
      {without, _} = EngineFixtures.run_weeks(game, 18)

      births = &Enum.map(&1, fn report -> report.newborn && report.newborn.colour end)

      assert births.(with_hunt) == births.(without)
      assert Enum.count(births.(with_hunt), & &1) == 9
    end

    test "exports food_from_hunting in the return week and the suspicion", %{game: game} do
      {:ok, game} = Game.start_hunt(game, [2])
      {reports, _game} = EngineFixtures.run_weeks(game, 18)
      rows = reports |> Reporting.to_csv() |> String.split("\n", trim: true) |> tl()
      food = List.last(reports).food_from_hunting

      assert food > 0
      assert rows |> Enum.at(16) |> String.ends_with?(",0,1,0,0")
      assert rows |> Enum.at(17) |> String.ends_with?(",#{food},1,0,0")
    end
  end

  defp with_unplaced(game, count) do
    extra =
      for i <- 1..count,
          do: %Worker{id: 100 + i, colour: :blue, place: nil}

    %{game | workers: game.workers ++ extra}
  end
end
