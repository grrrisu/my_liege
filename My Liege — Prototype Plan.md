# My Liege — Prototype Plan

Oct 28, 2026 · @Alessandro

## Purpose

Find out whether the core of *My Liege* is worth building: placing coloured workers, with the Manameter shaping who is born and the king testing the player outside their path. If placing workers is interesting here, the game has a heart; if not, no other system will fix that. This plan belongs to item T55 in the to-do list.

Each question is phrased as a hypothesis that a test can confirm or reject.

| ID | Hypothesis | Test |
| --- | --- | --- |
| H1 | No colour runs away: a player who tries can shift the Manameter within a reasonable time, and a typical society ends up as a mix of colours (pillar 1). | A (app, auto-run) |
| H2 | Placing workers creates real dilemmas: players sometimes place a worker off-colour on purpose. | B (app, play mode) |
| H3 | Decisions come often enough: there are no long stretches without anything to decide. | B (app, play mode) |
| H4 | Real time adds something, even though pausing is free. | C (app, clock mode, later) |

## Scope

**In:** coloured workers (born by chance from the Manameter, untrained and trained), the five path buildings (farm, monastery, watchtower, market, tavern), production by colour, mana by worker and building, the Manameter, and the king's demands.

**Out:** the map and neighbouring locations, trade and raids, combat, culture's influence and immigration, inventions beyond a single test invention, gifts and favours, world events, the second batch of buildings, scoring, and anything visual. These are left out on purpose, so the results speak about the core alone.

## Starting values

The prototype can't run on illustrative values. Values already in the concept are used as they are; the rest need a written first guess before testing. First guesses are allowed to be wrong; they only have to be written down.

**Known from the concept:**

| Value | Setting |
| --- | --- |
| Production by colour, untrained | Same 100%, neighbour 80%, opposite 50% |
| Production by colour, trained | Same 125%, neighbour 60%, opposite 30% |
| Mana per worker | Untrained: 2 in the building's colour, 1 in their own. Trained: the other way round |
| Training | Needs a guild and at least 30% of the worker's colour |
| Birth colour | Chance equals the colour's share in the Manameter |
| Starting Manameter | 80% green, 10% red, 5% blue, 5% yellow, 0% violet |
| Test invention | Improved plough: needs 50% green, +10% farm production |
| Game length | 144 weeks of 30 seconds |

**First guess needed:**

| Value | Linked item |
| --- | --- |
| How many Manameter points are exchanged per week (the concept's example uses 10 per update) | T39 |
| Which mana is removed at each update (simplest option: in proportion to current shares) | T38 |
| How often a worker is born | T15 |
| Starting workers: how many, which colours, which buildings | T17 |
| Base production per worker per week, and food eaten per worker | T16 |
| Training cost and duration | T43 |
| The king's demands: list, timing, deadlines | T13, T42 |

## The app

One small browser app serves all three tests. It does the bookkeeping, so the player only decides where workers go, and it records the data the report needs.

**Technology.** Elixir with Phoenix LiveView, the stack planned for the game. The rules engine is a plain Elixir module of pure functions, tested with ExUnit. Random births use a seed, so any run can be repeated exactly. Clock mode later runs as a process that advances one week every 30 seconds.

- **Rules engine, kept separate.** Births, production by colour, mana by worker and building, the Manameter update and the training check live in their own module of plain functions, with no interface code inside. This is the part worth reusing in later prototypes and possibly the game, so it deserves its own automated tests.
- **Settings panel.** All starting values are editable without touching code.
- **Play mode** (Test B): one week per click; the player places and moves workers; every decision is logged, with buttons for easy, some thought or torn.
- **Auto-run mode** (Test A): plays fixed placement patterns automatically, many runs at once.
- **Clock mode** (Test C, later): a week every 30 seconds, and a pause button.
- **Export.** The decision log and run results can be saved as a file for the report.
- **Keep it bare.** Coloured squares, buttons and numbers; only the rules listed under Scope. The interface is disposable; the rules engine is not.

## Test A: auto-run (H1)

No player needed. The app plays fixed placement patterns and shows how the Manameter moves.

**Patterns:**

- **Stay:** every worker goes to a building of their own colour.
- **Pivot:** from week 48, every new worker goes to a watchtower, whatever their colour.
- **Specialists:** as Stay, but workers are trained as soon as allowed.

**Run it:** each pattern once with expected births (for example, 0.8 of a newborn counts as green), then about 20 times with random births.

**Record:** the leading colour's share at weeks 48, 96 and 144 per pattern; in Pivot, how many weeks red needs to gain 20 points; the spread between random runs.

**Success criterion, set before testing:** H1 holds if, in Pivot, red gains 20 points within \_\_\_ weeks. H1 fails if green stays above \_\_\_% even when the player pivots.

## Test B: play mode (H2, H3)

A person plays; an observer watches. One click is one week, so this test ignores real time on purpose (that is Test C).

**Run it:** play the first year, 48 weeks. The player thinks aloud. After each placement the observer asks: why there?

**Recorded by the app:** per decision, the week, the worker's colour and training, the building, on- or off-colour, and how hard it felt; per session, weeks without any decision, the longest such stretch, and the king's demands met or missed.

**Recorded by the observer:** the reasons the player gives, and their impressions afterwards.

**Success criteria, set before testing:** H2 holds if at least \_\_\_% of placements are off-colour with a reason, and at least some decisions were rated "torn". H3 holds if no stretch without a decision lasts longer than \_\_\_ weeks.

## Test C: clock mode (H4, later)

Only worth running once Tests A and B pass.

**Run it:** with players who don't know the design. Don't explain the pause button beyond what it does.

**Record:** how many decisions were made while paused, how long pauses lasted, and whether players describe the game as tense or as turn-based.

**Success criterion, set before testing:** H4 holds if fewer than \_\_\_% of decisions are made while paused, or if players still report time pressure.

## Notes for implementation

The app is coded with GitHub Copilot, using this plan as the brief and `.github/copilot-instructions.md` for standing rules.

**Rules the engine must implement.** Open rules must be decided by the designer before they are coded; they are never filled in by the coding tool.

| ID | Rule | Status |
| --- | --- | --- |
| R1 | A newborn's colour is drawn with chances equal to the Manameter shares | Defined. Birth frequency open |
| R2 | Production = base production × colour factor (same 100%, neighbour 80%, opposite 50%; trained 125%, 60%, 30%) | Factors defined. Base production per building open |
| R3 | Mana per worker per week: untrained 2 in the building's colour and 1 in their own; trained 1 and 2. Same colour gives 3 of that colour | Defined |
| R4 | Manameter update: how produced mana turns into new shares, and which mana is removed | Open (T38, T39) |
| R5 | Training needs a guild and at least 30% of the worker's colour; colour never changes | Defined. Cost and duration open. The guildhouse's blue-trainer rule is a later idea, not part of the prototype |
| R6 | Improved plough: needs at least 50% green, +10% farm production, kept if green later drops | Defined. How it is researched in the prototype open |
| R7 | The king's demands: list, timing, deadlines, consequence of missing one | Open |
| R8 | Food eaten per worker, and what happens when food runs out | Open |

**How to build it:**

1. Every number lives in one configuration module; nothing is hard-coded. The settings panel edits that configuration.
2. Engine first: one ExUnit test per rule, checked by the designer against the concept before any interface is built.
3. Random births use a seed, stored with every run.
4. The decision log and run results export as CSV, matching the report fields.

## Who plays

| Test | Player | Why |
| --- | --- | --- |
| A | Nobody | Pure arithmetic |
| B | You first, then one to three others | You know the rules and your hopes, so you will find dilemmas a fresh player may not. Others show what really happens; a fellow designer or friends who play strategy games are enough |
| C | People who don't know the design | The question is how players naturally use the pause button |

No real users are needed until Test C.

## Report

One report per session, compared against the criteria set before testing.

| Field | Test |
| --- | --- |
| Date, test, player | All |
| Starting values used (and changes since the last run) | All |
| Leading colour at weeks 48, 96, 144; weeks for a 20-point pivot | A |
| Placements: total, off-colour, off-colour with a reason | B |
| Decisions rated easy / some thought / torn | B |
| Longest stretch without a decision | B |
| King's demands met / missed | B |
| Decisions made while paused; average pause length | C |
| Player's impressions, in their own words | B, C |
| Result per hypothesis: holds / fails / unclear | All |
| What changes in the concept as a result | All |
