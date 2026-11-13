defmodule MyLiege.AutoRun do
  @moduledoc """
  Test A: plays a bot strategy for a whole game, with random births from a seed.

  A strategy (`MyLiege.AutoRun.Strategy`) is an ordered list of bot actions
  (`MyLiege.AutoRun.BotAction`), run before each week, and a build condition. Order is
  priority: the actions compete for the same workers, and an earlier action gets them first.
  The runner runs consecutive actions that place workers as one pass, worker by worker
  (`MyLiege.AutoRun.Placing`).

  Bot actions (`MyLiege.AutoRun.BotActions.*`):
  - `StaffSites` – arrived unplaced workers fill sites short of builders, in worker order.
  - `Defend` – while bandits are on their way, workers move to watchtowers.
  - `Feed` – while food is low, unplaced workers go to a farm.
  - `SaveGold` – while gold is below the next tax, unplaced workers go to a market; option
    `born_before: week`.
  - `Pivot` – workers born from `from_week` go to building type `to`.
  - `PlaceOwn` – the rest go to their own colour's home building.
  - `PayAndDeliver` – always pay taxes and deliver the king's demands.

  A worker sent to a type with no building with room waits unplaced; a new building is
  ordered only when the sites already under construction can't take all waiting workers,
  only if the build condition allows it, and only if the gold covers `build_cost_gold`.
  Build conditions: `:always`; `:tax_safe` (`tax_safe_to_build?/1`); `:invest`
  (`invest_allowed?/3`).

  The named patterns (`MyLiege.AutoRun.Strategies.named/2` lists their actions):
  - `:stay` – every worker goes to a building of their own colour.
  - `:pivot` – as `:stay`, but workers born from `pivot_week` on go to a watchtower.
  - `:feed` – as `:stay`, but newborns go to a farm while food is low, else to a market
    while gold is low.
  - `:feed_pivot` – as `:feed`, but only workers born before `pivot_week` go to a market,
    and from `pivot_week` on as `:pivot`.
  - `:feed_save_tax` – "Feed, save for tax": as `:feed` with build condition `:tax_safe`.
  - `:feed_defend` – "Feed, defend": as `:feed`, with `Defend` before anything else.
  - `:feed_invest_defend` – "Feed, invest and defend": as `:feed_defend` with build
    condition `:invest`.

  ## Running the test cases

  Start a console with `iex -S mix`, then:

      alias MyLiege.AutoRun
      alias MyLiege.AutoRun.BotActions.{Defend, Feed, PayAndDeliver, PlaceOwn, StaffSites}
      config = MyLiege.Engine.Config.from_csv()

  Stay, one run, and the leading colour at the end of each year:

      {reports, _game} = AutoRun.run(:stay, config, 1)
      AutoRun.leading(reports, config)

  An ad hoc strategy as a list (build condition `:always`):

      AutoRun.run([Defend, StaffSites, Feed, PlaceOwn, PayAndDeliver], config, 1)

  Or with another build condition:

      strategy = AutoRun.Strategy.new([StaffSites, Feed, PlaceOwn, PayAndDeliver], build: :tax_safe)
      AutoRun.run(strategy, config, 1)

  Pivot, one run, and the weeks red needs to gain 20 points (`nil` if never); the
  pivot week can be changed with `pivot_week: 24`:

      {reports, _game} = AutoRun.run(:pivot, config, 1)
      AutoRun.pivot_weeks(reports)

  About 20 random runs of a pattern, and the spread between them at a week:

      runs = for seed <- 1..20, do: elem(AutoRun.run(:pivot, config, seed), 0)
      AutoRun.spread(runs, 144)

  Export one run as CSV:

      File.write!("pivot_1.csv", runs |> hd() |> MyLiege.Reporting.to_csv())

  Summary of Feed and "Feed, save for tax" over 20 seeds, 48 weeks each (see `summary_csv/4`):

      csv = AutoRun.summary_csv([:feed, :feed_save_tax], config, 1..20, weeks: 48)
      File.write!("summary.csv", csv)
  """

  alias MyLiege.AutoRun.{Analysis, BotActions, Placing, Strategies, Strategy}
  alias MyLiege.Engine.{Config, Game}

  @doc """
  Runs one game with `strategy`: a named strategy (atom), a `%Strategy{}`, or a list of
  actions (build condition `:always`). Returns `{reports, game}`; reports start with week 0.
  The run ends early at game over. Options: `:pivot_week` defaults to
  #{Game.weeks_per_year()}; `:weeks` stops the run after that many weeks (default: the
  whole game). Every action receives the options.
  """
  def run(strategy, %Config{} = config, seed, opts \\ []) do
    {reports, game, _orders} = play(strategy, config, seed, opts)
    {reports, game}
  end

  @doc false
  # as `run/4`, but also returns the buildings ordered per week: `%{week => count}`, by the
  # state they were ordered at
  def play(strategy, %Config{} = config, seed, opts \\ []) do
    steps = strategy |> strategy(opts) |> steps(opts)
    start = Game.new(config, seed)

    last_week = opts |> Keyword.get(:weeks, Game.last_week(start)) |> min(Game.last_week(start))

    # a week's report is kept after the actions ran, so it includes the gold spent on
    # buildings ordered then
    {reports, orders, game} =
      Enum.reduce_while(1..last_week//1, {[], %{}, start}, fn _, {reports, orders, g} ->
        if g.game_over,
          do: {:halt, {reports, orders, g}},
          else: {:cont, week(g, steps, reports, orders)}
      end)

    {Enum.reverse([Game.report(game) | reports]), game, orders}
  end

  defp week(game, steps, reports, orders) do
    acted = Enum.reduce(steps, game, fn {action, opts}, g -> action.run(g, opts) end)
    orders = Map.put(orders, game.week, length(acted.places) - length(game.places))
    {:ok, _report, next} = Game.run_week(acted)
    {[Game.report(acted) | reports], orders, next}
  end

  defp strategy(name, opts) when is_atom(name), do: Strategies.named(name, opts)
  defp strategy(%Strategy{} = strategy, _opts), do: strategy
  defp strategy(actions, _opts) when is_list(actions), do: Strategy.new(actions)

  # each action's opts on top of the strategy's build condition and the run options
  defp steps(%Strategy{build: build} = strategy, opts) do
    base = Keyword.put(opts, :build, build)

    strategy
    |> Strategy.actions()
    |> Enum.map(fn {action, own} -> {action, Keyword.merge(base, own)} end)
    |> Placing.group()
  end

  defdelegate tax_safe_to_build?(game), to: Placing
  defdelegate invest_allowed?(game, type, waiting), to: Placing
  defdelegate defend(game), to: BotActions.Defend
  defdelegate summary_csv(patterns, config, seeds, opts \\ []), to: Analysis
  defdelegate leading(reports, config), to: Analysis
  defdelegate pivot_weeks(reports, opts \\ []), to: Analysis
  defdelegate spread(runs, week), to: Analysis
end
