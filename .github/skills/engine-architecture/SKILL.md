---
name: engine-architecture
description: 'How the My Liege engine is structured: layers (Game → SimSteps → Rules), where code goes, the SimStep contract, rules on plain data, config, and the regression test. Use when: adding, moving or renaming engine modules; deciding where new code goes; refactoring; calling engine code from GameLive or AutoRun; reviewing a change for structure.'
---

# Engine architecture

The engine is pure Elixir: no LiveView, processes or database. The week itself (order, what
each step reads and writes) is in the `weekly-step` skill.

## Layers and dependencies

```
lib/my_liege/engine/
  game.ex            machinery: state, run_week/1, pipeline/0, action entry points
  weekly_report.ex   machinery: the report of one week
  sim_step.ex        machinery: the step behaviour
  config.ex          infrastructure: every game value, fixed per game
  load_config.ex     infrastructure: reads priv/balance_inputs.csv at compile time
  fixed.ex           infrastructure: thousandths
  random.ex          infrastructure: seeded random state
  building.ex        data
  worker.ex          data
  manameter.ex       data
  pentagon.ex        data
  rules/             what happens: MyLiege.Engine.Rules.*
  sim_steps/         when it happens: MyLiege.Engine.SimSteps.*
  actions/           player actions between weeks: MyLiege.Engine.Actions.*
```

Dependencies: `Game → SimSteps → Rules` and `Game → Actions → Rules`. Actions never call
`SimSteps`, and rules never reference `Actions`. Rules depend only on data and infrastructure
modules. `GameLive` and `AutoRun` call `Game` and `Rules` (e.g. `Rules.Taxes`, `Rules.Training`
for display or decisions), never `SimSteps` or `Actions.*`.

## Actions (between weeks)

[actions/](../../../lib/my_liege/engine/actions/)

- Each player action has a module in `Actions.*` with public `run/…`: the game is the first
  argument, followed by the same arguments as the corresponding `Game` function.
- An action returns `{:ok, game}` or `{:error, reason}`. It validates and changes state using
  `Rules.*` and `Game`'s state functions; it never calls `SimSteps`.
- Actions are pure: they return a changed game and touch nothing else. Their changes take
  effect in the next week; `Construct` pays its price from the gold stock at once.
- `Game` is the only entry point. Callers never use `Actions.*` directly.
- Each action has its own unit test file, `test/my_liege/engine/actions/<action>_test.exs`,
  calling `run/…` directly with its conditions and errors. Tests through `Game`
  (`game_actions_test.exs`, rule tests) are integration tests and don't replace them.

## Rules (what)

[rules/](../../../lib/my_liege/engine/rules/)

- One module per rule of `rules/rules.md` (a rule may have more than one, e.g. R7 has
  `Grace`, `Taxes`, `Demands` and `Misses`).
- The moduledoc starts with its rule number ("R7, taxes: …") and names no step and no
  position in the week: a rule doesn't know when it is called.
- Pure functions on plain data (workers, buildings, stocks, numbers) and an explicit
  `%Config{}`. Rule modules never reference `Game`, `WeeklyReport`, `SimStep` or `SimSteps`.
  Example: `Rules.Misses.add/2` takes and returns a count; the step writes `misses` and
  `game_over` back to the game.
- Function names say what the rule does (`advance_sites`, `count_down`, `output`), not when
  it runs (no `week/…`).

## Steps (when)

[sim_step.ex](../../../lib/my_liege/engine/sim_step.ex),
[sim_steps/](../../../lib/my_liege/engine/sim_steps/)

- Contract: `@behaviour MyLiege.Engine.SimStep`, `run(game, report) :: {game, report}`.
- A step is a thin adapter: it picks the inputs, calls a rule and writes the results to the
  game and the report. The rule itself stays in `rules/`.
- The moduledoc names its place in the week and its rule ("Step 9 of the week, R7 tax
  payment: …").
- A step decides itself whether it applies this week, and otherwise returns `{game, report}`
  unchanged. Steps can't fail.
- `game` is the state **now**, after the earlier steps; `game.week` is already the week being
  run. `report.start` is the game **as it was when the week began**: use it for anything
  "at the start of the week" (placed workers, builders, tax count, demand population).
- `SimSteps.EndOfWeek` runs last: it fills the report with the end-of-week state
  (`manameter`, `food_left`, `gold`, `builders`, `travelling`, `game_over`) and sets
  `start: nil`. It contains no game rules; anything that changes the village is its own step
  before it.

## `Game` and `WeeklyReport`

[game.ex](../../../lib/my_liege/engine/game.ex),
[weekly_report.ex](../../../lib/my_liege/engine/weekly_report.ex)

- `run_week/1` = validation, then `WeeklyReport.new(game.week + 1, game)`, `game.week + 1` and
  a reduce over `Game.pipeline/0`. No rule logic in `Game`.
- `Game.new/2` builds the week-0 report by passing `WeeklyReport.new(0, game)` through
  `EndOfWeek`.
- `game.report` is the last report only; the history of weeks is kept by the callers
  (`GameLive`, `AutoRun`, `EngineFixtures.run_weeks/2`).
- `report.start` is `nil` in every report that leaves `run_week/1` and is never exported
  (`Reporting` doesn't read it).

## Config

[config.ex](../../../lib/my_liege/engine/config.ex)

- Fixed for a game at `Game.new/2` and stored in `game.config`; it never changes during a game.
- Rules take it as an explicit `%Config{}` argument; steps pass `game.config`.
- No game value outside the config (hard rule 2). Tests build their own with
  `EngineFixtures.config/1`.

## Refactors and the regression test

[regression_test.exs](../../../test/my_liege/engine/regression_test.exs),
[regression_seed_42.csv](../../../test/fixtures/regression_seed_42.csv)

- One year with a fixed test config and seed 42 must export exactly the fixture. It uses
  `EngineFixtures.config/1`, never `Config.from_csv/0`, and no AutoRun.
- A refactor never changes the fixture: if the test fails, the refactor is wrong.
- Re-record it only in a commit that deliberately changes a rule, and give the reason in the
  commit message.

## Not there on purpose

No `events` field in the report, no trace, no `halt` in the pipeline, no `init`/`opts` in
`SimStep`, no `put_config`. No behaviour (`@behaviour`) for actions, as their arguments
differ; add one only when replay, a decision log or a `GameServer` needs it. No common
game-over or finished check for actions yet. Don't add any of these unasked; ask the designer.
