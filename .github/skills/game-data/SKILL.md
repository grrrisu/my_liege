---
name: game-data
description: 'The game data of My Liege: every value, its shape and unit, where it comes from (the CSV config, a hardcoded constant, or state that changes during a game) and which modules read or write it. Use when: looking for where a number comes from; adding, renaming or removing a CSV key or Config field; adding a field to Game, Worker, Building or WeeklyReport; checking hard rule 2 (no game value outside the config); deciding whether a value belongs in the CSV; tracing who changes a piece of state.'
---

# Game data

All game data falls into four kinds:

| Kind | Where | Changes |
|------|-------|---------|
| **Config**: balance values | `priv/balance_inputs.csv` → `LoadConfig` → `%Config{}` | never during a game; fixed at `Game.new/2`, kept in `game.config` |
| **Hardcoded**: structure and constants | module attributes in the engine | never; changing one is a code change |
| **State**: the village now | `%Game{}` and its `%Worker{}`, `%Building{}`, `%Manameter{}` | every week (steps) and between weeks (player actions) |
| **Report**: what one week did | `%WeeklyReport{}` in `game.report` | rebuilt each week; history kept by callers |

`Forecast` is read-only and derived from state and the last report. Elixir app config
(`config/*.exs`) holds **no game values**, only Phoenix, Repo and so on.

How the week runs is in the `weekly-step` skill. Layers and where code goes are in
`engine-architecture`.

## Units

- **Thousandths** (`Fixed`, scale 1000): every stock, production amount, tax, demand amount,
  `bandit_threat` and gold value in the state and the report. `27_000` food is 27 wheat.
- **Per mille** (1000 = 100%): Manameter shares (always summing to 1000), `colour_factors`,
  `spoilage_rates`, `demand_population_share`, `training_threshold`,
  `manameter_points_per_week`, `bandit_pressure`.
- **Whole units**: every `%Config{}` value. Convert with `Fixed.from/1` where it is used,
  never in the config.
- **Weeks**: `game.week` is the last week run (0 is the start). 48 weeks make a year.

## 1. Config (from the CSV)

[config.ex](../../../lib/my_liege/engine/config.ex),
[load_config.ex](../../../lib/my_liege/engine/load_config.ex),
[balance_inputs.csv](../../../priv/balance_inputs.csv)

- `Config.from_csv/0` is built **at compile time** (`@external_resource`), so editing the CSV
  recompiles `Config`. A missing key, a duplicate, a bad header or a value that isn't a whole
  number fails the build. The `manameter_start_*` keys must sum to 1000.
- The designer exports the CSV. Never edit it.
- `GameLive.mount/3` uses `Config.from_csv/0`, and AutoRun takes a config argument. Tests
  never use the CSV: they use `EngineFixtures.config/1`
  ([engine_fixtures.ex](../../../test/support/engine_fixtures.ex)), whose explicit values
  include `grace_weeks: 0`, `builders_per_building: 0`, `travel_weeks: 0` and very high bandit
  values.
- Rules receive `%Config{}` as an explicit argument. Steps pass `game.config`.

### Fields

| Config field | Shape | CSV key(s) | Read by |
|---|---|---|---|
| `years_per_game` | int | same | `Game.last_week/1`, `Rules.Demands.schedule/3`, `AutoRun.leading/2`, GameLive |
| `starting_farmers`, `starting_soldiers` | int | same | `Worker.starting/2` |
| `starting_food` | int | same | `Rules.Food.starting/1` (via `Game.new/2`) |
| `starting_gold` | int | same | `Game.new/2` (`starting_stocks`) |
| `starting_manameter` | `%Manameter{}` | `manameter_start_<colour>` ×5 | `Game.new/2` |
| `base_production` | `%{farm, monastery, watchtower, market, tavern}` | `wheat_per_farm_worker`, `base_production_monastery`, `base_production_watchtower`, `gold_per_market_worker`, `base_production_tavern` | `Rules.Production.worker_output/3`, `Rules.Demands.make/5` |
| `colour_factors` | `%{untrained \| trained => %{same \| neighbour \| opposite => ‰}}` | `factor_<relation>_<training>` ×6 | `Rules.Production.worker_output/3` |
| `capacity` | `%{type => int}`, guildhouse included | `capacity_<type>` ×6 | `Building.capacity/2`, `has_room?/3`, `AutoRun` (ordering), GameLive |
| `mana_per_worker` | `%{untrained \| trained => %{building_colour, own_colour}}` | `mana_building_<training>`, `mana_own_<training>` | `Rules.Mana.worker_mana/3` |
| `manameter_points_per_week` | ‰ | same | `Rules.ManameterUpdate.update/3` |
| `birth_interval_weeks` | int | same | `Rules.Births.birth_week?/2` |
| `birth_min_food_left` | int | same | `Rules.Births.attempt/5` |
| `food_eaten_per_worker` | int | **`wheat_eaten_per_worker`** | `Rules.Food.eat/3`, `AutoRun` (`food_low?`) |
| `construction_weeks` | int | same | `Rules.Construction`, GameLive |
| `build_cost_gold` | int | same | `Game.build_cost/1`, `Game.construct/2`, GameLive |
| `builders_per_building` | int | same | `Building.capacity/2` (sites), `Rules.Construction`, GameLive |
| `travel_weeks` | int | same | `Rules.Travel.depart/3`, `Rules.Training.first_week/2` |
| `training_threshold` | ‰ | same | `Rules.Training.check/3` |
| `training_weeks` | int | same | `Rules.Training.last_week/2` |
| `grace_weeks` | int | same | `Rules.Grace` (used by `Taxes` and `Demands`) |
| `tax_per_worker` | int | same | `Rules.Taxes.assess/2` (also `Forecast.tax_amount/1`) |
| `tax_interval_weeks` | int | same | `Rules.Taxes.due_week?/2`, `next_due_week/2` |
| `tax_count_lead_weeks` | int | same | `Rules.Taxes.count_week?/2`, GameLive |
| `tax_misses_forgiven` | int | same | `Rules.Misses`, GameLive |
| `demand_deadline_weeks` | int | same | `Rules.Demands.schedule/3`, `make/5` |
| `demand_population_share` | ‰ | same | `Rules.Demands.make/5` |
| `demand_production_weeks` | int | same | `Rules.Demands.make/5` |
| `spoilage_rates` | `%{product => ‰}` | `spoilage_rate_<product>` ×5 | `Rules.Spoilage.spoil/2` |
| `bandit_threshold` | int (×1000 in use) | same | `Rules.Bandits.threshold/1` (also `Forecast`, GameLive) |
| `bandit_warning_weeks` | int | same | `Rules.Bandits` (sets `raid_week`) |
| `bandit_cover_weeks` | int | same | `Rules.Bandits.protected/2` |
| `bandit_floor_step` | int (×1000 in use) | same | `Rules.Bandits.floor/3` |

Only `wheat_eaten_per_worker` has a field name that differs from its key. The lists of types,
products, trainings and relations in `LoadConfig` are written out there, not taken from
`Building`, because `Building` depends on `Config` at compile time.

**In the CSV but not read** (no rule uses them yet): `seconds_per_week`,
`plough_threshold_green`, `plough_bonus`, `plough_research_weeks` and `plough_cost_wisdom`
(R6, the improved plough, isn't implemented).

## 2. Hardcoded values

Hard rule 2 says no game value lives outside the config. The constants below sit in code
anyway. Some are structure (the pentagon, the building types) and some are numbers. Before
you add one, ask the designer whether it should be a CSV key.

| Value | Where | Used by |
|---|---|---|
| 48 weeks per year (the designer's only sanctioned exception) | `Game` `@weeks_per_year`, `Game.weeks_per_year/0` | `Game.last_week/1`, `Demands`, `Bandits`, AutoRun |
| The order of the pipeline steps | `Game` `@pipeline` | `run_week/1` |
| Colours in pentagon order `green, yellow, blue, red, violet` (Growth, Wealth, Wisdom, Strength, Culture) | `Manameter` `@enforce_keys`, `colours/0` | everything that iterates colours, `Pentagon`, `LoadConfig`, `Reporting` |
| Manameter total 1000 | `Manameter.total_shares/0` | `LoadConfig` (validation) |
| Same / neighbour / opposite from pentagon distance | `Pentagon.relation/2` | `Rules.Production` |
| Building type → colour, type → product; guildhouse neutral | `Building` `@colours`, `@products`, `types/0`, `products/0` | everything that iterates types or products |
| Starting buildings: farm (id 1) and watchtower (id 2), both ready | `Building.starting/0` | `Game.new/2` |
| Starting workers: green on the farm, red in the tower | `Worker.starting/2` (the counts come from the config) | `Game.new/2` |
| Starting stocks of knowledge, defence and entertainment are 0 | `Game` `starting_stocks/1` | `Game.new/2` |
| Fixed scale 1000 | `Fixed` `@scale` | all amounts |
| Per mille divisor 1000 | inline in `Production`, `Spoilage`, `Demands`, `Bandits.pressure/2` | — |
| Random algorithm `:exsss`, random seed up to 2³² | `Random` | `Game.new/2` |
| Short-week food marker `-1` | `Rules.Food` `@short` | `Food.eat/3`; read as `food_left < 0` |
| Births in weeks 1, 1 + interval, … | `Rules.Births.birth_week?/2` (`week - 1`) | — |
| 2 demands a year; project products `knowledge, entertainment`; takeable `food, gold`; Manameter rank by year `[0, 2, 4]` | `Rules.Demands` `@half_years_per_year`, `@project_products`, `@takeable_products`, `@ranks` | `Demands` |
| Bandits: 2 half years a year, floor 0 for the first 2 half years; pressure 1000 is the break-even and the repel limit | `Rules.Bandits` `@half_years_per_year`, `@floorless_half_years`, inline `1000` | `Bandits`, `Forecast.bandits/1` |
| Bandit starting state `%{threat: 0, raid_week: nil}` | `Rules.Bandits.starting/0` | `Game` defaults |
| AutoRun: pivot measure 200 ‰, default `pivot_week` 48 | `AutoRun` `@points`, opts | AutoRun only (not the game) |
| UI colour classes | `GameLive` `@colour_classes` | UI only |

## 3. State that changes over time

### `%Game{}` ([game.ex](../../../lib/my_liege/engine/game.ex))

| Field | Shape | Set at start | Changed by |
|---|---|---|---|
| `config` | `%Config{}` | `new/2` | never |
| `seed` | int | `new/2` (given or random) | never |
| `rand` | `:rand` state | `new/2` (after `Demands.schedule/3` drew from it) | `Birth` step (only births draw during the game) |
| `week` | int, last week run | 0 | `run_week/1` (+1) |
| `demand_weeks` | `[week]`, one per half year at most | `Demands.schedule/3` in `new/2` | never (tests: `EngineFixtures.game_without_demands/2` sets `[]`) |
| `workers` | `[%Worker{}]` | `Worker.starting/2` | `place_worker/3`, `unplace_worker/2` (between weeks); steps `Travel`, `Birth` (appends), `Construction` and `TrainingEnd` (release) |
| `buildings` | `[%Building{}]` | `Building.starting/0` | `construct/2` (appends a site, between weeks), `place/unplace` (resets site progress), `Construction` step |
| `manameter` | `%Manameter{}` ‰ | `config.starting_manameter` | `ManameterUpdate` step |
| `stocks` | `%{food, knowledge, defence, gold, entertainment}` thousandths | `starting_stocks/1` | `construct/2` (gold); steps `Production` (+), `Eating` (food), `TaxPayment` (gold), `DemandDelivery`, `Bandits` (gold), `Spoilage` |
| `report` | `%WeeklyReport{}` | week-0 report | `run_week/1`; `construct/2` adds to `gold_spent_buildings` |
| `tax_due` | thousandths \| nil | nil | `TaxCount` sets it, `TaxPayment` clears it |
| `pay_tax` | bool \| nil | nil | `decide_tax/2` sets it, `TaxPayment` clears it |
| `demand` | `%{product, amount, due_week, progress}` \| nil (`progress` is an int only for projects) | nil | `DemandMade` sets it, `Production` (project progress), `DemandDelivery` clears it |
| `deliver_demand` | bool \| nil | nil | `decide_demand/2`, `refuse_project/1`; `DemandDelivery` clears it |
| `misses` | int | 0 | `TaxPayment`, `DemandDelivery` (via `Rules.Misses`) |
| `bandits` | `%{threat (thousandths), raid_week \| nil}` | `Bandits.starting/0` | `Bandits` step |
| `game_over` | bool | false | `TaxPayment`, `DemandDelivery` |

### `%Worker{}` ([worker.ex](../../../lib/my_liege/engine/worker.ex))

`id` and `colour` never change after birth. `born_week` is set by the `Birth` step (nil for
starting workers). `trained` is set by `TrainingEnd` and never reset. `building` (id \| nil)
and `travel` change with every placement (`Rules.Travel.depart/3`), and the `Travel` step
counts `travel` down. `training_started` is set when the worker is placed in a finished
guildhouse (`Rules.Training.first_week/2`) and cleared on a move or at the end of training.

### `%Building{}` ([building.ex](../../../lib/my_liege/engine/building.ex))

`id` and `type` never change. A site has `ready_week: nil` and a `progress` count. The
`Construction` step advances `progress` and sets `ready_week`, and moving a builder off a
site resets `progress` to 0. Once `ready_week` is set the building is finished for good.

## 4. The weekly report

[weekly_report.ex](../../../lib/my_liege/engine/weekly_report.ex),
[reporting.ex](../../../lib/my_liege/reporting.ex)

`WeeklyReport.new/2` starts each week empty, with zero maps over products and colours, and
the steps fill it. The field-by-step mapping is the "Order inside a week" table in
`weekly-step`. `game.report` holds the last report only. The history lives in callers:
`GameLive` (`@reports`), `AutoRun.run/4` and `EngineFixtures.run_weeks/2`.

- **Exported** by `Reporting.to_csv/1`: week, production, mana, manameter, food_left,
  newborn, trained, builders, travelling, gold, tax_due, tax, demand (product, amount),
  demand_outcome, demand_progress, king_took, spoiled, gold_spent_buildings,
  bandit_pressure, bandit_threat, bandits_weeks_to_raid, gold_robbed, game_over.
- **Not exported**: `start` (the game at the start of the week, `nil` once the week is done),
  `stock_change` and `project_change` (for `Forecast`), `bandit_protected`,
  `bandit_threat_change` and `bandit_raid` (for the UI).

The export format is fixed. Ask before changing a column (hard rule 5).

## 5. Derived and read-only

- `Forecast` ([forecast.ex](../../../lib/my_liege/engine/forecast.ex)) is computed from
  `game.stocks`, `game.demand`, `game.bandits`, `game.tax_due`, `report.stock_change`,
  `report.project_change`, `report.bandit_pressure` and the config. It never changes the game.
  GameLive (`assign_game/2`) and AutoRun (`food_low?`, `gold_low?`) read it.
- Predicates on `Game` (`tax_decision_due?/1`, `demand_decision_due?/1`,
  `project_refusable?/1`, `won?/1`, `can_afford_building?/1`, `build_cost/1`) are derived
  from state and config too.

## Who touches what (outside the engine)

| Module | Reads | Writes |
|---|---|---|
| `MyLiegeWeb.GameLive` | `Config.from_csv/0`, game fields, config fields (see the tables), `Forecast`, `Rules.Bandits`, `Rules.Construction`, `Building`, `Manameter`, `Fixed.scale/0` | only through `Game` actions and `run_week/1` |
| `MyLiege.AutoRun` | the config it is given, `Forecast`, `Building`, `game.workers`, `game.buildings`, `game.stocks` | only through `Game` actions |
| `MyLiege.Reporting` | `WeeklyReport` fields, `Building.products/0`, `Manameter.colours/0` | none |
| `EngineFixtures` (tests) | builds its own `%Config{}` | none |

## Changing the data

- **New CSV key**: add it to `@enforce_keys` in `Config`, to `LoadConfig.load!/1` (and
  `EngineFixtures.config/1`), and read it in a rule. List the key and the designer's value in
  the hand-over. Name the key in `rules/rules.md`, never the value.
- **New state field**: add it to `Game`'s defstruct with a starting value. Have exactly one
  step (or one player action) change it, through a rule.
- **New report field**: add it to `WeeklyReport` (struct and `@type`). Export it only if the
  designer agrees (hard rule 5).
- **Update this skill** in the same change: the right table, and the "not read" list if a
  CSV key is now used.

Quick checks:

```sh
# CSV keys LoadConfig doesn't read (also matches interpolated keys such as "capacity_#{type}")
f=lib/my_liege/engine/load_config.ex
for k in $(tail -n +2 priv/balance_inputs.csv | cut -d, -f1); do
  p=$k; hit=$(grep -c "\"$k\"" $f)
  while [ "$hit" = 0 ] && [ "${p%_*}" != "$p" ]; do p=${p%_*}; hit=$(grep -cF "\"${p}_#{" $f); done
  [ "$hit" = 0 ] && echo $k
done; true
# numeric module attributes in the engine (candidates for hardcoded game values)
grep -rnE "^\s*@[a-z_]+ -?[0-9\[]" lib/my_liege
# who reads a config field
grep -rn "config\.<field>" lib
```
