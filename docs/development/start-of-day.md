# Start Of Day

Read this first to restore project context quickly, then read `current-state.md` and the latest file in `history/`.

## Project Snapshot

- Same-screen local co-op twin-stick roguelite prototype in Godot `4.6.2`.
- Current target is still the first-playable bar from Patch 7:
  - one readable, stable `10–15` minute run
  - understandable without explanation
  - co-op route/loot/shop decisions and shared failure
- The codebase already includes extra Patch 8 and Patch 9 systems:
  - `1–4` players
  - persistent profile/meta unlocks
  - more layouts/modifiers
  - placeholder juice and readability passes

## Locked Rules

- Same-screen camera only.
- Local co-op only.
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
- New primary behavior families are now implemented in runtime:
  - `Incinerator` using `cone`
  - `Beam Lance` using `beam`
  - `Arc Caster` using `chain`
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
- Layout presets now share one uniform olive-neutral floor treatment.
- Room-to-room identity should come mostly from geometry/objective shape, not full palette swaps.
- Floor grid lines are back as subtle fullscreen room texture.
- Combat rooms now support two objective styles:
  - `survive`
  - `destroy_generators`
- Primary weapon/runtime ruleset migration is now implemented:
  - primary weapons use explicit `tags` and `primary_behavior`
  - primaries compile from the new standard stat model in `RunState`
  - passive filtering is per-slot with optional `requires_tags`
  - projectile primaries now support compiled `range`, `area`, and `pierce`
  - aim assist now respects compiled primary range
  - trigger passives now exist for `on_fire`, `on_hit`, `on_kill`, and `on_explosion`
- Generator rooms use:
  - neutral monster generators
  - gold and food pickups
  - `gauntlet_pockets` layout for the current V1 authored placement
- Combat HUD is no longer the old debug text layout:
  - per-player inventory panels
  - top-center modifier chip
  - timer bar
  - styled result/pause/modifier panels
  - lighter transparency so the arena remains visible under HUD cards
  - latest pass makes the player cards smaller and icon-first, with placeholder passive chips
- Player visuals are now in transition from pure procedural shapes toward real sprites:
  - player 1 uses a sprite-backed body
  - player 1 uses one standing frame and two alternating running frames
  - player 1 also has visible rifle / scattergun / slug sprites attached to the aim pivot
  - player projectiles now use a real bullet sprite
  - players 2–4 still use the current procedural polygon body
  - gameplay hitbox is still circular, but player 1's current footprint and collision radius were increased to better match the new sprite presentation
- Settings now live in a shared real UI flow:
  - bootstrap menu `Settings`
  - in-run pause menu `Settings`
  - per-player aim modes: `Heavy Auto`, `Full Auto`, `Manual`
  - screen effects level: `Off`, `Minimal`, `Full`
  - default profile setting is currently `Off`

## Current Run Structure

- Run map is now procedural, not the old fixed six-step pattern.
- Each run now generates:
  - `5–7` pre-boss rows plus one boss row
  - `3` starting nodes
  - `2–4` nodes on each non-boss row
  - one guaranteed reachable rest row
  - one guaranteed reachable shop row
  - mixed combat/elite pressure rooms
  - linked row-to-row pathing where only connected next nodes are selectable
  - a final boss row
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
  - run mode: `Normal` or `Easy`
  - explicit room type, objective, modifier, layout, and step selection
  - starting primary, secondary, and gold selection
  - single-room relaunch flow through `RunFlow`
- Run modes currently behave like this:
  - `Normal`: HP carries between cleared rooms
  - `Easy`: all players fully heal after each cleared room
- Progression flow now behaves like this:
  - each player has a personal wallet
  - each player has `2` primary slots and `2` secondary slots
  - duplicate weapons level up instead of creating more copies
  - combat and elite rooms drop physical loot after clear
  - loot resolves through Take / Scrap and contested rolls
  - full weapon slots open a replacement UI
  - shop rooms run in-world with personal offers
  - room exits now open after loot/shop resolution instead of auto-transitioning
- Current combat-input/runtime follow-up:
  - gamepad dash is now on `B / O`
  - dash cooldown is now `2.0s`
  - a successful dash now grants a visible `0.5s` shield window
  - visible player and weapon sprites were enlarged again by roughly `33%`
  - primary fire intervals and secondary cooldowns are both globally reduced by `20%`
  - player loadouts now refresh immediately after loot/shop inventory changes
  - `Rifle` and `Mine` are now valid reward/shop rolls, so the starting weapons can level up
  - replacement UI now seeds its held-button state on open, so it no longer instantly confirms/cancels
  - combat spectacle now uses weapon-weighted muzzle flash, impact, death, dash, and explosion feedback

## Current Priorities

- Preserve the approved core loop.
- Favor cleanup, readability, and validation over adding new systems.
- Validate the newly implemented primary ruleset migration in live play before further expansion.
- Keep enemy ranged pressure under control.
- Keep projectile, aim-line, and arena contrast readable.
- Keep the arena bright and neutral enough that combat reads stay above environment styling.
- Keep grenade and mine roles distinct instead of blending them back together.
- Validate the new primary behavior family in live play:
  - `cone`
  - `beam`
  - `chain`
- Validate hook-passive proc frequency and trigger chaining in active combat.
- Validate the new HUD and modifier readability in live combat, not just parse/startup.
- Validate the new compact icon HUD and passive chips in live play, especially for secondaries that still use placeholder icon badges.
- Validate procedural run pacing and variation in live play, not just generation logic.
- Validate connected-map readability and route feel in live play, not just graph generation.
- Validate the new aim-settings flow at `1–4` players.
- Validate `Normal` vs `Easy` room-to-room HP persistence in live play.
- Validate chaser contact damage and pickup drops in active combat after the recent reliability fixes.
- Validate loot, replacement, shop, and exit UI flow with gamepad-first input.
- Validate `3–4` player behavior and full-run pacing later; do not expand scope casually.

## Important Runtime Ownership

- `RunState.gd`: cross-room run state, per-player inventories, loadouts, shop offers, progression, and run-mode health persistence.
- `ProfileState.gd`: persistent profile, meta gold, unlock ownership.
- `CoopManager.gd`: room orchestration, spawning, loot/shop flow, exit gating, primary behavior execution, and trigger event processing.
- `RunFlow.gd`: node-map and room transition flow.
- `Bootstrap.gd`: pre-run player setup, run-mode selection, shared settings, and the debug run launcher UI.
- `ScreenEffects.gd`: runtime post-process layer, now controlled by the settings menu.
- `assets/sprites/`: runtime sprite assets used by the game.
- `sprites/guidelines/`: sprite-generation prompts and rules, kept separate from runtime assets.
- `data/weapons.json`: weapon definitions and level data.
- `data/passives.json`: passive reward/shop item definitions.
- `data/modifiers.json`: room modifier tuning.
- `Enemy.gd`: enemy silhouettes, hitbox sizing, and motion identity.
- `PassiveTriggerSystem.gd`: centralized hook-passive throttling and action collection.
- `CoopManager.gd`: now also owns generator-room orchestration, pickup handling, the deferred pickup attach path, and shared combat-hit routing across primary and secondary sources.

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
