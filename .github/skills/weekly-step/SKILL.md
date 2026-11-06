---
name: weekly-step
description: 'How one week of My Liege runs in the rules engine (Game.run_week): order of steps, week numbering, units, and what each step reads and writes. Use when: changing or debugging the weekly loop, adding a step (e.g. taxes R7, training R5, plough R6), reading reports or CSV exports, writing tests that run weeks, or answering "when does X happen in a week".'
---

# Weekly step

One call to `Game.run_week(game)` runs one week and returns `{:ok, report, game}`.
It is blocked, without changing anything, with:
- `{:error, :game_over}` once `game.game_over` is set;
- `{:error, :finished}` after the last week, `Game.last_week/1` (48 × `years_per_game`;
  48 weeks per year is fixed in `Game.weeks_per_year/0`, not in the CSV). Reaching it without
  game over is a win: `Game.won?/1`;
- `{:error, :tax_undecided}` when the next week is a due week (`Game.tax_decision_due?/1`)
  and the player hasn't decided with `Game.decide_tax/2` yet;
- `{:error, :demand_undecided}` when the next week is the deadline of a demand from the stock
  (`Game.demand_decision_due?/1`) and the player hasn't decided with `Game.decide_demand/2`.
  Projects (knowledge, entertainment) need no decision.

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
- A full game is weeks 1 to 48 × `years_per_game`.
- Between two weeks the player (or an `AutoRun` pattern) acts on the state of week N:
  `place_worker/3`, `unplace_worker/2`, `construct/2`, `decide_tax/2`, `decide_demand/2`,
  `refuse_project/1`.
  Changes take effect in week N + 1. `construct/2` pays `build_cost_gold` from the gold stock
  at once and adds it to `gold_spent_buildings` of week N's report (`{:error, :not_enough_gold}`
  if the stock is short).

## Order inside a week

| # | Step | Module (`SimSteps.*` → rule) | Reads | Writes |
|---|------|--------|-------|--------|
| 0 | Tax count (R7), count weeks only | `TaxCount` → `Rules.Taxes.assess/2` | **all** workers before this week's birth | `game.tax_due`, `report.tax_due` |
| 1 | Production (R2) | `Production` → `Rules.Production.output/4`, `Rules.Demands.feed/2` | placed workers with travel 0 in buildings ready this week; an open, unrefused project | `report.production`; the project's product into `demand.progress` up to its amount, the rest added to `stocks`; `report.demand_progress` |
| 2 | Mana (R3) | `Mana` → `Rules.Mana.produced/4` | same workers | `report.mana` |
| 3 | Travel (R2) | `Travel` → `Rules.Travel.count_down/1` | every worker's `travel` | `travel` − 1, not below 0 |
| 4 | Manameter update (R4) | `ManameterUpdate` → `Rules.ManameterUpdate.update/3` | old Manameter, this week's mana | `manameter` |
| 5 | Eating (R8) | `Eating` → `Rules.Food.eat/3` | food stock after production, **all** workers (placed or not) | `food_left` |
| 6 | Birth (R1) | `Birth` → `Rules.Births.attempt/5` | week, `food_left`, the **updated** Manameter, `rand` | `newborn`, `rand` |
| 7 | Construction (R2) | `Construction` → `Rules.Construction.advance_sites/5` | sites, builders as at the **start** of the week (before step 3) | `progress`, `ready_week`, finished builders `building: nil` with `travel_weeks` |
| 8 | Training ends (R5) | `TrainingEnd` → `Rules.Training.finish/4` | trainees in the guildhouse, week | `trained`, `building: nil`, `travel_weeks`, `report.trained` |
| 9 | Tax payment (R7), due weeks only | `TaxPayment` → `Rules.Taxes.settle/3` | gold after production, `tax_due`, `pay_tax` | `stocks.gold`, `misses`, `game_over`, `report.tax` |
| 10 | Demand delivery (R7), deadline weeks, or a project refused before the week | `DemandDelivery` → `Rules.Demands.settle/3` | stocks, `demand`, `deliver_demand` | stocks (not for projects), `misses`, `game_over`, `report.demand_outcome` |
| 11 | Demand made (R7), demand weeks only | `DemandMade` → `Rules.Demands.make/5` | week, Manameter, workers at the start of the week | `game.demand`, `report.demand`, `report.demand_progress` (0 for a project) |
| 12 | Spoilage (R9) | `Spoilage` → `Rules.Spoilage.spoil/2` | every stock above 0, `spoilage_rates` (per mille, key `spoilage_rate_<product>`) | `stocks`, `report.spoiled`; `report.food_left` and `report.gold` are after it |
| 13 | End of week | `EndOfWeek` | the final game | `report.manameter`, `food_left`, `gold`, `builders`, `travelling`, `game_over`; `start: nil` |

Consequences of the order:
- A newborn is drawn from the Manameter updated in step 4 of the same week.
- Production, mana and construction see travel as it was before step 3, and training starts
  after the travel, so a worker placed at state N does nothing in N + 1 and works from N + 2.
- Workers released in steps 7 and 8 keep their full travel into the next week: released at
  the end of week M, they can be placed again from state M + 1.
- A newborn is added after eating, so it eats from the following week; it is unplaced.
- Production and mana use the workers as placed before the week started.
- Births, taxes and demands see the stocks before spoilage; spoilage rounds down and leaves
  stocks at or below 0 (a short week's -1) alone.

## Rules each step relies on

- **Sites and readiness:** a building ordered at state N (paid then, `build_cost_gold`) is a
  site: `ready_week: nil`, `progress: 0`, room for `builders_per_building` builders (any
  unplaced worker that has arrived). It advances in each week in which all builders were on
  it with travel 0 at the start of the week; when `progress` reaches `construction_weeks` at
  the end of week M, `ready_week = M + 1`. A builder leaving (moved or unplaced) resets
  `progress` to 0. Placement in a finished building needs `ready?(building, game.week + 1)`
  and room.
- **Travel:** `Rules.Travel.depart/3` sets `travel = travel_weeks` on every place, move, unplace and
  release. Unplaced workers with travel above 0 can't be placed (`{:error, :travelling}`).
  `Building.staffed/3` leaves travelling workers out.
- **Training:** the guildhouse is neutral (no colour, product or mana; `Building.staffed/3`
  leaves it out). Placing an untrained worker in a finished guildhouse needs its colour's share ≥
  `training_threshold`, checked once; `training_started = game.week + 1 + travel_weeks`
  (`Rules.Training.first_week/2`). At the end of week `training_started + training_weeks - 1` the
  worker is trained, unplaced and travelling. Moving it out earlier loses the progress.
  Trainees still eat and count for taxes; no other cost.
- **Births:** attempted in weeks 1, 1 + interval, … (`rem(week - 1, birth_interval_weeks) == 0`),
  only if `food_left >= Fixed.from(birth_min_food_left)`. `Rules.Births.attempt/5` is the
  single place that decides a birth.
- **Short week:** if food after production is less than everyone eats, the missing food is
  forgotten and `food_left` is set to -1. That blocks the birth and marks the week as short
  (`food_left < 0`). The -1 carries into the next week. Revisit with T65 (hunger).
- **Manameter:** shares in per mille, always summing to 1000. Each week
  `manameter_points_per_week` shares are removed in proportion to current shares and added
  in proportion to the week's mana; round down, leftover units to the largest remainders,
  ties in pentagon order. A week without mana leaves it unchanged.
- **Randomness:** only births draw random numbers, from `game.rand`; the same seed replays
  the same run.
- **Taxes:** due in weeks `tax_interval_weeks`, 2 × `tax_interval_weeks`, …; counted
  `tax_count_lead_weeks` earlier at `tax_per_worker` per head, and the amount is fixed then.
  The player must decide with `decide_tax/2` while the game stands at the week before a due
  week (`pay_tax` is `nil` until then and resets to `nil` after payment). Outcomes:
  `:paid` (full amount), `:skipped` (on purpose), `:missed` (not enough gold); no partial
  payments. More than `tax_misses_forgiven` misses set `game_over`, which blocks further
  weeks. The count `misses` is shared with the king's demands. `AutoRun` always tries to pay
  and deliver; its runs end at game over.
- **King's demands:** one per half year (`Game.weeks_per_year/0` ÷ 2), in a week drawn at
  `Game.new/2` from the seed (`game.demand_weeks`) so the deadline, `demand_deadline_weeks`
  later, stays in the same half year. The product belongs to the colour ranked 1st (year 1),
  3rd (year 2) or 5th (year 3 on) in the Manameter when the demand is made; ties in pentagon
  order. Amount: workers at the start of the demand week (before its birth) ×
  `demand_population_share` (per mille) × base production of that colour's building ×
  `demand_production_weeks`; 0 means no demand. Tests about other rules use
  `EngineFixtures.game_without_demands/2`.
  Outcomes: `:delivered`, `:refused`, `:missed` (stock short); refused and missed count as
  misses.
- **Projects:** a demand for knowledge or entertainment has `progress: 0` (others `nil`,
  `Rules.Demands.project?/1`). From the next week's step 1 the product goes into the project
  until `progress` reaches `amount`, the rest to the stock; mana is unchanged, the project
  doesn't spoil and the stock is never used for it. At the deadline (step 10, after that
  week's production) it is `:delivered` if `progress >= amount`, otherwise `:missed`; no
  decision gate. `refuse_project/1` (between weeks, while open) sets `deliver_demand: false`:
  the next week's production goes to the stock and its step 10 settles it as `:refused`.

## Units

- Stocks and production: thousandths (`Fixed`), so `27_000` food is 27 wheat.
- Shares and factors: per mille (`800` = 80%).
- Config values stay in whole units; convert with `Fixed.from/1` at the point of use.

## Report

`%WeeklyReport{week, production, mana, manameter, food_left, newborn, trained, builders,
travelling, gold, tax_due, tax, demand, demand_outcome, demand_progress, spoiled,
gold_spent_buildings,
game_over, start}` (`start`: see `engine-architecture`). `builders` counts arrived builders
on sites and `travelling` the workers with travel above 0, both at the end of the week;
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
   `builders_per_building` and `travel_weeks` to 0; tests about R2 builders or travel pass
   their own values) in `test/my_liege/engine/rules/`, a test of the step in
   `test/my_liege/engine/sim_steps/`, and the new step in the `Game.pipeline/0` test in
   `game_test.exs`. To run many weeks in a test, use
   `EngineFixtures.run_weeks/2` (pays every tax). Update this skill, and update
   `rules/rules.md` (the rule, its order and a changelog line) so the designer can sync it.
6. Run `mix precommit`.
