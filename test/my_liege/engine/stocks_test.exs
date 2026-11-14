defmodule MyLiege.Engine.StocksTest do
  @moduledoc """
  No stock goes below 0. Seed 2473626401 on the normal level showed -1 food (thousandths) in
  week 34: a short week (R8) used to leave -1 food as its marker. Every named bot strategy
  plays these seeds; the starving ones (`stay`, `pivot`) have many short weeks.
  """
  use ExUnit.Case, async: true

  alias MyLiege.Bot
  alias MyLiege.Bot.Strategies
  alias MyLiege.Engine.Config

  @seeds [2_473_626_401, 1, 42, 7_777]

  for seed <- @seeds do
    test "seed #{seed}: food and gold stay at 0 or above every week, every stock at the end" do
      config = Config.from_csv()

      for name <- Strategies.names() do
        {reports, game} = Bot.run(name, config, unquote(seed))

        for report <- reports do
          assert report.food_left >= 0, "#{name}, week #{report.week}: food #{report.food_left}"
          assert report.gold >= 0, "#{name}, week #{report.week}: gold #{report.gold}"
        end

        for {product, stock} <- game.stocks,
            do: assert(stock >= 0, "#{name}: #{product} #{stock}")
      end
    end
  end

  test "a short week is reported and leaves 0 food" do
    {reports, _game} = Bot.run(:stay, Config.from_csv(), 2_473_626_401)
    short = Enum.filter(reports, & &1.food_short)

    assert short != []
    assert Enum.all?(short, &(&1.food_left == 0))
  end
end
