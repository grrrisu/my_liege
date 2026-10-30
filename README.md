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
{report, game} = Game.run_week(game, config)
```

- `Config.from_csv/0` returns the values from `priv/balance_inputs.csv`, read when the app was compiled. Edit a copy to try other values, e.g. `%{config | manameter_points_per_week: 10}`.
- `Game.new/2` takes the config and a seed. The same seed replays the same run; leave the seed out to get a random one, stored in `game.seed`.
- `Game.run_week/2` runs the next week (production, Manameter update, eating, birth) and returns `{report, game}`. Week 0 is the starting state from the config; the first `run_week` runs week 1.

Run several weeks and keep the reports:

```elixir
{reports, game} =
  Enum.map_reduce(1..48, Game.new(config, 42), fn _, g -> Game.run_week(g, config) end)

Enum.map(reports, &{&1.week, &1.food_left, &1.manameter})
```

Each report holds `week`, `production`, `mana`, `manameter`, `food_left` and `newborn`. A week without enough food has `food_left < 0`. `Game.report(game)` returns the report of the last week run; for a new game it is week 0, the starting state:

```elixir
[Game.report(Game.new(config, 42)) | reports]
```

Export a run as CSV, one row per week (engine units: thousandths and per mille):

```elixir
game = Game.new(config, 42)
{reports, _game} = Enum.map_reduce(1..144, game, fn _, g -> Game.run_week(g, config) end)
File.write!("run_42.csv", MyLiege.Reporting.to_csv([Game.report(game) | reports]))
```

### Test A (auto-run)

Plays a fixed pattern (`:stay` or `:pivot`) for a whole game with random births from a seed:

```elixir
alias MyLiege.AutoRun

runs = for seed <- 1..20, do: elem(AutoRun.run(:pivot, config, seed), 0)

AutoRun.leading(hd(runs), config)      # leading colour and share at weeks 48, 96, 144
AutoRun.pivot_weeks(hd(runs))          # weeks red needs to gain 20 points, or nil
AutoRun.spread(runs, 144)              # lowest and highest share per colour across runs
File.write!("pivot_1.csv", MyLiege.Reporting.to_csv(hd(runs)))
```

Units:

- Stocks and production are in thousandths: `27_000` food is 27 wheat.
- Manameter shares are in per mille and sum to 1000: `800` is 80%.
