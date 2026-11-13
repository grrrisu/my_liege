defmodule MyLiege.AutoRun.Strategies do
  @moduledoc """
  The named strategies of Test A: today's patterns as ordered lists of bot actions.

  | Pattern | Actions, in order | `build` |
  |---|---|---|
  | `:stay` | StaffSites, PlaceOwn, PayAndDeliver | `:always` |
  | `:pivot` | StaffSites, {Pivot, to: :watchtower, from_week: pivot_week}, PlaceOwn, PayAndDeliver | `:always` |
  | `:feed` | StaffSites, Feed, SaveGold, PlaceOwn, PayAndDeliver | `:always` |
  | `:feed_pivot` | StaffSites, Feed, {SaveGold, born_before: pivot_week}, {Pivot, to: :watchtower, from_week: pivot_week}, PlaceOwn, PayAndDeliver | `:always` |
  | `:feed_save_tax` | as `:feed` | `:tax_safe` |
  | `:feed_defend` | Defend, StaffSites, Feed, SaveGold, PlaceOwn, PayAndDeliver | `:always` |
  | `:feed_invest_defend` | as `:feed_defend` | `:invest` |

  `pivot_week` is the run option `:pivot_week` (default #{MyLiege.Engine.Game.weeks_per_year()}).
  """

  alias MyLiege.AutoRun.BotActions.{
    Defend,
    Feed,
    PayAndDeliver,
    Pivot,
    PlaceOwn,
    SaveGold,
    StaffSites
  }

  alias MyLiege.AutoRun.Strategy
  alias MyLiege.Engine.Game

  @names [:stay, :pivot, :feed, :feed_pivot, :feed_save_tax, :feed_defend, :feed_invest_defend]

  @doc "The names of the named strategies."
  def names, do: @names

  @doc "The named strategy `name`; reads `:pivot_week` from `opts`."
  def named(name, opts \\ [])

  def named(:stay, _opts), do: Strategy.new([StaffSites, PlaceOwn, PayAndDeliver])

  def named(:pivot, opts) do
    Strategy.new([StaffSites, pivot(opts), PlaceOwn, PayAndDeliver])
  end

  def named(:feed, _opts), do: Strategy.new([StaffSites, Feed, SaveGold, PlaceOwn, PayAndDeliver])

  def named(:feed_pivot, opts) do
    Strategy.new([
      StaffSites,
      Feed,
      {SaveGold, born_before: pivot_week(opts)},
      pivot(opts),
      PlaceOwn,
      PayAndDeliver
    ])
  end

  def named(:feed_save_tax, opts), do: %{named(:feed, opts) | build: :tax_safe}

  def named(:feed_defend, _opts) do
    Strategy.new([Defend, StaffSites, Feed, SaveGold, PlaceOwn, PayAndDeliver])
  end

  def named(:feed_invest_defend, opts), do: %{named(:feed_defend, opts) | build: :invest}

  defp pivot(opts), do: {Pivot, to: :watchtower, from_week: pivot_week(opts)}

  defp pivot_week(opts), do: Keyword.get(opts, :pivot_week, Game.weeks_per_year())
end
