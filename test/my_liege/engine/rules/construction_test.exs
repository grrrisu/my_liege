defmodule MyLiege.Engine.Rules.ConstructionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, Manameter, Place, Worker}
  alias MyLiege.Engine.Place.{Building, Project}
  alias MyLiege.Engine.Rules.Construction
  alias MyLiege.EngineFixtures

  # 4 work, at most 2 builders, 1 week of travel; workers 1 (green) and 2 (red) start on the
  # farm (1) and the tower (2); the market site has id 3
  setup do
    config = EngineFixtures.config(build_work: 4, build_capacity: 2, travel_weeks: 1)
    game = EngineFixtures.game_without_demands(config, 1)
    {:ok, game} = Game.construct(game, :market)
    %{config: config, game: game, site: List.last(game.places)}
  end

  describe "R2 builders" do
    test "an ordered building is a site without progress; the price is paid at once", context do
      %{config: config, game: game, site: site} = context

      assert %Project{id: 3, gives: {:building, :market}, progress: 0} = site
      assert site.target == config.build_work
      assert Place.colour(site) == nil
      refute Project.done?(site)
      assert game.stocks.gold == 100_000 - Game.build_cost(game)
    end

    test "the starting farm and tower are buildings and need no builders", %{game: game} do
      assert game.places |> Enum.take(2) |> Enum.all?(&match?(%Building{}, &1))
    end

    test "sites can be ordered without limit, each with its own id", %{config: config} do
      places =
        Enum.reduce(1..10, Building.starting(), fn _, places ->
          Construction.new_site(places, :market, config)
        end)

      ids = Enum.map(places, & &1.id)

      assert Enum.count(places, &match?(%Project{gives: {:building, :market}}, &1)) == 10
      assert Enum.uniq(ids) == ids
    end

    test "a site never takes more than build_capacity builders, of any colour", context do
      %{game: game, site: site} = context
      game = add_unplaced(game, :blue)
      game = place_builders(game, site)

      assert Game.place_worker(game, 3, site.id) == {:error, :full}

      {weeks, _game} = weekly(game, site, 2)
      assert Enum.map(weeks, & &1.builders) == [2, 2]
      assert Enum.map(weeks, & &1.progress) == [0, 2]
    end

    test "2 builders finish in 2 weeks", context do
      %{game: game, site: site} = context
      game = place_builders(game, site)
      {weeks, _game} = weekly(game, site, 3)

      # week 1 travel, weeks 2 and 3 building
      assert Enum.map(weeks, & &1.progress) == [0, 2, nil]
      assert Enum.map(weeks, & &1.builders) == [2, 2, 0]
    end

    test "1 builder finishes in 4 weeks", context do
      %{game: game, site: site} = context
      {:ok, game} = Game.place_worker(game, 1, site.id)
      {weeks, game} = weekly(game, site, 5)

      # week 1 travel, weeks 2 to 5 building
      assert Enum.map(weeks, & &1.progress) == [0, 1, 2, 3, nil]
      assert %Building{blueprint: %{type: :market}} = List.last(game.places)
    end

    test "a builder still travelling at the start of the week adds nothing", context do
      %{game: game, site: site} = context
      {:ok, game} = Game.place_worker(game, 1, site.id)
      {_reports, game} = EngineFixtures.run_weeks(game, 1)
      {:ok, game} = Game.place_worker(game, 2, site.id)

      # week 2: worker 1 has arrived, worker 2 travels; week 3: both
      {weeks, _game} = weekly(game, site, 2)
      assert Enum.map(weeks, & &1.progress) == [1, 3]
    end

    test "a builder leaving keeps the progress; the site goes on with the other", context do
      %{game: game, site: site} = context
      game = place_builders(game, site)
      {_reports, game} = EngineFixtures.run_weeks(game, 2)
      assert find_place(game, site.id).progress == 2

      {:ok, game} = Game.place_worker(game, 1, 1)
      assert find_place(game, site.id).progress == 2
      gold = game.stocks.gold

      # worker 2 alone: 1 work in week 3, the 4th in week 4
      {weeks, game} = weekly(game, site, 2)
      assert Enum.map(weeks, & &1.progress) == [3, nil]
      assert game.stocks.gold == gold
    end

    test "unplacing a builder keeps the progress", context do
      %{game: game, site: site} = context
      game = place_builders(game, site)
      {_reports, game} = EngineFixtures.run_weeks(game, 2)
      {:ok, game} = Game.unplace_worker(game, 2)

      assert find_place(game, site.id).progress == 2
    end

    test "the finished building has a new id; its builders are unplaced and travel", context do
      %{game: game, site: site} = context
      game = place_builders(game, site)
      {_reports, game} = EngineFixtures.run_weeks(game, 3)

      assert find_place(game, site.id) == nil
      assert %Building{id: 4, blueprint: %{type: :market}} = List.last(game.places)

      assert [%Worker{place: nil, travel: 1}, %Worker{place: nil, travel: 1}] =
               Enum.take(game.workers, 2)
    end

    test "workers on a king's demand project are not counted as builders", context do
      %{game: game, site: site} = context
      project = EngineFixtures.new_demand_project(4, :culture)
      game = %{game | places: game.places ++ [project]}
      {:ok, game} = Game.place_worker(game, 1, site.id)
      {:ok, game} = Game.place_worker(game, 2, project.id)
      {[_week_1, week_2], _game} = EngineFixtures.run_weeks(game, 2)

      assert week_2.builders == 1
    end

    test "builders produce nothing and no mana, but eat", context do
      %{game: game, site: site} = context
      game = place_builders(game, site)
      {[week_1], game} = EngineFixtures.run_weeks(game, 1)
      {[week_2], _game} = EngineFixtures.run_weeks(game, 1)

      assert week_2.production == %{food: 0, knowledge: 0, defence: 0, gold: 0, culture: 0}
      assert week_2.mana == %{green: 0, blue: 0, red: 0, yellow: 0, violet: 0}
      assert week_2.food_left == week_1.food_left - length(game.workers) * 3_000
    end

    test "a worker on a guildhouse site builds; it doesn't train", context do
      %{game: game} = context
      {:ok, game} = Game.construct(game, :guildhouse)
      site = List.last(game.places)
      game = %{game | manameter: %Manameter{green: 1000, blue: 0, red: 0, yellow: 0, violet: 0}}

      {:ok, game} = Game.place_worker(game, 2, site.id)

      assert %Worker{place: building, training_started: nil} = find_worker(game, 2)
      assert building == site.id
    end

    test "a guildhouse site is built and then released like any site", context do
      %{game: game} = context
      {:ok, game} = Game.construct(game, :guildhouse)
      site = List.last(game.places)
      game = place_builders(game, site)
      {reports, game} = EngineFixtures.run_weeks(game, 4)

      assert %Building{id: 5, blueprint: %{type: :guildhouse}} = List.last(game.places)
      assert Enum.all?(reports, &(&1.trained == []))
      assert Enum.all?(Enum.take(game.workers, 2), &(&1.place == nil and not &1.trained))
    end

    test "a finished building at week M takes workers at M; they produce from M + 2", context do
      %{game: game, site: site} = context
      game = place_builders(game, site)
      {_reports, game} = EngineFixtures.run_weeks(game, 4)
      # finished at the end of week 3; the builders arrive back unplaced in week 4
      market = List.last(game.places)
      {:ok, game} = Game.place_worker(game, 1, market.id)
      {[week_5, week_6], _game} = EngineFixtures.run_weeks(game, 2)

      assert week_5.production.gold == 0
      assert week_6.production.gold > 0
    end
  end

  defp place_builders(game, site) do
    {:ok, game} = Game.place_worker(game, 1, site.id)
    {:ok, game} = Game.place_worker(game, 2, site.id)
    game
  end

  # runs `count` weeks; for each, the site's progress (nil once it is gone) and the report's
  # arrived builders
  defp weekly(game, site, count) do
    Enum.map_reduce(1..count, game, fn _, game ->
      {[report], game} = EngineFixtures.run_weeks(game, 1)
      {%{progress: progress(find_place(game, site.id)), builders: report.builders}, game}
    end)
  end

  defp progress(%Project{progress: progress}), do: progress
  defp progress(nil), do: nil

  defp add_unplaced(game, colour) do
    worker = %Worker{id: Worker.next_id(game.workers), colour: colour}
    %{game | workers: game.workers ++ [worker]}
  end

  defp find_place(game, id), do: Enum.find(game.places, &(&1.id == id))
  defp find_worker(game, id), do: Enum.find(game.workers, &(&1.id == id))
end
