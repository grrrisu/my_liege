# My Liege prototype: current rules

The rules the engine implements, as they stand now. The designer keeps the reasoning and test reports elsewhere; this file holds only what to build.
Values are never written here: each rule names its CSV keys in `priv/balance_inputs.csv`.

## Changelog
<!-- One line per change: date, rule, what changed. Newest first. -->
- 2026-11-06: R10, UI: the threat's direction is next week's change at today's gold and the protected gold shown (was last week's change, which could contradict the protected gold next to it).
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
- Buildings and their output: farm → food, monastery → knowledge, watchtower → defence, market → gold, tavern → entertainment. Guildhouse: neutral, trains workers, produces nothing.
- The concept says "wisdom" for knowledge and "culture" for entertainment.
- Week: one simulation step. 48 weeks per year (hardcoded); game length `years_per_game`.

## Weekly order
0. Tax count (R7), count weeks only
1. Production (R2); an open project (R7) takes its good first
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
- Every `birth_interval_weeks`, one worker is born if at least `birth_min_food_left` food is left after eating.
- Colour is drawn with chances equal to the Manameter shares (seeded random). Colour never changes.
- A newborn is unplaced and eats from the following week.
- Start: `starting_farmers` green on a farm, `starting_soldiers` red in the tower (the tower counts as a watchtower), `starting_food`, `starting_gold`, Manameter `manameter_start_<colour>`.

## R2 Production
- Per worker per week: base production × colour factor.
- Base: `wheat_per_farm_worker`, `gold_per_market_worker`, `base_production_<building>`.
- Factors: `factor_<same|neighbour|opposite>_<untrained|trained>`.
- Capacity per building: `capacity_<building>`.
- Every building the player orders costs `build_cost_gold` gold, the same for every type, guildhouse included. Paid from the gold stock when ordering (between weeks, before the next week's production). Not possible with less gold than the price; the UI shows the price and disables ordering. The starting farm and tower are free, finished and need no builders.
- Market workers produce gold directly (prototype simplification).

### Builders
- An ordered building is a site. It needs `builders_per_building` builders: unplaced workers the player places on the site, any colour, colour has no effect. A site takes no more.
- A site advances one week in every week in which all its builders are on it and have arrived (travel 0). After `construction_weeks` such weeks it is finished: workers can be placed in it from then on, and its builders become unplaced (travelling).
- A builder leaving the site before it is finished (moved or unplaced) resets its progress to 0. The site stays; the gold isn't refunded or paid again.
- Builders eat and count toward taxes, but produce nothing and no mana.
- UI: each site shows its arrived builders (arrived / `builders_per_building`) and progress (weeks done / `construction_weeks`).

### Travel
- A worker's travel is set to `travel_weeks` whenever it is placed from unplaced (into a building, a site or the guildhouse), moved directly from one building to another (once), unplaced by the player, or released as a finished trainee or builder. Moving a worker that is still travelling sets it to `travel_weeks` again.
- The worker takes its place at once, but while its travel is above 0 it produces nothing and no mana, isn't an arrived builder, and doesn't train. It still eats and counts toward taxes.
- An unplaced worker can't be placed while its travel is above 0.
- Newborns and starting workers have travel 0.
- UI: travelling workers are marked with their remaining travel.

## R3 Mana
- Per worker per week: untrained `mana_building_untrained` in the building's colour and `mana_own_untrained` in their own colour; trained `mana_building_trained` and `mana_own_trained`. Same colour: the two add up.
- Trainees, builders and travelling workers produce no mana.

## R4 Manameter
- Each week: remove `manameter_points_per_week` points in proportion to the current shares, then add the same number in proportion to the mana produced that week. Shares always sum to 1000.

## R5 Training
- Needs a guildhouse with a free place (`capacity_guildhouse`) and the worker's colour at or above `training_threshold` in the Manameter.
- Takes `training_weeks`, no other cost, starting once the trainee has arrived (after `travel_weeks`). More than one guildhouse can be built. A guildhouse site trains no one; workers there are builders.
- A trainee eats and counts toward taxes, but produces nothing and no mana.
- Moving a trainee out early loses the progress. A finished trainee is unplaced and travels (R2).

## R6 Improved plough
- Research needs green at or above `plough_threshold_green`; costs `plough_cost_wisdom` knowledge from the stock (about `plough_research_weeks` of a full monastery), never from a project (R7).
- Effect: farm production + `plough_bonus`. Kept if green later drops.

## R7 Taxes and demands
- Grace period: in weeks 1 to `grace_weeks` the king collects no taxes and makes no demands; everything else runs as usual. The UI shows that it is running and its last week.
- Taxes: every `tax_interval_weeks`. The village is counted `tax_count_lead_weeks` before; amount = workers counted × `tax_per_worker` gold, fixed at counting. No due week (and no count for it) inside the grace period; the first payment is the first regular due week after it. The player decides before each due week: pay or skip. Paid in full, skipped or missed (not enough gold); no partial payment.
- Demands: one per half year, in a random week drawn from the half year's weeks after the grace period, so that the deadline stays in the same half year. A half year with no such week (wholly inside the grace period, or without room for the deadline after it) has no demand and no draw. `demand_deadline_weeks` to deliver.
- Demanded colour by Manameter rank: year 1 biggest, year 2 third, year 3 smallest.
- Amount: population × `demand_population_share` × base production of that colour × `demand_production_weeks`.
- Food, gold and defence demands are delivered from the stock. The player decides before the deadline: deliver or refuse. Delivered, refused or missed (stock short).
- Knowledge and entertainment demands are projects with the amount above as target:
  - From the week after the demand until the target is reached, the village's whole production of that good (all monasteries or all taverns) goes into the project instead of the stock. In the week the target is reached, only what is missing goes in and the rest to the stock; after that, production goes to the stock.
  - Mana is unchanged. The project doesn't spoil; the stock of that good is never used for it and spoils as usual.
  - The project stays open until the deadline (the deadline week's production counts). Target reached → delivered; otherwise → missed. No partial delivery; no decision needed.
  - The player can refuse it at any time while it is open: from the next week production goes to the stock again, and the refusal counts as a miss in that next week.
- The current demand, its amount, deadline and progress must be visible in the UI; for a project also the buildings whose production goes into it.
- Misses: skipped or missed taxes and refused or missed demands count in one shared tally. `tax_misses_forgiven` misses are forgiven; the next ends the game.
- The king takes what he can: on every skipped or missed tax and every refused or missed gold or food demand, the king also takes the stock there is (gold for taxes and gold demands, food for food demands), up to the amount owed; a stock at or below 0 gives nothing. Defence demands and projects leave nothing to take: a miss only. Taking happens in the step of the payment or delivery, before spoilage.

## R8 Food
- Every worker eats `wheat_eaten_per_worker` per week.
- Leftover food carries over (stored in the tower, no limit). The stock may go below 0, meaning the village is out of food.
- Short week (food after production is less than everyone eats): the missing food is forgotten and the stock is set to -1, so no birth; log every such week. No other effect until T65 (hunger).

## R9 Spoilage
- At the end of the week, every stock above 0 loses `spoilage_rate_<good>` per mille of itself, rounded down. Stocks at or below 0 don't spoil.
- Births, tax payments, demand deliveries and what the king takes use stocks before spoilage.
- Food, gold, defence, entertainment and knowledge are all stored. A king's project (R7) is not a stock and doesn't spoil.

## R10 Bandits
Robbery only: bandits take gold, nothing else (no fights, no wounded, no mana).
- Runs every week from week 1; the grace period (R7) doesn't apply.
- Uses the gold after taxes and demands, before spoilage (step 12), and this week's defence production: what watchtowers produce this week, the tower included (travelling workers produce nothing, R2). The defence stock plays no part.
- Protected gold = defence production × `bandit_cover_weeks`.
- Pressure = gold ÷ protected gold, per mille, rounded down. Gold at or below 0 gives 0. No defence production with gold above 0: the threat jumps to `bandit_threshold` at once, so bandits set out (unless they already are on their way).
- Threat: starts at 0; each week it changes by pressure − 1000 (per mille; `bandit_threshold` and `bandit_floor_step` are whole threat points). It never falls below the floor: 0 in year 1 (the first two half years), then `bandit_floor_step` more at the start of each later half year (half year = 48 ÷ 2 weeks).
- Setting out: when the threat reaches `bandit_threshold` (at or above) and no bandits are on their way, they set out and raid `bandit_warning_weeks` later. In the setting-out week the threat has already changed. From the next week until the raid, it doesn't change.
- The raid, in the raid week with that week's values: pressure 1000 or less → repelled, nothing lost; otherwise they take loot = gold − protected gold. Afterwards, repelled or not, the threat drops to the floor and moves again from the following week.
- A raid is not a miss (R7) and the king takes nothing for it.
- UI: the threat and its direction (rising, falling or steady: how it would change next week with today's gold and the protected gold shown) are always visible, and the protected gold next to the gold stock (next week's defence production with the workers as placed now × `bandit_cover_weeks`). Bandits on their way are shown with the raid week and the weeks left instead of the direction; setting out and the raid's outcome are reported when the week runs.

## Export
- Weekly CSV, one row per week. Header states units (values ×1000). Keep the column names already in use; the list below describes content, not exact names.
- Columns: week, population, food_eaten, food_left, gold, stock_defence, stock_entertainment, stock_knowledge, spoiled_food, spoiled_gold, spoiled_defence, spoiled_entertainment, spoiled_knowledge, Manameter share per colour, workers per building and colour, off_colour_workers, trainees, trained_total, builders (arrived, at the end of the week), travelling (workers with travel above 0, at the end of the week), demand_progress (a project's total at the end of every week it is open, the week it is made and its deadline week included; empty for food, gold and defence demands and when no project is open), king_took_gold and king_took_food (what the king took that week on a skipped or missed tax and a refused or missed demand; 0 otherwise), gold_spent_buildings (gold paid for buildings ordered while the game stood at that week; not yet taken from that row's gold), bandit_pressure (per mille; `inf` without defence production and with gold; empty in week 0), bandit_threat (end of the week, ×1000), bandits_weeks_to_raid (weeks left at the end of the week; empty if no bandits are on their way, also in the raid week), gold_robbed (what the bandits took that week, before spoilage; 0 otherwise), game_over.
- Separate decision log, one row per decision: week, worker colour, trained or not, from building, to building, on- or off-colour, rating (easy / some thought / torn).
