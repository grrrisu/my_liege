defmodule MyLiege.Engine.TaxesTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.{Game, Taxes}
  alias MyLiege.EngineFixtures

  setup do
    %{config: EngineFixtures.config()}
  end

  describe "R7: taxes" do
    test "due every 24 weeks, counted 4 weeks before", %{config: config} do
      assert Enum.filter(1..144, &Taxes.due_week?(&1, config)) == [24, 48, 72, 96, 120, 144]
      assert Enum.filter(1..144, &Taxes.count_week?(&1, config)) == [20, 44, 68, 92, 116, 140]
    end

    test "10 gold per worker", %{config: config} do
      assert Taxes.assess(List.duplicate(:worker, 12), config) == 120_000
    end

    test "paid in full, skipped on purpose, or missed; no partial payments" do
      assert Taxes.settle(150_000, 120_000, true) == {:paid, 30_000}
      assert Taxes.settle(150_000, 120_000, false) == {:skipped, 150_000}
      assert Taxes.settle(100_000, 120_000, true) == {:missed, 100_000}
    end

    test "the first miss is forgiven, the second ends the game", %{config: config} do
      refute Taxes.game_over?(1, config)
      assert Taxes.game_over?(2, config)
    end
  end

  describe "R7 in the week" do
    test "the village is counted at the start of week 20, before its birth", %{config: config} do
      # a birth in every week, so week 20 has one
      config = %{config | birth_interval_weeks: 1, starting_food: 10_000}
      game = run_weeks(Game.new(config, 1), 19, config)
      workers_before = length(game.workers)
      {[report], game} = EngineFixtures.run_weeks(game, 1, config)

      assert report.newborn
      assert report.tax_due == workers_before * 10_000
      assert game.tax_due == report.tax_due
    end

    test "the due week waits for the player's decision", %{config: config} do
      game = run_weeks(Game.new(config, 1), 23, config)

      assert Game.tax_decision_due?(game, config)
      assert Game.run_week(game, config) == {:error, :tax_undecided}
      assert {:ok, _game} = Game.decide_tax(game, true, config)
    end

    test "no decision outside the week before a due week", %{config: config} do
      game = run_weeks(Game.new(config, 1), 22, config)

      refute Game.tax_decision_due?(game, config)
      assert Game.decide_tax(game, true, config) == {:error, :no_tax_due}
    end

    test "the amount fixed at the count is paid in week 24", %{config: config} do
      game = run_weeks(Game.new(config, 1), 19, config)
      due = length(game.workers) * 10_000
      {reports, game} = EngineFixtures.run_weeks(game, 5, config)
      week_20 = Enum.find(reports, &(&1.week == 20))
      week_24 = Enum.find(reports, &(&1.week == 24))

      assert week_20.tax_due == due
      assert week_24.tax == :paid
      assert week_24.gold == 100_000 - due
      assert game.tax_due == nil
    end

    test "not enough gold: missed, gold kept, first miss forgiven", %{config: config} do
      config = %{config | starting_gold: 0}
      game = EngineFixtures.game_without_demands(config, 1)
      {reports, game} = EngineFixtures.run_weeks(game, 24, config)
      week_24 = List.last(reports)

      assert week_24.tax == :missed
      assert week_24.gold == 0
      assert game.misses == 1
      refute week_24.game_over
    end

    test "the player can skip a payment on purpose; the decision resets", %{config: config} do
      config = %{config | starting_gold: 1000}
      game = run_weeks(Game.new(config, 1), 23, config)
      {:ok, game} = Game.decide_tax(game, false, config)
      {:ok, report, game} = Game.run_week(game, config)

      assert report.tax == :skipped
      assert report.gold == 1_000_000
      assert game.pay_tax == nil
    end

    test "a second miss ends the game and blocks further weeks", %{config: config} do
      config = %{config | starting_gold: 0}
      game = EngineFixtures.game_without_demands(config, 1)
      {reports, game} = EngineFixtures.run_weeks(game, 48, config)

      assert List.last(reports).tax == :missed
      assert List.last(reports).game_over
      assert game.game_over
      assert Game.run_week(game, config) == {:error, :game_over}
    end
  end

  defp run_weeks(game, count, config) do
    game |> EngineFixtures.run_weeks(count, config) |> elem(1)
  end
end
