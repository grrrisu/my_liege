---
name: bots
description: 'How the bots (`MyLiege.Bot`) work: strategies as ordered lists of bot actions, the build condition, the named patterns, and how to add a bot action or a strategy. Use when: changing or adding a bot action or strategy, changing the bots or their analysis (summary CSV, leading colour, pivot weeks, spread), writing bot tests, or when a game rule change affects how the bots play.'
---

# Bots

[bot.ex](../../../lib/my_liege/bot.ex), [bot/](../../../lib/my_liege/bot/),
[tests](../../../test/my_liege/bot/)

## What the bots are

A client of the engine that plays whole games for Test A, with random births from a seed.
They decide like a player and change the game only through `Game` (`place_worker/3`,
`construct/2`, `decide_tax/2`, …); to decide they may read `Rules.*` and `Forecast`. No code
in `lib/my_liege/engine/` references `MyLiege.Bot`.

Hard rule 6: the bots are never used as a check, not to verify a change and not with the
CSV values. The tests in `test/my_liege/bot/` test the bots themselves with small fixture
configs (`EngineFixtures.config/1`).

## Bot decisions are not game rules, but they are the designer's

Every bot action encodes a player decision ("while food is low, newborns go to a farm"). A
new bot action, or a change to what one decides, needs the designer's rule first (hard
rule 1): ask, give options, don't pick one.

## Strategy

`%Bot.Strategy{actions, build}`. `actions` is an ordered list of `{module, opts}` or bare
modules (Plug-style); `Strategy.new(actions, build: …)` builds one (`build: :always` by
default). Before each week the runner (`Bot.run/4`) reduces over the actions, then calls
`Game.run_week/1`.

**Order is priority:** the actions compete for the same workers, and an earlier action gets
them first. Consecutive placing actions run as one pass, worker by worker (see
`Bot.Placing`), so a worker an earlier action sends to a full building waits for it instead
of falling through to a later action.

`build` says when an action that places workers may order a building. It is a setting, not
a step:
- `:always`: whenever the gold covers `build_cost_gold`.
- `:tax_safe`: `Placing.tax_safe_to_build?/1` ("Feed, save for tax").
- `:invest`: `Placing.invest_allowed?/3` ("Feed, invest and defend").

## The bot actions

`MyLiege.Bot.BotActions.*`, one module each:

| Bot action | Decides | Opts |
|---|---|---|
| `StaffSites` | arrived unplaced workers fill sites short of builders, in worker order | – |
| `Defend` | while bandits are on their way, workers move to watchtowers until the raid's gold is protected | – |
| `Feed` | while food is low (`food_low?/1`), workers go to a farm (placing) | – |
| `DemandProject` | while a king's demand project is open, only workers of its colour (violet for culture, blue for knowledge) go to it: first all unplaced, arrived ones; then, as many as needed for the expected output by the due week to cover what is missing, from finished buildings (not watchtowers, guildhouse or sites; not travelling), in worker order, only if they can work before the due week; starts and refuses nothing (placing, `{:place, id}`, `after_pass/2`) | – |
| `WriteBooks` | from `from_week` (`game.week >= from_week`), starts a book of each listed colour with none held and none in progress (`before_pass/2`); each book without a writer gets one: a left-over unplaced, arrived blue worker; else one from a monastery, blue first, then any colour (`after_pass/2`); else any left-over unplaced, arrived worker; one per book (placing, `{:place, id}`) | `colours: [colour]` (`[]` = no books), `from_week:` |
| `SaveGold` | while gold is below the next tax (`gold_low?/1`), workers go to a market (placing) | `born_before: week` |
| `Pivot` | workers born from `from_week` go to type `to` (placing) | `to:`, `from_week:` |
| `PlaceOwn` | workers go to their own colour's home type (placing) | – |
| `PayAndDeliver` | always pay the tax and deliver the king's demands | – |

No bot action uses the ways (R13–R16): the bots never order a granary, start the improved
plough or start a trade. `Bot.Placing` sends no worker to an invention or a trade.

The `Bot.BotAction` contract: `run(game, opts) :: game`. It receives its own opts merged
over the strategy's `build` and the run options (`pivot_week:`, `weeks:`). Named
`BotAction` to keep them apart from the engine's player actions, `Engine.Actions.*`.

## `Bot.Placing`

The shared helper for every action that places workers: the available workers (unplaced,
arrived), a building of the type with room or a site that gives one, ordering a building
when the sites under construction can't take all waiting workers and the build condition
allows it, and waiting otherwise. A placing action implements `target(worker, game, opts)`:
a building type, `{:place, place_id}` for one specific place (e.g. a demand project: placed
if `Rules.Placement.check_enter/3` allows it, else left unplaced; no building is ordered),
or `nil` to leave the worker to the next action. Its `run/2` calls
`Placing.run/2` with itself as the only rule. New placing actions use it. Optional hooks,
run once per pass in rule order, so an action stays in the shared pass:
- `before_pass(game, opts)`: before the pass, without placing workers (`WriteBooks` starts
  books);
- `after_pass(game, opts)`: after it, for decisions that move placed workers
  (`DemandProject`, `WriteBooks` from a monastery).

Each rule's opts get `earlier:`, the rules before it in the pass; `Placing.left_over?/3`
says whether they leave a worker alone (`WriteBooks` counts only those).

## The named strategies

`Bot.Strategies.named/2` maps the atoms (`pivot_week` is the run option, default 48):

| Pattern | Actions, in order | `build` |
|---|---|---|
| `:stay` | StaffSites, DemandProject, no_books, PlaceOwn, PayAndDeliver | `:always` |
| `:pivot` | StaffSites, DemandProject, no_books, {Pivot, to: :watchtower, from_week: pivot_week}, PlaceOwn, PayAndDeliver | `:always` |
| `:feed` | StaffSites, Feed, DemandProject, no_books, SaveGold, PlaceOwn, PayAndDeliver | `:always` |
| `:feed_pivot` | StaffSites, Feed, DemandProject, no_books, {SaveGold, born_before: pivot_week}, {Pivot, to: :watchtower, from_week: pivot_week}, PlaceOwn, PayAndDeliver | `:always` |
| `:feed_save_tax` | as `:feed` | `:tax_safe` |
| `:feed_defend` | Defend, StaffSites, Feed, DemandProject, no_books, SaveGold, PlaceOwn, PayAndDeliver | `:always` |
| `:feed_invest_defend` | as `:feed_defend` | `:invest` |
| `:feed_books` | StaffSites, Feed, DemandProject, {WriteBooks, colours: [:red, :green], from_week: 25}, SaveGold, PlaceOwn, PayAndDeliver | `:always` |

`no_books` is `{WriteBooks, colours: [], from_week: 25}`: it writes nothing, so those
strategies play as before. `DemandProject` comes right after survival (`Feed`, `Defend`);
in `:stay` and `:pivot`, which have no `Feed`, right after `StaffSites`. `WriteBooks` comes
right after `DemandProject`, before `SaveGold`, `Pivot` and `PlaceOwn`.

## Adding a bot action

One module in `lib/my_liege/bot/bot_actions/` with `@behaviour MyLiege.Bot.BotAction` (and
`@behaviour MyLiege.Bot.Placing` if it places workers), the designer's rule in its
moduledoc, a unit test in `test/my_liege/bot/`, and a line in this skill's table. Existing
strategies only change if the designer says so.

## Adding a strategy

A named one: a clause in `Bot.Strategies.named/2` with the designer's order and build
condition, its name in `Strategies.names/0`, and a row in the table above. Or ad hoc in iex
as a list (`iex -S mix`):

```elixir
alias MyLiege.Bot
alias MyLiege.Bot.BotActions.{Defend, Feed, PayAndDeliver, PlaceOwn, StaffSites}
config = MyLiege.Engine.Config.from_csv()

{reports, _game} = Bot.run(:feed, config, 1, weeks: 48)
Bot.run([Defend, StaffSites, Feed, PlaceOwn, PayAndDeliver], config, 1)
Bot.run(Bot.Strategy.new([StaffSites, Feed, PlaceOwn, PayAndDeliver], build: :tax_safe), config, 1)

runs = for seed <- 1..20, do: elem(Bot.run(:pivot, config, seed), 0)
Bot.leading(hd(runs), config)   # leading colour and share at the end of each year
Bot.pivot_weeks(hd(runs))       # weeks red needs to gain 20 points, or nil
Bot.spread(runs, 144)           # lowest and highest share per colour across runs
File.write!("pivot_1.csv", MyLiege.Reporting.to_csv(hd(runs)))
File.write!("summary.csv", Bot.summary_csv([:feed, :feed_save_tax], config, 1..20, weeks: 48))
```

`Bot.Analysis` holds `summary_csv/4`, `leading/2`, `pivot_weeks/2` and `spread/2`; `Bot`
delegates to them. `summary_csv/4` takes named strategies only; besides the tax, building,
food and robbery columns it has `book_week_<colour>` (pentagon order): the week the first
book of that colour was finished, empty if never and in the totals.

## Projects and books

The bots place workers of the project's colour on the king's demand projects
(`DemandProject`): unplaced, arrived ones first, then as many as needed from buildings.
Workers released when a project ends are unplaced and travelling; once arrived, later
actions place them as usual. Books are written only by `WriteBooks` with listed colours
(`:feed_books`: red and green from week 25); a finished book's writer is released the same
way.
