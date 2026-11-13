defmodule MyLiege.Bot do
  @moduledoc """
  The bots: Test A plays a bot strategy for a whole game, with random births from a seed.
  The bots are a client of the engine: they decide like a player and change the game only
  through `MyLiege.Engine.Game`.

  A strategy (`MyLiege.Bot.Strategy`) is an ordered list of bot actions
  (`MyLiege.Bot.BotActions.*`), run before each week, and a build condition (`:always`,
  `:tax_safe` or `:invest`). Order is priority: an earlier action gets the workers first.
  The named strategies (`:stay`, `:pivot`, `:feed`, `:feed_pivot`, `:feed_save_tax`,
  `:feed_defend`, `:feed_invest_defend`, `:feed_books`) are in `MyLiege.Bot.Strategies.named/2`. The
  `bots` skill (`.github/skills/bots/SKILL.md`) describes the actions, the strategies and
  how to add one.

  ## Running the test cases

  Start a console with `iex -S mix`, then:

      alias MyLiege.Bot
      alias MyLiege.Bot.BotActions.{Defend, Feed, PayAndDeliver, PlaceOwn, StaffSites}
      config = MyLiege.Engine.Config.from_csv()

  A named strategy, one run, and the leading colour at the end of each year:

      {reports, _game} = Bot.run(:stay, config, 1)
      Bot.leading(reports, config)

  An ad hoc strategy as a list (build condition `:always`), or with another build condition:

      Bot.run([Defend, StaffSites, Feed, PlaceOwn, PayAndDeliver], config, 1)

      strategy = Bot.Strategy.new([StaffSites, Feed, PlaceOwn, PayAndDeliver], build: :tax_safe)
      Bot.run(strategy, config, 1)

  Pivot, and the weeks red needs to gain 20 points (`nil` if never); the pivot week can be
  changed with `pivot_week: 24`:

      {reports, _game} = Bot.run(:pivot, config, 1)
      Bot.pivot_weeks(reports)

  About 20 random runs, the spread between them at a week, and one run as CSV:

      runs = for seed <- 1..20, do: elem(Bot.run(:pivot, config, seed), 0)
      Bot.spread(runs, 144)
      File.write!("pivot_1.csv", runs |> hd() |> MyLiege.Reporting.to_csv())

  Summary over 20 seeds, 48 weeks each (`MyLiege.Bot.Analysis.summary_csv/4`):

      csv = Bot.summary_csv([:feed, :feed_save_tax], config, 1..20, weeks: 48)
      File.write!("summary.csv", csv)
  """

  alias MyLiege.Bot.{Analysis, BotActions, Placing, Strategies, Strategy}
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
