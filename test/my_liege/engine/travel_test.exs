defmodule MyLiege.Engine.TravelTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, Taxes, Worker}
  alias MyLiege.EngineFixtures

  # 1 week of travel; worker 1 (green) on the farm (id 1), worker 2 (red) in the tower (id 2);
  # week 1 brings an unplaced green newborn (id 3)
  setup do
    config = EngineFixtures.config(travel_weeks: 1)
    game = EngineFixtures.game_without_demands(config, 1)
    {[_week_1], game} = EngineFixtures.run_weeks(game, 1, config)
    %{config: config, game: game}
  end

  describe "R2 travel" do
    test "starting workers and newborns have arrived", %{game: game} do
      assert Enum.map(game.workers, & &1.travel) == [0, 0, 0]
    end

    test "a worker placed at week N produces nothing in N + 1 and works from N + 2", context do
      %{config: config, game: game} = context
      {:ok, game} = Game.place_worker(game, 3, 1, config)
      assert find(game, 3).travel == 1

      {[week_2, week_3], _game} = EngineFixtures.run_weeks(game, 2, config)

      assert week_2.production.food == 9_000
      assert week_3.production.food == 18_000
    end

    test "a travelling worker makes no mana", context do
      %{config: config, game: game} = context
      {:ok, game} = Game.place_worker(game, 3, 1, config)
      {[week_2, week_3], _game} = EngineFixtures.run_weeks(game, 2, config)

      assert week_2.mana.green == 3
      assert week_3.mana.green == 6
    end

    test "moving directly between buildings costs travel_weeks once", context do
      %{config: config, game: game} = context
      {:ok, game} = Game.place_worker(game, 1, 2, config)

      assert %Worker{building: 2, travel: 1} = find(game, 1)
    end

    test "moving a travelling worker starts its travel again", context do
      %{config: config, game: game} = context
      {:ok, game} = Game.place_worker(game, 3, 1, config)
      {:ok, game} = Game.place_worker(game, 3, 2, config)
      {[week_2, week_3], _game} = EngineFixtures.run_weeks(game, 2, config)

      assert find(game, 3).travel == 1
      assert week_2.production.defence == 3_000
      assert week_3.production.defence > 3_000
    end

    test "an unplaced worker can only be placed once it has arrived", context do
      %{config: config, game: game} = context
      {:ok, game} = Game.unplace_worker(game, 1, config)

      assert %Worker{building: nil, travel: 1} = find(game, 1)
      assert Game.place_worker(game, 1, 1, config) == {:error, :travelling}

      {_reports, game} = EngineFixtures.run_weeks(game, 1, config)
      assert {:ok, _game} = Game.place_worker(game, 1, 1, config)
    end

    test "travelling workers eat and count for taxes", context do
      %{config: config, game: game} = context
      {:ok, game} = Game.place_worker(game, 3, 1, config)
      {[week_2], _game} = EngineFixtures.run_weeks(game, 1, config)

      assert week_2.food_left == game.stocks.food + week_2.production.food - 3 * 3_000
      assert Taxes.assess(game.workers, config) == 3 * 10_000
    end

    test "travel goes down by 1 a week; the report counts travellers at its end", context do
      %{game: game} = context
      config = EngineFixtures.config(travel_weeks: 2)
      {:ok, game} = Game.place_worker(game, 3, 1, config)
      {[week_2, week_3], game} = EngineFixtures.run_weeks(game, 2, config)

      assert {week_2.travelling, week_3.travelling} == {1, 0}
      assert {week_2.production.food, week_3.production.food} == {9_000, 9_000}
      assert find(game, 3).travel == 0
    end
  end

  defp find(game, id), do: Enum.find(game.workers, &(&1.id == id))
end
