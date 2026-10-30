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

**In:** coloured workers (born by chance from the Manameter, untrained and trained), the five path buildings (farm, monastery, watchtower, market, tavern), production by colour, mana by worker and building, the Manameter, the king's demands, and taxes twice a year.

**Out:** the map and neighbouring locations, trade and raids, combat, culture's influence and immigration, inventions beyond a single test invention, gifts and favours, world events, the second batch of buildings, scoring, and anything visual. These are left out on purpose, so the results speak about the core alone.

## Starting values

The prototype can't run on illustrative values. Values already in the concept are used as they are; the rest need a written first guess before testing. First guesses are allowed to be wrong; they only have to be written down.

**Source of truth for numbers: the balance model** (`my_liege_balance_model.xlsx`). It holds every value on its Inputs sheet and calculates the derived figures. The tables below list which values exist and their status; when a value changes, change it on the balance model's Inputs sheet, then save its Export sheet as CSV over \`priv/balance\_inputs.csv\` in the repository. The app reads values from that file by key. All calculations use whole numbers; shares and factors are exported in per mille (800 = 80%).

**Known from the concept:**

| Value | Setting |
| --- | --- |
| Production by colour, untrained | Same 100%, neighbour 80%, opposite 50% |
| Production by colour, trained | Same 125%, neighbour 60%, opposite 30% |
| Mana per worker | Untrained: 2 in the building's colour, 1 in their own. Trained: the other way round |
| Training | Needs a guild and at least 30% of the worker's colour |
| Birth colour | Chance equals the colour's share in the Manameter |
| Starting Manameter | 20% per colour (decided after Test A) |
| Test invention | Improved plough: needs 50% green, +10% farm production |
| Game length | 144 weeks of 30 seconds |

**First guess needed:**

| Value | Linked item |
| --- | --- |
| How many Manameter points are exchanged per week (the concept's example uses 10 per update) | T39 |
| Which mana is removed at each update (simplest option: in proportion to current shares) | T38 |
| How often a worker is born. First guess: every 2 weeks (24 a year) | T15 |
| Starting workers: decided, the minimum of one green farmer on the farm and one red soldier in the tower (a better watchtower). Values in the balance model | T17 |
| Base production per worker per week, and food eaten per worker. First guess: a farm holds 4 workers, each producing 9 wheat a week at 100%; every worker eats 3 wheat a week. Other buildings still open | T16 |
| Training cost and duration | T43 |
| The king's demands: list, timing, deadlines. Taxes per head. First guess: 10 gold per worker per payment, every 24 weeks; the player starts with 100 gold; a market worker earns 3 gold a week. The village is counted four weeks before each payment and the amount is fixed then (first guess: counted in weeks 20 and 44, due in weeks 24 and 48). If the player can't pay: no partial payments; the first missed payment is forgiven, a second one ends the game (first, simple version) | T13, T42 |

**Balance checks.** The balance model calculates both checks. With the current values (12 wheat per farmer, decided after Test A): one farm worker feeds four people, so a quarter of the village farms; one market worker pays the taxes of about seven workers, so about 14% works at the market. Together that is roughly 40% of the village in green and yellow, more with off-colour workers. Taxes total 360 gold in year 1, 840 in year 2 and 1,320 in year 3, including the two starting workers. The first payment is 120 gold, 20 more than the starting gold, so a market worker is needed in the first half year; the last is 720 gold and needs about 10 market workers. The base price is now 4 wheat per gold.

**Decided after Test A (2026-10-30):** 12 wheat per farm worker, 30 Manameter points per week, and an equal starting Manameter of 20% per colour.

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
| R1 | A newborn's colour is drawn with chances equal to the Manameter shares. A birth every 2 weeks, only if food is left after eating. The game starts with one green farmer on the farm and one red soldier in the tower (counts as a watchtower) | Defined |
| R2 | Production = base production × colour factor (same 100%, neighbour 80%, opposite 50%; trained 125%, 60%, 30%). Market workers produce money directly, a simplification for the first test (in the concept, money comes from trading). Every building has its own capacity and base production; construction takes time but costs nothing else | Defined |
| R3 | Mana per worker per week: untrained 2 in the building's colour and 1 in their own; trained 1 and 2. Same colour gives 3 of that colour | Defined |
| R4 | Manameter update, each week: remove a fixed number of points in proportion to the current shares; add the same number of points in proportion to the mana produced that week | Defined |
| R5 | Training needs a guild and at least 30% of the worker's colour; colour never changes | Defined. Cost and duration open. The guildhouse's blue-trainer rule is a later idea, not part of the prototype |
| R6 | Improved plough: needs at least 50% green, +10% farm production, kept if green later drops. Costs wisdom: about 4 months of a full monastery | Defined |
| R7 | The king's demands: list, timing, deadlines, consequence of missing one. Taxes in money twice a year, per head, counted four weeks before each payment; paid in full or missed; the first miss is forgiven, the second ends the game | Taxes defined. Demands open |
| R8 | Food: every worker eats wheat each week. No birth unless enough food is left. Leftover food carries over, stored in the tower, with no capacity limit in the prototype. A newborn eats from the following week; births cost no extra food. When there isn't enough food for everyone: for the first test, no effect except that no births happen, and every such week is logged (the real rule is T65, Later) | Defined for the first test |

All values for these rules are in the balance model, not here.

**Weekly order.** Each week runs in this order: production, then eating, then birth, then taxes when due. A birth only happens if food is left over; a hungry society stops growing.

**How to build it:**

1. Every number lives in one configuration module; nothing is hard-coded. The settings panel edits that configuration.
2. Engine first: one ExUnit test per rule, checked by the designer against the concept before any interface is built.
3. Random births use a seed, stored with every run.
4. The decision log and run results export as CSV, matching the report fields.

## Results

### Test A, run 1 (2026-10-30)

Starting Manameter 80% green, 5% blue, 10% red, 5% yellow, 0% violet. 20 seeded runs per setting. The success criteria for H1 had not been set before testing.

**How Stay played:** no training yet. Every worker goes to a building of their own colour; if none has room, the worker waits unplaced and a new building is ordered. Placed workers are never moved, and food is never considered. Without training, a worker in their own colour's building produces only their own colour, so in Stay the mana mix equals the worker mix.

| Points per week (per mille) | Red +20 after the pivot (median) | Pivot runs without +20 | Stay: green at week 144 |
| --- | --- | --- | --- |
| 15 | \~88 weeks | 2 of 20 | 54–91% |
| 30 | \~65 weeks | 1 of 20 | 27–95% |
| 60 | \~50 weeks | 1 of 20 | 25–95% |

**At 30 per week:**

|  | Week 48 | Week 96 | Week 144 |
| --- | --- | --- | --- |
| Stay, green share | 39–89% | 28–95% | 27–95% |
| Pivot, red share | 8–40% | 21–48% | 38–60% |

**Findings:**

- Faster updates make a pivot faster, but also let early chance births swing the Stay runs much further. At 60, by week 48 red already ranges from 7% to 71% across seeds; at 15, Stay runs differ much less, but a pivot barely works within the game.
- At 30, a pivot reaches +20 red in about 65 weeks, roughly 1.4 of the 2 years left after the pivot in week 48.
- The spread in Stay comes from births, not from the Manameter itself: an early run of red births feeds red mana, which makes more red births. The update speed only decides how strongly that luck is amplified.

**Decision:** 30 per mille per week for now.

**Open:** H1 can't be judged formally without the criteria. Is a Stay society that ends anywhere between 27% and 95% green "a typical mix" (pillar 1), or too much luck? Early births are risk the player can't avoid, so by pillar 3 they must be fair.

**Next for Test A:**

- Report per run: population at week 144, weeks without enough food, and worker-weeks spent unplaced. If runs that lost green also stopped growing, part of the spread comes from food, not luck.
- Add a pattern **Feed**: as Stay, but a newborn goes to a farm whenever food runs short, whatever their colour. This is closer to real play and shows whether the spread survives the food floor.
- The Specialists pattern waits for training to be built.

### Test A, run 2: Feed (2026-10-30)

**Feed:** as Stay, but a newborn goes to a farm, whatever their colour, when last week's food surplus can't feed one more worker, or the stock is below 0. It only looks back one week. 20 seeds, run with 60 points per week (the CSV value in the repository at the time, not the 30 decided after run 1).

|  | Stay | Feed |
| --- | --- | --- |
| Runs with short weeks | 1 of 20 (seed 18: 124 short weeks) | 0 of 20 |
| Workers at week 144 | 12–74 | 74 in every run |
| Green at week 144 | 25–95% | 39–95% |
| Red at week 144 | 3–74% | 3–60% |
| Yellow at week 144 | 0.4–27% | 0.4–11% |

**Findings:**

- Feed prevents starvation in every run; every birth goes through.
- Feeding pulls the village toward green: green never drops below 39%, and red and yellow lose their high end. This is the pull the plan expected.
- The spread survives: at week 144, green still ranges from 39% to 95%. Some Feed societies end almost purely green, which is not the mix pillar 1 describes.

**For the next run:** repeat at 30 points per week; report medians and quartiles, not only ranges; report blue and violet; say whether taxes were applied.

### Test A, run 3: Stay and Feed at 30 points (2026-10-30)

20 seeds, `manameter_points_per_week` = 30 from the CSV.

|  | Stay | Feed |
| --- | --- | --- |
| Runs with short weeks | 1 of 20 (seed 18: 124 short weeks) | 0 of 20 |
| Workers at week 144 | 12–74 | 74 in every run |
| Green leads at week 144 | 19 of 20 (1 red) | 20 of 20 |

| Share, lowest–highest | Stay wk 48 | Stay wk 96 | Stay wk 144 | Feed wk 48 | Feed wk 96 | Feed wk 144 |
| --- | --- | --- | --- | --- | --- | --- |
| Green | 39–89% | 28–95% | 27–95% | 52–89% | 52–95% | 47–95% |
| Red | 8–40% | 4–47% | 4–49% | 8–37% | 4–38% | 4–39% |
| Blue | 1–20% | 1–23% | 1–24% | 1–11% | 1–11% | 1–13% |
| Yellow | 1–17% | 1–22% | 1–21% | 1–10% | 1–10% | 1–10% |

**Findings:**

- With food taken care of, green leads in every run and never drops below 47%. Red is capped at about 39%; blue and yellow at about 13% and 10%.
- From this start, a society that simply feeds itself always ends green-led. Any other character needs deliberate effort.
- Same pattern as at 60, with smaller swings.

**Still to test:** Pivot with Feed, which is H1 in realistic play: can a fed society become red-led by week 144? Medians and quartiles, violet, and whether taxes were applied are still missing from the report.

### Test A, run 4: equal start (2026-10-30)

Starting Manameter 20% per colour; otherwise as run 3 (30 points per week, 20 seeds).

|  | Stay | Feed |
| --- | --- | --- |
| Runs with short weeks | 15 of 20 (87–136 short weeks) | 0 of 20 |
| Workers at week 144 | 6–74 | 74 in every run |
| Leader at week 144 | red 9, green 5, violet 3, yellow 2, blue 1 | green 20 |

| Share, lowest–highest | Stay wk 48 | Stay wk 144 | Feed wk 48 | Feed wk 144 |
| --- | --- | --- | --- | --- |
| Green | 18–49% | 17–53% | 35–49% | 35–53% |
| Blue | 5–30% | 1–32% | 5–19% | 1–23% |
| Red | 15–56% | 12–65% | 14–36% | 17–35% |
| Yellow | 5–31% | 1–36% | 5–22% | 4–25% |
| Violet | 4–42% | 1–48% | 5–35% | 1–33% |

**Findings:**

- Without deliberate feeding, a mixed society starves: only 20% of newborns are green, food runs short within weeks, births stop, and the society freezes in a near-random mix.
- With feeding, green leads in every run, but as a plurality, not a majority: 35–53%, while the other colours keep up to 35%. This is much closer to pillar 1's "typical mix" than the 80% green start (green 47–95%).
- Green's lead looks structural: one colour has a mandatory building (the farm), while the rest of the village is split among four colours.
- The starting Manameter is the strongest lever found so far: it decides whether a fed society ends as a mix or almost purely green.

### Test A, run 5: Feed then Pivot (2026-10-30)

**Feed then Pivot:** a newborn goes to a farm when food is low (Feed's rule); otherwise as in Pivot: to a watchtower if born from week 48 on, else to their own colour. Existing workers are never moved. Equal start (20% per colour), 30 points per week, 20 seeds.

|  | Pivot | Feed then Pivot |
| --- | --- | --- |
| Runs with short weeks | 20 of 20 | 0 of 20 |
| Workers at week 144 | 6–69 | 74 in every run |
| Red +20 points after week 48 | 2 of 20 (in 70 and 76 weeks) | 0 of 20 |
| Leader at week 144 | red 12, violet 3, green 2, yellow 2, blue 1 | green 10, red 10 |
| Green at week 144 | 17–34% | 36–43% |
| Red at week 144 | 12–65% | 31–48% |

**Findings:**

- Pivot without feeding starves in every run; its high red shares come from societies that froze.
- With feeding, the pivot works partly: red ends at 31–48% and leads in half the runs, but never gains 20 points. Watchtower workers eat without making food, so every second or third newborn after the pivot has to farm.
- Only newborns pivot. About a third of the final village was born before week 48 and never moves, and about a third of later newborns must farm. A non-green colour seems capped at roughly half the Manameter while food comes only from farms.

**For H1:** "+20 points" was a proxy picked before the success criteria were set. If the question is "can a player who wants to make the society red-led", the answer is: in half the runs, after two years of full effort. Set the criterion before the next run.

### Test A, run 6: all four patterns at 60 points (2026-10-30)

Equal start (20% per colour), `manameter_points_per_week` = 60, 20 seeds.

|  | Stay | Feed | Pivot | Feed then Pivot |
| --- | --- | --- | --- | --- |
| Runs with short weeks | 16 of 20 | 0 | 18 of 20 | 0 |
| Workers at week 144 | 6–74 | 74 | 6–74 | 74 |
| Red +20 points after week 48 | – | – | 3 of 20 (45–71 weeks) | 5 of 20 (50–96 weeks) |
| Leader at week 144 | red 9, green 5, others 2 each | green 18, red 2 | red 12, others 2 each | red 16, green 4 |
| Green at week 144 | 17–66% | 36–66% | 17–38% | 38–44% |
| Red at week 144 | 16–82% | 14–45% | 16–82% | 35–56% |

**Comparison with 30 points (runs 4 and 5), fed patterns only:**

|  | 30 points | 60 points |
| --- | --- | --- |
| Feed: green at week 144 | 35–53% | 36–66% |
| Feed: green leads | 20 of 20 | 18 of 20 |
| Feed then Pivot: red at week 144 | 31–48% | 35–56% |
| Feed then Pivot: red leads | 10 of 20 | 16 of 20 |

**Findings:**

- Faster updates make a deliberate pivot work more often (red leads in 16 of 20 runs instead of 10), but also let untouched societies swing wider through chance births.
- The Manameter can't tell a deliberate change from a lucky one: both arrive as a shift in the worker mix. Any speed that makes intent work faster also makes luck work faster.
- "+20 points from week 48" is a weak measure: in 15 runs red was already high at the pivot. Since every pattern runs on the same seeds, the effect of the player's intent can be measured per seed instead: red in Feed then Pivot minus red in Feed.

### Test A, run 7: farm yield 12 (2026-10-30)

`wheat_per_farm_worker` = 12 instead of 9, so one farmer feeds four people instead of three. Equal start, 30 points per week, 20 seeds.

|  | Stay | Feed | Pivot | Feed then Pivot |
| --- | --- | --- | --- | --- |
| Runs with short weeks | 11 of 20 | 0 | 19 of 20 | 0 |
| Workers at week 144 | 7–74 | 74 | 7–74 | 74 |
| Red +20 points after week 48 | – | – | 5 of 20 (65–84 weeks) | 6 of 20 (76–94 weeks) |
| Leader at week 144 | green 7, red 7, violet 3, yellow 2, blue 1 | green 14, red 3, yellow 2, violet 1 | red 14, violet 3, yellow 2, blue 1 | red 20 |
| Green at week 144 | 15–53% | 28–53% | 15–33% | 28–36% |
| Red at week 144 | 14–69% | 10–46% | 15–69% | 34–57% |

**Comparing the two levers tried so far (fed patterns, equal start):**

|  | Baseline (9 wheat, 30 points) | Faster Manameter (9 wheat, 60 points) | Higher yield (12 wheat, 30 points) |
| --- | --- | --- | --- |
| Feed: green leads | 20 of 20 | 18 of 20 | 14 of 20 |
| Feed: green at week 144 | 35–53% | 36–66% | 28–53% |
| Feed then Pivot: red leads | 10 of 20 | 16 of 20 | 20 of 20 |

**Findings:**

- The farm yield sets the share of the village that must farm (a quarter at 12 instead of a third at 9). That share is the main source of the pull toward green and the main ceiling on a pivot.
- A higher yield makes a deliberate pivot work in every run, while untouched societies stay more mixed. Unlike a faster Manameter, it doesn't widen the high end of the luck spread.
- This is the first setting where both hold: an untouched society leans green but not always, and a society that commits to another colour gets there within two years.

### Test A, run 8: farm yield 15 (2026-10-30)

`wheat_per_farm_worker` = 15 as a console override (the CSV holds 12). Equal start, 30 points per week, 20 seeds.

|  | Stay | Feed | Pivot | Feed then Pivot |
| --- | --- | --- | --- | --- |
| Runs with short weeks | 7 of 20 | 0 | 15 of 20 | 0 |
| Workers at week 144 | 9–74 | 74 | 9–74 | 74 |
| Red +20 points after week 48 | – | – | 12 of 20 (53–89 weeks) | 11 of 20 (65–96 weeks) |
| Leader at week 144 | green 8, red 5, yellow 3, violet 3, blue 1 | green 11, red 3, violet 3, yellow 2, blue 1 | red 16, violet 2, yellow 1, blue 1 | red 20 |
| Green at week 144 | 12–53% | 23–53% | 12–33% | 24–33% |
| Red at week 144 | 8–48% | 8–50% | 12–65% | 35–61% |

| Wheat per farm worker | 9 | 12 | 15 |
| --- | --- | --- | --- |
| Share of the village that must farm | 1/3 | 1/4 | 1/5 |
| Stay: runs that starve | 15 of 20 | 11 of 20 | 7 of 20 |
| Feed: green leads at week 144 | 20 of 20 | 14 of 20 | 11 of 20 |
| Feed then Pivot: red leads at week 144 | 10 of 20 | 20 of 20 | 20 of 20 |
| Feed then Pivot: red +20 points | 0 of 20 | 6 of 20 | 11 of 20 |

### Test A: summary so far

- **The starting Manameter** decides most of the outcome: from 80% green, a fed society ends almost purely green; from an equal start, it ends as a mix.
- **The farm yield** is the strongest rule lever: it sets the share of the village that must farm, which drives the pull toward green and caps any change of direction. From 12 wheat on, a committed pivot to red succeeds in every run.
- **The Manameter speed** amplifies intent and luck equally, because both arrive as a change in the worker mix. 30 points per week is the current choice.
- **Luck from births** stays: across all settings, the highest green share in Feed is 53% or more. Birth chance is self-reinforcing and no tuning tested so far removes it.
- **What Test A can't answer:** whether the remaining food pressure still creates interesting decisions (H2). A yield of 15 makes food matter less, which helps the choice of character but may remove a dilemma. That is for Test B.

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
| Weeks without enough food; king's demands met / missed; taxes paid / missed, which payment was missed, and whether on purpose | B |
| Decisions made while paused; average pause length | C |
| Player's impressions, in their own words | B, C |
| Result per hypothesis: holds / fails / unclear | All |
| What changes in the concept as a result | All |
