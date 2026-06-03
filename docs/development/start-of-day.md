# Start Of Day

Read this first to restore project context quickly, then read `current-state.md` and the latest file in `history/`.

## Working Branch

- Active gameplay work happens on `v3/main`.
- Treat this branch as the current game.
- `v3/main` is now also the GitHub default branch / mainline.
- Treat the repo as the current game only.
- Old v1 branch/archive content was intentionally removed and should not shape live runtime decisions.

## Source Of Truth

- `docs/development/current-state.md` is the compact source of truth for the active runtime on `v3/main`.
- `docs/design/roadmap.md` is the source of truth for locked feature design and open design questions.
- `history/` records what changed, why, and what remains open.
- If `start-of-day.md` and `current-state.md` ever disagree, treat `current-state.md` as correct and update this file.

## Project Snapshot

- Same-screen local co-op twin-stick roguelite prototype in Godot `4.6.2`.
- Current target is the active `1-2` player V3 runtime.
- The live runtime now follows the `Feature Roadmap V3` redesign captured in `current-state.md`.
- Current stable runtime includes the round-6 performance/gameplay patch on top of the round-4 + round-5 baseline.
- Current focus is manual round-6 validation, especially Scanline, Fire Bullets correctness, enemy readability, and the boss add-wave performance gate.

## Live Runtime Summary

- Player count target:
  - `1-2` players only
  - `3-4` players deferred
- Current run modes:
  - `Structured`
  - `Endless`
- Current live loadout structure:
  - auto-firing `Rifle`
  - `2` equal ability slots per player
- Current main-menu settings:
  - keybinding editor
  - controller binding editor for active `1-2P` gameplay actions
  - binding persistence in `user://input_bindings.cfg`
- Current in-run pause menu:
  - build summary only
  - no in-run Settings panel
  - aim mode remains default `auto`
- Current live ability roster:
  - `Shockwave`
  - `Dash`
  - `Overcharge`
  - `Blink`
  - `Shield`
  - `Decoy`
  - `Turret`
  - `Minefield`
  - `Orbit`
- Current live enemies:
  - `Chaser`
  - `Charger`
  - `Spitter`
  - `Splitter`
  - `Splitter Mini`
  - `Bomber`
- Current live elite mini-bosses:
  - `Elite Charger`
  - `Elite Spitter`
  - `Elite Support`
- Current live bosses:
  - `Warden`
  - `Hydra`
  - `Hive`
  - `Pulsar`
- Current round-6 state:
  - `Mine Field` display is now `Scanline` while keeping id `mine_field`
  - `Duration` affects sustained abilities only, not `Dash` / `Blink`
  - Fire Bullets pools use distance checks instead of `Area2D` overlap bodies
  - enemy visuals use one polygon draw per enemy instead of shadow + outline + visual
  - heavy boss add-waves are debug dry-run only via `debug_boss_add_waves`
  - live playtest feedback reports a massive performance improvement
- Current live progression loop:
  - enemy kills feed one shared XP bar
  - level-ups bank room-end pick rounds
  - elite rooms grant one additional free pick round
  - health resets at the start of every room
  - gold / shops / rest-room economy are removed from the live runtime
- Current live structured flow:
  - Act 1 combat rows
  - optional elites
  - mid-boss
  - Act 2 combat rows
  - optional elites
  - final boss
- Current live endless flow:
  - sequential combat rooms
  - no map
  - boss every `5` rooms

## Current Priorities

- Preserve the approved V3 core loop.
- Favor validation, tuning, and readability over adding more systems.
- Validate the current round-6 local build in live play:
  - shared XP and room-end pick cadence
  - structured map flow pacing
  - endless scaling past room `20`
  - elite reward value, spawn distance, Act 2 scaling, add waves, and new pressure patterns
  - boss escalation, phase transitions, adds, heavy-attack feel, and round-5 boss-specific mechanics
  - modifier readability
  - projectile pooling / AI time-slicing / boss entity-load performance at `100-150+` enemies/projectiles
  - real boss-room stress gate with `debug_boss_add_waves` before promoting heavy boss add-waves
  - controller usability in ability select, map UI, pause menu, and remapped bindings
- Tune:
  - rifle cadence (`~5 shots/sec` in the current build)
  - room duration / spawn interval pressure
  - ability feel across the `9`-ability roster
  - Overcharge after round-5 nerf (`22s`, `1.3x` fire-rate, no extra projectiles)
  - Blink movement-direction / arrival detonation feel
  - Fire Bullets impact-pool balance and team-correct damage behavior
  - Fire Floor `280px` / `7` zone pressure
  - boss pressure, especially Warden reach, Hydra homing/sweep, Hive shield/burrow, and Pulsar EMP/beam
  - Pulsar reactive teleport feel
- Keep scope tight:
  - no casual re-expansion toward removed gold/shop/meta directions
  - no casual `3-4` player work

## Current Design Context

- The active branch runtime is the V3 game and should not be read as "v2 plus patches."
- Roadmap work should assume:
  - the working branch is `v3/main`
  - the live game is the runtime described in `current-state.md`
- `docs/design/roadmap.md` currently contains archived V2 material only.
- Current roadmap discussion areas are validation and post-V3 tuning:
  - spawn pacing
  - elite difficulty / reward feel
  - modifier readability
  - boss feel
  - controller usability

## Important Runtime Ownership

- `scripts/game/RunState.gd`:
  - structured + endless run generation
  - shared XP and banked pick progression
  - boss / modifier / side-objective assignment
  - per-player inventory state
  - `debug_boss_add_waves` pass-through for single-room debug boss stress tests
- `scripts/game/CoopManager.gd`:
  - room runtime
  - continuous time-based spawning
  - pooled projectile runtime
  - ability dispatch
  - reward sequencing
  - boss helper attacks
  - elite add waves
  - debug-only boss add-wave dry-run budget
  - Pulsar EMP / beam helpers
  - modifier / side-objective orchestration
- `scripts/player/Player.gd`:
  - movement
  - auto-fire
  - generic aim mode support; current runtime defaults to auto-target
  - generic ability-slot runtime
  - additive ability lockout from Pulsar EMP
  - ability visuals / local state
- `scripts/player/AutoTarget.gd`:
  - automatic target selection
- `scripts/game/MutationSystem.gd`:
  - live mutation compilation
  - act-weighted rare rolls
  - elite `force_rare` support
- `scripts/weapons/Projectile.gd`:
  - live projectile behavior
  - rare effect delivery
  - pooled activation/deactivation
- `scripts/weapons/FireTrailZone.gd`:
  - Fire Bullets impact pools
  - team-dependent distance-check damage
- `scripts/ui/RunFlow.gd`:
  - structured map flow
  - endless room chaining
  - resolution screens
- `scripts/ui/Bootstrap.gd`:
  - player setup
  - run-mode / ability selection
  - main-menu Settings and input remapping
  - run launch

## Round-4 + Round-5 Build Notes

- Round-4 and round-5 code are the previous stable baseline on `v3/main`.
- Round-6 is now the current stable baseline for future work.
- Headless parse passed after implementation, Hive safeguard cleanup, and unused-parameter warning cleanup.
- `docs/development/playtest-round-4-plan.md` is the historical round-4 plan that was implemented.
- `docs/development/playtest-round-5-plan.md` is the historical round-5 plan that was implemented.
- `docs/development/playtest-round-5-validation.md` is the active manual validation checklist for the combined build.
- Known follow-up after playtest:
  - decide whether objective-panel letter icons (`H` / `K` / `C`) need an IconFactory/drawn-glyph polish pass
  - validate whether Pulsar beam line-of-sight needs a wall/raycast check
  - validate Hive shield / boss add pressure so boss fights do not become slogs

## Current Round-6 Build Notes

- `docs/development/playtest-round-6-plan.md` is the round-6 implementation plan.
- `docs/development/playtest-round-6-validation.md` is the active manual validation checklist for this patch.
- Treat the round-6 patch as the current stable branch state for future work.
- Heavy boss add-waves are implemented as a dry-run debug path only and are not shipped in normal runs.
- Live playtest feedback after the patch reported a massive performance improvement.
- Non-headless profiling harness after A2/B1 reported:
  - `50+50`: `1174.6 FPS`, `154` draw calls
  - `100+100`: `461.3 FPS`, `316` draw calls
  - `150+150`: `191.9 FPS`, `487` draw calls
  - `200+200`: `73.8 FPS`, `651` draw calls
- Headless harness output has `0` draw calls and should not be used for render profiling.
- Warning cleanup after implementation removed Godot local-name conflicts in `FireTrailZone.gd` and `MineFieldModifier.gd`.

## Validation Reminder

- Headless validation executable:
  - `D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`
- Standard parse check:

```powershell
& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit
```

## Development Guidelines

- Build one vertical slice at a time.
- Prefer the smallest testable version of a system.
- Expand only after the current slice is runnable and documented.
- Give AI one bounded task at a time.
- Do not modify multiple untested systems in one pass unless the dependency chain requires it and the result is validated together.
- Review generated code before treating it as accepted.
- Record important AI-assisted design or architecture changes in docs.
- Commit only after a patch or sub-feature is working.
- Never treat a broken intermediate state as done.

## Documentation Guidelines

- `start-of-day.md` is the fast refresher.
- `current-state.md` is the runtime source of truth for the live `v3/main` runtime.
- `history/` records what changed, why, and what remains open.
- `docs/design/roadmap.md` currently serves as archived V2 reference unless/until a new V3 roadmap pass is written.
- `docs/process/` stays the source of truth for scope, roadmap, architecture, and workflow rules.
- Write for continuation, not presentation.
- Keep entries short, factual, and useful for the next session.
- After meaningful work:
  - update `current-state.md`
  - add or append the history entry
  - update any affected process doc if the source of truth changed

## Session Read Order

- Before changing code, reread:
  - `start-of-day.md`
  - `current-state.md`
  - latest file in `docs/development/history/`
  - `docs/design/roadmap.md` if the task touches mutations, encounters, side objectives, buffs, or economy
  - any process doc that the task touches
