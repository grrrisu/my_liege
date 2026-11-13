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

### Test A (bots)

The bots (`MyLiege.Bot`, in `lib/my_liege/bot/`) play a whole game with random births from a seed. A strategy is an ordered list of bot actions (staff sites, feed, save gold, defend, pivot, place in the own colour, pay and deliver) and a build condition (`:always`, `:tax_safe`, `:invest`); an earlier action gets the workers first. The named strategies are `:stay`, `:pivot`, `:feed`, `:feed_pivot`, `:feed_save_tax`, `:feed_defend` and `:feed_invest_defend`; see the `bots` skill (`.github/skills/bots/SKILL.md`). The bots always try to pay taxes and deliver demands; a run ends early at game over. `:feed_save_tax` ("Feed, save for tax") plays like `:feed` but only orders a building if the forecast gold for the next tax week, minus the price, still covers that tax, and never right after a week in which gold left the stock (tax, the king's takings, a delivered demand, robbery). `:feed_defend` ("Feed, defend") plays like `:feed`, but while bandits are on their way it moves workers to watchtowers (unplaced ones first, red first, then from the product with the largest surplus) until the protected gold covers the gold forecast for the raid week; the moved workers stay there afterwards. `:feed_invest_defend` ("Feed, invest and defend") defends the same way and orders a building only if the forecast gold at the next tax week, minus the price, plus a new market's expected gold until then, still covers the tax; a farm is always allowed while food is low. Add `weeks: 48` to `Bot.run/4` to stop a run after 48 weeks:

```elixir
alias MyLiege.Bot
alias MyLiege.Engine.Config

config = Config.from_csv()
runs = for seed <- 1..20, do: elem(Bot.run(:pivot, config, seed), 0)

Bot.leading(hd(runs), config)      # leading colour and share at weeks 48, 96, 144
Bot.pivot_weeks(hd(runs))          # weeks red needs to gain 20 points, or nil
Bot.spread(runs, 144)              # lowest and highest share per colour across runs
File.write!("pivot_1.csv", MyLiege.Reporting.to_csv(hd(runs)))
```

An ad hoc strategy as a list of bot actions:

```elixir
alias MyLiege.Bot.BotActions.{Defend, Feed, PayAndDeliver, PlaceOwn, StaffSites}

Bot.run([Defend, StaffSites, Feed, PlaceOwn, PayAndDeliver], config, 1)
```

or multiple game runs

```elixir
alias MyLiege.Bot
alias MyLiege.Engine.Config

config = Config.from_csv()

Enum.each(0..20, fn seed ->
  {runs, _game} = Bot.run(:feed, config, seed)
  File.write!("feed_#{seed}.csv", MyLiege.Reporting.to_csv(runs))
end)
```

Summary of several patterns over the same seeds, e.g. Feed and the defending patterns with 20 seeds for 48 weeks:

```elixir
alias MyLiege.Bot
alias MyLiege.Engine.Config

config = Config.from_csv()
csv = Bot.summary_csv([:feed, :feed_defend, :feed_invest_defend], config, 1..20, weeks: 48)
File.write!("summary.csv", csv)
```

One row per pattern and seed, then a `total` row per pattern that sums its seeds. Gold is in whole gold:

- `first_tax_week`: week of the first tax payment (empty if the run ended before it, and in the totals).
- `first_tax_paid`, `first_tax_missed`: 1 or 0.
- `first_tax_gold_difference`: gold at the end of the week before the first tax week minus the tax. It is measured before the tax week's own production, which comes before the payment, so a run can pay with a negative difference.
- `buildings_ordered`: buildings ordered while the game stood at weeks 1–48.
- `weeks_food_below_0`: weeks that ended with food below 0.
- `gold_robbed`: gold the bandits took in the run.

Units:

- Stocks and production are in thousandths: `27_000` food is 27 wheat.
- Manameter shares are in per mille and sum to 1000: `800` is 80%.
