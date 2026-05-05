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
- Enemy silhouettes are now intentionally separated:
  - `Chaser`: small red dart
  - `Spitter`: medium magenta hex
  - `Charger`: large brown wedge
  - `Boss`: oversized crimson crown
- Grenades use aimed throw behavior.
- Mines place instantly on secondary press and detonate on proximity fuse.
- Mine proximity radius was increased by `100%` from the original mine implementation.
- Layout presets now share one brighter neutral floor treatment.
- Room-to-room identity should come mostly from geometry/objective shape, not full palette swaps.
- Floor grid lines were removed.
- Combat rooms now support two objective styles:
  - `survive`
  - `destroy_generators`
- Generator rooms use:
  - neutral monster generators
  - gold and food pickups
  - `gauntlet_pockets` layout for the current V1 authored placement
- Combat HUD is no longer the old debug text layout:
  - stacked player health bars
  - top-center modifier chip
  - timer bar
  - styled result/pause/modifier panels
- Aim mode is now configurable through real UI:
  - bootstrap menu `Aim Settings`
  - in-run pause menu `Aim Settings`
  - modes: `Heavy Auto`, `Full Auto`, `Manual`

## Current Run Structure

- Run map is now procedural, not the old fixed six-step pattern.
- Each run now generates:
  - `5–7` pre-boss steps
  - one guaranteed rest slot
  - one guaranteed shop slot
  - mixed combat/elite pressure rooms
  - a final boss step
- Room rewards and pressure now scale by depth:
  - gold reward
  - survival duration
  - enemy spawn interval
- Survival waves are depth-aware:
  - early rooms favor `Chaser`
  - mid rooms balance all three enemy types
  - later rooms lean harder on `Spitter` and `Charger`
- Boss HP now scales slightly with how many rooms were cleared before the boss.
- Debug setup is now a real launcher, not just starting-gear overrides:
  - `Normal Run` or `Single Room`
  - explicit room type, objective, modifier, layout, and step selection
  - starting primary, secondary, and gold selection
  - single-room relaunch flow through `RunFlow`

## Current Priorities

- Preserve the approved core loop.
- Favor tuning and readability over adding new systems.
- Keep enemy ranged pressure under control.
- Keep projectile, aim-line, and arena contrast readable.
- Keep the arena bright and neutral enough that combat reads stay above environment styling.
- Keep grenade and mine roles distinct instead of blending them back together.
- Validate the new HUD and modifier readability in live combat, not just parse/startup.
- Validate procedural run pacing and variation in live play, not just generation logic.
- Validate the new aim-settings flow at `1–4` players.
- Validate `3–4` player behavior and full-run pacing later; do not expand scope casually.

## Important Runtime Ownership

- `RunState.gd`: cross-room run state, loadouts, gold, progression.
- `ProfileState.gd`: persistent profile, meta gold, unlock ownership.
- `CoopManager.gd`: combat-room orchestration and spawning.
- `RunFlow.gd`: node-map and room transition flow.
- `Bootstrap.gd`: pre-run player setup, debug start options, and aim settings menu.
- `Bootstrap.gd`: also owns the debug run launcher UI.
- `data/items.json`: shared reward/shop item definitions.
- `data/modifiers.json`: room modifier tuning.
- `Enemy.gd`: enemy silhouettes, hitbox sizing, and motion identity.
- `CoopManager.gd`: now also owns generator-room orchestration and pickup handling.

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
