defmodule MyLiege.Engine.TrainingTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Building, Game, Manameter, Worker}
  alias MyLiege.EngineFixtures

  # green farmer (id 1) at 80% green; red soldier (id 2) at 10% red
  setup do
    config = EngineFixtures.config()
    {:ok, game} = config |> Game.new(1) |> Game.construct(:guildhouse, config)
    game = game |> EngineFixtures.run_weeks(2, config) |> elem(1)
    guildhouse = Enum.find(game.buildings, &(&1.type == :guildhouse))
    %{config: config, game: game, guildhouse: guildhouse}
  end

  describe "R5: training in the guildhouse" do
    test "the guildhouse can be built and is neutral", %{guildhouse: guildhouse} do
      assert guildhouse.ready_week == 2
      assert Building.colour(guildhouse) == nil
    end

    test "a worker trains for 4 weeks, then returns unplaced and trained", context do
      %{config: config, game: game, guildhouse: guildhouse} = context
      {:ok, game} = Game.place_worker(game, 1, guildhouse.id, config)
      {reports, game} = EngineFixtures.run_weeks(game, 4, config)

      assert Enum.map(reports, &Enum.map(&1.trained, fn w -> w.id end)) == [[], [], [], [1]]
      assert %Worker{trained: true, building: nil, colour: :green} = find(game, 1)
    end

    test "a trainee produces nothing and makes no mana, but eats", context do
      %{config: config, game: game, guildhouse: guildhouse} = context
      {:ok, game} = Game.place_worker(game, 1, guildhouse.id, config)
      {:ok, report, _game} = Game.run_week(game, config)

      assert report.production.food == 0
      assert report.mana.green == 0
      assert report.food_left == game.stocks.food - length(game.workers) * 3_000
    end

    test "the colour must have at least 30% of the Manameter when placed", context do
      %{config: config, game: game, guildhouse: guildhouse} = context

      assert Game.place_worker(game, 2, guildhouse.id, config) == {:error, :below_threshold}

      game = %{game | manameter: %Manameter{green: 700, blue: 0, red: 300, yellow: 0, violet: 0}}
      assert {:ok, _game} = Game.place_worker(game, 2, guildhouse.id, config)
    end

    test "a trained worker can't train again", context do
      %{config: config, game: game, guildhouse: guildhouse} = context
      game = %{game | workers: Enum.map(game.workers, &%{&1 | trained: true})}

      assert Game.place_worker(game, 1, guildhouse.id, config) == {:error, :already_trained}
    end

    test "the guildhouse takes only one worker", context do
      %{config: config, game: game, guildhouse: guildhouse} = context
      game = %{game | manameter: %Manameter{green: 700, blue: 0, red: 300, yellow: 0, violet: 0}}
      {:ok, game} = Game.place_worker(game, 1, guildhouse.id, config)

      assert Game.place_worker(game, 2, guildhouse.id, config) == {:error, :full}
    end

    test "moving a trainee out loses its progress", context do
      %{config: config, game: game, guildhouse: guildhouse} = context
      {:ok, game} = Game.place_worker(game, 1, guildhouse.id, config)
      {_reports, game} = EngineFixtures.run_weeks(game, 3, config)
      {:ok, game} = Game.unplace_worker(game, 1)
      {:ok, game} = Game.place_worker(game, 1, guildhouse.id, config)
      {reports, game} = EngineFixtures.run_weeks(game, 3, config)

      assert Enum.all?(reports, &(&1.trained == []))
      refute find(game, 1).trained
    end
  end

  defp find(game, id), do: Enum.find(game.workers, &(&1.id == id))
end
