# My Liege — prototype: instructions for Copilot

## What this project is

A throwaway test prototype for *My Liege*, a single-player real-time strategy game in development. The prototype exists to answer four design questions (H1–H4 in the Prototype Plan), not to become the game. Read the Prototype Plan before writing code; it is the brief.

Only the **rules engine** is meant to be reused later. The interface is disposable.

## Stack

- Elixir, Phoenix LiveView.
- Rules engine: a plain Elixir module (or small set of modules) of pure functions. No LiveView, Phoenix, process or database code inside the engine.
- Tests: ExUnit, one test (or describe block) per rule R1–R8 in the plan.
- Random numbers: always seeded. Store the seed with every run so it can be replayed exactly.

## Hard rules

1. **Never invent numbers or rules.** Every number comes from the single configuration module. If a value or rule is marked "open" in the plan (R4, R7, R8 and the open parts of R1, R2, R5, R6), stop and ask the designer. Do not choose a default silently.
2. **Never hard-code a game value** outside the configuration module.
3. **Stay inside the scope** listed in the plan. No map, trade, raids, combat, culture, scoring or graphics, even if they seem easy to add.
4. **Engine first.** Build and test the rules engine before any interface. Wait for the designer to confirm the tests match the concept before starting the interface.
5. **Keep the interface bare:** coloured squares, buttons, numbers.

## Ask before you

- implement any rule marked open, or interpret a rule that can be read more than one way;
- change a formula or table from the plan, even to fix what looks like an error;
- add a dependency;
- add a feature, mode or screen not listed in the plan;
- change the format of the decision log or the run export.

When asking, quote the line of the plan in question and give the options you see, without picking one.

## Git and review

- **Never work or commit on `main`.** All code goes on a feature branch.
- **One branch per rule**, created from `main` and named after the rule, e.g. `r3-mana-per-worker`. Rules are built top to bottom, starting with R1.
- **A rule's open parts are decided by the designer before its branch is created.**
- **Commits:** the rule's implementation is one commit. Each round of designer feedback and each refactor gets its own commit. Work that is not a rule (configuration, interface, export) goes in its own commits on the current branch.
- **After all rules are implemented**, ask the designer for the names of new branches.
- **Run `mix precommit` before every commit**; it must pass.
- **Review before every commit:** stop, show a short summary and the diff, and wait for the designer's OK.
- **The designer pushes, pulls and merges.** Never run `git push` or `git pull`.
- **After the designer has pulled `main`**, delete local branches already merged into it without asking. Use `git branch -d`; PRs are rebased, so if it refuses, use `git branch -D` only when `git diff main <branch>` is empty.

## Domain terms

- **Five paths and colours:** Growth (green), Wisdom (blue), Strength (red), Wealth (yellow), Culture (violet).
- **Pentagon order:** Growth – Wisdom – Strength – Wealth – Culture – back to Growth. Neighbours are allies; non-neighbours are opponents.
- **Manameter:** the society's mana shares per colour, always summing to 100%.
- **Worker:** has a fixed colour from birth and is either untrained or trained.
- **Week:** one simulation step. Clock mode (later) runs one week per 30 seconds.

## Outputs the tests depend on

- Play mode logs every placement: week, worker colour, trained or not, building, on- or off-colour, and the player's rating (easy, some thought, torn).
- Auto-run mode records Manameter shares per week for each placement pattern and seed.
- Both export as CSV matching the report fields in the plan.
