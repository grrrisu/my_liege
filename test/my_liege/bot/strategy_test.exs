defmodule MyLiege.Bot.StrategyTest do
  use ExUnit.Case, async: true

  alias MyLiege.Bot.BotActions.{
    Defend,
    DemandProject,
    Feed,
    PayAndDeliver,
    Pivot,
    PlaceOwn,
    SaveGold,
    StaffSites,
    WriteBooks
  }

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
               feed_invest_defend: :invest,
               feed_books: :always
             }
    end

    test "DemandProject, then WriteBooks, come right after Feed and Defend, or after StaffSites" do
      modules = fn name ->
        name |> Strategies.named() |> Strategy.actions() |> Enum.map(&elem(&1, 0))
      end

      assert modules.(:stay) == [StaffSites, DemandProject, WriteBooks, PlaceOwn, PayAndDeliver]

      assert modules.(:pivot) ==
               [StaffSites, DemandProject, WriteBooks, Pivot, PlaceOwn, PayAndDeliver]

      for name <- [:feed, :feed_save_tax, :feed_books] do
        assert modules.(name) ==
                 [StaffSites, Feed, DemandProject, WriteBooks, SaveGold, PlaceOwn, PayAndDeliver]
      end

      assert modules.(:feed_pivot) ==
               [
                 StaffSites,
                 Feed,
                 DemandProject,
                 WriteBooks,
                 SaveGold,
                 Pivot,
                 PlaceOwn,
                 PayAndDeliver
               ]

      for name <- [:feed_defend, :feed_invest_defend] do
        assert modules.(name) ==
                 [
                   Defend,
                   StaffSites,
                   Feed,
                   DemandProject,
                   WriteBooks,
                   SaveGold,
                   PlaceOwn,
                   PayAndDeliver
                 ]
      end
    end

    test "only :feed_books writes books: red and green from week 25" do
      for name <- Strategies.names() do
        {WriteBooks, opts} =
          name |> Strategies.named() |> Strategy.actions() |> List.keyfind(WriteBooks, 0)

        colours = if name == :feed_books, do: [:red, :green], else: []

        assert opts == [colours: colours, from_week: 25]
      end
    end

    test "the pivot week comes from the run options" do
      assert {Pivot, to: :watchtower, from_week: 24} in Strategies.named(:pivot, pivot_week: 24).actions
    end
  end
end
