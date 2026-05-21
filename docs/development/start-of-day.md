# Start Of Day

Read this first to restore project context quickly, then read `current-state.md` and the latest file in `history/`.

## Working Branch

- Active gameplay work happens on `v2/core-refactor`.
- Treat this branch as the current game.
- `v2/core-refactor` is now also the GitHub default branch / mainline.
- Treat the repo as the current game only.
- Old v1 branch/archive content was intentionally removed and should not shape live runtime decisions.

## Source Of Truth

- `docs/development/current-state.md` is the compact source of truth for the active runtime on `v2/core-refactor`.
- `docs/design/roadmap.md` is the source of truth for locked feature design and open design questions.
- `history/` records what changed, why, and what remains open.
- If `start-of-day.md` and `current-state.md` ever disagree, treat `current-state.md` as correct and update this file.

## Project Snapshot

- Same-screen local co-op twin-stick roguelite prototype in Godot `4.6.2`.
- Current target is the active `1-2` player branch runtime.
- The live runtime currently uses the later auto-fire / shockwave / dash combat direction described by the newer design docs.
- Current focus is validation, tuning, and roadmap design clarity.

## Live Runtime Summary

- Player count target:
  - `1-2` players only
  - `3-4` players deferred
- Current live loadout:
  - auto-firing `Rifle`
  - `Shockwave`
  - `Dash`
- Current live enemies:
  - `Chaser`
  - `Charger`
  - `Spitter`
  - `Boss`
- Current live room objective:
  - `survive`
- Current live map flow:
  - `combat`
  - `elite`
  - `rest`
  - `shop`
  - `boss`
- Current live economy loop:
  - enemies drop gold pickups
  - gold is shared on collection and copied into each player's wallet
  - room-end mutation picks cost gold
  - shop rooms sell mutations, healing, and rerolls

## Current Priorities

- Preserve the approved v2 branch core loop.
- Favor validation, tuning, and readability over adding more systems.
- Validate the full encounter restructure in live play:
  - combat / elite / rest / shop / boss flow
  - elite difficulty and payout
  - gold pacing across a full run
  - shop usability
  - mutation pricing feel at `1P` and `2P`
- Tune:
  - rifle cadence
  - shockwave feel
  - dash usefulness
  - room pressure
- Keep scope tight:
  - no casual re-expansion toward discarded directions
  - no casual `3-4` player work

## Current Design Context

- The active branch runtime is ahead of the old v2 refactor baseline and should not be read as "v1 plus patches."
- Roadmap work should assume:
  - the working branch is `v2/core-refactor`
  - the live game is the runtime described in `current-state.md`
- Current roadmap discussion areas are the post-economy follow-ups:
  - modifier / economy pacing
  - elite difficulty and reward feel
  - hold-zone / buff readability
  - boss redesign priorities

## Important Runtime Ownership

- `scripts/game/RunState.gd`:
  - node-map progression
  - per-player health persistence
  - per-player wallets
  - per-player inventory state
- `scripts/game/CoopManager.gd`:
  - room runtime
  - spawning
  - gold pickup payout flow
  - mutation pick handoff
  - shop flow
  - revive / fail / clear handling
- `scripts/player/Player.gd`:
  - movement
  - auto-fire
  - shockwave cooldown ownership
  - dash runtime
- `scripts/player/AutoTarget.gd`:
  - automatic target selection
- `scripts/game/MutationSystem.gd`:
  - live mutation compilation
- `scripts/weapons/Projectile.gd`:
  - live projectile behavior
- `scripts/pickups/GoldPickup.gd`:
  - live room-currency pickup path
- `scripts/ui/RunFlow.gd`:
  - room transition and map flow UI
- `scripts/ui/Bootstrap.gd`:
  - player setup
  - encounter builder
  - run launch

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
- `current-state.md` is the runtime source of truth for the active v2 branch.
- `history/` records what changed, why, and what remains open.
- `docs/design/roadmap.md` is the feature roadmap.
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
