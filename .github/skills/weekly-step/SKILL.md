---
name: weekly-step
description: 'How one week of My Liege runs in the rules engine (Game.run_week): order of steps, week numbering, units, and what each step reads and writes. Use when: changing or debugging the weekly loop, adding a step (e.g. taxes R7, training R5, plough R6), reading reports or CSV exports, writing Game or AutoRun tests, or answering "when does X happen in a week".'
---

# Weekly step

One call to `Game.run_week(game, config)` runs one week and returns `{:ok, report, game}`.
It is blocked, without changing anything, with:
- `{:error, :game_over}` once `game.game_over` is set;
- `{:error, :finished}` after the last week, `Game.last_week/1` (48 × `years_per_game`;
  48 weeks per year is fixed in `Game.weeks_per_year/0`, not in the CSV). Reaching it without
  game over is a win: `Game.won?/2`;
- `{:error, :tax_undecided}` when the next week is a due week (`Game.tax_decision_due?/2`)
  and the player hasn't decided with `Game.decide_tax/3` yet;
- `{:error, :demand_undecided}` when the next week is a demand's deadline
  (`Game.demand_decision_due?/1`) and the player hasn't decided with `Game.decide_demand/2`.

Code: [game.ex](../../../lib/my_liege/engine/game.ex).

## Week numbering

- `game.week` is the **last week run**, i.e. the state at the end of that week.
- Week 0 is the starting state from the config (`Game.new/2`); nothing has happened yet.
- `run_week` runs `game.week + 1`. Every rule in it sees that same week number.
- A full game is weeks 1 to 48 × `years_per_game`.
- Between two weeks the player (or an `AutoRun` pattern) acts on the state of week N:
  `place_worker/4`, `unplace_worker/3`, `construct/3`, `decide_tax/3`, `decide_demand/2`.
  Changes take effect in week N + 1. `construct/3` pays `build_cost_gold` from the gold stock
  at once and adds it to `gold_spent_buildings` of week N's report (`{:error, :not_enough_gold}`
  if the stock is short).

## Order inside a week

| # | Step | Module | Reads | Writes |
|---|------|--------|-------|--------|
| 0 | Tax count (R7), count weeks only | `Taxes.assess/2` | **all** workers before this week's birth | `game.tax_due`, `report.tax_due` |
| 1 | Production (R2) | `Production.week/4` | placed workers with travel 0 in buildings ready this week | `report.production`, added to `stocks` |
| 2 | Mana (R3) | `Mana.week/4` | same workers | `report.mana` |
| 3 | Travel (R2) | `Travel.week/1` | every worker's `travel` | `travel` − 1, not below 0 |
| 4 | Manameter update (R4) | `ManameterUpdate.update/3` | old Manameter, this week's mana | `manameter` |
| 5 | Eating (R8) | `Food.eat/3` | food stock after production, **all** workers (placed or not) | `food_left` |
| 6 | Birth (R1) | `Births.attempt/5` | week, `food_left`, the **updated** Manameter, `rand` | `newborn`, `rand` |
| 7 | Construction (R2) | `Construction.week/5` | sites, builders as at the **start** of the week (before step 3) | `progress`, `ready_week`, finished builders `building: nil` with `travel_weeks` |
| 8 | Training ends (R5) | `Training.finish/4` | trainees in the guildhouse, week | `trained`, `building: nil`, `travel_weeks`, `report.trained` |
| 9 | Tax payment (R7), due weeks only | `Taxes.settle/3` | gold after production, `tax_due`, `pay_tax` | `stocks.gold`, `misses`, `game_over`, `report.tax` |
| 10 | Demand delivery (R7), deadline weeks only | `Demands.settle/3` | stocks, `demand`, `deliver_demand` | stocks, `misses`, `game_over`, `report.demand_outcome` |
| 11 | Demand made (R7), demand weeks only | `Demands.make/5` | week, Manameter, workers at the start of the week | `game.demand`, `report.demand` |
| 12 | Spoilage | `Spoilage.spoil/2` | every stock above 0, `spoilage_rates` (per mille, key `spoilage_rate_<product>`) | `stocks`, `report.spoiled`; `report.food_left` and `report.gold` are after it |

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
- **Travel:** `Travel.depart/3` sets `travel = travel_weeks` on every place, move, unplace and
  release. Unplaced workers with travel above 0 can't be placed (`{:error, :travelling}`).
  `Building.staffed/3` leaves travelling workers out.
- **Training:** the guildhouse is neutral (no colour, product or mana; `Building.staffed/3`
  leaves it out). Placing an untrained worker in a finished guildhouse needs its colour's share ≥
  `training_threshold`, checked once; `training_started = game.week + 1 + travel_weeks`
  (`Training.first_week/2`). At the end of week `training_started + training_weeks - 1` the
  worker is trained, unplaced and travelling. Moving it out earlier loses the progress.
  Trainees still eat and count for taxes; no other cost.
- **Births:** attempted in weeks 1, 1 + interval, … (`rem(week - 1, birth_interval_weeks) == 0`),
  only if `food_left >= Fixed.from(birth_min_food_left)`. `Births.attempt/5` is the
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
  The player must decide with `decide_tax/3` while the game stands at the week before a due
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

## Units

- Stocks and production: thousandths (`Fixed`), so `27_000` food is 27 wheat.
- Shares and factors: per mille (`800` = 80%).
- Config values stay in whole units; convert with `Fixed.from/1` at the point of use.

## Report

`%{week, production, mana, manameter, food_left, newborn, trained, builders, travelling, gold,
tax_due, tax, demand, demand_outcome, spoiled, gold_spent_buildings, game_over}`; `builders`
counts arrived builders on sites and `travelling` the workers with travel above 0, both at
the end of the week;
`Game.report/1` returns the last one (week 0 for a new game). `MyLiege.Reporting.to_csv/1`
writes one row per report.

## Adding or changing a step

1. Check `rules/rules.md` and `.github/copilot-instructions.md`: the rule must be defined,
   every value must come from a CSV key, and open points must be asked, not guessed.
2. Decide where the step sits in the order above and what it reads and writes; ask the
   designer if `rules/rules.md` doesn't say.
3. Keep the rule in its own engine module of pure functions; call it from `run_week/2`.
4. Add what the step produces to the report, then to `Reporting` if it belongs in the export.
5. Tests: one describe block per rule with `EngineFixtures.config/1` (it sets
   `builders_per_building` and `travel_weeks` to 0; tests about R2 builders or travel pass
   their own values), plus a case in
   `game_test.exs` that checks its place in the order. To run many weeks in a test, use
   `EngineFixtures.run_weeks/3` (pays every tax). Update this skill, and update
   `rules/rules.md` (the rule, its order and a changelog line) so the designer can sync it.
6. Run `mix precommit`.
