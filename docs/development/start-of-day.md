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
  - `Bruiser`: oversized brown hex bruiser
  - `Boss`: oversized crimson crown
- Grenades use aimed throw behavior.
- Mines place instantly on secondary press and detonate on proximity fuse.
- Mine proximity radius was increased by `100%` from the original mine implementation.
- Layout presets now share one uniform olive-neutral floor treatment.
- Room-to-room identity should come mostly from geometry/objective shape, not full palette swaps.
- Floor grid lines are back as subtle fullscreen room texture.
- Combat rooms now support two objective styles:
  - `survive`
  - `capture_the_hill`
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
  - latest pass makes the player cards smaller and icon-first
  - weapon slots now prefer real sprites and fall back to procedural placeholder icons
  - passive chips now use procedural icons instead of text abbreviations
  - gold readouts now use a coin icon plus value
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
  - default profile setting is currently `Full`

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
  - early rooms are almost all `Chaser` with rare `Spitter`
  - mid rooms introduce `Charger` and `Bruiser` while `Spitter` stays rare
  - later rooms are heavy-melee rooms dominated by `Charger` and `Bruiser`
- Boss support waves are now melee-only:
  - `Chaser`
  - `Charger`
  - `Bruiser`
  - no `Spitter` support add in the boss room
- Room modifiers are now progression-gated:
  - early core pool stays readable
  - advanced modifiers stay out of normal runs
  - normal recipes now use a reduced identity-first set:
    - `Swarm`
    - `Crossfire`
    - `Hot Floor`
    - `Death Pop`
  - generic stat-pressure modifiers are now disabled from normal recipe selection
- Arena layouts now include obstacle variants:
  - `pillars`
  - `ring`
  - `pockets`
  - `lane`
  - obstacle visuals now use a high-contrast pillar treatment instead of subtle floor tinting
  - arena center is reserved so obstacle placement cannot block center-spawned loot
  - generator slots are now sanitized against obstacle geometry before generator-room setup
  - `ring` is now a tighter eight-pillar loop with cut-through gaps
  - `pockets` now push objectives into clearer inward-facing pocket clusters
  - `lane` now creates three broad combat lanes with safe rotation gaps
- Combat and elite rooms are now recipe-driven:
  - layout, modifier, enemy-weight hints, and optional pacing overrides combine into recognizable encounters
  - the recipe picker now avoids repeating the last 2 recipe IDs
  - example identities now include open swarm rooms, crossfire lanes, pillar skirmishes, ring runs, and pocket breakthroughs
  - crossfire rooms now bias spitters toward side spawns
  - `Swarm` now owns a much larger enemy-count push with a 200% spawn-rate increase
  - hot-floor rooms now use telegraphed floor hazards instead of anti-idle punishment
  - death-pop rooms now use temporary danger puddles instead of instant death bursts
- Boss HP now scales slightly with how many rooms were cleared before the boss.
- Debug setup is now a real launcher, not just starting-gear overrides:
  - `Normal Run` or `Single Room`
  - run mode: `Normal` or `Easy`
  - explicit room type, objective, modifier, layout, and step selection
  - explicit obstacle-layout testing through `pillars`, `ring`, `pockets`, and `lane`
  - starting primary, secondary, and gold selection
  - single-room relaunch flow through `RunFlow`
- Home menu `Debug` is now being repurposed into an `Encounter Builder` flow:
  - one configured room per launch
  - auto-launches directly into the room instead of stopping on a one-node debug map
  - returns to the builder when the encounter ends
  - current builder objective focus is `survive` and `capture_the_hill`, not generators
  - primary use is testing layout/modifier/objective combinations, not simulating a full run
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
  - loot vote, shop, and replacement panels are now icon-first instead of text-heavy
  - enemies now steer around walls/obstacles with forward feelers instead of waiting for a long blocked-time delay
  - enemy packs now apply capped local separation so Swarm pressure spreads through obstacle rooms better
  - enemy base move speed was raised across the roster, while `Chaser`, `Charger`, and `Bruiser` also got tighter attack timings
  - enemy lunge / charge / slam attacks now emit short trail effects and heavier hit/kill feedback
  - survival/support waves now sample valid spawn positions across the arena instead of only using six fixed layout markers
  - sampled wave spawns must stay away from players and invalid geometry instead of appearing directly on top of active fights
  - `capture_the_hill` is now a live alternative objective that reuses standard combat-wave pressure instead of generator-owned spawns
  - recent runtime cleanup throttled repeated HUD/debug refresh work and removed the latest parser shadowing warnings from encounter/runtime UI code

## Current Priorities

- Preserve the approved core loop.
- Favor cleanup, readability, and validation over adding new systems.
- The newly implemented primary ruleset migration has now passed gameplay validation.
- Favor follow-up tuning and cleanup over more architecture churn.
- Keep enemy ranged pressure under control.
- Keep projectile, aim-line, and arena contrast readable.
- Keep the arena bright and neutral enough that combat reads stay above environment styling.
- Keep grenade and mine roles distinct instead of blending them back together.
- Tune the new primary behavior family in live play:
  - `cone`
  - `beam`
  - `chain`
- Tune hook-passive proc frequency and trigger chaining in active combat.
- Validate the new HUD and modifier readability in live combat, not just parse/startup.
- Validate the new compact icon HUD and passive chips in live play, especially for secondaries that still use placeholder icon badges.
- Validate procedural run pacing and variation in live play, not just generation logic.
- Validate connected-map readability and route feel in live play, not just graph generation.
- Validate the new aim-settings flow at `1–4` players.
- Validate `Normal` vs `Easy` room-to-room HP persistence in live play.
- Validate chaser contact damage and pickup drops in active combat after the recent reliability fixes.
- Validate the melee-first enemy rebalance in live play:
  - early rooms should feel like dodge-the-rush, not dodge-the-bullets
  - `Spitter` should read as occasional support pressure, not main screen load
  - combat food sustain should make `Normal` more survivable without collapsing into `Easy`
- Validate the icon-first UI pass in live play:
  - placeholder icons must stay readable at gameplay scale
  - shop offers must read faster than the old text blocks
  - replacement choices should read icon-to-icon at a glance
  - Patch 12 has now been accepted, so future UI edits should preserve this scan speed
- Validate Patch 13 encounter identity in live play:
  - `Bruiser` must read as a slow durable slam threat, not a worse Charger
  - early rooms must stay clean of late modifiers and generic stat-pressure rooms
  - pillar/ring/pocket/lane rooms must change movement without creating stuck enemies under the new feeler steering pass
  - the new feeler steering plus arena-wide valid spawn sampling must hold up under bigger `Swarm` counts
  - capture-the-hill rooms must read clearly and feel better than generator rooms before more objective expansion
  - hot-floor telegraphs must read clearly before activation
  - death-pop puddles must feel avoidable at melee range
  - crossfire flank spawns must create readable side pressure instead of noise
  - enemy projectiles must now read cleanly when they persist until wall or obstacle impact
  - curated recipe-driven rooms should feel authored rather than arbitrary
  - generator rooms must stay compatible with their selected layout and modifier every time
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
- `data/recipes.json`: encounter recipe definitions and enemy weight hints.
- `scripts/ui/IconFactory.gd`: procedural fallback icon generation and icon cache for weapons, passives, and UI chrome.
- `RecipeEngine.gd`: room recipe loading and recipe/weight-hint selection.
- `HotFloorZone.gd`: telegraphed floor-hazard runtime.
- `DeathPuddle.gd`: telegraphed corpse-puddle runtime.
- `docs/design/weapons-passives-balance.xlsx`: balancing/design source of truth for primary weapons, secondary weapons, and passive items.
- `docs/design/enemies-arenas-modifiers-balance.xlsx`: balancing/design source of truth for enemies, arena layouts, encounter modifiers, and recipes.
- `Enemy.gd`: enemy silhouettes, hitbox sizing, and motion identity.
- `PassiveTriggerSystem.gd`: centralized hook-passive throttling and action collection.
- `CoopManager.gd`: now also owns generator-room orchestration, pickup handling, encounter wave composition, obstacle spawning, the deferred pickup attach path, and shared combat-hit routing across primary and secondary sources.

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
- `docs/design/weapons-passives-balance.xlsx` is the balancing design document for weapons and passives.
- `docs/design/enemies-arenas-modifiers-balance.xlsx` is the balancing design document for enemies, arenas, modifiers, and encounter recipes.
- `docs/process/` stays the source of truth for scope, roadmap, architecture, and workflow rules.
- Any change to primary weapons, secondary weapons, or passive items must update `docs/design/weapons-passives-balance.xlsx` in the same slice.
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
