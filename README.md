# MyLiege

## Develope

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

### Run Game

Start a console with `iex -S mix`, then:

```elixir
alias MyLiege.Engine.{Config, Game}

config = Config.from_csv()
game = Game.new(config, 42)
{:ok, report, game} = Game.run_week(game)
```

- `Config.from_csv/0` returns the values from `priv/balance_inputs.csv`, read when the app was compiled. Edit a copy to try other values, e.g. `%{config | manameter_points_per_week: 10}`.
- `Game.new/2` takes the config and a seed. The config is kept in `game.config` and fixed for the whole game. The same seed replays the same run; leave the seed out to get a random one, stored in `game.seed`.
- `Game.run_week/1` runs the next week (tax count, production, Manameter update, eating, birth, tax payment) and returns `{:ok, report, game}`. Week 0 is the starting state from the config; the first `run_week` runs week 1.
- `run_week` is blocked with `{:error, :tax_undecided}` before a due week until the player decides with `Game.decide_tax(game, true_or_false)`, and with `{:error, :game_over}` once the game is over.

Run several weeks, paying every tax, and keep the reports:

```elixir
run = fn game ->
  game =
    if Game.tax_decision_due?(game),
      do: elem(Game.decide_tax(game, true), 1),
      else: game

  Game.run_week(game)
end

{reports, game} =
  Enum.map_reduce(1..48, Game.new(config, 42), fn _, g ->
    {:ok, report, g} = run.(g)
    {report, g}
  end)

Enum.map(reports, &{&1.week, &1.food_left, &1.gold, &1.tax})
```

Each report holds `week`, `production`, `mana`, `manameter`, `food_left`, `newborn`, `gold`, `tax_due` (in the count week), `tax` (`:paid`, `:skipped` or `:missed` in the due week) and `game_over`. A week without enough food has `food_left < 0`. `Game.report(game)` returns the report of the last week run; for a new game it is week 0, the starting state.

Export a run as CSV, one row per week (engine units: thousandths and per mille):

```elixir
File.write!("run_42.csv", MyLiege.Reporting.to_csv([Game.report(Game.new(config, 42)) | reports]))
```

### Test A (auto-run)

Plays a fixed pattern (`:stay`, `:pivot`, `:feed`, `:feed_pivot` or `:feed_save_tax`) with random births from a seed. The pattern always tries to pay taxes; a run ends early at game over. `:feed_save_tax` ("Feed, save for tax") plays like `:feed` but only orders a building if the forecast gold for the next tax week, minus the price, still covers that tax, and never right after a week in which gold left the stock (tax, the king's takings, a delivered demand, robbery). Add `weeks: 48` to `AutoRun.run/4` to stop a run after 48 weeks:

```elixir
alias MyLiege.AutoRun
alias MyLiege.Engine.Config

config = Config.from_csv()
runs = for seed <- 1..20, do: elem(AutoRun.run(:pivot, config, seed), 0)

AutoRun.leading(hd(runs), config)      # leading colour and share at weeks 48, 96, 144
AutoRun.pivot_weeks(hd(runs))          # weeks red needs to gain 20 points, or nil
AutoRun.spread(runs, 144)              # lowest and highest share per colour across runs
File.write!("pivot_1.csv", MyLiege.Reporting.to_csv(hd(runs)))
```
or multiple game runs

```elixir
alias MyLiege.AutoRun
alias MyLiege.Engine.Config

config = Config.from_csv()

Enum.each(0..20, fn seed ->
  {runs, _game} = AutoRun.run(:feed, config, seed)
  File.write!("feed_#{seed}.csv", MyLiege.Reporting.to_csv(runs))
end)
```

Summary of several patterns over the same seeds, e.g. Feed and "Feed, save for tax" with 20 seeds for 48 weeks:

```elixir
alias MyLiege.AutoRun
alias MyLiege.Engine.Config

config = Config.from_csv()
csv = AutoRun.summary_csv([:feed, :feed_save_tax], config, 1..20, weeks: 48)
File.write!("summary.csv", csv)
```

One row per pattern and seed, then a `total` row per pattern that sums its seeds. Gold is in whole gold:

- `first_tax_week`: week of the first tax payment (empty if the run ended before it, and in the totals).
- `first_tax_paid`, `first_tax_missed`: 1 or 0.
- `first_tax_gold_difference`: gold at the end of the week before the first tax week minus the tax.
- `buildings_ordered`: buildings ordered while the game stood at weeks 1–48.
- `weeks_food_below_0`: weeks that ended with food below 0.
- `gold_robbed`: gold the bandits took in the run.

Units:

- Stocks and production are in thousandths: `27_000` food is 27 wheat.
- Manameter shares are in per mille and sum to 1000: `800` is 80%.
