defmodule MyLiege.Engine.Rules.ConstructionTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, Manameter, Worker}
  alias MyLiege.Engine.Place.Building
  alias MyLiege.EngineFixtures

  # 2 builders, 1 week of travel, 2 construction weeks; workers 1 (green) and 2 (red) start
  # on the farm and the tower
  setup do
    config = EngineFixtures.config(build_builders: 2, travel_weeks: 1)
    game = EngineFixtures.game_without_demands(config, 1)
    {:ok, game} = Game.construct(game, :market)
    %{config: config, game: game, site: List.last(game.places)}
  end

  describe "R2 builders" do
    test "an ordered building is a site without progress; the price is paid at once", context do
      %{game: game, site: site} = context

      assert Building.site?(site)
      assert %Building{ready_week: nil, progress: 0} = site
      assert game.stocks.gold == 100_000 - Game.build_cost(game)
      refute Building.ready?(site, 99)
    end

    test "the starting farm and tower are finished and need no builders", %{game: game} do
      assert game.places |> Enum.take(2) |> Enum.all?(&(not Building.site?(&1)))
    end

    test "a site takes build_builders builders of any colour", context do
      %{game: game, site: site} = context
      game = add_unplaced(game, :blue)
      {:ok, game} = Game.place_worker(game, 1, site.id)
      {:ok, game} = Game.place_worker(game, 2, site.id)

      assert Game.place_worker(game, 3, site.id) == {:error, :full}
    end

    test "with all builders arrived, it is finished after build_weeks weeks", context do
      %{game: game, site: site} = context
      game = place_builders(game, site)
      {weeks, game} = weekly(game, site, 3)

      # week 1 travel, weeks 2 and 3 building
      assert Enum.map(weeks, & &1.progress) == [0, 1, 2]
      assert %Building{ready_week: 4, progress: 2} = find_place(game, site.id)
      assert Enum.map(weeks, & &1.builders) == [2, 2, 0]
    end

    test "finished builders become unplaced and travel", context do
      %{game: game, site: site} = context
      game = place_builders(game, site)
      {_reports, game} = EngineFixtures.run_weeks(game, 3)

      assert [%Worker{place: nil, travel: 1}, %Worker{place: nil, travel: 1}] =
               Enum.take(game.workers, 2)
    end

    test "with too few builders the site doesn't advance", context do
      %{game: game, site: site} = context
      {:ok, game} = Game.place_worker(game, 1, site.id)
      {_reports, game} = EngineFixtures.run_weeks(game, 5)

      assert %Building{ready_week: nil, progress: 0} = find_place(game, site.id)
    end

    test "moving a builder off resets the progress; it restarts once all are back", context do
      %{game: game, site: site} = context
      game = place_builders(game, site)
      {_reports, game} = EngineFixtures.run_weeks(game, 2)
      assert find_place(game, site.id).progress == 1

      {:ok, game} = Game.place_worker(game, 1, 1)
      assert find_place(game, site.id).progress == 0
      gold = game.stocks.gold

      {:ok, game} = Game.place_worker(game, 1, site.id)
      # travel in week 3, building in weeks 4 and 5
      {weeks, game} = weekly(game, site, 3)

      assert Enum.map(weeks, & &1.progress) == [0, 1, 2]
      assert find_place(game, site.id).ready_week == 6
      assert game.stocks.gold == gold
    end

    test "unplacing a builder resets the progress", context do
      %{game: game, site: site} = context
      game = place_builders(game, site)
      {_reports, game} = EngineFixtures.run_weeks(game, 2)
      {:ok, game} = Game.unplace_worker(game, 2)

      assert find_place(game, site.id).progress == 0
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

      assert find_place(game, site.id).ready_week == 4
      assert Enum.all?(reports, &(&1.trained == []))
      assert Enum.all?(Enum.take(game.workers, 2), &(&1.place == nil and not &1.trained))
    end

    test "a finished building at week M takes workers at M; they produce from M + 2", context do
      %{game: game, site: site} = context
      game = place_builders(game, site)
      {_reports, game} = EngineFixtures.run_weeks(game, 4)
      # finished at the end of week 3; the builders arrive back unplaced in week 4
      {:ok, game} = Game.place_worker(game, 1, site.id)
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

  # runs `count` weeks; for each, the site's progress and the report's arrived builders
  defp weekly(game, site, count) do
    Enum.map_reduce(1..count, game, fn _, game ->
      {[report], game} = EngineFixtures.run_weeks(game, 1)
      {%{progress: find_place(game, site.id).progress, builders: report.builders}, game}
    end)
  end

  defp add_unplaced(game, colour) do
    worker = %Worker{id: Worker.next_id(game.workers), colour: colour}
    %{game | workers: game.workers ++ [worker]}
  end

  defp find_place(game, id), do: Enum.find(game.places, &(&1.id == id))
  defp find_worker(game, id), do: Enum.find(game.workers, &(&1.id == id))
end
