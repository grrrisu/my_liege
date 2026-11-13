defmodule MyLiege.Bot.StrategyTest do
  use ExUnit.Case, async: true

  alias MyLiege.Bot.BotActions.{Feed, PayAndDeliver, Pivot, PlaceOwn}
  alias MyLiege.Bot.{Strategies, Strategy}

  describe "new/2" do
    test "build condition :always by default" do
      assert Strategy.new([Feed, PlaceOwn]) == %Strategy{
               actions: [Feed, PlaceOwn],
               build: :always
             }
    end

    test "takes another build condition" do
      assert Strategy.new([Feed], build: :invest).build == :invest
    end

    test "refuses an unknown build condition" do
      assert_raise MatchError, fn -> Strategy.new([Feed], build: :never) end
    end
  end

  test "actions/1 turns bare modules into {module, []}" do
    strategy = Strategy.new([Feed, {Pivot, to: :watchtower, from_week: 3}])

    assert Strategy.actions(strategy) == [{Feed, []}, {Pivot, to: :watchtower, from_week: 3}]
  end

  describe "Strategies.named/2" do
    test "every name gives a strategy that ends by paying" do
      for name <- Strategies.names() do
        assert %Strategy{actions: actions} = Strategies.named(name)
        assert List.last(actions) == PayAndDeliver
      end
    end

    test "the build condition per name" do
      builds = Map.new(Strategies.names(), &{&1, Strategies.named(&1).build})

      assert builds == %{
               stay: :always,
               pivot: :always,
               feed: :always,
               feed_pivot: :always,
               feed_save_tax: :tax_safe,
               feed_defend: :always,
               feed_invest_defend: :invest
             }
    end

    test "the pivot week comes from the run options" do
      assert {Pivot, to: :watchtower, from_week: 24} in Strategies.named(:pivot, pivot_week: 24).actions
    end
  end
end
