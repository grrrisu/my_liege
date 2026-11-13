defmodule MyLiege.Bot.Strategies do
  @moduledoc """
  The named strategies of Test A: today's patterns as ordered lists of bot actions.

  | Pattern | Actions, in order | `build` |
  |---|---|---|
  | `:stay` | StaffSites, DemandProject, no_books, PlaceOwn, PayAndDeliver | `:always` |
  | `:pivot` | StaffSites, DemandProject, no_books, {Pivot, to: :watchtower, from_week: pivot_week}, PlaceOwn, PayAndDeliver | `:always` |
  | `:feed` | StaffSites, Feed, DemandProject, no_books, SaveGold, PlaceOwn, PayAndDeliver | `:always` |
  | `:feed_pivot` | StaffSites, Feed, DemandProject, no_books, {SaveGold, born_before: pivot_week}, {Pivot, to: :watchtower, from_week: pivot_week}, PlaceOwn, PayAndDeliver | `:always` |
  | `:feed_save_tax` | as `:feed` | `:tax_safe` |
  | `:feed_defend` | Defend, StaffSites, Feed, DemandProject, no_books, SaveGold, PlaceOwn, PayAndDeliver | `:always` |
  | `:feed_invest_defend` | as `:feed_defend` | `:invest` |
  | `:feed_books` | as `:feed`, with {WriteBooks, colours: [:red, :green], from_week: 25} for no_books | `:always` |

  `no_books` is `{WriteBooks, colours: [], from_week: 25}`: it writes nothing, so those
  strategies play as before. `DemandProject` comes right after survival (`Feed`, `Defend`),
  or after `StaffSites` where there is no `Feed` (the designer's decision, 2026-11-13);
  `WriteBooks` right after `DemandProject`, before `SaveGold`, `Pivot` and `PlaceOwn`.

  `pivot_week` is the run option `:pivot_week` (default #{MyLiege.Engine.Game.weeks_per_year()}).
  """

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

  alias MyLiege.Bot.Strategy
  alias MyLiege.Engine.Game

  # the designer's week from which WriteBooks starts books
  @books_from_week 25

  @names [
    :stay,
    :pivot,
    :feed,
    :feed_pivot,
    :feed_save_tax,
    :feed_defend,
    :feed_invest_defend,
    :feed_books
  ]

  @doc "The names of the named strategies."
  def names, do: @names

  @doc "The named strategy `name`; reads `:pivot_week` from `opts`."
  def named(name, opts \\ [])

  def named(:stay, _opts),
    do: Strategy.new([StaffSites, DemandProject, no_books(), PlaceOwn, PayAndDeliver])

  def named(:pivot, opts) do
    Strategy.new([StaffSites, DemandProject, no_books(), pivot(opts), PlaceOwn, PayAndDeliver])
  end

  def named(:feed, _opts), do: feed(no_books())

  def named(:feed_pivot, opts) do
    Strategy.new([
      StaffSites,
      Feed,
      DemandProject,
      no_books(),
      {SaveGold, born_before: pivot_week(opts)},
      pivot(opts),
      PlaceOwn,
      PayAndDeliver
    ])
  end

  def named(:feed_save_tax, opts), do: %{named(:feed, opts) | build: :tax_safe}

  def named(:feed_defend, _opts) do
    Strategy.new([
      Defend,
      StaffSites,
      Feed,
      DemandProject,
      no_books(),
      SaveGold,
      PlaceOwn,
      PayAndDeliver
    ])
  end

  def named(:feed_invest_defend, opts), do: %{named(:feed_defend, opts) | build: :invest}

  def named(:feed_books, _opts),
    do: feed({WriteBooks, colours: [:red, :green], from_week: @books_from_week})

  defp feed(write_books),
    do:
      Strategy.new([
        StaffSites,
        Feed,
        DemandProject,
        write_books,
        SaveGold,
        PlaceOwn,
        PayAndDeliver
      ])

  # WriteBooks with no colours writes nothing
  defp no_books, do: {WriteBooks, colours: [], from_week: @books_from_week}

  defp pivot(opts), do: {Pivot, to: :watchtower, from_week: pivot_week(opts)}

  defp pivot_week(opts), do: Keyword.get(opts, :pivot_week, Game.weeks_per_year())
end
