defmodule MyLiege.Engine.Rules.SpoilageTest do
  use ExUnit.Case, async: true

  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Rules.Spoilage
  alias MyLiege.EngineFixtures

  defp config(rates, overrides \\ []) do
    EngineFixtures.config(
      [good_spoilage: Map.merge(EngineFixtures.config().good_spoilage, Map.new(rates))] ++
        overrides
    )
  end

  defp stocks(values),
    do: Map.merge(%{food: 0, knowledge: 0, defence: 0, gold: 0, culture: 0}, Map.new(values))

  describe "spoilage" do
    test "every stock loses its rate (per mille) of itself" do
      config = config(food: 50, gold: 10, defence: 250, knowledge: 250, culture: 250)

      stock =
        stocks(
          food: 20_000,
          gold: 100_000,
          defence: 4_000,
          knowledge: 8_000,
          culture: 12_000
        )

      {left, spoiled} = Spoilage.spoil(stock, config)

      assert spoiled ==
               stocks(
                 food: 1_000,
                 gold: 1_000,
                 defence: 1_000,
                 knowledge: 2_000,
                 culture: 3_000
               )

      assert left ==
               stocks(
                 food: 19_000,
                 gold: 99_000,
                 defence: 3_000,
                 knowledge: 6_000,
                 culture: 9_000
               )
    end

    test "the spoiled amount is rounded down; the stock keeps the remainder" do
      # 27.001 × 5% = 1.35005
      {left, spoiled} = Spoilage.spoil(stocks(food: 27_001), config(food: 50))

      assert spoiled.food == 1_350
      assert left.food == 25_651
    end

    test "stocks at or below 0 don't spoil" do
      {left, spoiled} = Spoilage.spoil(stocks(food: -1), config(food: 50))

      assert spoiled.food == 0
      assert left.food == -1
    end
  end

  describe "spoilage in the week" do
    test "comes at the end of the week, after eating and birth" do
      config = config(food: 500)
      game = EngineFixtures.game_without_demands(config, 1)

      {:ok, report, game} = Game.run_week(game)

      # 24 + 9 - 2 × 3 = 27 after eating, enough for the birth; then half spoils
      assert report.newborn
      assert report.spoiled.food == 13_500
      assert report.food_left == 13_500
      assert game.stocks.food == 13_500
    end

    test "comes after the tax payment, so the tax is paid from the unspoiled gold" do
      config = config([gold: 10], start_gold: 1_000, start_food: 1_000)

      game = EngineFixtures.game_without_demands(config, 1)
      {reports, _game} = EngineFixtures.run_weeks(game, config.king_tax_interval_weeks)
      due = List.last(reports)
      before = Enum.at(reports, -2)
      tax = Enum.at(reports, -5).tax_due

      assert due.tax == :paid
      assert due.spoiled.gold == div((before.gold - tax) * 10, 1000)
      assert due.gold == before.gold - tax - due.spoiled.gold
    end
  end
end
