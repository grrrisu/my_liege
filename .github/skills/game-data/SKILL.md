---
name: game-data
description: 'The game data of My Liege: every value, its shape and unit, where it comes from (the CSV config, a hardcoded constant, or state that changes during a game) and which modules read or write it. Use when: looking for where a number comes from; adding, renaming or removing a CSV key or Config field; adding a field to Game, Worker, a place (Place.Building, Place.Project, Place.Blueprint) or WeeklyReport; checking hard rule 2 (no game value outside the config); deciding whether a value belongs in the CSV; tracing who changes a piece of state.'
---

# Game data

All game data falls into four kinds:

| Kind | Where | Changes |
|------|-------|---------|
| **Config**: balance values | `priv/balance_inputs.csv` → `LoadConfig` → `%Config{}` | never during a game; fixed at `Game.new/2`, kept in `game.config` |
| **Hardcoded**: structure and constants | module attributes in the engine | never; changing one is a code change |
| **State**: the village now | `%Game{}` and its `%Worker{}`, `%Place.Building{}`, `%Place.Project{}`, `%Manameter{}` | every week (steps) and between weeks (player actions) |
| **Report**: what one week did | `%WeeklyReport{}` in `game.report` | rebuilt each week; history kept by callers |

`Forecast` is read-only and derived from state and the last report. Elixir app config
(`config/*.exs`) holds **no game values**, only Phoenix, Repo and so on.

How the week runs is in the `weekly-step` skill. Layers and where code goes are in
`engine-architecture`.

## Units

- **Thousandths** (`Fixed`, scale 1000): every stock, production amount, tax, demand amount,
  `bandit_threat` and gold value in the state and the report. `27_000` food is 27 wheat.
- **Per mille** (1000 = 100%): Manameter shares (always summing to 1000), `efficiency`,
  `good_spoilage`, `king_demand_population_share`, `training_min_share`,
  `manameter_points_per_week`, `bandit_pressure`.
- **Whole units**: every `%Config{}` value. Convert with `Fixed.from/1` where it is used,
  never in the config.
- **Config keys** say their unit: `_permille` is per mille, `_weeks` is weeks, everything else
  is a whole amount.
- **Weeks**: `game.week` is the last week run (0 is the start). 48 weeks make a year.

## 1. Config (from the CSV)

[config.ex](../../../lib/my_liege/engine/config.ex),
[load_config.ex](../../../lib/my_liege/engine/load_config.ex),
[balance_inputs.csv](../../../priv/balance_inputs.csv)

- `Config.from_csv/0` is built **at compile time** (`@external_resource`), so editing the CSV
  recompiles `Config`. A missing key, a key `LoadConfig` doesn't read, a duplicate, a bad
  header or a value that isn't a whole number fails the build. `LoadConfig` takes each key
  out of the parsed inputs as it reads it; whatever is left over is unread. The
  `manameter.<colour>.start_permille` keys must sum to 1000.
- The designer exports the CSV. Never edit it.
- `GameLive.mount/3` uses `Config.from_csv/0`, and `Bot.run/4` takes a config argument. Tests
  never use the CSV: they use `EngineFixtures.config/1`
  ([engine_fixtures.ex](../../../test/support/engine_fixtures.ex)), whose explicit values
  include `king_grace_weeks: 0`, `travel_weeks: 0` and very high bandit values; a test that
  needs a finished building adds one with `EngineFixtures.add_building/2`.
- Rules receive `%Config{}` as an explicit argument. Steps pass `game.config`.

### Key names

Keys are `group.item.attribute`, lowercase, dot-separated, e.g. `place.farm.capacity`. The item
is left out when a group has only one thing (`travel.weeks`).

- **Group**, the system: `game`, `start`, `birth`, `place`, `good`, `efficiency`, `mana`,
  `manameter`, `training`, `build`, `travel`, `king`, `bandit`, `happiness`, `book`, `way`
  (v2 later: `trade`, `expedition`, `suspicion`). A way that is a building keeps its keys
  under `place.<type>.*` (`place.granary.capacity`); a way that is an invention under
  `way.<type>.*` (`way.plough.work`).
- **Item**, a name the code already uses: place type, good, colour, training level,
  relation; also the king's `tax` and `demand`, and happiness levels `level1` to `level3`.
- **Unit** from the ending: `_permille`, `_weeks`, otherwise a whole amount.
- **Config field**: the key with its dots as underscores and `_permille` dropped
  (`king.tax.per_worker` → `king_tax_per_worker`). Keys that differ only by item are one field,
  a map keyed by the item (`place.<type>.capacity` → `place_capacity: %{farm: …}`), and the
  item drops out of the name. A per-mille field shows its unit in this table, not in its name.

### Fields

| Config field | Shape | CSV key(s) | Read by |
|---|---|---|---|
| `game_years` | int | `game.years` | `Game.last_week/1`, `Rules.Demands.schedule/3`, `Bot.Analysis.leading/2`, GameLive |
| `start_farmers`, `start_soldiers` | int | `start.farmers`, `start.soldiers` | `Worker.starting/2` |
| `start_food` | int | `start.food` | `Rules.Food.starting/1` (via `Game.new/2`) |
| `start_gold` | int | `start.gold` | `Game.new/2` (`starting_stocks`) |
| `manameter_start` | `%Manameter{}` | `manameter.<colour>.start_permille` ×5 | `Game.new/2` |
| `place_output_per_worker` | `%{farm, market, monastery, watchtower, tavern}` (home places only, `Blueprint.home_types/0`) | `place.<type>.output_per_worker` ×5 | `Rules.Production.worker_output/3`, `Rules.Demands.make/5` |
| `efficiency` | `%{untrained \| trained => %{same \| neighbour \| opposite => ‰}}` | `efficiency.<training>.<relation>_permille` ×6 | `Rules.Production.worker_output/3` |
| `place_capacity` | `%{type => int}`, every building type (`Blueprint.building_types/0`): granary and guildhouse included | `place.<type>.capacity` ×7 | `Rules.Placement.capacity/2` and `check_enter/3`, `Bot.Placing` (ordering), GameLive |
| `mana_place_colour` | int | `mana.place_colour` | `Rules.Mana.worker_mana/2` |
| `mana_good_colour` | int | `mana.good_colour` | `Rules.Mana.worker_mana/2` |
| `manameter_points_per_week` | ‰ | `manameter.points_per_week_permille` | `Rules.ManameterUpdate.update/3` |
| `birth_interval_weeks` | int | `birth.interval_weeks` | `Rules.Births.birth_week?/2` |
| `birth_min_food_left` | int | `birth.min_food_left` | `Rules.Births.attempt/5` |
| `good_food_eaten_per_worker` | int | `good.food.eaten_per_worker` | `Rules.Food.eat/3`, `Bot.BotActions.Feed` (`food_low?`) |
| `build_work` | int | `build.work` | `Rules.Construction.new_site/3` (a site's target), `Bot.Placing` (`earnings`), GameLive |
| `build_cost_gold` | int | `build.cost_gold` | `Game.build_cost/1`, `Game.construct/2`, GameLive |
| `build_capacity` | int | `build.capacity` | `Rules.Placement.capacity/2` (sites), `Bot.Placing` (`earnings`), GameLive |
| `book_work` | int (knowledge units) | `book.work` | `Rules.Books.new_book/3` (a book's target, `Fixed.from`) |
| `place_granary_food_spoilage` | ‰ | `place.granary.food_spoilage_permille` | `Rules.Granary.food_spoilage/2` (via `Rules.Spoilage.spoil/3`), GameLive |
| `place_granary_culture_upkeep` | int (culture units a week) | `place.granary.culture_upkeep` | `Rules.Granary.upkeep/3` (`Fixed.from`) |
| `way_plough_work` | int (knowledge units) | `way.plough.work` | `Rules.Inventions.new_invention/3` (the target, `Fixed.from`) |
| `way_plough_capacity` | int | `way.plough.capacity` | `Rules.Inventions.capacity/2` (via `Rules.Placement.capacity/2`) |
| `way_plough_bonus` | ‰ | `way.plough.bonus_permille` | `Rules.Inventions.farm_output/3`, GameLive |
| `travel_weeks` | int | `travel.weeks` | `Rules.Travel.depart/3`, `Rules.Training.first_week/2` |
| `training_min_share` | ‰ | `training.min_share_permille` | `Rules.Training.check/3` |
| `training_weeks` | int | `training.weeks` | `Rules.Training.last_week/2` |
| `king_grace_weeks` | int | `king.grace_weeks` | `Rules.Grace` (used by `Taxes`, `Demands` and `Happiness`) |
| `king_tax_per_worker` | int | `king.tax.per_worker` | `Rules.Taxes.assess/2` (also `Forecast.tax_amount/1`) |
| `king_tax_interval_weeks` | int | `king.tax.interval_weeks` | `Rules.Taxes.due_week?/2`, `next_due_week/2` |
| `king_tax_count_lead_weeks` | int | `king.tax.count_lead_weeks` | `Rules.Taxes.count_week?/2`, GameLive |
| `king_misses_forgiven` | int | `king.misses_forgiven` | `Rules.Misses`, GameLive |
| `king_demand_deadline_weeks` | int | `king.demand.deadline_weeks` | `Rules.Demands.schedule/3`, `make/5` |
| `king_demand_population_share` | ‰ | `king.demand.population_share_permille` | `Rules.Demands.make/5` |
| `king_demand_production_weeks` | int | `king.demand.production_weeks` | `Rules.Demands.make/5` |
| `good_spoilage` | `%{good => ‰}` | `good.<good>.spoilage_permille` ×5 | `Rules.Spoilage.spoil/3`, `Rules.Granary.food_spoilage/2` |
| `bandit_threshold` | int (×1000 in use) | `bandit.threshold` | `Rules.Bandits.threshold/1` (also `Forecast`, GameLive) |
| `bandit_warning_weeks` | int | `bandit.warning_weeks` | `Rules.Bandits` (sets `raid_week`) |
| `bandit_cover_weeks` | int | `bandit.cover_weeks` | `Rules.Bandits.protected/2` |
| `bandit_floor_step` | int (×1000 in use) | `bandit.floor_step` | `Rules.Bandits.floor/3` |
| `happiness_need_per_worker` | ‰ of a unit | `happiness.need_per_worker_permille` | `Rules.Happiness.ratio/3` |
| `happiness_penalty_below` | `%{level1..level3 => ‰}` | `happiness.level<n>.penalty_below_permille` ×3 | `Rules.Happiness.step_for/2` |
| `happiness_bonus_from` | `%{level1..level3 => ‰}` | `happiness.level<n>.bonus_from_permille` ×3 | `Rules.Happiness.step_for/2` |
| `happiness_change` | `%{level1..level3 => ‰}` | `happiness.level<n>.change_permille` ×3 | `Rules.Happiness.apply_step/3` |

`LoadConfig` takes the building types (capacities), the home types (output per worker) and
the goods from `Place.Blueprint.building_types/0`, `home_types/0` and `goods/0`,
and colours and relations from `Pentagon.colours/0` and `Pentagon.relations/0`; none of
them depends on `Config`. The list of trainings is written out in `LoadConfig`, not taken
from `Worker`, which depends on `Config` at compile time; `config_test.exs` checks it equals
`Worker.trainings/0`, and that every building type has its `place.<type>.*` keys.

## 2. Hardcoded values

Hard rule 2 says no game value lives outside the config. The constants below sit in code
anyway. Some are structure (the pentagon, the building types) and some are numbers. Before
you add one, ask the designer whether it should be a CSV key.

| Value | Where | Used by |
|---|---|---|
| 48 weeks per year (the designer's only sanctioned exception) | `Game` `@weeks_per_year`, `Game.weeks_per_year/0` | `Game.last_week/1`, `Demands`, `Bandits`, the bots |
| The order of the pipeline steps | `Game` `@pipeline` | `run_week/1` |
| Colours in pentagon order `green, yellow, blue, red, violet` (Growth, Wealth, Wisdom, Strength, Culture) | `Pentagon` `@colours`, `colours/0` | everything that iterates colours, the `Manameter` struct keys, `LoadConfig`, `Reporting` |
| Manameter total 1000 | `Manameter.total_shares/0` | `LoadConfig` (validation) |
| Same / neighbour / opposite from pentagon distance | `Pentagon.relation/2` | `Rules.Production` |
| Place type → colour, type → good; home places, ways (granary violet→food, building; plough blue→food, invention), guildhouse neutral | `Place.Blueprint` catalogue, `types/0`, `building_types/0`, `home_types/0`, `ways/0`, `way?/1`, `goods/0`, `home_type/1`, `home_colour/1` | everything that iterates types or goods |
| A way unlocks with 1 book of its colour and 1 of its good's home colour | `Rules.Ways.missing/2` | `Construct`, `Rules.Inventions.check_start/4`, GameLive |
| The improved plough's bonus applies to farm workers only | `Rules.Production` (`with_bonus`) | `Production.output/5` |
| The experience factor's normal share 200 ‰ (books and inventions) | `Rules.Books` `@normal_share` | `Books.written/3`, `Inventions.written/3` |
| Starting buildings: farm (id 1) and watchtower (id 2), both ready | `Place.Building.starting/0` | `Game.new/2` |
| Starting workers: green on the farm, red in the tower | `Worker.starting/2` (the counts come from the config) | `Game.new/2` |
| Starting stocks of knowledge, defence and culture are 0 | `Game` `starting_stocks/1` | `Game.new/2` |
| Fixed scale 1000 | `Fixed` `@scale` | all amounts |
| Per mille divisor 1000 | inline in `Production`, `Spoilage`, `Demands`, `Bandits.pressure/2` | — |
| Random algorithm `:exsss`, random seed up to 2³² | `Random` | `Game.new/2` |
| Short-week food marker `-1` | `Rules.Food` `@short` | `Food.eat/3`; read as `food_left < 0` |
| Births in weeks 1, 1 + interval, … | `Rules.Births.birth_week?/2` (`week - 1`) | — |
| 2 demands a year; project products `knowledge, culture`; takeable `food, gold`; Manameter rank by year `[0, 2, 4]` | `Rules.Demands` `@half_years_per_year`, `@project_products`, `@takeable_products`, `@ranks` | `Demands` |
| Bandits: 2 half years a year, floor 0 for the first 2 half years; pressure 1000 is the break-even and the repel limit | `Rules.Bandits` `@half_years_per_year`, `@floorless_half_years`, inline `1000` | `Bandits`, `Forecast.bandits/1` |
| Bandit starting state `%{threat: 0, raid_week: nil}` | `Rules.Bandits.starting/0` | `Game` defaults |
| Bots: pivot measure 200 ‰, default `pivot_week` 48 | `Bot.Analysis` `@points`, opts | the bots only (not the game) |
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
| `places` | `[%Place.Building{} \| %Place.Project{}]` | `Place.Building.starting/0` | `construct/2` (appends a site with `Rules.Construction.new_site/3`, between weeks), `start_book/2`, `start_invention/2` (append a project), `refuse_project/1` (removes the demand project); steps `Production` (project progress), `Construction` (site progress; replaces a done site by a building with a new id), `Books`, `Inventions` (remove done projects), `DemandDelivery` (removes the settled demand project), `DemandMade` (appends a demand project) |
| `manameter` | `%Manameter{}` ‰ | `config.manameter_start` | `ManameterUpdate` step |
| `stocks` | `%{food, knowledge, defence, gold, culture}` thousandths | `starting_stocks/1` | `construct/2` (gold); steps `Production` (+, and − the granaries' culture upkeep), `Eating` (food), `TaxPayment` (gold), `DemandDelivery`, `Bandits` (gold), `Spoilage` |
| `report` | `%WeeklyReport{}` | week-0 report | `run_week/1`; `construct/2` adds to `gold_spent_buildings` |
| `tax_due` | thousandths \| nil | nil | `TaxCount` sets it, `TaxPayment` clears it |
| `pay_tax` | bool \| nil | nil | `decide_tax/2` sets it, `TaxPayment` clears it |
| `demand` | `%{product, amount, due_week, project_id}` \| nil (`project_id` is the id of its project for knowledge and culture, `nil` otherwise) | nil | `DemandMade` sets it, `DemandDelivery` clears it |
| `deliver_demand` | bool \| nil | nil | `decide_demand/2`, `refuse_project/1`; `DemandDelivery` clears it |
| `misses` | int | 0 | `TaxPayment`, `DemandDelivery` (via `Rules.Misses`) |
| `bandits` | `%{threat (thousandths), raid_week \| nil}` | `Bandits.starting/0` | `Bandits` step |
| `books` | `%{colour => count}`, all five colours | `Rules.Books.none/0` (all 0) | `Books` step (+1 per finished book) |
| `inventions` | `[type]`, the types invented, in the order finished (R15) | `[]` | `Inventions` step (appends a finished invention) |
| `game_over` | bool | false | `TaxPayment`, `DemandDelivery` |

### `%Worker{}` ([worker.ex](../../../lib/my_liege/engine/worker.ex))

`id` and `colour` never change after birth. `born_week` is set by the `Birth` step (nil for
starting workers). `trained` is set by `TrainingEnd` and never reset. `place` (id \| nil)
and `travel` change with every placement (`Rules.Travel.depart/3`), and the `Travel` step
counts `travel` down. `training_started` is set when the worker is placed in a finished
guildhouse (`Rules.Training.first_week/2`) and cleared on a move or at the end of training.

### `%Place.Building{}` ([place/building.ex](../../../lib/my_liege/engine/place/building.ex))

`id` and `blueprint` (from `Place.Blueprint`, giving type, colour and good) never change. A
building is always finished.

### `%Place.Project{}` ([place/project.ex](../../../lib/my_liege/engine/place/project.ex))

`id`, `blueprint`, `target` and `gives` never change; `progress` starts at 0. A
construction site has the site blueprint (`type: :site`, no colour, no good), `target:
build_work` and `gives: {:building, type}`. The `Construction` step adds 1 to `progress` per
arrived builder; a builder leaving doesn't change it. Once `done?/1`, the step replaces the
site by a `%Place.Building{}` of `type` with a new id.

A book (R12) has `Project.book_blueprint/0` (blue, knowledge), `target:
Fixed.from(book_work)` and `gives: {:book, colour}`; `Actions.StartBook` appends it, the
`Production` step adds its writer's output (× experience) to `progress`, the `Books` step
removes it once done and adds the book to `game.books`.

An invention (R15) has its way's catalogue blueprint (`Blueprint.fetch!(:plough)`: blue,
food), `target: Fixed.from(way_plough_work)` and `gives: {:invention, type}`;
`Actions.StartInvention` appends it (unlocked, not open, not invented), the `Production`
step adds its workers' output (as in a blue building × the experience of food's home
colour, green) to `progress`, the `Inventions` step removes it once done and appends the
type to `game.inventions`.

A king's demand project has `Project.demand_blueprint(good)` (`type: :demand`, the good's
home colour, the good), `target` the demand's amount and `gives: {:demand, due_week}`. It is
appended by `DemandMade` (`Rules.Demands.open_project/2`); the `Production` step adds its
workers' output to `progress`, up to the target; `DemandDelivery` and `refuse_project/1`
remove it and release its workers.

## 4. The weekly report

[weekly_report.ex](../../../lib/my_liege/engine/weekly_report.ex),
[reporting.ex](../../../lib/my_liege/reporting.ex)

`WeeklyReport.new/2` starts each week empty, with zero maps over products and colours, and
the steps fill it. The field-by-step mapping is the "Order inside a week" table in
`weekly-step`. `game.report` holds the last report only. The history lives in callers:
`GameLive` (`@reports`), `Bot.run/4` and `EngineFixtures.run_weeks/2`.

- **Exported** by `Reporting.to_csv/1`: week, production, mana, manameter, food_left,
  newborn, trained, builders, travelling, gold, tax_due, tax, demand (product, amount),
  demand_outcome, demand_progress, king_took, spoiled, gold_spent_buildings,
  bandit_pressure, bandit_threat, bandits_weeks_to_raid, gold_robbed, happiness_ratio,
  happiness_step, game_over, books (`books_<colour>` in pentagon order, held at the end of
  the week), `plough_done` (`:plough in report.inventions`, end of the week),
  `granary_working`, `culture_upkeep` (thousandths, taken that week).
- **Not exported**: `start` (the game at the start of the week, `nil` once the week is done),
  `stock_change` and `project_change` (for `Forecast`), `bandit_protected`,
  `bandit_threat_change` and `bandit_raid` (for the UI), `books_finished` (the colours of
  the books finished that week), `inventions_finished` (the types finished that week).

The export format is fixed. Ask before changing a column (hard rule 5).

## 5. Derived and read-only

- `Forecast` ([forecast.ex](../../../lib/my_liege/engine/forecast.ex)) is computed from
  `game.stocks`, `game.demand`, `game.bandits`, `game.tax_due`, `report.stock_change`,
  `report.project_change`, `report.bandit_pressure` and the config. It never changes the game.
  GameLive (`assign_game/2`) and the bots (`Feed.food_low?/1`, `SaveGold.gold_low?/1`, `Bot.Placing`) read it.
- Predicates on `Game` (`tax_decision_due?/1`, `demand_decision_due?/1`,
  `project_refusable?/1`, `won?/1`, `can_afford_building?/1`, `build_cost/1`) are derived
  from state and config too.

## Who touches what (outside the engine)

| Module | Reads | Writes |
|---|---|---|
| `MyLiegeWeb.GameLive` | `Config.from_csv/0`, game fields, config fields (see the tables), `Forecast`, `Rules.Bandits`, `Rules.Construction`, `Rules.Placement`, `Place`, `Place.Blueprint`, `Manameter`, `Fixed.scale/0` | only through `Game` actions and `run_week/1` |
| `MyLiege.Bot` (`lib/my_liege/bot/`) | the config it is given, `Forecast`, `Place`, `Place.Blueprint`, `game.workers`, `game.places`, `game.stocks` | only through `Game` actions |
| `MyLiege.Reporting` | `WeeklyReport` fields, `Place.Blueprint.goods/0`, `Pentagon.colours/0` | none |
| `EngineFixtures` (tests) | builds its own `%Config{}` | none |

## Changing the data

- **New CSV key**: name it by the key names above, add it to `@enforce_keys` in `Config`, to `LoadConfig.load!/1` (and
  `EngineFixtures.config/1`), and read it in a rule. List the key and the designer's value in
  the hand-over. Name the key in `rules/rules.md`, never the value.
- **New state field**: add it to `Game`'s defstruct with a starting value. Have exactly one
  step (or one player action) change it, through a rule.
- **New report field**: add it to `WeeklyReport` (struct and `@type`). Export it only if the
  designer agrees (hard rule 5).
- **Update this skill** in the same change: the right table. A CSV key no code reads fails
  the build, so add the key and its reader together.

Quick checks:

```sh
# numeric module attributes in the engine (candidates for hardcoded game values)
grep -rnE "^\s*@[a-z_]+ -?[0-9\[]" lib/my_liege
# who reads a config field
grep -rn "config\.<field>" lib
```
