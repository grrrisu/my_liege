---
name: weekly-step
description: 'How one week of My Liege runs in the rules engine (Game.run_week): order of steps, week numbering, units, and what each step reads and writes. Use when: changing or debugging the weekly loop, adding a step (e.g. taxes R7, training R5, inventions R15), reading reports or CSV exports, writing tests that run weeks, or answering "when does X happen in a week".'
---

# Weekly step

One call to `Game.run_week(game)` runs one week and returns `{:ok, report, game}`.
It is blocked, without changing anything, with:
- `{:error, :game_over}` once `game.game_over` is set;
- `{:error, :finished}` after the last week, `Game.last_week/1` (48 × `game_years`;
  48 weeks per year is fixed in `Game.weeks_per_year/0`, not in the CSV). Reaching it without
  game over is a win: `Game.won?/1`;
- `{:error, :tax_undecided}` when the next week is a due week (`Game.tax_decision_due?/1`)
  and the player hasn't decided with `Game.decide_tax/2` yet;
- `{:error, :demand_undecided}` when the next week is the deadline of a demand from the stock
  (`Game.demand_decision_due?/1`) and the player hasn't decided with `Game.decide_demand/2`.
  Projects (knowledge, culture) need no decision.

Code: [game.ex](../../../lib/my_liege/engine/game.ex),
[sim_steps/](../../../lib/my_liege/engine/sim_steps/),
[rules/](../../../lib/my_liege/engine/rules/).

## Pipeline

The week is `Game.pipeline/0`, in the order of "Weekly order" in `rules/rules.md` (table
below). The structure (the step contract, `game` vs. the start of the week, `EndOfWeek`,
rules vs. steps) is in the `engine-architecture` skill.

## Week numbering

- `game.week` is the **last week run**, i.e. the state at the end of that week.
- Week 0 is the starting state from the config (`Game.new/2`); nothing has happened yet.
- `run_week` runs `game.week + 1`. Every rule in it sees that same week number.
- A full game is weeks 1 to 48 × `game_years`.
- Between two weeks the player (or a bot, `MyLiege.Bot`) acts on the state of week N through
  `Game`: `Game.place_worker/3` (`Actions.PlaceWorker`), `Game.unplace_worker/2`
  (`Actions.UnplaceWorker`), `Game.construct/2` (`Actions.Construct`),
  `Game.decide_tax/2` (`Actions.DecideTax`), `Game.decide_demand/2`
  (`Actions.DecideDemand`), `Game.refuse_project/1` (`Actions.RefuseProject`),
  `Game.start_book/2` (`Actions.StartBook`), `Game.start_invention/2`
  (`Actions.StartInvention`). Traders on a trade route (R16) and hunters at the hunting camp
  (R17) are placed with `place_worker/3` like any worker; a camp left empty loses its bag.
  Changes take effect in week N + 1. `construct/2` pays `build_cost_gold` from the gold stock
  at once and adds it to `gold_spent_buildings` of week N's report (`{:error, :not_enough_gold}`
  if the stock is short; `{:error, :locked}` for a way without its two books, R13).

## Order inside a week

| # | Step | Module (`SimSteps.*` → rule) | Reads | Writes |
|---|------|--------|-------|--------|
| 0 | Tax count (R7), count weeks only | `TaxCount` → `Rules.Taxes.assess/2` | **all** workers before this week's birth | `game.tax_due`, `report.tax_due` |
| 1 | Production (R2), granary upkeep (R14), the ploughs' bonus (R15), happiness (R11) | `Production` → `Rules.Production.output/5` and `project_output/5`, `Rules.Granary.working/3`, `upkeep/3` and `culture_for_happiness/2`, `Rules.Happiness.assess/4` and `apply_step/3` | placed workers with travel 0 in buildings and on projects (`Rules.Staffing.working/3`); `game.inventions`; the culture stock; **all** workers at the start of the week (population) | home buildings' output (farm workers × the plough bonus once invented; a granary produces nothing): `report.production` (food and defence after the happiness step), added to `stocks`; the granaries' upkeep taken from `stocks.culture` (never below 0): `report.culture_upkeep`, `report.granary_working`, `report.granaries_working` (how many); `report.happiness` (`ratio`, `step`, `step_without_grace`) from the buildings' culture minus the upkeep, never below 0; demand projects' output (same step), books' and inventions' output (as in a blue building × the experience of the book's colour, or of the invention's good's home colour; Manameter at the **start** of the week) into each project's `progress`, up to its target, the rest lost; `report.demand_progress` |
| 2 | Mana (R3) | `Mana` → `Rules.Mana.produced/4` | same workers and their places (not the workers' colour or training) | `report.mana` |
| 3 | Travel (R2) | `Travel` → `Rules.Travel.count_down/1` | every worker's `travel` | `travel` − 1, not below 0 |
| 4 | Manameter update (R4) | `ManameterUpdate` → `Rules.ManameterUpdate.update/3` | old Manameter, this week's mana | `manameter` |
| 5 | Eating (R8) | `Eating` → `Rules.Food.eat/3` | food stock after production, **all** workers (placed or not) | `stocks.food` (0 in a short week), `report.food_short` |
| 6 | Birth (R1) | `Birth` → `Rules.Births.attempt/5` | week, the food left, `report.food_short`, the **updated** Manameter, `rand` | `newborn`, `rand` (no attempt and no draw in a short week) |
| 7 | Construction (R2) | `Construction` → `Rules.Construction.advance_sites/4` | sites (`%Place.Project{}`), builders as at the **start** of the week (before step 3) | `progress` (+1 per arrived builder); a done site replaced by its `%Place.Building{}` with a new id; its builders `place: nil` with `travel_weeks` |
| 8 | Books finished (R12), trade route (R16) and hunting camp (R17) opened | `Books` → `Rules.Books.finish/4`, `Rules.Placement.release/3`, `Rules.Ways.open/4` | book projects with `progress >= target`; the books held | `game.books` (+1 of the colour), the project removed from `places`, its writer `place: nil` with `travel_weeks`; `report.books_finished`; a route or camp the books now unlock appended to `places` (once each), `report.ways_opened` |
| 8 | Inventions finished (R15), after the books | `Inventions` → `Rules.Inventions.finish/4`, `Rules.Placement.release/3` | invention projects with `progress >= target` | `game.inventions` (+ the type), the project removed from `places`, its workers `place: nil` with `travel_weeks`; `report.inventions_finished` |
| 8 | Hunting camp (R17) and the king's suspicion (R18), after the inventions | `Hunts` → `Rules.Hunting.hunt/4`, `Rules.Suspicion.after_haul/4`, `block_end?/2`, `decay/2`, `check_threshold/2`, `Rules.Misses.add/2` | the camp, its hunters' travel at the **start** of the week, `rand`, `suspicion`, `misses`, week | the camp's `bag`, `weeks`, `hunted_in_block`; in a haul week one luck draw (`rand`) and `stocks.food` (+ the haul); `suspicion` (haul change, idle-block decay at weeks 6, 12, …, halved at the threshold); `misses`, `game_over` at the threshold; `report.hunters`, `haul`, `food_from_hunting`, `suspicion_miss` |
| 9 | Training ends (R5) | `TrainingEnd` → `Rules.Training.finish/4` | trainees in the guildhouse, week | `trained`, `place: nil`, `travel_weeks`, `report.trained` |
| 10 | Tax payment (R7), due weeks only | `TaxPayment` → `Rules.Taxes.settle/3` | gold after production, `tax_due`, `pay_tax` | `stocks.gold`, `misses`, `game_over`, `report.tax`, `report.king_took.gold` |
| 11 | Demand delivery (R7): deadline week, a project done, or a project refused before the week | `DemandDelivery` → `Rules.Demands.settle/4`, `Rules.Placement.release/3` | stocks, `demand`, its project, `deliver_demand` | stocks (not for projects), the project removed from `places` and its workers released, `misses`, `game_over`, `report.demand_outcome`, `report.king_took` |
| 12 | Demand made (R7), demand weeks only | `DemandMade` → `Rules.Demands.make/5`, `open_project/2` | week, Manameter, workers at the start of the week | `game.demand`, for knowledge and culture its project appended to `places`; `report.demand`, `report.demand_progress` (0 for a project) |
| 13 | Trade route (R16), every week | `TradeRoute` → `Rules.Trades.settle/4` | each route's queue, its traders' travel at the **start** of the week, the gold stock | `stocks.gold` (− each price paid), `stocks.food` (+ `way_grain_trade_food_per_week` per paying trader), the queue cut to the workers still on the route; `report.gold_to_trade`, `food_from_trade`, `traders` |
| 14 | Bandits (R10), every week | `Bandits` → `Rules.Bandits.run/6` | `bandits` (threat, raid week), gold after steps 10–13, `report.production.defence`, week | `bandits`, `stocks.gold` (raid), `report.bandit_pressure`, `bandit_protected`, `bandit_threat_change`, `bandit_raid`, `gold_robbed` |
| 15 | Spoilage (R9), granary (R14) | `Spoilage` → `Rules.Spoilage.spoil/3` | every stock above 0, `good_spoilage` (per mille, key `good.<good>.spoilage_permille`); food in two parts: `Granary.protected/3` (`report.granaries_working` from step 1 × `place_granary_food_capacity`, at most the stock) at `place_granary_food_spoilage`, the rest at the good's rate, each rounded down (`Granary.food_spoiled/3`) | `stocks`, `report.spoiled`, `report.food_protected`; `report.food_left` and `report.gold` are after it |
| 16 | End of week | `EndOfWeek` | the final game | `report.manameter`, `food_left`, `gold`, `builders`, `travelling`, `bandit_threat`, `bandits_weeks_to_raid`, `books`, `inventions`, `game_over`; `start: nil` |

Consequences of the order:
- A newborn is drawn from the Manameter updated in step 4 of the same week.
- Production, mana and construction see travel as it was before step 3, and training starts
  after the travel, so a worker placed at state N does nothing in N + 1 and works from N + 2.
- An invention finished in step 8 of week M takes effect from the production of week M + 1.
- A haul arrives in step 8: after eating and birth, before taxes, demands, bandits and
  spoilage of the same week. A hunter placed at state N hunts from week N + 1 +
  `way_hunting_travel_weeks`; hunting every week from then, his first haul is in week
  N + `way_hunting_travel_weeks` + `way_hunting_haul_weeks`.
- The trade route settles in step 13, after taxes and demands (so it never makes them
  miss) and before bandits and spoilage: the bandits see the gold after the trade, and its
  food spoils that week. A trader placed at state N arrives after
  `way_grain_trade_travel_weeks` like production: he trades from week N + 1 + travel.
- A haul's luck is drawn in step 8, after the week's birth draw (step 6), at most once a
  week and only in a haul week: it never changes that week's birth, only later ones, and a
  game without hauls draws only births.
- A suspicion miss (step 8) is counted before that week's tax (step 10) and demand
  (step 11); either may then end the game.
- A granary works (spoilage, upkeep) in the weeks its keeper works: the staffing at the
  start of the week, the same as production and mana.
- Workers released in steps 7, 8 and 9 (and 11, from a demand project) keep their full travel into the next week: released at
  the end of week M, they can be placed again from state M + 1.
- A newborn is added after eating, so it eats from the following week; it is unplaced.
- Production and mana use the workers as placed before the week started.
- Happiness (R11) changes food and defence inside step 1, before anything goes to a stock or a
  project, so eating and bandits see the changed production; culture made on a project
  doesn't count toward it; a newborn counts in the
  population from the following week.
- Bandits see the gold after taxes, demands and the trade route: paying the king lowers the
  pressure, and a raid never causes a tax or demand miss.
- Births, taxes, demands and bandits see the stocks before spoilage; spoilage rounds down and leaves
  an empty stock alone. No stock goes below 0.

## Rules each step relies on

- **Sites:** a building ordered at state N (paid then, `build_cost_gold`) is a site, a
  `%Place.Project{}` with `target: build_work`, `progress: 0` and room for `build_capacity`
  builders (any colour). Each week, every builder on it with travel 0 at the start of the
  week adds 1 to `progress`; when `progress` reaches the target at the end of week M, the
  site is replaced by a `%Place.Building{}` with the next free id, which takes workers from
  then on and produces from M + 1 (production runs before construction). A builder leaving
  (moved or unplaced) keeps the progress. Placement needs room
  (`Rules.Placement.check_enter/3`); a building is always finished.
- **Travel:** `Rules.Travel.depart/3` sets `travel = travel_weeks` on every place, move, unplace and
  release. Unplaced workers with travel above 0 can't be placed (`{:error, :travelling}`).
  `Rules.Staffing.working/3` leaves travelling workers out.
- **Training:** the guildhouse is neutral (no colour, product or mana; `Rules.Staffing.working/3`
  leaves it out). Placing an untrained worker in a finished guildhouse needs its colour's share ≥
  `training_min_share`, checked once; `training_started = game.week + 1 + travel_weeks`
  (`Rules.Training.first_week/2`). At the end of week `training_started + training_weeks - 1` the
  worker is trained, unplaced and travelling. Moving it out earlier loses the progress.
  Trainees still eat and count for taxes; no other cost.
- **Births:** attempted in weeks 1, 1 + interval, … (`rem(week - 1, birth_interval_weeks) == 0`),
  only if the week wasn't short and `food_left >= Fixed.from(birth_min_food_left)`. `Rules.Births.attempt/5` is the
  single place that decides a birth.
- **Short week:** if food after production is less than everyone eats, the missing food is
  forgotten and the food stock stops at 0 (`Rules.Food.eat/3` returns `{0, true}`).
  `report.food_short` marks the week; it blocks the birth, the UI shows "short", the bots'
  `Feed` reads it and the analysis counts it (`weeks_food_below_0`). Revisit with T65
  (hunger).
- **Manameter:** shares in per mille, always summing to 1000. Each week
  `manameter_points_per_week` shares are removed in proportion to current shares and added
  in proportion to the week's mana; round down, leftover units to the largest remainders,
  ties in pentagon order. A week without mana leaves it unchanged.
- **Randomness:** births (step 6) and returning hunts (step 8, one draw each) draw from
  `game.rand`, nothing else during the game; the same seed and the same actions replay
  the same run.
- **Grace period:** `Rules.Grace`: weeks 1 to `king_grace_weeks` have no due week, no count for
  one and no demand week. Test configs set `king_grace_weeks: 0`.
- **Taxes:** due in weeks `king_tax_interval_weeks`, 2 × `king_tax_interval_weeks`, … after the grace
  period; counted
  `king_tax_count_lead_weeks` earlier at `king_tax_per_worker` per head, and the amount is fixed then.
  The player must decide with `decide_tax/2` while the game stands at the week before a due
  week (`pay_tax` is `nil` until then and resets to `nil` after payment). Outcomes:
  `:paid` (full amount), `:skipped` (on purpose), `:missed` (not enough gold); no partial
  payments. On `:skipped` and `:missed` the king takes the gold there is, up to the amount
  (`Rules.Taxes.settle/3` returns it as `taken`). More than `king_misses_forgiven` misses set `game_over`, which blocks further
  weeks. The count `misses` is shared with the king's demands. The bots always try to pay
  and deliver; their runs end at game over.
- **Bandits (R10):** `game.bandits` is `%{threat, raid_week}` (threat in thousandths).
  Not affected by the grace period. Protected gold = defence production × `bandit_cover_weeks`;
  pressure = gold × 1000 ÷ protected (0 without gold, `:unbounded` without defence); the
  threat rises by pressure − 1000 when positive (never falls on its own), floored at `Rules.Bandits.floor/3` (0 in year 1, then
  + `bandit_floor_step` per half year); `:unbounded` sets it to the threshold. At the threshold
  they set out (`raid_week = week + bandit_warning_weeks`) and the threat freezes; in the raid
  week they take gold − protected unless pressure ≤ 1000, then the threat drops to the floor.
  `EngineFixtures.config/1` sets threshold and warning weeks so high that tests about other
  rules are never robbed. The UI shows the last report's `bandit_protected` and
  `bandit_threat_change`, so they match the production shown.
- **King's demands:** one per half year (`Game.weeks_per_year/0` ÷ 2), in a week drawn at
  `Game.new/2` from the seed (`game.demand_weeks`), among the half year's weeks after the
  grace period, so the deadline, `king_demand_deadline_weeks` later, stays in the same half year;
  a half year without such a week has no demand and uses no draw. The product belongs to the colour ranked 1st (year 1),
  3rd (year 2) or 5th (year 3 on) in the Manameter when the demand is made; ties in pentagon
  order. Amount: workers at the start of the demand week (before its birth) ×
  `king_demand_population_share` (per mille) × base production of that colour's building ×
  `king_demand_production_weeks`; 0 means no demand. Tests about other rules use
  `EngineFixtures.game_without_demands/2`.
  Outcomes: `:delivered`, `:refused`, `:missed` (stock short); refused and missed count as
  misses. On a refused or missed food or gold demand the king takes the stock there is, up to
  the amount; defence and projects leave nothing to take.
- **Projects:** a demand for knowledge or culture opens a `%Place.Project{gives: {:demand,
  due_week}}` with the amount as target (`project_id` on the demand, others `nil`;
  `Rules.Demands.project?/1`). Workers placed on it (any number, any colour, travel as usual)
  produce and make mana as in a building of its colour and good; their output goes into it in
  step 1, up to the target. Building output never goes into it and the stock is never used.
  Step 11 settles it as `:delivered` in the week its target is reached (at or before the
  deadline), `:missed` at the end of the deadline week; either way the project leaves
  `places` and its workers are released (unplaced, travelling). No decision gate.
  `refuse_project/1` (between weeks, while open) sets `deliver_demand: false`, removes the
  project and releases its workers at once; the next week's step 11 settles it as `:refused`.

- **Books (R12):** `Game.start_book/2` (`Actions.StartBook`, between weeks, free, any
  colour, several at once) appends a `%Place.Project{gives: {:book, colour}}` with target
  `Fixed.from(book_work)`; it takes one writer (`Rules.Placement.capacity/2` is 1). In step 1
  the writer produces as in a blue building (`Rules.Production.project_output/5`), times
  `Rules.Books.written/3`: × the book colour's share of `report.start.manameter` ÷ 200,
  rounded down per worker, into the book up to its target. Mana as in a blue building. Step
  8 (`Rules.Books.finish/4`) adds a finished book to `game.books` (colour => count, all
  colours from 0), removes the project and releases the writer. Books are never used up;
  they unlock ways (R13).
- **Ways (R13):** `Rules.Ways.missing/4` (blueprint, books, inventions, config): a way
  (`Blueprint.way?/1`) needs `Ways.books_needed/2` books of its colour and as many of its
  good's home colour (the entry's `books`: 1, or `:config` for `config.way_books[type]`),
  and the invention in its entry's `requires`, if any. It returns what is missing,
  `[{:book, colour, count} | {:invention, type}]`. `Construct` and `StartInvention` refuse a
  locked way with `{:error, :locked}`; the Books step opens a standing way once unlocked.
- **Granary (R14):** a violet building for food, ordered and built as usual; capacity
  `place_capacity.granary`. Its keeper produces nothing (`Production.produces?/1`), makes
  mana (2 violet, 1 green). A granary works while its keeper works (`Granary.working/3`):
  in step 15 each working granary protects up to `place_granary_food_capacity` food (all
  of them together at most the stock), which spoils at `place_granary_food_spoilage`; the
  rest of the stock spoils at the good's rate, each part rounded down in thousandths; and
  each working granary takes `place_granary_culture_upkeep` culture from the stock in step 1,
  never below 0; what is taken is subtracted from the culture for happiness, never below 0.
- **Improved plough I and II (R15):** `Game.start_invention(game, type)` with `:plough` or
  `:plough_2` (free, once unlocked, one open project per type, once per game) appends
  `%Place.Project{gives: {:invention, type}}`, target `Inventions.target/2`
  (`way_plough_work`, `way_plough_2_work`), up to `Inventions.capacity/2` workers. They write
  as in a blue building × green's experience (`Rules.Inventions.written/3`); mana 2 blue,
  1 green. Step 8 appends the type to `game.inventions`; from the next week each farm
  worker's output × (1000 + `Inventions.farm_bonus/2`, the bonuses of the ploughs invented
  added) ÷ 1000, rounded down per worker, before happiness.
- **Grain trade route (R16):** `%Place.Trade{}` appended by the Books step once a yellow
  and a green book are held, one per game. `place_worker/3` puts a worker on it up to
  `way_grain_trade_capacity` (any colour, trained or not) and last in its `traders` queue
  (`Trades.join/3`); travel there and away is `way_grain_trade_travel_weeks`
  (`Rules.Travel.weeks/3`). Arrived, a trader is a working worker for mana (2 yellow,
  1 green; `Staffing.works?/2`) but produces nothing (`Production.produces?/1`); he eats and
  counts for taxes. Step 13: for each arrived trader in queue order, price =
  `Fixed.from(way_grain_trade_gold_per_week) × 1000 ÷` his factor against yellow (R2),
  rounded down (`Trades.price/3`); paid if the gold left covers it, then
  `way_grain_trade_food_per_week` food; otherwise nothing, and he stays.
- **Hunting camp (R17):** `%Place.Expedition{}` appended by the Books step once a red and a
  green book are held, one per game. `place_worker/3` puts a worker on it up to
  `way_hunting_max_party` (any colour); travel there and away is
  `way_hunting_travel_weeks`. Arrived, a hunter is a working worker for mana (2 red, 1 green)
  but produces nothing. Step 8: each arrived hunter adds `Fixed.from(way_hunting_food_per_week)`
  × his factor against red ÷ 1000 to `bag` (`Hunting.hunter_week/2`); a week with one adds 1
  to `weeks`. At `weeks == way_hunting_haul_weeks`: `Hunting.draw_luck/3`
  (`:rand.uniform_s(10)` against the counts for the arrived hunters), `bag × luck ÷ 1000`
  rounded down into `stocks.food`, `bag` and `weeks` back to 0. `abandon_empty/2` in
  `PlaceWorker`/`UnplaceWorker` empties both when no worker is left on the camp.
- **Suspicion (R18):** in step 8 after the camp: a haul by 2+ hunters adds
  `king_suspicion[luck]`, by 1 hunter takes `king_suspicion_decay`; at a block end (`rem(week,
  way_hunting_haul_weeks) == 0`) a camp with `hunted_in_block` false takes the decay, and the
  flag is cleared; never below 0. Then `check_threshold/2`: at `king_suspicion_threshold` or
  more, one miss (`Misses.add/2`, may end the game) and the suspicion halved, rounded down.

## Units

- Stocks and production: thousandths (`Fixed`), so `27_000` food is 27 wheat.
- Shares and factors: per mille (`800` = 80%).
- Config values stay in whole units; convert with `Fixed.from/1` at the point of use.

## Report

`%WeeklyReport{week, production, mana, manameter, food_left, newborn, trained, builders,
travelling, gold, tax_due, tax, demand, demand_outcome, demand_progress, king_took, spoiled,
gold_spent_buildings, bandit_pressure, bandit_protected, bandit_threat, bandit_threat_change,
bandits_weeks_to_raid, bandit_raid, gold_robbed, happiness, books, books_finished,
granary_working, granaries_working, food_protected, culture_upkeep, inventions,
inventions_finished, food_short,
food_from_trade, gold_to_trade, traders, ways_opened, hunters, haul, food_from_hunting,
suspicion, suspicion_miss, stock_change,
project_change, game_over, start}` (`start`: see `engine-architecture`). `builders` counts arrived builders
on sites and `travelling` the workers with travel above 0, both at the end of the week;
`king_took` is `%{food, gold}`, what the king took that week on misses.
`Game.report/1` returns the last one (week 0 for a new game). `MyLiege.Reporting.to_csv/1`
writes one row per report.

## Adding or changing a step

1. Check `rules/rules.md` and `.github/copilot-instructions.md`: the rule must be defined,
   every value must come from a CSV key, and open points must be asked, not guessed.
2. Decide where the step sits in the order above and what it reads and writes; ask the
   designer if `rules/rules.md` doesn't say.
3. Put the rule in `rules/` and the step in `sim_steps/` as described in the
   `engine-architecture` skill, and add one line in `@pipeline` in `Game` at its place in
   "Weekly order".
4. Add what the step produces to `WeeklyReport`, then to `Reporting` if it belongs in the
   export.
5. Tests: one describe block per rule with `EngineFixtures.config/1` (it sets
   `travel_weeks` to 0, and a site needs builders: a test that needs a finished building adds
   one with `EngineFixtures.add_building/2`; tests about R2 builders or travel pass their
   own values) in `test/my_liege/engine/rules/`, a test of the step in
   `test/my_liege/engine/sim_steps/`, and the new step in the `Game.pipeline/0` test in
   `game_test.exs`. To run many weeks in a test, use
   `EngineFixtures.run_weeks/2` (pays every tax). Update this skill, and update
   `rules/rules.md` (the rule, its order and a changelog line) so the designer can sync it.
6. Run `mix precommit`.
