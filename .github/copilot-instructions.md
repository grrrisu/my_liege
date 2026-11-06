# My Liege prototype: instructions

Throwaway test prototype for a single-player strategy game. Only the rules engine may be reused; the UI is disposable.
The rules to implement are in `rules/rules.md`. Read it only when a task touches game rules.

## Stack
- Elixir, Phoenix LiveView. Engine: pure functions, no LiveView/process/DB code inside. ExUnit, one describe block per rule (R1, R2, …).
- Random numbers always seeded; store the seed with every run.

## Numbers
- All game values come from `priv/balance_inputs.csv` (`key,value`), read by key at compile time with `@external_resource`. The designer exports it; never edit it.
- Fail at compile time on a missing key or a value that isn't a whole number. No defaults, no rounding.
- Per mille (800 = 80%): keys starting with `factor_`, `manameter_start_`, `spoilage_rate_`, and `manameter_points_per_week`, `demand_population_share`, `training_threshold`, `plough_threshold_green`, `plough_bonus`.
- Only exception: 48 weeks per year, hardcoded.
- Tests may build their own configuration with explicit values.

## Hard rules
1. Never invent a rule or a number. If a rule is missing, open or ambiguous, or a value has no key, stop and ask the designer. Give options; don't pick one. No placeholder values.
2. No game value outside the configuration module.
3. Only what `rules/rules.md` lists. No map, trade, raids, combat, culture effects, scoring or graphics.
4. Bare UI: coloured squares, buttons, numbers.
5. Ask before adding a dependency or changing the export or decision-log format.
6. Never use AutoRun as a check: not to verify a change, not in `mix precommit` beyond AutoRun's own tests, not with the CSV values. The tests in `auto_run_test.exs` test the AutoRun module itself with small fixture configs and stay. If an AutoRun would help, ask the designer and say which pattern, how many seeds and how many weeks. Other tests use small explicit runs (`EngineFixtures.run_weeks/2`).

## Engine structure
- `Game` runs the week as a pipeline of `SimSteps.*` (when); each step calls `Rules.*` (what).
- Rules are pure functions on plain data and `%Config{}`; they never reference `Game`,
  `WeeklyReport` or `SimSteps`.
- Refactors must not change `test/fixtures/regression_seed_42.csv`.
- Read the `engine-architecture` skill before adding, moving or renaming engine modules.

## When a feature is agreed
At the end of every task that changes or adds a rule, a key or the export:
1. Update `rules/rules.md`: the rule in its section, named by its CSV keys (no values), and one changelog line.
2. List any new CSV keys with the values the designer gave, so the designer can add them to the balance model.
Keep `rules/rules.md` short: current rules only, no history or reasoning.

## Git and review
- **Never work on `main`.** All code goes on a feature branch.
- **One branch per feature or rule change**, created from `main` and named after it, e.g. `t43-building-costs`.
- **Agree the rule in the chat first;** create the branch only when nothing is open. Create it only from a clean working tree; if there are uncommitted changes, ask.
- **Never commit, push, pull or merge.** No `git commit`, `git push`, `git pull`, `git merge`, `git rebase` or `git stash`. Leave all changes uncommitted on the branch; the designer commits, pushes and merges.
- **`rules/rules.md` is updated together with the rule it describes.**
- **Run `mix precommit` before handing over**; it must pass.
- **Hand-over when the work is ready to merge:** stop and show a short summary of what changed and why. Don't print the diff; the designer reviews it in the editor.
- **Pull request description:** with the hand-over, give a pull request description as one fenced markdown block, ready to paste: a title line, what changed and why, then the full checklist from `.github/pull_request_template.md`. Tick the items that are done, mark items that don't apply "n/a", and complete open phrases such as "because …".
- **After the designer has pulled `main`**, delete local branches already merged into it with `git branch -d` without asking. Never use `git branch -D`.
