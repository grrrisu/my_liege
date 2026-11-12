# My Liege prototype: current rules

The rules the engine implements, as they stand now. The designer keeps the reasoning and test reports elsewhere; this file holds only what to build.
Values are never written here: each rule names its CSV keys in `priv/balance_inputs.csv`.

## Changelog
<!-- One line per change: date, rule, what changed. Newest first. -->
- 2026-11-12: Config keys renamed to `group.item.attribute` (units: `_permille`, `_weeks`, else whole amounts); no rule or value changes. Unused keys removed and R6 (improved plough) dropped from this file. Entertainment renamed culture, also in the export (`production_culture`, `spoiled_culture`, demand product `culture`). Export lists only the columns exported today.
- 2026-11-09: R11 (new), happiness: each week the entertainment production against the population sets a step from −3 to +3 that changes the week's food and defence production (0 in the grace period); computed and applied in step 1, so eating and bandits (R10) use the changed values; UI shows the last week's step and ratio (no forecast); export columns `happiness_ratio`, `happiness_step`. New CSV keys `happiness_*`.
- 2026-11-06: Forecasts (T77, UI only, no rule change): food, gold, next tax, open demand or project and bandits each show what happens if the last week's change repeats; computed in the engine, used by the UI and the AutoRun bots (their results unchanged). No new CSV keys or export columns.
- 2026-11-06: R10, the threat never falls on its own: it rises by pressure − 1000 only if that is positive, otherwise it stays; it still drops to the floor after a raid. CSV: `bandit_floor_step` and `bandit_cover_weeks` changed.
- 2026-11-06: R10, UI: the threat's direction and the protected gold both describe the last week run, matching the production shown (3 defence → 60 protected); the protected gold was next week's, which could contradict the direction.
- 2026-11-06: R10 (new), bandits, robbery only: weekly pressure (gold ÷ protected gold) drives a threat with a rising floor; at `bandit_threshold` bandits set out and raid `bandit_warning_weeks` later, taking the gold above the protected gold; new weekly step 12 after taxes and demands, before spoilage; export columns `bandit_pressure`, `bandit_threat`, `bandits_weeks_to_raid`, `gold_robbed`. R1: `starting_gold` lowered in the CSV.
- 2026-11-06: R7, grace period and the king takes what he can: no taxes and no demands for the first `grace_weeks` weeks; on every skipped or missed tax and every refused or missed food or gold demand the king takes the stock there is, up to the amount owed; export columns `king_took_gold`, `king_took_food`.
- 2026-11-06: Terms, new pentagon order: Growth – Wealth – Wisdom – Strength – Culture (was Growth – Wisdom – Strength – Wealth – Culture); changes neighbours/opposites (R2 factors), tie-breaks (R4 rounding, R7 demand ranks), the birth draw order (R1, same chances) and the colour/product column order in the UI and export.
- 2026-11-06: R7, demand projects (T42): knowledge and entertainment demands are projects fed by the village's whole production of that good until the target; delivered at the deadline only if reached; refusable at any time (miss counted in the next week); export column `demand_progress`.
- 2026-11-04: R2, R3, R5, builders and travel (T43): ordered buildings need `builders_per_building` builders for `construction_weeks` weeks; every move costs `travel_weeks`; export shows builders and travelling workers.
- 2026-11-03: R2, building costs (T43): every ordered building costs `build_cost_gold`; export shows gold spent on buildings.
- 2026-11-03: R7, missed demands decided: they count in the same tally as tax misses (as already implemented).
- 2026-11-03: file created from the Prototype Plan (R1–R9) and the weekly-step skill.

## Terms
- Paths/colours, pentagon order: Growth (green) – Wealth (yellow) – Wisdom (blue) – Strength (red) – Culture (violet) – back to green. Neighbours: green–yellow, yellow–blue, blue–red, red–violet, violet–green; all other pairs are opposites. Ties (Manameter rounding, demand colour ranks) and the colour order in the UI and exports follow this order.
- Relation of a worker's colour to a building's colour: same; neighbour (adjacent on the pentagon); opposite (not adjacent).
- Buildings and their output: farm → food, monastery → knowledge, watchtower → defence, market → gold, tavern → culture. Guildhouse: neutral, trains workers, produces nothing.
- The concept says "wisdom" for knowledge.
- Week: one simulation step. 48 weeks per year (hardcoded); game length `game.years`.

## Weekly order
0. Tax count (R7), count weeks only
1. Production (R2), changed by happiness (R11); an open project (R7) then takes its good first
2. Mana (R3)
3. Travel (R2): every travelling worker's travel goes down by 1
4. Manameter update (R4)
5. Eating (R8)
6. Birth (R1), drawn from the Manameter updated in step 4
7. Construction (R2): sites advance; finished buildings release their builders
8. Training ends (R5)
9. Tax payment (R7), due weeks only
10. Demand delivery (R7), deadline weeks only; a project refused before the week is settled then
11. Demand made (R7), demand weeks only
12. Bandits (R10): threat, setting out, raid; every week from week 1
13. Spoilage (R9)

The player acts between weeks; changes take effect the following week. Production, mana, construction and training use travel as it was when the week started, so a worker placed while the game stands at week N does nothing in week N+1 and works from week N+2. Code-level detail: the `weekly-step` skill.

## R1 Birth and start
- Every `birth.interval_weeks`, one worker is born if at least `birth.min_food_left` food is left after eating.
- Colour is drawn with chances equal to the Manameter shares (seeded random). Colour never changes.
- A newborn is unplaced and eats from the following week.
- Start: `start.farmers` green on a farm, `start.soldiers` red in the tower (the tower counts as a watchtower), `start.food`, `start.gold`, Manameter `manameter.<colour>.start_permille`.

## R2 Production
- Per worker per week: base production × colour factor.
- Base: `place.<building>.output_per_worker`.
- Factors: `efficiency.<untrained|trained>.<same|neighbour|opposite>_permille`.
- Capacity per building: `place.<building>.capacity`.
- Every building the player orders costs `build.cost_gold` gold, the same for every type, guildhouse included. Paid from the gold stock when ordering (between weeks, before the next week's production). Not possible with less gold than the price; the UI shows the price and disables ordering. The starting farm and tower are free, finished and need no builders.
- Market workers produce gold directly (prototype simplification).

### Builders
- An ordered building is a site. It needs `build.builders` builders: unplaced workers the player places on the site, any colour, colour has no effect. A site takes no more.
- A site advances one week in every week in which all its builders are on it and have arrived (travel 0). After `build.weeks` such weeks it is finished: workers can be placed in it from then on, and its builders become unplaced (travelling).
- A builder leaving the site before it is finished (moved or unplaced) resets its progress to 0. The site stays; the gold isn't refunded or paid again.
- Builders eat and count toward taxes, but produce nothing and no mana.
- UI: each site shows its arrived builders (arrived / `build.builders`) and progress (weeks done / `build.weeks`).

### Travel
- A worker's travel is set to `travel.weeks` whenever it is placed from unplaced (into a building, a site or the guildhouse), moved directly from one building to another (once), unplaced by the player, or released as a finished trainee or builder. Moving a worker that is still travelling sets it to `travel.weeks` again.
- The worker takes its place at once, but while its travel is above 0 it produces nothing and no mana, isn't an arrived builder, and doesn't train. It still eats and counts toward taxes.
- An unplaced worker can't be placed while its travel is above 0.
- Newborns and starting workers have travel 0.
- UI: travelling workers are marked with their remaining travel.

## R3 Mana
- Per worker per week: untrained `mana.untrained.place_colour` in the building's colour and `mana.untrained.worker_colour` in their own colour; trained `mana.trained.place_colour` and `mana.trained.worker_colour`. Same colour: the two add up.
- Trainees, builders and travelling workers produce no mana.

## R4 Manameter
- Each week: remove `manameter.points_per_week_permille` points in proportion to the current shares, then add the same number in proportion to the mana produced that week. Shares always sum to 1000.

## R5 Training
- Needs a guildhouse with a free place (`place.guildhouse.capacity`) and the worker's colour at or above `training.min_share_permille` in the Manameter.
- Takes `training.weeks`, no other cost, starting once the trainee has arrived (after `travel.weeks`). More than one guildhouse can be built. A guildhouse site trains no one; workers there are builders.
- A trainee eats and counts toward taxes, but produces nothing and no mana.
- Moving a trainee out early loses the progress. A finished trainee is unplaced and travels (R2).

## R7 Taxes and demands
- Grace period: in weeks 1 to `king.grace_weeks` the king collects no taxes and makes no demands; everything else runs as usual. The UI shows that it is running and its last week.
- Taxes: every `king.tax.interval_weeks`. The village is counted `king.tax.count_lead_weeks` before; amount = workers counted × `king.tax.per_worker` gold, fixed at counting. No due week (and no count for it) inside the grace period; the first payment is the first regular due week after it. The player decides before each due week: pay or skip. Paid in full, skipped or missed (not enough gold); no partial payment.
- Demands: one per half year, in a random week drawn from the half year's weeks after the grace period, so that the deadline stays in the same half year. A half year with no such week (wholly inside the grace period, or without room for the deadline after it) has no demand and no draw. `king.demand.deadline_weeks` to deliver.
- Demanded colour by Manameter rank: year 1 biggest, year 2 third, year 3 smallest.
- Amount: population × `king.demand.population_share_permille` × base production of that colour × `king.demand.production_weeks`.
- Food, gold and defence demands are delivered from the stock. The player decides before the deadline: deliver or refuse. Delivered, refused or missed (stock short).
- Knowledge and culture demands are projects with the amount above as target:
  - From the week after the demand until the target is reached, the village's whole production of that good (all monasteries or all taverns) goes into the project instead of the stock. In the week the target is reached, only what is missing goes in and the rest to the stock; after that, production goes to the stock.
  - Mana is unchanged. The project doesn't spoil; the stock of that good is never used for it and spoils as usual.
  - The project stays open until the deadline (the deadline week's production counts). Target reached → delivered; otherwise → missed. No partial delivery; no decision needed.
  - The player can refuse it at any time while it is open: from the next week production goes to the stock again, and the refusal counts as a miss in that next week.
- The current demand, its amount, deadline and progress must be visible in the UI; for a project also the buildings whose production goes into it.
- Misses: skipped or missed taxes and refused or missed demands count in one shared tally. `king.misses_forgiven` misses are forgiven; the next ends the game.
- The king takes what he can: on every skipped or missed tax and every refused or missed gold or food demand, the king also takes the stock there is (gold for taxes and gold demands, food for food demands), up to the amount owed; a stock at or below 0 gives nothing. Defence demands and projects leave nothing to take: a miss only. Taking happens in the step of the payment or delivery, before spoilage.

## R8 Food
- Every worker eats `good.food.eaten_per_worker` per week.
- Leftover food carries over (stored in the tower, no limit). The stock may go below 0, meaning the village is out of food.
- Short week (food after production is less than everyone eats): the missing food is forgotten and the stock is set to -1, so no birth; log every such week. No other effect until T65 (hunger).

## R9 Spoilage
- At the end of the week, every stock above 0 loses `good.<good>.spoilage_permille` per mille of itself, rounded down. Stocks at or below 0 don't spoil.
- Births, tax payments, demand deliveries and what the king takes use stocks before spoilage.
- Food, gold, defence, culture and knowledge are all stored. A king's project (R7) is not a stock and doesn't spoil.

## R10 Bandits
Robbery only: bandits take gold, nothing else (no fights, no wounded, no mana).
- Runs every week from week 1; the grace period (R7) doesn't apply.
- Uses the gold after taxes and demands, before spoilage (step 12), and this week's defence production: what watchtowers produce this week, the tower included (travelling workers produce nothing, R2). The defence stock plays no part.
- Protected gold = defence production × `bandit.cover_weeks`.
- Pressure = gold ÷ protected gold, per mille, rounded down. Gold at or below 0 gives 0. No defence production with gold above 0: the threat jumps to `bandit.threshold` at once, so bandits set out (unless they already are on their way).
- Threat: starts at 0; each week it rises by pressure − 1000 if that is positive, otherwise it stays as it is (per mille; `bandit.threshold` and `bandit.floor_step` are whole threat points). It never falls on its own, only after a raid. It is never below the floor, and is raised to it when the floor rises: 0 in year 1 (the first two half years), then `bandit.floor_step` more at the start of each later half year (half year = 48 ÷ 2 weeks).
- Setting out: when the threat reaches `bandit.threshold` (at or above) and no bandits are on their way, they set out and raid `bandit.warning_weeks` later. In the setting-out week the threat has already changed. From the next week until the raid, it doesn't change.
- The raid, in the raid week with that week's values: pressure 1000 or less → repelled, nothing lost; otherwise they take loot = gold − protected gold. Afterwards, repelled or not, the threat drops to the floor and can rise again from the following week.
- A raid is not a miss (R7) and the king takes nothing for it.
- UI: the threat and its direction (rising or steady: its change in the last week run; falling only in a raid week) are always visible, and the protected gold next to the gold stock (the last week's defence production, as shown with the production, × `bandit.cover_weeks`). Both describe the same week as the production shown. Bandits on their way are shown with the raid week and the weeks left instead of the direction; setting out and the raid's outcome are reported when the week runs.

## R11 Happiness
- Every week from week 1: ratio = this week's culture production ÷ (population × `happiness.need_per_worker_permille`), per mille, rounded down.
  - Culture production counts whether it goes to the stock or into a project (R7). The culture stock plays no part.
  - Population: every worker at the start of the week (placed, unplaced, builders, trainees, travelling); a newborn counts from the following week. A population of 0 is an error.
- Step from the ratio: below `happiness.level3.penalty_below_permille` −3, below `happiness.level2.penalty_below_permille` −2, below `happiness.level1.penalty_below_permille` −1; from `happiness.level3.bonus_from_permille` +3, from `happiness.level2.bonus_from_permille` +2, from `happiness.level1.bonus_from_permille` +1; otherwise 0.
- Effect: this week's food and defence production change by ± `happiness.level1.change_permille`, `happiness.level2.change_permille` or `happiness.level3.change_permille` per mille (step −2: production × (1000 − `happiness.level2.change_permille`) ÷ 1000). Applied once to each product's total, after the colour factors (R2), rounded down. Nothing else changes: gold, knowledge, culture, mana and births stay as they are.
- Grace period (R7): the step applied is 0; the ratio and the step it would have are still computed and shown.
- Everything after production uses the changed values: eating (R8) and the defence production that protects gold (R10).
- UI: next to the stocks, the step applied in the last week run and its ratio; in the grace period also the step it would have. No forecast: next week's culture production depends on the placement.

## Forecasts
UI only: forecasts change nothing in the game. Each one repeats the change of the last week run (its end minus its start) unchanged for every week ahead. The change is raw: taxes paid, demands delivered, what the king took and robbery in that week count in it; gold spent on buildings between weeks doesn't. No forecasts in week 0 (no week before it); the next tax's amount and week are shown from week 0. The AutoRun bots use the same forecasts (food balance, next tax).
- Food: the stock's change per week, rising, falling or steady; if falling, the week it goes below 0.
- Gold: the stock's change per week (spoilage included), rising, falling or steady.
- Next tax: the amount fixed at the count, or before the count `king.tax.per_worker` × the current workers (shown as "at least": births until the count raise it); its due week; the gold expected then (gold now + change × weeks until the due week, that week included) and the shortfall, if any. None after the game's last payment.
- Open demand: the amount, the deadline and the amount expected by the deadline, deadline week included: from the stock, the stock + its change × weeks left; for a project, progress + its gain in the last week × weeks left, at most the target. Met or short. No forecast for a project in the week it was made, or once refused.
- Bandits: the threat's direction (as in R10) and the week it reaches `bandit.threshold` at the last week's pressure (rising by pressure − 1000 a week; next week if the pressure was unbounded; never at 1000 or less). The rising floor is left out. Not shown while bandits are on their way.

## Export
- Weekly CSV, one row per week, week 0 (the start) first. Amounts of goods and `bandit_threat` in thousandths; mana in whole points; Manameter shares per mille; counts and weeks as plain numbers. Product columns in the pentagon order of their buildings, colour columns in pentagon order.
- Columns: week; production_food, production_gold, production_knowledge, production_defence, production_culture; mana_<colour>; manameter_<colour>; food_left (after spoilage); newborn (the newborn's colour, empty if none); trained (colours of the workers who finished training that week); builders (arrived, at the end of the week); travelling (workers with travel above 0, at the end of the week); gold (after spoilage); tax_due (filled in the count week); tax (paid, skipped or missed, in the due week); demand_product and demand_amount (in the week the demand is made); demand_outcome (delivered, refused or missed, in the deadline week, or for a refused project in the week after the refusal); demand_progress (a project's total at the end of every week it is open, the week it is made and its deadline week included; empty for food, gold and defence demands and when no project is open); king_took_gold and king_took_food (what the king took that week on a skipped or missed tax and a refused or missed demand; 0 otherwise); spoiled_food, spoiled_gold, spoiled_knowledge, spoiled_defence, spoiled_culture; gold_spent_buildings (gold paid for buildings ordered while the game stood at that week; not yet taken from that row's gold); bandit_pressure (per mille; `inf` without defence production and with gold; empty in week 0); bandit_threat (end of the week); bandits_weeks_to_raid (weeks left at the end of the week; empty if no bandits are on their way, also in the raid week); gold_robbed (what the bandits took that week, before spoilage; 0 otherwise); happiness_ratio (per mille; empty in week 0); happiness_step (the step applied, −3 to +3, a plain number; 0 in the grace period; empty in week 0); game_over.
