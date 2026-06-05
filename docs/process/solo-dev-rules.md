# Solo Dev Rules

## Workspace & Git

- **Work in `D:\GameDev\Project_Twin_stick` on `v3/main`** (the mainline / GitHub default). Treat
  this repo as the current game.
- **No new git worktrees.** Work in the main checkout. (Stale agent worktrees under
  `.claude/worktrees/` should be removed, not added to.)
- **Keep everything on `D:`.** `C:` is a small SSD — do not write project or tooling output to `C:`.
- Git is required. **Commit only after a patch or sub-feature works** and validation passes; never
  commit a broken intermediate state as if it passed. **Don't push unless asked.**
- End commit messages with the `Co-Authored-By` trailer.

## Working Model

- Build one vertical slice at a time; prefer the smallest testable version of a system.
- Expand only after the current slice is runnable and documented.
- Give AI one bounded task at a time; don't modify multiple untested systems in one pass unless the
  dependency chain requires it and the result is validated together.
- Review generated code before treating it as accepted.

## Round Workflow

The project iterates in numbered playtest rounds:
1. Playtest → collect findings.
2. Design the patch collaboratively; capture it as a single self-contained **Codex build spec**
   in `docs/development/playtest-round-N-plan.md` (ordered slices + exact values + acceptance).
3. Implement (Codex or in-session), parse-checking each slice.
4. Validate, then commit on `v3/main`.
5. After it ships, **archive** the round plan to `docs/archive/` and record it in `history/`.

## Terminology (player-facing + docs)

- **Upgrade** = anything picked on the Reward screen. `Upgrade = Weapon + (Effect + Attribute + Ability)`.
- Categories: **Weapon** (the 5 guns) · **Effect** (on-hit riders) · **Attribute** (stat boosts) ·
  **Ability** (ability mods; a rare one is a **Signature**).
- **"Mutation" is a code-only word** (the storage for Effect/Attribute/Ability) — never used in
  design docs or player-facing UI. Full glossary lives in the round-9 plan.

## Validation

- Headless parse check after changes:
  `& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit`

## Performance Testing

- Use the **automated Perf Runner** (`scripts/dev/PerfRunner.gd`, dev autoload) for perf tests —
  it runs unattended and prints a CSV:
  `Godot…console.exe --path <project> -- --profile=<scenario> [--players=N] [--build=heavy]`
  Scenarios: `boss:<id>`, `room:<type>` (real rooms), `entity_ramp`.
- **Known bottleneck:** raw entity count (~200 enemies+projectiles → ~60 FPS), not any one boss.
  The MultiMesh/caps fix is parked for a dedicated perf round.

## Documentation Rule

- At start of work read `docs/development/start-of-day.md`, `current-state.md`, and the latest
  `history/` entry.
- After meaningful work: update `current-state.md`, append a `history/` entry, and update any
  affected process doc in the same slice.
- Shipped round plans/validations live in `docs/archive/`; `history/` is the canonical change log.

## Definition Of Done

Work is done only when:
- the intended behavior exists and matches current scope,
- the result is understandable,
- the important docs are updated,
- the next step can be picked up without guessing.
