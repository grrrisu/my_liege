# My Liege prototype: current rules

The rules the engine implements, as they stand now. The designer keeps the reasoning and test reports elsewhere; this file holds only what to build.
Values are never written here: each rule names its CSV keys in `priv/balance_inputs.csv`.

## Changelog
<!-- One line per change: date, rule, what changed. Newest first. -->
- 2026-11-04: R2, R3, R5, builders and travel (T43): ordered buildings need `builders_per_building` builders for `construction_weeks` weeks; every move costs `travel_weeks`; export shows builders and travelling workers.
- 2026-11-03: R2, building costs (T43): every ordered building costs `build_cost_gold`; export shows gold spent on buildings.
- 2026-11-03: R7, missed demands decided: they count in the same tally as tax misses (as already implemented).
- 2026-11-03: file created from the Prototype Plan (R1–R9) and the weekly-step skill.

## Terms
- Paths/colours, pentagon order: Growth (green) – Wisdom (blue) – Strength (red) – Wealth (yellow) – Culture (violet) – back to green.
- Relation of a worker's colour to a building's colour: same; neighbour (adjacent on the pentagon); opposite (not adjacent).
- Buildings and their output: farm → food, monastery → knowledge, watchtower → defence, market → gold, tavern → entertainment. Guildhouse: neutral, trains workers, produces nothing.
- The concept says "wisdom" for knowledge and "culture" for entertainment.
- Week: one simulation step. 48 weeks per year (hardcoded); game length `years_per_game`.

## Weekly order
0. Tax count (R7), count weeks only
1. Production (R2)
2. Mana (R3)
3. Travel (R2): every travelling worker's travel goes down by 1
4. Manameter update (R4)
5. Eating (R8)
6. Birth (R1), drawn from the Manameter updated in step 4
7. Construction (R2): sites advance; finished buildings release their builders
8. Training ends (R5)
9. Tax payment (R7), due weeks only
10. Demand delivery (R7), deadline weeks only
11. Demand made (R7), demand weeks only
12. Spoilage (R9)

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
- Research needs green at or above `plough_threshold_green`; costs `plough_cost_wisdom` knowledge (about `plough_research_weeks` of a full monastery).
- Effect: farm production + `plough_bonus`. Kept if green later drops.

## R7 Taxes and demands
- Taxes: every `tax_interval_weeks`. The village is counted `tax_count_lead_weeks` before; amount = workers counted × `tax_per_worker` gold, fixed at counting. The player decides before each due week: pay or skip. Paid in full, skipped or missed (not enough gold); no partial payment.
- Demands: one per half year, in a random week. `demand_deadline_weeks` to deliver.
- Demanded colour by Manameter rank: year 1 biggest, year 2 third, year 3 smallest.
- Amount: population × `demand_population_share` × base production of that colour × `demand_production_weeks`.
- The player decides before the deadline: deliver or refuse. Delivered, refused or missed (stock short).
- The current demand, its amount, deadline and progress must be visible in the UI.
- Misses: skipped or missed taxes and refused or missed demands count in one shared tally. `tax_misses_forgiven` misses are forgiven; the next ends the game.

## R8 Food
- Every worker eats `wheat_eaten_per_worker` per week.
- Leftover food carries over (stored in the tower, no limit). The stock may go below 0, meaning the village is out of food.
- Short week (food after production is less than everyone eats): the missing food is forgotten and the stock is set to -1, so no birth; log every such week. No other effect until T65 (hunger).

## R9 Spoilage
- At the end of the week, every stock above 0 loses `spoilage_rate_<good>` per mille of itself, rounded down. Stocks at or below 0 don't spoil.
- Births, tax payments and demand deliveries use stocks before spoilage.
- Food, gold, defence, entertainment and knowledge are all stored.

## Export
- Weekly CSV, one row per week. Header states units (values ×1000). Keep the column names already in use; the list below describes content, not exact names.
- Columns: week, population, food_eaten, food_left, gold, stock_defence, stock_entertainment, stock_knowledge, spoiled_food, spoiled_gold, spoiled_defence, spoiled_entertainment, spoiled_knowledge, Manameter share per colour, workers per building and colour, off_colour_workers, trainees, trained_total, builders (arrived, at the end of the week), travelling (workers with travel above 0, at the end of the week), demand_progress, gold_spent_buildings (gold paid for buildings ordered while the game stood at that week; not yet taken from that row's gold), game_over.
- Separate decision log, one row per decision: week, worker colour, trained or not, from building, to building, on- or off-colour, rating (easy / some thought / torn).
