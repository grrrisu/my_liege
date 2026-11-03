# My Liege prototype: current rules

The rules the engine implements, as they stand now. The designer keeps the reasoning and test reports elsewhere; this file holds only what to build.
Values are never written here: each rule names its CSV keys in `priv/balance_inputs.csv`.

## Changelog
<!-- One line per change: date, rule, what changed. Newest first. -->
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
3. Manameter update (R4)
4. Eating (R8)
5. Birth (R1), drawn from the Manameter updated in step 3
6. Training ends (R5)
7. Tax payment (R7), due weeks only
8. Demand delivery (R7), deadline weeks only
9. Demand made (R7), demand weeks only
10. Spoilage (R9)

The player acts between weeks; changes take effect the following week. Code-level detail: the `weekly-step` skill.

## R1 Birth and start
- Every `birth_interval_weeks`, one worker is born if at least `birth_min_food_left` food is left after eating.
- Colour is drawn with chances equal to the Manameter shares (seeded random). Colour never changes.
- A newborn is unplaced and eats from the following week.
- Start: `starting_farmers` green on a farm, `starting_soldiers` red in the tower (the tower counts as a watchtower), `starting_food`, `starting_gold`, Manameter `manameter_start_<colour>`.

## R2 Production
- Per worker per week: base production × colour factor.
- Base: `wheat_per_farm_worker`, `gold_per_market_worker`, `base_production_<building>`.
- Factors: `factor_<same|neighbour|opposite>_<untrained|trained>`.
- Capacity per building: `capacity_<building>`. Building takes `construction_weeks`, no other cost (see T43, under discussion).
- Market workers produce gold directly (prototype simplification).
- Moving a worker: free and immediate (see T43, under discussion).

## R3 Mana
- Per worker per week: untrained `mana_building_untrained` in the building's colour and `mana_own_untrained` in their own colour; trained `mana_building_trained` and `mana_own_trained`. Same colour: the two add up.
- Trainees produce no mana.

## R4 Manameter
- Each week: remove `manameter_points_per_week` points in proportion to the current shares, then add the same number in proportion to the mana produced that week. Shares always sum to 1000.

## R5 Training
- Needs a guildhouse with a free place (`capacity_guildhouse`) and the worker's colour at or above `training_threshold` in the Manameter.
- Takes `training_weeks`, no other cost. More than one guildhouse can be built.
- A trainee eats and counts toward taxes, but produces nothing and no mana.
- Moving a trainee out early loses the progress. A finished trainee is unplaced.

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
- Columns: week, population, food_eaten, food_left, gold, stock_defence, stock_entertainment, stock_knowledge, spoiled_food, spoiled_gold, spoiled_defence, spoiled_entertainment, spoiled_knowledge, Manameter share per colour, workers per building and colour, off_colour_workers, trainees, trained_total, demand_progress, game_over.
- Separate decision log, one row per decision: week, worker colour, trained or not, from building, to building, on- or off-colour, rating (easy / some thought / torn).
