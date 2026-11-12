defmodule MyLiege.Engine.Rules.TaxesTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.Taxes
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
      assert {:paid, 30_000, 0} = Taxes.settle(150_000, 120_000, true)
      assert {:skipped, _gold, _taken} = Taxes.settle(150_000, 120_000, false)
      assert {:missed, _gold, _taken} = Taxes.settle(100_000, 120_000, true)
    end

    test "on a skip or a miss the king takes the gold there is, up to the tax" do
      # tax 120, gold 100: missed, and the 100 gold are taken
      assert Taxes.settle(100_000, 120_000, true) == {:missed, 0, 100_000}
      assert Taxes.settle(150_000, 120_000, false) == {:skipped, 30_000, 120_000}
      assert Taxes.settle(50_000, 120_000, false) == {:skipped, 0, 50_000}
      assert Taxes.settle(0, 120_000, true) == {:missed, 0, 0}
    end
  end

  describe "R7: grace period" do
    test "no payment and no count inside it; then the regular weeks", %{config: config} do
      config = %{config | king_grace_weeks: 24}

      assert Enum.filter(1..144, &Taxes.due_week?(&1, config)) == [48, 72, 96, 120, 144]
      assert Enum.filter(1..144, &Taxes.count_week?(&1, config)) == [44, 68, 92, 116, 140]
    end

    test "the first due week is the first regular one after it", %{config: config} do
      assert Taxes.next_due_week(0, %{config | king_grace_weeks: 24}) == 48
      assert Taxes.next_due_week(24, %{config | king_grace_weeks: 24}) == 48
      assert Taxes.next_due_week(0, %{config | king_grace_weeks: 30}) == 48
      assert Taxes.next_due_week(0, %{config | king_grace_weeks: 48}) == 72
      assert Taxes.next_due_week(0, config) == 24
    end

    test "nothing is counted or collected until week 48", %{config: config} do
      config = %{config | king_grace_weeks: 24}
      game = EngineFixtures.game_without_demands(config, 1)
      {reports, _game} = EngineFixtures.run_weeks(game, 48)

      assert Enum.filter(reports, & &1.tax_due) |> Enum.map(& &1.week) == [44]
      assert Enum.filter(reports, & &1.tax) |> Enum.map(&{&1.week, &1.tax}) == [{48, :paid}]
    end
  end

  describe "R7 in the week" do
    test "the village is counted at the start of week 20, before its birth", %{config: config} do
      # a birth in every week, so week 20 has one
      config = %{config | birth_interval_weeks: 1, start_food: 10_000}
      game = run_weeks(Game.new(config, 1), 19)
      workers_before = length(game.workers)
      {[report], game} = EngineFixtures.run_weeks(game, 1)

      assert report.newborn
      assert report.tax_due == workers_before * 10_000
      assert game.tax_due == report.tax_due
    end

    test "the due week waits for the player's decision", %{config: config} do
      game = run_weeks(Game.new(config, 1), 23)

      assert Game.tax_decision_due?(game)
      assert Game.run_week(game) == {:error, :tax_undecided}
      assert {:ok, _game} = Game.decide_tax(game, true)
    end

    test "no decision outside the week before a due week", %{config: config} do
      game = run_weeks(Game.new(config, 1), 22)

      refute Game.tax_decision_due?(game)
      assert Game.decide_tax(game, true) == {:error, :no_tax_due}
    end

    test "the amount fixed at the count is paid in week 24", %{config: config} do
      game = run_weeks(Game.new(config, 1), 19)
      due = length(game.workers) * 10_000
      {reports, game} = EngineFixtures.run_weeks(game, 5)
      week_20 = Enum.find(reports, &(&1.week == 20))
      week_24 = Enum.find(reports, &(&1.week == 24))

      assert week_20.tax_due == due
      assert week_24.tax == :paid
      assert week_24.gold == 100_000 - due
      assert game.tax_due == nil
    end

    test "not enough gold: missed, first miss forgiven", %{config: config} do
      config = %{config | start_gold: 0}
      game = EngineFixtures.game_without_demands(config, 1)
      {reports, game} = EngineFixtures.run_weeks(game, 24)
      week_24 = List.last(reports)

      assert week_24.tax == :missed
      assert week_24.gold == 0
      assert game.misses == 1
      refute week_24.game_over
    end

    test "missed: the king takes the gold there is", %{config: config} do
      # 5 gold, less than any tax
      game = EngineFixtures.game_without_demands(%{config | start_gold: 5}, 1)
      game = run_weeks(game, 23)
      gold = game.stocks.gold
      assert gold == 5_000
      {[week_24], game} = EngineFixtures.run_weeks(game, 1)

      assert week_24.tax == :missed
      assert week_24.king_took == %{gold: gold, food: 0}
      assert week_24.gold == 0
      assert game.misses == 1
    end

    test "the player can skip a payment on purpose; the decision resets", %{config: config} do
      config = %{config | start_gold: 1000}
      game = run_weeks(Game.new(config, 1), 23)
      %{tax_due: due, misses: misses} = game
      {:ok, game} = Game.decide_tax(game, false)
      {:ok, report, game} = Game.run_week(game)

      # skipped with enough gold: a miss, and the king takes the full tax
      assert report.tax == :skipped
      assert report.king_took.gold == due
      assert report.gold == 1_000_000 - due
      assert game.misses == misses + 1
      assert game.pay_tax == nil
    end

    test "a second miss ends the game and blocks further weeks", %{config: config} do
      config = %{config | start_gold: 0}
      game = EngineFixtures.game_without_demands(config, 1)
      {reports, game} = EngineFixtures.run_weeks(game, 48)

      assert List.last(reports).tax == :missed
      assert List.last(reports).game_over
      assert game.game_over
      assert Game.run_week(game) == {:error, :game_over}
    end
  end

  defp run_weeks(game, count) do
    game |> EngineFixtures.run_weeks(count) |> elem(1)
  end
end
