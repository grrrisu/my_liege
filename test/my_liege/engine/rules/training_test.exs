defmodule MyLiege.Engine.Rules.TrainingTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Building, Game, Manameter, Worker}
  alias MyLiege.EngineFixtures

  # green farmer (id 1) at 80% green; red soldier (id 2) at 10% red
  setup do
    config = EngineFixtures.config()
    game = with_guildhouse(config)
    %{config: config, game: game, guildhouse: guildhouse(game)}
  end

  describe "R5: training in the guildhouse" do
    test "the guildhouse can be built and is neutral", %{guildhouse: guildhouse} do
      assert guildhouse.ready_week == 3
      assert Building.colour(guildhouse) == nil
    end

    test "a worker trains for 4 weeks, then returns unplaced and trained", context do
      %{game: game, guildhouse: guildhouse} = context
      {:ok, game} = Game.place_worker(game, 1, guildhouse.id)
      {reports, game} = EngineFixtures.run_weeks(game, 4)

      assert Enum.map(reports, &Enum.map(&1.trained, fn w -> w.id end)) == [[], [], [], [1]]
      assert %Worker{trained: true, building: nil, colour: :green} = find(game, 1)
    end

    test "a trainee produces nothing and makes no mana, but eats", context do
      %{game: game, guildhouse: guildhouse} = context
      {:ok, game} = Game.place_worker(game, 1, guildhouse.id)
      {:ok, report, _game} = Game.run_week(game)

      assert report.production.food == 0
      assert report.mana.green == 0
      assert report.food_left == game.stocks.food - length(game.workers) * 3_000
    end

    test "the colour must have at least 30% of the Manameter when placed", context do
      %{game: game, guildhouse: guildhouse} = context

      assert Game.place_worker(game, 2, guildhouse.id) == {:error, :below_threshold}

      game = %{game | manameter: %Manameter{green: 700, blue: 0, red: 300, yellow: 0, violet: 0}}
      assert {:ok, _game} = Game.place_worker(game, 2, guildhouse.id)
    end

    test "a trained worker can't train again", context do
      %{game: game, guildhouse: guildhouse} = context
      game = %{game | workers: Enum.map(game.workers, &%{&1 | trained: true})}

      assert Game.place_worker(game, 1, guildhouse.id) == {:error, :already_trained}
    end

    test "the guildhouse takes only one worker", context do
      %{game: game, guildhouse: guildhouse} = context
      game = %{game | manameter: %Manameter{green: 700, blue: 0, red: 300, yellow: 0, violet: 0}}
      {:ok, game} = Game.place_worker(game, 1, guildhouse.id)

      assert Game.place_worker(game, 2, guildhouse.id) == {:error, :full}
    end

    test "moving a trainee out loses its progress", context do
      %{game: game, guildhouse: guildhouse} = context
      {:ok, game} = Game.place_worker(game, 1, guildhouse.id)
      {_reports, game} = EngineFixtures.run_weeks(game, 3)
      {:ok, game} = Game.unplace_worker(game, 1)
      {:ok, game} = Game.place_worker(game, 1, guildhouse.id)
      {reports, game} = EngineFixtures.run_weeks(game, 3)

      assert Enum.all?(reports, &(&1.trained == []))
      refute find(game, 1).trained
    end
  end

  describe "R5: training with travel" do
    test "training starts after the travel; the trained worker travels back" do
      game = with_guildhouse(EngineFixtures.config(travel_weeks: 1))
      {:ok, game} = Game.place_worker(game, 1, guildhouse(game).id)

      # placed at week 2: travel in week 3, training in weeks 4 to 7
      assert find(game, 1).training_started == 4
      {reports, game} = EngineFixtures.run_weeks(game, 5)

      assert Enum.map(reports, &Enum.map(&1.trained, fn w -> w.id end)) == [[], [], [], [], [1]]
      assert %Worker{trained: true, building: nil, travel: 1} = find(game, 1)
      assert Game.place_worker(game, 1, 1) == {:error, :travelling}
    end
  end

  defp with_guildhouse(config) do
    {:ok, game} = config |> Game.new(1) |> Game.construct(:guildhouse)
    game |> EngineFixtures.run_weeks(2) |> elem(1)
  end

  defp guildhouse(game), do: Enum.find(game.buildings, &(&1.type == :guildhouse))

  defp find(game, id), do: Enum.find(game.workers, &(&1.id == id))
end
