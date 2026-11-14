# My Liege prototype: current rules

The rules the engine implements, as they stand now. The designer keeps the reasoning and test reports elsewhere; this file holds only what to build.
Values are never written here: each rule names its CSV keys in `priv/balance_inputs.csv`.

## Changelog
<!-- One line per change: date, rule, what changed. Newest first. -->
- 2026-11-14: R13 extended: a way may need more than one book of each of its two colours (`way.<type>.books`, default 1) and an invention made first; the lock names the books still needed per colour and the missing invention. R15 rewritten, improved plough I and II: plough I as before with `way.plough.bonus_permille` lowered in the CSV; plough II a second invention (`way.plough_2.work`, `.capacity`, `.bonus_permille`), unlocked with `way.plough_2.books` blue and green books and plough I invented; the bonuses of the ploughs invented add up. One open project per invention. UI: an inventions overview from week 0, the invented ones with their effect in the state column, the farm's total bonus on its card. New keys `way.plough_2.*`; export column `plough_done` replaced by `plough_level` (0, 1, 2).
- 2026-11-14: R17 rewritten, the hunting camp: once unlocked (red + green books) one camp opens as a place, free, like the trade route; up to `way.hunting.max_party` hunters, travelling `way.hunting.travel_weeks` both ways; each arrived hunter adds `way.hunting.food_per_week` × his factor against red to the camp's bag every week; every `way.hunting.haul_weeks` weeks with an arrived hunter, a haul: one luck draw by the arrived hunters, bag × luck into the stock; the bag is lost when the last hunter leaves. Replaces the one-off hunt (key `way.hunting.hunt_weeks` removed; new `way.hunting.haul_weeks`). R18 rewritten: a haul by 2 or more hunters adds `king.suspicion.low/mid/high` by its luck, a haul by 1 hunter and every block of `way.hunting.haul_weeks` game weeks without an arrived hunter take `king.suspicion.decay`, never below 0; at `king.suspicion.threshold` it counts as a miss (R7) and halves (key `king.suspicion.per_expedition` removed). Weekly order: step 8 hunts and settles the suspicion. Export: `food_from_hunting` is the haul; new columns `hunters`, `suspicion_miss`.
- 2026-11-14: R16 rewritten, the grain trade is a trade route: once unlocked (yellow + green books) one route opens as a place, free; workers are placed on it and leave it as in a building, up to `way.grain_trade.capacity`, travelling `way.grain_trade.travel_weeks` both ways; every week each arrived trader, in the order placed, pays `way.grain_trade.gold_per_week` × 1000 ÷ his factor against yellow and brings `way.grain_trade.food_per_week` food, or pays and brings nothing if the gold is short. Replaces the one-off trade (keys `way.grain_trade.gold`, `.food`, `.trade_weeks` removed; new `way.grain_trade.capacity`, `.gold_per_week`, `.food_per_week`). Weekly order: new step 13, the trade route, after the demand made; bandits 14, spoilage 15; step 8 no longer returns trades. Export: `food_from_trade` is the route's food that week; new columns `gold_to_trade`, `traders`.
- 2026-11-14: R8, no stock goes below 0: a short week leaves 0 food (it was -1) and is still logged as short and blocks the birth (R1). Seed 2473626401 showed -1 food in week 34 for this reason. The food forecast's weeks left count to the next short week.
- 2026-11-14: R17 (new), hunting, red's way to food (unlocks as R13: red + green books): an expedition is a new kind of place; a free hunt with a party of 1 to `way.hunting.max_party` arrived workers, away 2 × `way.hunting.travel_weeks` + `way.hunting.hunt_weeks` weeks (mana as R3, no production or defence, can't leave); on return the haul (each hunter's `way.hunting.food_per_week` × `way.hunting.hunt_weeks` × his factor against red, summed, × a luck factor drawn by party size from the seeded random) and the party released. R18 (new), the king's suspicion: each hunt that sets out adds `king.suspicion.per_expedition`; shown, no effect yet. New keys `way.hunting.*`, `king.suspicion.per_expedition`; export columns `food_from_hunting`, `suspicion`; weekly order: step 8 also returns hunts.
- 2026-11-14: R16 (new), grain trade, yellow's way to food (unlocks as R13: yellow + green books): a trade is a new kind of place; started free with one arrived trader, paying `way.grain_trade.gold` × 1000 ÷ the trader's factor against yellow at once; away 2 × `way.grain_trade.travel_weeks` + `way.grain_trade.trade_weeks` weeks (mana as R3, no production, can't leave); on return `way.grain_trade.food` food and the trader released. New keys `way.grain_trade.*`; export column `food_from_trade`; weekly order: step 8 also returns trades.
- 2026-11-14: R13–R15 (new), ways: a way (a colour making another colour's home good) unlocks with one book of its colour and one of its good's home colour (R12 books now have this effect, never used up). R14 granary (violet way to food, a building): while a keeper works, food spoils at `place.granary.food_spoilage_permille`; each working granary takes `place.granary.culture_upkeep` culture a week from the stock. R15 improved plough (blue way to food, an invention): a free project of `way.plough.work` knowledge, up to `way.plough.capacity` workers; once invented farm workers produce × (1000 + `way.plough.bonus_permille`) ÷ 1000. New keys `place.granary.*`, `way.plough.*`; export columns `plough_done`, `granary_working`, `culture_upkeep`; weekly order: step 1 takes the upkeep and applies the bonus, step 8 also finishes inventions, step 14 uses the granary's rate.
- 2026-11-14: R11, happiness counts the culture made in buildings minus the culture spent (the granaries' upkeep, R14), never below 0.
- 2026-11-14: R3, mana comes from the place, not the worker: every working worker makes `mana.place_colour` of the place's colour and `mana.good_colour` of the colour of the good's home place; the worker's colour and training no longer matter. Keys `mana.place_colour`, `mana.good_colour` replace `mana.<training>.*`.
- 2026-11-14: R2, efficiency values changed in the CSV (untrained neighbour, trained neighbour and opposite); no rule change.
- 2026-11-13: R12 (new), books: the player writes books of any colour as projects (capacity 1); a worker writes as in a blue building × the colour's Manameter share ÷ 200; finished books are held, with no effect yet; new key `book.work`; export columns `books_<colour>`.
- 2026-11-13: R7, knowledge and culture demands are worker projects: workers placed on them produce into them as in a building; delivered when the target is reached at or before the deadline; workers released when the project ends or is refused; production no longer flows in automatically.
- 2026-11-13: R2, construction sites are projects: progress counts work (one per arrived builder and week) up to `build.work`; any number of builders up to `build.capacity`; leaving keeps the progress; a finished site becomes a new building.
- 2026-11-12: Config keys renamed to `group.item.attribute` (units: `_permille`, `_weeks`, else whole amounts); no rule or value changes. Unused keys removed and R6 (improved plough) dropped from this file. Entertainment renamed culture, also in the export (`production_culture`, `spoiled_culture`, demand product `culture`). Export lists only the columns exported today.
- 2026-11-09: R11 (new), happiness: each week the entertainment production against the population sets a step from −3 to +3 that changes the week's food and defence production (0 in the grace period); computed and applied in step 1, so eating and bandits (R10) use the changed values; UI shows the last week's step and ratio (no forecast); export columns `happiness_ratio`, `happiness_step`. New CSV keys `happiness_*`.
- 2026-11-06: Forecasts (T77, UI only, no rule change): food, gold, next tax, open demand or project and bandits each show what happens if the last week's change repeats; computed in the engine, used by the UI and the bots (their results unchanged). No new CSV keys or export columns.
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
- Buildings and their output: farm → food, monastery → knowledge, watchtower → defence, market → gold, tavern → culture. These are the home places, one per colour. Guildhouse: neutral, trains workers, produces nothing. Granary: a way (R14), produces nothing.
- Way (R13): a place type with a colour and a good that are not each other's home, e.g. the granary (violet, food), the improved ploughs I and II (blue, food), the grain trade route (yellow, food) or the hunting camp (red, food).
- The concept says "wisdom" for knowledge.
- place: anything a worker is placed at: a building, a project (a site, a king's project, a book, an invention), a trade route (R16) or the hunting camp (R17).
- Week: one simulation step. 48 weeks per year (hardcoded); game length `game.years`.

## Weekly order
0. Tax count (R7), count weeks only
1. Production (R2), the ploughs' bonus (R15), the granaries' culture upkeep (R14), changed by happiness (R11): buildings into the stock, workers on a project (R7) into the project; a worker on a book or an invention writes into it (R12, R15)
2. Mana (R3)
3. Travel (R2): every travelling worker's travel goes down by 1
4. Manameter update (R4)
5. Eating (R8)
6. Birth (R1), drawn from the Manameter updated in step 4
7. Construction (R2): sites advance; finished buildings release their builders
8. Books finished (R12), opening a trade route (R16) or the hunting camp (R17) the books now unlock; then inventions finished (R15); then the hunting camp (R17): its arrived hunters fill the bag, a haul (drawing its luck) goes into the stock; then the king's suspicion (R18): the haul's change, an idle block's decay, the threshold (a miss)
9. Training ends (R5)
10. Tax payment (R7), due weeks only
11. Demand delivery (R7): in the deadline week; a project also in the week its target is reached, and in the week after it was refused
12. Demand made (R7), demand weeks only
13. Trade route (R16): each arrived trader, in the order placed, pays and brings food
14. Bandits (R10): threat, setting out, raid; every week from week 1
15. Spoilage (R9), at the granary's rate for food while a granary works (R14)

The player acts between weeks; changes take effect the following week. Production, mana, construction, training, the trade route, the hunting camp and whether a granary works use travel as it was when the week started, so a worker placed while the game stands at week N does nothing in week N+1 and works from week N+2. Code-level detail: the `weekly-step` skill.

## R1 Birth and start
- Every `birth.interval_weeks`, one worker is born if at least `birth.min_food_left` food is left after eating and the week wasn't short (R8).
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
- A way building (R13, the granary) produces nothing. The improved ploughs (R15) change farm workers' output.
- A way can be ordered only once it is unlocked (R13); the UI shows a locked way disabled with what it still needs.

### Builders
- An ordered building is a site, a project: it needs `build.work` work. Builders are workers the player places on it, any colour (colour has no effect), at most `build.capacity`.
- Each week, every builder on the site who has arrived (travel 0 at the start of the week) adds 1 to its progress. When the progress reaches `build.work`, the site is finished: a new building (with a new id) stands in its place, and its builders become unplaced (travelling).
- A builder leaving the site (moved or unplaced) doesn't change its progress. The gold isn't refunded.
- Builders eat and count toward taxes, but produce nothing and no mana.
- UI: each site shows its arrived builders (arrived / `build.capacity`) and progress (progress / `build.work`).

### Travel
- A worker's travel is set to `travel.weeks` whenever it is placed from unplaced (into a building, a site, a project or the guildhouse), moved directly from one building to another (once), unplaced by the player, or released as a finished trainee or builder, or from a project that ends or is refused (R7). Moving a worker that is still travelling sets it to `travel.weeks` again. To or from a trade route (R16), `way.grain_trade.travel_weeks` instead of `travel.weeks`; to or from the hunting camp (R17), `way.hunting.travel_weeks` (between the route and the camp, the larger).
- The worker takes its place at once, but while its travel is above 0 it produces nothing and no mana, isn't an arrived builder, and doesn't train. It still eats and counts toward taxes.
- An unplaced worker can't be placed while its travel is above 0.
- Newborns and starting workers have travel 0.
- UI: travelling workers are marked with their remaining travel.

## R3 Mana
- Per working worker per week: `mana.place_colour` in the place's colour and `mana.good_colour` in the colour of the home place of the place's good. A home place (farm, market, monastery, watchtower, tavern) gives both to its own colour; they add up.
- The worker's own colour and training play no part.
- Places: a building of its colour and good; a king's project (R7) as the building of its colour and good; a book (R12) as a monastery (blue, knowledge); a granary (R14) violet and food (2 violet, 1 green); the improved ploughs (R15) blue and food (2 blue, 1 green); the grain trade route (R16) yellow and food (2 yellow, 1 green); a hunter at the camp (R17) red and food (2 red, 1 green).
- Trainees, builders, unplaced and travelling workers produce no mana.

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
- Knowledge and culture demands are projects:
  - When the demand is made, a project appears among the places, with the amount as target and the colour of the good's home place.
  - The player places workers on it: any number, any colour; travel as usual. Workers on it produce and make mana exactly as in a building of that colour and good. Their output goes into the project, not the stock, and doesn't count toward happiness; output beyond the target is lost. Nothing else feeds the project, and the stock is never used for it.
  - At the end of each week: target reached at or before the deadline → delivered; the project disappears and its workers become unplaced (travelling). Not reached by the end of the deadline week → missed; the project disappears and its workers become unplaced. No partial delivery.
  - The player can refuse it at any time while it is open: the project disappears and its workers become unplaced at once; the refusal counts as a miss in the next week.
- The current demand, its amount, deadline and progress must be visible in the UI; for a project its progress and the workers on it.
- Misses: skipped or missed taxes, refused or missed demands and the king's suspicion reaching its threshold (R18) count in one shared tally. `king.misses_forgiven` misses are forgiven; the next ends the game.
- The king takes what he can: on every skipped or missed tax and every refused or missed gold or food demand, the king also takes the stock there is (gold for taxes and gold demands, food for food demands), up to the amount owed; a stock at or below 0 gives nothing. Defence demands and projects leave nothing to take: a miss only. Taking happens in the step of the payment or delivery, before spoilage.

## R8 Food
- Every worker eats `good.food.eaten_per_worker` per week.
- Leftover food carries over (stored in the tower, no limit). No stock goes below 0.
- Short week (food after production is less than everyone eats): the missing food is forgotten and the stock stops at 0; no birth (R1); log every such week (UI "short"; the bots' analysis counts them as `weeks_food_below_0`). No other effect until T65 (hunger).

## R9 Spoilage
- At the end of the week, every stock above 0 loses `good.<good>.spoilage_permille` per mille of itself, rounded down. Stocks at or below 0 don't spoil.
- Births, tax payments, demand deliveries and what the king takes use stocks before spoilage.
- Food, gold, defence, culture and knowledge are all stored. A king's project (R7) is not a stock and doesn't spoil.
- While a granary works, food spoils at `place.granary.food_spoilage_permille` instead (R14).

## R10 Bandits
Robbery only: bandits take gold, nothing else (no fights, no wounded, no mana).
- Runs every week from week 1; the grace period (R7) doesn't apply.
- Uses the gold after taxes and demands, before spoilage (step 13), and this week's defence production: what watchtowers produce this week, the tower included (travelling workers produce nothing, R2). The defence stock plays no part.
- Protected gold = defence production × `bandit.cover_weeks`.
- Pressure = gold ÷ protected gold, per mille, rounded down. Gold at or below 0 gives 0. No defence production with gold above 0: the threat jumps to `bandit.threshold` at once, so bandits set out (unless they already are on their way).
- Threat: starts at 0; each week it rises by pressure − 1000 if that is positive, otherwise it stays as it is (per mille; `bandit.threshold` and `bandit.floor_step` are whole threat points). It never falls on its own, only after a raid. It is never below the floor, and is raised to it when the floor rises: 0 in year 1 (the first two half years), then `bandit.floor_step` more at the start of each later half year (half year = 48 ÷ 2 weeks).
- Setting out: when the threat reaches `bandit.threshold` (at or above) and no bandits are on their way, they set out and raid `bandit.warning_weeks` later. In the setting-out week the threat has already changed. From the next week until the raid, it doesn't change.
- The raid, in the raid week with that week's values: pressure 1000 or less → repelled, nothing lost; otherwise they take loot = gold − protected gold. Afterwards, repelled or not, the threat drops to the floor and can rise again from the following week.
- A raid is not a miss (R7) and the king takes nothing for it.
- UI: the threat and its direction (rising or steady: its change in the last week run; falling only in a raid week) are always visible, and the protected gold next to the gold stock (the last week's defence production, as shown with the production, × `bandit.cover_weeks`). Both describe the same week as the production shown. Bandits on their way are shown with the raid week and the weeks left instead of the direction; setting out and the raid's outcome are reported when the week runs.

## R11 Happiness
- Every week from week 1: ratio = this week's culture production ÷ (population × `happiness.need_per_worker_permille`), per mille, rounded down.
  - Culture production counts only from buildings; culture produced on a project (R7) doesn't count. The culture stock plays no part.
  - The culture spent that week is subtracted from it: the granaries' upkeep (R14), as taken from the stock. The result is never below 0.
  - Population: every worker at the start of the week (placed, unplaced, builders, trainees, travelling); a newborn counts from the following week. A population of 0 is an error.
- Step from the ratio: below `happiness.level3.penalty_below_permille` −3, below `happiness.level2.penalty_below_permille` −2, below `happiness.level1.penalty_below_permille` −1; from `happiness.level3.bonus_from_permille` +3, from `happiness.level2.bonus_from_permille` +2, from `happiness.level1.bonus_from_permille` +1; otherwise 0.
- Effect: this week's food and defence production change by ± `happiness.level1.change_permille`, `happiness.level2.change_permille` or `happiness.level3.change_permille` per mille (step −2: production × (1000 − `happiness.level2.change_permille`) ÷ 1000). Applied once to each product's total, after the colour factors (R2), rounded down. Nothing else changes: gold, knowledge, culture, mana and births stay as they are.
- Grace period (R7): the step applied is 0; the ratio and the step it would have are still computed and shown.
- Everything after production uses the changed values: eating (R8) and the defence production that protects gold (R10).
- UI: next to the stocks, the step applied in the last week run and its ratio; in the grace period also the step it would have. No forecast: next week's culture production depends on the placement.

## R12 Books
- The player can start writing a book of any colour (green, yellow, blue, red, violet) at any time, at no cost; several books can be written at once. A book is a project among the places and needs `book.work` knowledge, whatever its colour.
- A book takes one worker, any colour. Travel and leaving as for sites (R2): the worker travels first, and leaving keeps the progress.
- The worker writes what he would produce in a blue building (`place.monastery.output_per_worker`, his colour's factor against blue, trained or not), × the book colour's Manameter share ÷ 200 (normal at 20%; linear, no floor, no cap), with the Manameter at the start of the week; rounded down per worker. It goes into the book, not the stock, and doesn't count toward happiness (R11); output beyond the target is lost.
- Mana: as in a blue building (R3).
- At the end of the week (step 8), a book whose progress reached `book.work` is finished: the village holds one more book of its colour, the project disappears and its worker becomes unplaced (travelling).
- A game starts with no books. Books are held for good and never used up. They unlock ways (R13).
- UI: a button per colour to start a book; each book among the places with its colour, its progress / target and its worker; the books held per colour next to the stocks.
- Export: `books_green`, `books_yellow`, `books_blue`, `books_red`, `books_violet`, the books held at the end of the week.

## R13 Ways
- A way is a place type in the catalogue with a colour and a good that are not each other's home: granary (violet, food; R14), improved plough I and II (blue, food; R15), grain trade (yellow, food; R16), hunting (red, food; R17).
- One rule for every way: it is unlocked while the village holds at least n books (R12) of its colour and at least n books of the colour of its good's home place, and has made the invention it requires, if any (granary: violet and green; plough I: blue and green; plough II: `way.plough_2.books` blue and green and plough I invented; grain trade: yellow and green; hunting: red and green). n is 1 unless the way has a `way.<type>.books` key (today only plough II). Books are not used up and inventions are kept, so a way once unlocked stays unlocked. No fixed week.
- A locked way can't be ordered (a building) or started (an invention); a locked trade route or hunting camp isn't a place yet (R16, R17).
- UI: a locked way is shown disabled with a lock naming what is missing: a swatch with the number of books still needed for each colour short of books, and the invention still needed; unlocked, it is ordered or started like the others.

## R14 Granary
- Violet's way to food, a building: ordered and built like any building (`build.cost_gold`, builders, `build.work`); capacity `place.granary.capacity`.
- A granary works in a week while a keeper works there (placed, travel 0 at the start of the week).
- The keeper produces nothing. Mana as in R3: 2 violet + 1 green with the current values.
- While at least one granary works, food spoils at `place.granary.food_spoilage_permille` instead of `good.food.spoilage_permille` (R9). More granaries don't lower it further.
- Upkeep: each working granary costs `place.granary.culture_upkeep` culture a week, taken from the culture stock after the week's production (step 1), never below 0. What is taken is culture spent: it is subtracted from the culture that counts for happiness (R11).
- UI: whether a granary worked in the last week, the food spoilage then and the upkeep taken.

## R15 Improved plough I and II
- Blue's ways to food, inventions. Plough I unlocks with a blue and a green book (R13); plough II with `way.plough_2.books` blue and as many green books, and plough I invented.
- Once unlocked, the player starts one like a book, at no cost: a project among the places that needs `way.plough.work` (plough I) or `way.plough_2.work` (plough II) knowledge. One open project per invention; each can be invented only once.
- Up to `way.plough.capacity` or `way.plough_2.capacity` workers, any colour. Travel and leaving as for books: leaving keeps the progress.
- Each worker writes what he would produce in a blue building (as for books, R12), × the experience factor of green, the colour of food's home place (its Manameter share ÷ 200, with the Manameter at the start of the week); rounded down per worker. Output beyond the target is lost; it doesn't count toward happiness.
- Mana as in R3: 2 blue + 1 green with the current values.
- At the end of the week (step 8), once the progress reaches the target, the plough is invented: the project disappears and its workers become unplaced (travelling).
- From the next week for the rest of the game, every farm worker's output × (1000 + the bonus of each plough invented: `way.plough.bonus_permille`, `way.plough_2.bonus_permille`) ÷ 1000, rounded down per worker, after the colour factors (R2) and before happiness (R11). With both at the current values: × 1250 ÷ 1000.
- UI: an inventions overview in the village column from week 0, listing every invention with its state: invented (with its effect, e.g. "farm output +12.5%"), being invented (progress / target, workers / capacity), can be started (a start button) or locked (what is missing, as in R13). Once anything is invented, the invented ones with their effect in the state column; the farm shows the total bonus ("+25% (plough I + II)"). Each invention's project is among the places with its progress and workers.

## R16 Grain trade route
- Yellow's way to food, a trade route: a kind of place that is neither a building nor a project. Unlocked as in R13 (a yellow and a green book).
- Once unlocked, the route opens as a place in the village (in step 8 of the week the last book it needs is finished): one route, nothing to build or pay. Until then the UI shows it locked, with the books it needs.
- Placing and leaving as for a building (R2): placed, moved or unplaced by the player, any colour, trained or not, up to `way.grain_trade.capacity` traders. Travel to and from the route is `way.grain_trade.travel_weeks` instead of `travel.weeks`: when a worker is placed on it and when he leaves it (unplaced, or moved to another place). A trader stays until the player moves him.
- A trader eats and counts toward taxes; he produces nothing in step 1 and doesn't defend (R10). Once arrived he makes mana as at a yellow place for food (R3: 2 yellow + 1 green with the current values); nothing while travelling.
- Weekly trade, step 13: for each trader who has arrived (travel 0 at the start of the week, as for production), in the order they were placed on the route (one who leaves and comes back goes to the end): price = `way.grain_trade.gold_per_week` × 1000 ÷ his colour factor against yellow, untrained or trained (R2), rounded down. If the gold stock covers the price, he pays it and `way.grain_trade.food_per_week` food goes into the stock; otherwise he pays and brings nothing this week, and stays. A later trader with a lower price may still pay.
- Taxes and demands are settled before (steps 10–11), so a route never causes a tax or demand miss; the bandits (step 14) see the gold after the trade; the food spoils that week (step 15). The trade food is bought, not produced: happiness (R11) doesn't change it.
- UI: the route among the places with its traders and capacity, the gold paid and food brought last week, and the selected worker's weekly price; locked as in R13 until it opens.

## R17 Hunting camp
- Red's way to food, a hunting camp: a kind of place that is neither a building, a project nor a trade route. Unlocked as in R13 (a red and a green book).
- Once unlocked, the camp opens as a place in the village (in step 8 of the week the last book it needs is finished), like the trade route (R16): one camp, nothing to build or pay, open to the end of the game. Until then the UI shows it locked, with the books it needs.
- Placing and leaving as for a building (R2): any colour, trained or not, up to `way.hunting.max_party` hunters. Travel to and from the camp is `way.hunting.travel_weeks` instead of `travel.weeks`, both ways. A hunter stays until the player moves him.
- A hunter eats and counts toward taxes; he produces nothing in step 1 and doesn't defend (R10). Once arrived he makes mana as at a red place for food (R3: 2 red + 1 green with the current values); nothing while travelling.
- Every week (step 8), each hunter who has arrived (travel 0 at the start of the week, as for production) adds `way.hunting.food_per_week` × his colour factor against red, untrained or trained (R2), to the camp's bag; the bag is not in the stock. A week with at least one arrived hunter counts.
- Haul: at every `way.hunting.haul_weeks`-th counted week, in that week's step 8: one luck draw, out of 10, from the game's seeded random (the same as births), by the number n of hunters arrived that week: the first `way.hunting.party<n>.low` of the 10 give low, the next `way.hunting.party<n>.mid` mid, the rest high; low, mid and high are × `way.hunting.luck_low_permille`, `luck_mid_permille`, `luck_high_permille` ÷ 1000. Bag × the luck factor ÷ 1000, rounded down, goes into the food stock; the bag and the count start again. The food is not eaten that week, counts for that week's taxes and demands, and spoils that week (R9).
- When the player takes the last worker off the camp (arrived or still travelling), the bag and the count are lost. A week with hunters on the camp but none arrived keeps them and doesn't count.
- Draw order: at most one draw a week, only in a haul week, in step 8 after the week's birth draw (step 6). The same seed and the same placements replay the same luck and births; a game without hunting draws as before; a haul changes the births after it compared with not hunting.
- A bag not hauled when the game ends brings nothing.
- UI: the camp among the places with its hunters and capacity, its bag and the hunting weeks to the next haul; locked as in R13 until it opens. A haul is reported with the hunters, the luck, the food and the suspicion's change.

## R18 The king's suspicion
- Starts at 0, never below 0. Settled in step 8, after the camp's week.
- At each haul (R17) by 2 or more hunters: + `king.suspicion.low`, `.mid` or `.high`, by the luck drawn. At each haul by 1 hunter: − `king.suspicion.decay`.
- At the end of every block of `way.hunting.haul_weeks` game weeks, counted from week 1 (weeks 1 to 6, 7 to 12, …), in which no hunter had arrived in the camp in any week: − `king.suspicion.decay`. The weeks before the camp opens count as idle.
- Threshold: whenever the suspicion is `king.suspicion.threshold` or more, it counts as one miss in the shared tally (R7: the forgiven misses first, the next ends the game), in that week; then it is set to half its value, rounded down. The king takes nothing for it.
- UI: the suspicion against the threshold next to the stocks, with its change at the last haul and that haul's week; a threshold miss is reported.

## Forecasts
UI only: forecasts change nothing in the game. Each one repeats the change of the last week run (its end minus its start) unchanged for every week ahead. The change is raw: taxes paid, demands delivered, what the king took and robbery in that week count in it; gold spent on buildings between weeks doesn't. No forecasts in week 0 (no week before it); the next tax's amount and week are shown from week 0. The bots use the same forecasts (food balance, next tax).
- Food: the stock's change per week, rising, falling or steady; if falling, the week it runs short (R8; already if the last week was). The trade route's food and gold (R16) are part of the change.
- Gold: the stock's change per week (spoilage included), rising, falling or steady.
- Next tax: the amount fixed at the count, or before the count `king.tax.per_worker` × the current workers (shown as "at least": births until the count raise it); its due week; the gold expected then (gold now + change × weeks until the due week, that week included) and the shortfall, if any. None after the game's last payment.
- Open demand: the amount, the deadline and the amount expected by the deadline, deadline week included: from the stock, the stock + its change × weeks left; for a project, progress + its gain in the last week × weeks left, at most the target. Met or short. No forecast for a project in the week it was made, or once refused.
- Bandits: the threat's direction (as in R10) and the week it reaches `bandit.threshold` at the last week's pressure (rising by pressure − 1000 a week; next week if the pressure was unbounded; never at 1000 or less). The rising floor is left out. Not shown while bandits are on their way.

## Export
- Weekly CSV, one row per week, week 0 (the start) first. Amounts of goods and `bandit_threat` in thousandths; mana in whole points; Manameter shares per mille; counts and weeks as plain numbers. Product columns in the pentagon order of their buildings, colour columns in pentagon order.
- Columns: week; production_food, production_gold, production_knowledge, production_defence, production_culture (what buildings produced; output on a project is not included); mana_<colour>; manameter_<colour>; food_left (after spoilage); newborn (the newborn's colour, empty if none); trained (colours of the workers who finished training that week); builders (arrived, at the end of the week); travelling (workers with travel above 0, at the end of the week); gold (after spoilage); tax_due (filled in the count week); tax (paid, skipped or missed, in the due week); demand_product and demand_amount (in the week the demand is made); demand_outcome (delivered, refused or missed, in the deadline week; for a project delivered early, in the week its target is reached; for a refused project, in the week after the refusal); demand_progress (a project's total at the end of every week it is open, the week it is made and the week it is delivered or missed included; empty for food, gold and defence demands and when no project is open); king_took_gold and king_took_food (what the king took that week on a skipped or missed tax and a refused or missed demand; 0 otherwise); spoiled_food, spoiled_gold, spoiled_knowledge, spoiled_defence, spoiled_culture; gold_spent_buildings (gold paid for buildings ordered while the game stood at that week; not yet taken from that row's gold); bandit_pressure (per mille; `inf` without defence production and with gold; empty in week 0); bandit_threat (end of the week); bandits_weeks_to_raid (weeks left at the end of the week; empty if no bandits are on their way, also in the raid week); gold_robbed (what the bandits took that week, before spoilage; 0 otherwise); happiness_ratio (per mille; empty in week 0); happiness_step (the step applied, −3 to +3, a plain number; 0 in the grace period; empty in week 0); game_over; books_green, books_yellow, books_blue, books_red, books_violet (books held at the end of the week, R12); plough_level (how many ploughs are invented at the end of the week: 0, 1 for plough I, 2 for plough I and II, R15); granary_working (true or false: a granary worked that week, R14); culture_upkeep (the culture taken from the stock for the granaries that week, R14); food_from_trade (the food the trade route brought that week, R16); food_from_hunting (the hunting camp's haul that week, R17); suspicion (the king's suspicion at the end of the week, after any threshold halving, R18); gold_to_trade (the gold paid to the trade route that week, R16); traders (the workers on the trade route in that week's trade step, arrived or not, R16); hunters (the workers on the hunting camp in that week's step 8, arrived or not, R17); suspicion_miss (true in the week the suspicion reached its threshold and counted as a miss, R18).
