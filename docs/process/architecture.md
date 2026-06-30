# Architecture

## Scope Note

- Describes the active runtime on `v3/main` (V3 + round-9 weapon system).
- If this conflicts with `docs/development/current-state.md`, update this file to match it.

## Folder Ownership

- `scenes/`: scene composition (runtime, UI, player, enemies, pickups, flow)
- `scripts/`: gameplay and runtime logic
- `scripts/dev/`: dev-only tooling (Perf Runner, profiling harness, debug overlay) — inert in normal play
- `data/`: editable JSON definitions (`weapons.json`, `mutations.json`, `abilities.json`, `modifiers.json`)
- `assets/`: runtime art/audio/fonts
- `docs/process/`: scope, architecture, workflow rules · `docs/development/`: runtime truth + session memory
- `docs/design/`: active design direction · `docs/archive/`: shipped/superseded docs

## Runtime Boundaries

- **Simulation owns:** movement, auto-targeting, auto-fire, ability runtime (OFF/DEF), enemy/boss
  spawning, continuous time-based spawning, room clear/fail/revive, run progression, **shared XP +
  room-end reward (Upgrade) flow**, room runtime freeze on clear/pause.
- **Presentation owns:** arena visuals, HUD, route presentation, Reward screen, pause/result/menu,
  particles/readability VFX, camera framing/zoom.
- Scene files compose nodes; they should not hide rule logic. Placeholder visuals are fine while
  readability stays high.
- **No gold/shop/rest economy** — progression is the XP economy (health resets each room).

## Singletons (autoloads)

- `RunState.gd` — cross-room state: player configs, structured+endless run generation, current
  node, shared XP + banked picks, boss/modifier/side-objective assignment, per-player inventories,
  **active weapon id + shared weapon level**, single-room debug setup, `debug_profiling` flag.
- `ProfileState.gd` — meta/profile state (not central to the active loop).
- `DebugOverlay.gd` — F3 perf overlay (dev).
- `PerfRunner.gd` — dev-only automated profiler; inert unless `--profile=` is passed.

## Run Flow

- `Bootstrap.gd` — player/run-mode/weapon/ability setup, main-menu settings (VSync, key/pad
  rebinding; P2 is keyboard-only for now), launches the run into `RunFlow`.
- `RunFlow.gd` — structured route presentation (round 10: next-choices cards), endless chaining,
  resolution screens. Hosts the in-room game.
- `CoopManager.gd` — in-room runtime orchestrator and `Enemy._combat_owner` facade: player/enemy
  spawning, continuous spawning, pooled projectiles, ability dispatch, reward sequencing (XP picks +
  weapon cards), champion helper attacks, modifier/objective orchestration, pause/clear runtime freeze.
- `CoopFormat.gd` / `EnemyTypes.gd` / `ArenaGeometry.gd` — stateless CoopManager helpers for text/color
  formatting, champion type classification, and pure arena/spawn geometry.
- `ProjectileSystem.gd` — CoopManager-owned child node for projectile pooling, beam state, homing orb
  updates, projectile split/impact callbacks, and projectile VFX. CoopManager remains the public fire signal
  entry point, enemy combat-owner facade, and source of player/enemy target accessors.
- `ArenaVisuals.gd` — CoopManager-owned child node for floor/grid/wall visuals, arena collision bounds,
  exit-zone/camera arena setup, arena color application, and the grid pulse pump.
- `GameHud.gd` — CoopManager-owned child node for in-room HUD construction and refresh: XP/score/room
  labels, boss health, side-objective panel, modifier chips, player combat indicators, revive markers, and
  bottom player cards. CoopManager exposes read-only room/player/objective accessors and keeps wrapper
  call sites until the remaining decomposition tasks move result/flow code.
- `WaveDirector.gd` — CoopManager-owned child node for spawn cadence/scaling/progress, opening/burst/stream
  enemy spawns, deferred spawn queues, champion spawn timing, and the active boss pointer. CoopManager
  remains the single owner of `_enemy_nodes`, room clear handling, enemy signal callbacks, and the enemy
  combat-owner facade.
- Room types: `combat` / `elite` / `boss` (no rest/shop). Encounter Builder / Debug Menu use the
  single-room debug path — a fast-iteration entry, not a second source of truth.

## Main Runtime Ownership

- `RunState.gd` — see Singletons.
- `Player.gd` — movement, auto-fire timing, aim mode (default auto), generic ability-slot runtime,
  additive ability lockout (e.g. Pulsar EMP), ability visuals/local state.
- `AutoTarget.gd` — nearest-enemy targeting.
- `MutationSystem.gd` — Upgrade definition loading; **active-weapon stat compilation + weapon-card
  generation**; Effect/Attribute compilation; loadout-gated ability-rare (Signature) filtering;
  act-weighted rare rolls + pity; `force_rare` for elites.
- `Projectile.gd` — pooled projectile movement/impact; pierce/ricochet/explosion/slow/poison and
  burn-pool delivery.
- `FireTrailZone.gd` — Fire Bullets impact pools (team-routed distance-check damage).
- `Enemy.gd` — enemy/elite/boss behavior, boss phases/telegraphs/add pressure.
- `ZoomCamera.gd` — dynamic 2P fit-zoom camera.
- `MutationPickUI.gd` — the Reward screen (Upgrade cards grouped Weapon/Effect/Attribute/Ability).

## Core Data Contracts

- `PlayerConfig`: `player_id`, `control_source`, `tint`, `aim_mode`.
- `PlayerInventory`: `weapon_id`, `weapon_level`, `ability_slot_1`, `ability_slot_2`, `mutations`.
- `data/weapons.json`: 5 weapon definitions with fixed `stats` + per-level arrays.
- `data/mutations.json`: Effect/Attribute/Ability upgrade definitions (code term "mutation").
- `data/abilities.json`: the 9 abilities (OFF/DEF) + their stats.
- `RunState.get_player_runtime_loadout_for()` returns the level-resolved runtime loadout consumed
  by `Player.gd` (active weapon stats + abilities + mutations + HP).

## Current Risks

- Ownership boundaries are stable. The live risks are **gameplay validation** (pacing, reward/rarity
  feel, boss feel/fairness, readability) and the **~200-entity performance ceiling** (parked for a
  dedicated perf round; use the Perf Runner to measure).
- Add new systems only after the current loop stays readable and fun in live play.
