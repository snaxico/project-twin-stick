# Start Of Day

Read this first to restore project context quickly, then read `current-state.md` and the latest file in `history/`.

## Project Snapshot

- Same-screen local co-op twin-stick roguelite prototype in Godot `4.6.2`.
- Current target is still the first-playable bar from Patch 7:
  - one readable, stable `10–15` minute run
  - understandable without explanation
  - shared co-op decisions and shared failure
- The codebase already includes extra Patch 8 and Patch 9 systems:
  - `1–4` players
  - persistent profile/meta unlocks
  - more layouts/modifiers
  - placeholder juice and readability passes

## Locked Rules

- Same-screen camera only.
- Local co-op only.
- Shared loot and shared economy.
- No split-screen.
- No class system.
- Godot `4.6.2` stable only.
- GDScript gameplay code only.
- JSON-first data definitions.
- Placeholder visuals stay Godot-native for now.

## Current Combat Identity

- Primary family:
  - `Rifle`
  - `Scatter`
  - `Slug`
- Secondary family is now split cleanly:
  - thrown explosives: `Grenade`, `Cluster Grenade`, `Siege Grenade`
  - proximity explosives: `Mine`, `Shrapnel Mine`, `Heavy Mine`
- Grenades use aimed throw behavior.
- Mines place instantly on secondary press and detonate on proximity fuse.
- Mine proximity radius was increased by `100%` from the original mine implementation.

## Current Priorities

- Preserve the approved core loop.
- Favor tuning and readability over adding new systems.
- Keep enemy ranged pressure under control.
- Keep projectile, aim-line, and arena contrast readable.
- Keep grenade and mine roles distinct instead of blending them back together.
- Validate `3–4` player behavior and full-run pacing later; do not expand scope casually.

## Important Runtime Ownership

- `RunState.gd`: cross-room run state, loadouts, gold, progression.
- `ProfileState.gd`: persistent profile, meta gold, unlock ownership.
- `CoopManager.gd`: combat-room orchestration and spawning.
- `RunFlow.gd`: node-map and room transition flow.
- `data/items.json`: shared reward/shop item definitions.
- `data/modifiers.json`: room modifier tuning.

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
- `current-state.md` is the compact source of truth for active runtime state.
- `history/` records what changed, why, and what remains open.
- `docs/process/` stays the source of truth for scope, roadmap, architecture, and workflow rules.
- Write for continuation, not presentation.
- Keep entries short, factual, and useful for the next session.
- If implementation changes scope or architecture, update the relevant process doc in the same slice.
- After meaningful work:
  - update `current-state.md`
  - add or append the history entry
  - update any affected process doc if the source of truth changed

## Session Read Order

- Before changing code, reread:
  - `start-of-day.md`
  - `current-state.md`
  - latest file in `docs/development/history/`
  - any process doc that the task touches
