---
name: weekly-step
description: 'How one week of My Liege runs in the rules engine (Game.run_week): order of steps, week numbering, units, and what each step reads and writes. Use when: changing or debugging the weekly loop, adding a step (e.g. taxes R7, training R5, plough R6), reading reports or CSV exports, writing Game or AutoRun tests, or answering "when does X happen in a week".'
---

# Weekly step

One call to `Game.run_week(game, config)` runs one week and returns `{:ok, report, game}`.
It is blocked, without changing anything, with:
- `{:error, :game_over}` once `game.game_over` is set;
- `{:error, :tax_undecided}` when the next week is a due week (`Game.tax_decision_due?/2`)
  and the player hasn't decided with `Game.decide_tax/3` yet.

Code: [game.ex](../../../lib/my_liege/engine/game.ex).

## Week numbering

- `game.week` is the **last week run**, i.e. the state at the end of that week.
- Week 0 is the starting state from the config (`Game.new/2`); nothing has happened yet.
- `run_week` runs `game.week + 1`. Every rule in it sees that same week number.
- A full game is weeks 1 to 48 × `years_per_game`.
- Between two weeks the player (or an `AutoRun` pattern) acts on the state of week N:
  `place_worker/4`, `unplace_worker/2`, `construct/3`, `decide_tax/3`. Changes take effect in
  week N + 1.

## Order inside a week

| # | Step | Module | Reads | Writes |
|---|------|--------|-------|--------|
| 0 | Tax count (R7), count weeks only | `Taxes.assess/2` | **all** workers before this week's birth | `game.tax_due`, `report.tax_due` |
| 1 | Production (R2) | `Production.week/4` | placed workers in buildings ready this week | `report.production`, added to `stocks` |
| 2 | Mana (R3) | `Mana.week/4` | same workers | `report.mana` |
| 3 | Manameter update (R4) | `ManameterUpdate.update/3` | old Manameter, this week's mana | `manameter` |
| 4 | Eating (R8) | `Food.eat/3` | food stock after production, **all** workers (placed or not) | `food_left` |
| 5 | Birth (R1) | `Births.attempt/5` | week, `food_left`, the **updated** Manameter, `rand` | `newborn`, `rand` |
| 6 | Training ends (R5) | `Training.finish/4` | trainees in the guildhouse, week | `trained`, `building: nil`, `report.trained` |
| 7 | Tax payment (R7), due weeks only | `Taxes.settle/3` | gold after production, `tax_due`, `pay_tax` | `stocks.gold`, `tax_misses`, `game_over`, `report.tax` |

Consequences of the order:
- A newborn is drawn from the Manameter updated in step 3 of the same week.
- A newborn is added after eating, so it eats from the following week; it is unplaced.
- Production and mana use the workers as placed before the week started.

## Rules each step relies on

- **Readiness:** a building ordered at state N has `ready_week = N + construction_weeks`
  and produces from that week. Placement needs `ready?(building, game.week + 1)` and room.
- **Training:** the guildhouse is neutral (no colour, product or mana; `Building.staffed/3`
  leaves it out). Placing an untrained worker there needs its colour's share ≥
  `training_threshold`, checked once; `training_started = game.week + 1`. At the end of week
  `training_started + training_weeks - 1` the worker is trained and unplaced. Moving it out
  earlier loses the progress. Trainees still eat and count for taxes; no other cost.
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
  payments. More than `tax_misses_forgiven` misses (skipped or missed) set `game_over`, which
  blocks further weeks. `AutoRun` always tries to pay and its runs end at game over.

## Units

- Stocks and production: thousandths (`Fixed`), so `27_000` food is 27 wheat.
- Shares and factors: per mille (`800` = 80%).
- Config values stay in whole units; convert with `Fixed.from/1` at the point of use.

## Report

`%{week, production, mana, manameter, food_left, newborn, trained, gold, tax_due, tax,
game_over}`;
`Game.report/1` returns the last one (week 0 for a new game). `MyLiege.Reporting.to_csv/1`
writes one row per report.

## Adding or changing a step

1. Check the Prototype Plan and `.github/copilot-instructions.md`: the rule must be defined,
   every value must come from a CSV key, and open points must be asked, not guessed.
2. Decide where the step sits in the order above and what it reads and writes; ask the
   designer if the plan doesn't say.
3. Keep the rule in its own engine module of pure functions; call it from `run_week/2`.
4. Add what the step produces to the report, then to `Reporting` if it belongs in the export.
5. Tests: one describe block per rule with `EngineFixtures.config/1`, plus a case in
   `game_test.exs` that checks its place in the order. To run many weeks in a test, use
   `EngineFixtures.run_weeks/3` (pays every tax). Update this skill.
6. Run `mix precommit`.
