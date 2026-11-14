defmodule MyLiege.Engine.WaysTest do
  @moduledoc "R13–R18 through `Game`: the granary and the improved plough over whole weeks."
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Forecast, Game, Worker}
  alias MyLiege.Engine.Place.{Expedition, Trade}
  alias MyLiege.Engine.Rules.{Books, Hunting, Production, Trades, Ways}
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

      assert String.ends_with?(row, ",false,true,5000,0,0,0,0,0,0,false")
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

      assert String.ends_with?(row, ",true,false,0,0,0,0,0,0,0,false")
    end
  end

  describe "R16: grain trade route" do
    # farm (1) with green worker 1, tower (2) with red worker 2; the route (3) and the camp
    # (4) open
    setup do
      game = game(start_gold: 1000, start_food: 1000)
      {places, [:grain_trade, :hunting]} = Ways.open(game.places, game.books)
      %{game: %{game | places: places}}
    end

    defp trader_travel(game, id), do: Enum.find(game.workers, &(&1.id == id)).travel

    test "opens in the Books step once the books unlock it, once" do
      game = game([])
      {:ok, report, game} = Game.run_week(game)

      assert report.ways_opened == [:grain_trade, :hunting]
      assert [%Trade{id: 3, traders: []}] = for(%Trade{} = t <- game.places, do: t)
      assert [%Expedition{id: 4}] = for(%Expedition{} = e <- game.places, do: e)

      {:ok, report, game} = Game.run_week(game)
      assert report.ways_opened == []
      assert game.places |> Enum.count(&match?(%Trade{}, &1)) == 1
      assert game.places |> Enum.count(&match?(%Expedition{}, &1)) == 1
    end

    test "stays closed without the books" do
      game = %{game([]) | books: Books.none()}
      {_reports, game} = EngineFixtures.run_weeks(game, 2)

      refute Enum.any?(game.places, &match?(%Trade{}, &1))
      refute Enum.any?(game.places, &match?(%Expedition{}, &1))
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

      assert rows |> Enum.at(2) |> String.ends_with?(",0,0,0,0,0,1,0,false")
      assert rows |> Enum.at(3) |> String.ends_with?(",40000,0,0,24000,1,0,false")
    end
  end

  describe "R17: hunting camp" do
    # farm (1) with green worker 1, tower (2) with red worker 2; the route (3) and the camp
    # (4) open; plenty of food
    setup do
      game = game(start_food: 10_000)
      {places, _opened} = Ways.open(game.places, game.books)
      %{game: %{game | places: places}}
    end

    defp camp(game), do: Hunting.camp(game.places)

    test "travel there and away is way.hunting.travel_weeks; from the route too", %{game: game} do
      {:ok, at_camp} = Game.place_worker(game, 2, 4)
      assert Enum.find(at_camp.workers, &(&1.id == 2)).travel == 3

      {:ok, back} = Game.place_worker(at_camp, 2, 2)
      assert Enum.find(back.workers, &(&1.id == 2)).travel == 3

      {:ok, unplaced} = Game.unplace_worker(at_camp, 2)
      assert Enum.find(unplaced.workers, &(&1.id == 2)).travel == 3
    end

    test "takes way.hunting.max_party hunters of any colour", %{game: game} do
      game = with_unplaced(game, 5)

      game =
        Enum.reduce(101..104, game, fn id, game ->
          {:ok, game} = Game.place_worker(game, id, 4)
          game
        end)

      assert Game.place_worker(game, 105, 4) == {:error, :full}
    end

    test "a hunter travels 3 weeks, then fills the bag; the 6th hunting week is a haul",
         %{game: game} do
      {:ok, game} = Game.place_worker(game, 2, 4)
      {reports, game} = EngineFixtures.run_weeks(game, 8)

      for report <- Enum.take(reports, 3) do
        assert report.mana == %{green: 3, yellow: 0, blue: 0, red: 0, violet: 0}
        assert report.hunters == 1
      end

      for report <- Enum.drop(reports, 3) do
        assert report.mana == %{green: 4, yellow: 0, blue: 0, red: 2, violet: 0}
        assert report.production.defence == 0
        assert report.haul == nil
      end

      # weeks 4 to 8: five hunting weeks of 15
      assert %Expedition{bag: 75_000, weeks: 5} = camp(game)

      food = game.stocks.food
      eaten = 3_000 * length(game.workers)
      {:ok, report, game} = Game.run_week(game)

      assert %{hunters: 1, luck: luck, food: haul, suspicion_change: 0} = report.haul
      assert haul == Hunting.haul(90_000, luck, game.config)
      assert report.food_from_hunting == haul
      assert %Expedition{bag: 0, weeks: 0} = camp(game)
      assert game.stocks.food == food + report.production.food - eaten + haul
    end

    test "the last hunter leaving loses the bag", %{game: game} do
      {:ok, game} = Game.place_worker(game, 2, 4)
      {_reports, game} = EngineFixtures.run_weeks(game, 5)
      assert camp(game).bag == 30_000

      {:ok, game} = Game.unplace_worker(game, 2)
      assert %Expedition{bag: 0, weeks: 0} = camp(game)
    end

    test "the same seed and the same placements replay the same luck and births", %{game: game} do
      {:ok, game} = Game.place_worker(game, 2, 4)
      {first, _} = EngineFixtures.run_weeks(game, 30)
      {again, _} = EngineFixtures.run_weeks(game, 30)

      assert first == again
      assert Enum.count(first, & &1.haul) == 4
    end

    test "the births up to the first haul are as without hunting", %{game: game} do
      {:ok, hunting} = Game.place_worker(game, 2, 4)
      {:ok, idle} = Game.unplace_worker(game, 2)
      {with_camp, _} = EngineFixtures.run_weeks(hunting, 9)
      {without, _} = EngineFixtures.run_weeks(idle, 9)

      births = &Enum.map(&1, fn report -> report.newborn && report.newborn.colour end)

      assert List.last(with_camp).haul
      assert births.(with_camp) == births.(without)
      assert Enum.count(births.(with_camp), & &1) == 5
    end

    test "R18: an idle block of 6 weeks lowers the suspicion", %{game: game} do
      {reports, _game} = EngineFixtures.run_weeks(%{game | suspicion: 2}, 12)

      assert Enum.map(reports, & &1.suspicion) ==
               List.duplicate(2, 5) ++ List.duplicate(1, 6) ++ [0]
    end

    test "exports food_from_hunting in the haul week, hunters and suspicion_miss", %{game: game} do
      {:ok, game} = Game.place_worker(game, 2, 4)
      {reports, _game} = EngineFixtures.run_weeks(game, 9)
      rows = reports |> Reporting.to_csv() |> String.split("\n", trim: true) |> tl()
      food = List.last(reports).food_from_hunting

      assert food > 0
      assert rows |> Enum.at(7) |> String.ends_with?(",0,0,0,0,1,false")
      assert rows |> Enum.at(8) |> String.ends_with?(",#{food},0,0,0,1,false")
    end
  end

  defp with_unplaced(game, count) do
    extra =
      for i <- 1..count,
          do: %Worker{id: 100 + i, colour: :blue, place: nil}

    %{game | workers: game.workers ++ extra}
  end
end
