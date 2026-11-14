---
name: engine-architecture
description: 'How the My Liege engine is structured: layers (Game → SimSteps → Rules), places (blueprint, building), where a function goes (model, rule, orchestration), the SimStep contract, rules on plain data, config, and the regression test. Use when: adding, moving or renaming engine modules; deciding where new code goes; refactoring; calling engine code from GameLive or the bots; reviewing a change for structure.'
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
  place.ex           model: what all kinds of place share (colour, good, type, next_id, workers_at)
  place/
    blueprint.ex     model: the catalogue, one blueprint per type of place
    building.ex      model: a building that stands in the game, always finished
    project.ex       model: a project, collects progress to a target, then gives something once
    trade.ex         model: a trade route, traders placed on it in queue order (R16)
    expedition.ex    model: the hunting camp, its bag and hunting-week count (R17)
  worker.ex          data
  manameter.ex       data
  pentagon.ex        data
  rules/             what happens: MyLiege.Engine.Rules.*
    placement.ex     R2: who may enter a place, its capacity, releasing its workers
    books.ex         R12: books, their experience factor, finishing
    ways.ex          R13: when a way is unlocked (one rule for every way)
    granary.ex       R14: working granaries, culture upkeep, food spoilage
    inventions.ex    R15: starting, writing and finishing inventions; their effects (the ploughs' bonus)
    trades.ex        R16: a trade route's opening, queue, price, food and weekly settlement
    hunting.ex       R17: the camp's week: filling the bag, the haul and its luck draw; a camp left empty
    suspicion.ex     R18: the king's suspicion: a haul's change, idle-block decay, the threshold
    staffing.ex      R2: which workers work in a week
    …
  sim_steps/         when it happens: MyLiege.Engine.SimSteps.*
  actions/           player actions between weeks: MyLiege.Engine.Actions.*
```

Outside the engine, in `lib/my_liege/`: `bot.ex` and `bot/` (the bots, `MyLiege.Bot.*`),
`reporting.ex` (CSV export); the UI is `MyLiegeWeb.GameLive`.

Dependencies: `Game → SimSteps → Rules` and `Game → Actions → Rules`. Actions never call
`SimSteps`, and rules never reference `Actions`. Rules depend only on data and infrastructure
modules. `GameLive` and the bots (`MyLiege.Bot`) call `Game` and `Rules` (e.g. `Rules.Taxes`, `Rules.Training`
for display or decisions), never `SimSteps` or `Actions.*`.

## Clients

`GameLive` and the bots (`MyLiege.Bot`, in `lib/my_liege/bot/`) are clients outside the
engine: they decide like a player and change the game only through `Game`. The three kinds
below (model, rule, orchestration) apply only inside the engine. The bots are described in
the `bots` skill.

## Where a function goes

Ask: "Could the designer change this in `rules/rules.md`?" If yes, it is a rule.

- **Model** (`Place`, `Place.Building`, `Place.Project`, `Place.Blueprint`, `Worker`, …):
  only reads stored data (`done?`, `colour`, `workers_at`). No `%Config{}`, no decision.
  Creating a site is a rule (`Rules.Construction.new_site/3`), as its target is a config value.
- **Rule** (`Rules.*`): decides (may this worker enter, how many fit, what is produced). Pure
  functions on plain data and an explicit `%Config{}`.
- **Orchestration** (`Actions.*`, `SimSteps.*`): fetch what is needed, ask the rules, apply
  the answer to the game. No decisions of its own.

## Places

[place.ex](../../../lib/my_liege/engine/place.ex),
[place/](../../../lib/my_liege/engine/place/)

- A **blueprint** (`Place.Blueprint`) describes a type of place: its colour, the good it
  makes and which kind of place it becomes (`engine`). The catalogue has the five home
  places in pentagon order, then the ways, then the guildhouse; its test checks the home
  order against `Pentagon.colours/0`. It depends on no other module, so `LoadConfig` reads
  the types from it at compile time (`building_types/0` for capacities, `home_types/0` for
  output per worker).
- A **way** (R13) is a catalogue entry whose colour is not its good's home colour
  (`Blueprint.way?/1`), decided by data alone: the granary (violet, food, `engine:
  :building`), the improved ploughs I and II (blue, food, `engine: :project`, inventions),
  the grain trade route and the hunting camp. One rule unlocks them all (`Rules.Ways`): the
  catalogue entry says how many books of each colour (`books`: 1 by default, or `:config`,
  read from `way.<type>.books` into `config.way_books`) and which invention it `requires`;
  `Blueprint` stays pure data and never reads the config. A way building is ordered like any building but
  produces nothing (`Production.produces?/1`); its effect is its own rule (`Rules.Granary`).
  An invention is never ordered (`Construct` takes only `building_types/0`); it is started
  with `Game.start_invention/2` and is a project with its catalogue blueprint. A trade
  route (`engine: :trade`, a `Place.Trade`) and the hunting camp (`engine: :expedition`, a
  `Place.Expedition`) are never ordered or started: they open in the Books step once the
  books unlock them (`Rules.Ways.open/4`).
- A **place** is one that exists in the game. There is one struct per kind of place:
  `Place.Building` (always finished), `Place.Project`, `Place.Trade` and
  `Place.Expedition`. Each holds
  its `id` and its `blueprint`; `Place.next_id/1` gives the next free id over all places.
- A **project** (`Place.Project`: `id`, `blueprint`, `target`, `gives`, `progress`) collects
  progress until `done?/1` (`progress >= target`), then gives `gives` once and leaves
  `game.places`. Its blueprint is not in the catalogue (which lists the types that can stand
  and be ordered and the inventions, with config keys): a project builds its own, except an
  invention, which uses its way's catalogue entry. Projects are told apart by
  `gives`, and rules match on it (`%Project{gives: {:building, _}}`):
  - a **construction site** gives `{:building, type}`: blueprint `type: :site`, no colour,
    no good; target `build_work`; up to `build_capacity` builders, who produce nothing. Once
    done it is replaced by a `%Building{}` with a new id (`Rules.Construction`).
  - a **king's demand project** gives `{:demand, due_week}`: blueprint `type: :demand`, the
    colour of the good's home place (`Blueprint.home_colour/1`) and the good; target the
    demand's amount; any number of workers, who produce and make mana as in a building of
    that colour and good (`Rules.Production.project_output/4`), into the project. Opened by
    `Rules.Demands.open_project/2`; removed when the demand is settled or refused.
  - a **book** (R12) gives `{:book, colour}`: `Project.book_blueprint/0` (`type: :book`,
    blue, knowledge — the method is blue, the book's own colour is in `gives`); target
    `book_work` knowledge; one writer, who produces and makes mana as in a blue building,
    his output scaled by the experience factor of the book's colour (its Manameter share ÷
    200, `Rules.Books.written/3`). Started by `Actions.StartBook`; once done, step 8
    (`Rules.Books.finish/4`) adds it to `game.books` (colour => count) and removes the
    project.
  - an **invention** (R15) gives `{:invention, type}`: blueprint `Blueprint.fetch!(type)`
    (plough I and II: blue, food); target `Inventions.target/2` knowledge; up to
    `Inventions.capacity/2` workers, who write as in a blue building times the experience
    of the good's home colour (`Rules.Inventions.written/3`) and make mana as at a blue
    place for food (2 blue, 1 green). Started by `Actions.StartInvention`; once done, step 8
    (`SimSteps.Inventions`, `Rules.Inventions.finish/4`) appends the type to
    `game.inventions` and removes the project. What an invention does is
    `Inventions.effect/2` (`{:farm_output, bonus}` for the ploughs); the production bonus,
    the UI's overview and the farm's label all read it, so a new invention is a catalogue
    entry, its config keys and one clause each of `target/2`, `capacity/2` and `effect/2`.
- A **trade route** (`Place.Trade`: `id`, `blueprint`, `traders`, R16) has its way's
  catalogue blueprint (the grain trade: yellow, food); one per type, opened in step 8 by
  `Rules.Ways.open/4` once `game.books` unlock it, and never removed. Workers are placed
  and leave as in a building (`Placement.check_enter/3`: `:travelling`, `:full` at
  `way_grain_trade_capacity`), but travel `way_grain_trade_travel_weeks` both ways
  (`Rules.Travel.weeks/3`, used by `Travel.depart/4` in `PlaceWorker` and `UnplaceWorker`).
  `traders` is the queue of worker ids in the order placed (`Trades.join/3` in
  `PlaceWorker`: a worker who comes back goes last); it may hold ids of workers who left,
  so read it through `Trades.traders/2`, and step 13 cuts it. A trader makes mana once
  arrived and produces nothing; step 13 (`SimSteps.TradeRoute`, `Rules.Trades.settle/4`)
  charges each arrived trader's price and adds the food.
- The **hunting camp** (`Place.Expedition`: `id`, `blueprint`, `bag`, `weeks`,
  `hunted_in_block`, R17) is one per game, opened by `Rules.Ways.open/4` and never removed.
  Workers are placed and leave as in a building (`check_enter/3`: `:travelling`, `:full` at
  `way_hunting_max_party`), travelling `way_hunting_travel_weeks` both ways
  (`Rules.Travel.weeks/3`). `PlaceWorker` and `UnplaceWorker` call
  `Rules.Hunting.abandon_empty/2` after a move: a camp no worker is on loses `bag` and
  `weeks`. Step 8 (`SimSteps.Hunts`, `Rules.Hunting.hunt/4`) fills `bag` from the arrived
  hunters and at `way_hunting_haul_weeks` counted weeks hauls: one luck draw from
  `game.rand`, the food into the stock. A rule that draws takes the random state and
  returns the next one (`{value, rand}`); the step writes it back to `game.rand`. The same
  step settles `game.suspicion` (R18, `Rules.Suspicion`): the haul's change, the idle-block
  decay (`hunted_in_block` is set by a hunting week and cleared at each block end) and the
  threshold, which adds a miss through `Rules.Misses.add/2`, as taxes and demands do.
- No place makes a worker "away": any worker may be moved or unplaced at any time.
- The **demand** (`game.demand`, `%{product, amount, due_week, project_id}`) is the king's
  obligation, not a place; `project_id` points to its project (`Demands.project/2`), `nil`
  for a demand from the stock.
- When a place ends, its workers leave with `Rules.Placement.release/3` (unplaced,
  travelling): a finished site, a settled or refused demand project, a finished book or
  invention, a returned hunt. A trade route never ends.
- `game.places` is one list of all places, whatever their kind. Workers point to their place
  by id (`worker.place`, `nil` when unplaced).
- `Place` holds what all kinds share and only reads `place.blueprint` (`colour/1`, `good/1`,
  `type/1`, `neutral?/1`), plus `workers_at/2`.
- Rules are organised **by rule, not by kind**: a rule module has one function clause per
  kind of place (`check_enter(%Place.Building{} = place, …)`), not one module per kind.

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
- Pure functions on plain data (workers, places, stocks, numbers) and an explicit
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
- The moduledoc names its place in the week and its rule ("Step 10 of the week, R7 tax
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
  (`GameLive`, `Bot.run/4`, `EngineFixtures.run_weeks/2`).
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
  `EngineFixtures.config/1`, never `Config.from_csv/0`, and no bot run.
- A refactor never changes the fixture: if the test fails, the refactor is wrong.
- Re-record it only in a commit that deliberately changes a rule, and give the reason in the
  commit message.

## Not there on purpose

No `events` field in the report, no trace, no `halt` in the pipeline, no `init`/`opts` in
`SimStep`, no `put_config`. No behaviour (`@behaviour`) for actions, as their arguments
differ; add one only when replay, a decision log or a `GameServer` needs it. No common
game-over or finished check for actions yet. Don't add any of these unasked; ask the designer.
