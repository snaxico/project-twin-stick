# Start Of Day

Read this first to restore project context quickly, then read `current-state.md` and the latest file in
`history/`.

## Working Branch

- Active gameplay work happens on `v3/main`.
- Treat `v3/main` as the current game and GitHub mainline.
- Old v1/v2 branch or archive material should not shape live runtime decisions.
- Work in `D:\GameDev\Project_Twin_stick`; do not create new worktrees; keep generated output on `D:`.

## Source Of Truth

- `docs/development/current-state.md` is the compact runtime source of truth.
- `docs/design/game-direction.md` is the game-direction source of truth.
- `docs/development/history/` records what changed, why, and what remains open.
- If this file and `current-state.md` disagree, treat `current-state.md` as correct and update this file.

## Project Snapshot

- Godot `4.6.2` same-screen local co-op twin-stick roguelite prototype.
- Current target is the active `1-2` player V3 runtime.
- Current local runtime includes the round-14 weapon/manual-aim/Momentum implementation on top of the
  round-13 tool-validated baseline and the round-9 Mutation-to-Weapon system rework.
- Round 14 is implemented and tool-validated, including the controller movement regression fix.
- Manual playtest with real controllers is still pending.
- Current focus is round-14 live validation:
  - P1/P2 controller ownership and no cross-drive
  - controller movement after the regression fix
  - right-stick / mouse manual aim feel
  - Momentum pacing and damaging-hit tier loss
  - Beam ramp/contact behavior
  - Boomerang outbound/return readability
  - Split targeting
  - additive stat balance
  - smaller player/enemy/zoom readability pass
- Active validation plan: `docs/development/playtest-round-14-plan.md`.
- Perf Runner (`scripts/dev/PerfRunner.gd`) profiles unattended scenarios:
  `--profile=boss:<id>|room:<type>|entity_ramp`.

## Live Runtime Summary

- Player count target: `1-2`; no casual `3-4` player work.
- Run modes: `Structured` and `Endless`.
- Front menu paths:
  - `Play`
  - `Settings`
  - `Encounter Builder` in debug builds or when launched with `--debug-menu`
- Current live loadout structure:
  - one active weapon, starting with `Rifle`
  - shared weapon level `1-5`, preserved when changing weapons
  - `1 OFF` ability on `LT`
  - `1 DEF` ability on `RT`
- Live weapons:
  - `Rifle`
  - `Rocket Launcher`
  - `Shotgun`
  - `Cannon`
  - `Railgun`
  - `Beam`
  - `Boomerang`
- Live ability roster:
  - `Shockwave`
  - `Dash`
  - `Overcharge`
  - `Blink`
  - `Shield`
  - `Decoy`
  - `Turret`
  - `Minefield`
  - `Orbit`
- Live enemies:
  - `Chaser`
  - `Charger`
  - `Spitter`
  - `Splitter`
  - `Splitter Mini`
  - `Bomber`
- Live elite mini-bosses:
  - `Elite Charger`
  - `Elite Spitter`
  - `Elite Support`
- Live bosses:
  - `Warden`
  - `Hydra`
  - `Hive`
  - `Pulsar`

## Current Round-14 State

- Active weapons are now `Rifle`, `Rocket Launcher`, `Shotgun`, `Cannon`, `Railgun`, `Beam`, and
  `Boomerang`.
- Weapon fire defaults to nearest-target auto-targeting with seamless right-stick / mouse manual
  override.
- Aim modes are `auto`, `movement`, and `manual`.
- Cannon is slower/heavier with no pierce or knockback.
- Shotgun spread is tighter and no longer has weapon knockback.
- Dash cooldown is `1.5s`; Overcharge cooldown is `12s`.
- Player visuals are `1.35x`, enemy readability scale is `1.2x`, close-player zoom is `0.56`, and
  floor-grid lines are antialiased.
- Boss off-screen arrow indicator is removed; boss health/phase HUD remains.
- Ricochet is repurposed as `Split`: projectile hits spawn one pooled follow-up shot at the nearest
  other enemy.
- Beam is a continuous line weapon with `0.1s` ticks, per-target dwell-ramp damage, Beam-specific
  upgrade compilation, and one refreshed fire pool per beam when Fire Bullets is active.
- Boomerang travels out and returns, with separate outbound/return hit tracking so enemies can be hit
  once per leg.
- Momentum/Flow is live:
  - shared kill gain
  - per-player damaging-hit tier loss
  - four HUD pips
  - player aura
  - additive uncapped move/fire-rate bonuses
- Weapon/player percent bonuses use additive accumulation: `base * (1 + sum(percent bonuses))`.
- Controller movement, aim, abilities, and mutation-pick controls use player config ownership so
  `Hybrid` remains hybrid and `Gamepad` remains device-owned.

## Progression Loop

- Enemy kills feed one shared XP bar.
- Level-ups bank room-end pick rounds.
- In co-op, both players level together and each gets an independent pick per round.
- Elite rooms grant one additional free pick round after XP picks resolve.
- Rare weighting:
  - Act 1: `20%`
  - Act 2: `30%`
  - Endless: `40%`
- Rare bad-luck protection is per-player and forces rare options after `3` non-rare pick rounds.
- Health resets at the start of every room.
- Gold, shops, rest nodes, and the old purchase loop are removed from the live runtime.

## Current Priorities

- Preserve the approved V3 core loop.
- Favor validation, tuning, and readability over adding more systems.
- Run manual round-14 validation before treating the patch as stable.
- Keep scope tight:
  - no meta progression
  - no meta weapon unlocks
  - no additional ability signatures beyond the round-9 set
  - no casual `3-4` player work
  - no final art pass yet

## Manual Validation Focus

- P1/P2 controller ownership; one controller must not move/control both players.
- Controller movement, right-stick aim, OFF/DEF triggers, and mutation-pick confirm/cancel in `1P`
  and `2P`.
- Manual aim feel in auto override and manual-only modes.
- Momentum pacing, tier pips, aura, additive stat balance, and damaging-hit loss behavior.
- Beam ramp behavior, contact-point Fire Bullets behavior, and Beam upgrade compatibility.
- Boomerang outbound/return double-hit readability.
- Split targeting and pooled follow-up behavior.
- Weapon level-up cards, weapon swap cards, shared weapon level preservation, and all seven weapon
  firing profiles.
- Continuous spawn pacing in `1P` and `2P`.
- Endless difficulty scaling past room `20`.
- Elite reward value, Act 2 scaling, add-wave pressure, spawn distance, and telegraphed patterns.
- Boss escalation, phase transitions, adds, heavy-attack feel, and boss-specific mechanics.
- Boss HP bar visibility, phase pips, and readability in `1P` and `2P`.
- Modifier readability under stacked late-game rooms.
- Scanline readability, safe gaps, and performance.
- Fire Bullets impact-pool balance, correctness, and performance.
- Projectile pooling / AI time-slicing / boss entity-load performance at `100-150+`
  enemies/projectiles.
- Bloom, hit-stop, VFX density, and generated SFX fatigue.

## Important Runtime Ownership

- `scripts/game/RunState.gd`:
  - structured + endless run generation
  - shared XP and banked pick progression
  - boss / modifier / side-objective assignment
  - per-player inventory state
  - active weapon id and shared weapon level
  - single-room debug setup for Encounter Builder runs
- `scripts/game/CoopManager.gd`:
  - room runtime
  - continuous time-based spawning
  - pooled projectile runtime
  - Beam, Boomerang, Split, Momentum, boss health/phase HUD, and controller-owned local co-op input
  - ability dispatch
  - reward sequencing
  - boss helper attacks
  - elite add waves
  - modifier / side-objective orchestration
- `scripts/player/Player.gd`:
  - movement
  - auto-fire and manual aim override
  - aim-mode support
  - ability-slot runtime
  - ability visuals / local state
- `scripts/game/MutationSystem.gd`:
  - live upgrade compilation
  - weapon card generation and active weapon stat compilation
  - Beam-specific upgrade compilation
  - loadout-gated ability rare filtering and effect exposure
  - act-weighted rare rolls
  - elite `force_rare` support
- `scripts/weapons/Projectile.gd`:
  - live projectile behavior
  - rare effect delivery
  - pooled activation/deactivation
  - Boomerang and Split projectile behavior
- `scripts/weapons/ProjectileRenderer.gd`:
  - batched MultiMesh projectile visuals keyed by `projectile_shape`
- `scripts/ui/Bootstrap.gd`:
  - player setup
  - run-mode / starting weapon / ability selection
  - main-menu VSync, audio, and input remapping
  - per-player controller ownership and rebinding
  - Encounter Builder wiring
- `scripts/ui/RunFlow.gd`:
  - structured map flow
  - endless room chaining
  - resolution screens

## Known Risks

- Full live playtesting and balance validation still have not been run after the full V3 integration.
- Round 14 controller ownership, manual aim, Momentum, Beam, Boomerang, Split, and the controller
  movement regression fix passed headless validation but still need live `1P` / `2P` testing with real
  controllers.
- Boss and elite behavior is implemented, but likely needs feel tuning against real runs.
- Modifier stacking, projectile pooling, AI time-slicing, delayed boss combat rooms, homing orbs, and
  endless pressure need manual stress testing.
- `GoldPickup.gd` remains deleted; gold stub functions in `RunState.gd` remain no-ops.
- `wave_count` fields in RunState node data are unused dead data.
- Objective-panel icons currently use simple letter fallback glyphs (`H` / `K` / `C`).
- Pulsar beam currently uses angle/range damage and does not raycast line-of-sight through walls.
- Hive shield and boss add pressure may make boss fights feel too long.
- Enemy visual draw reduction still needs a manual readability check.
- `entity_ramp` at `200 enemies + 200 projectiles` was below target in round-11 synthetic profiling
  because enemies remain per-node; real boss-room profiles were healthy, so enemy MultiMesh remains
  deferred unless live playtest contradicts real-room performance.

## Validation Reminder

- Headless validation executable:
  - `D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`
- Standard parse check:

```powershell
& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit
```

## Development Guidelines

Canonical guidelines live in `docs/process/solo-dev-rules.md`. Key rules:

- Build one vertical slice at a time; give AI one bounded task at a time; review generated code.
- Codex implementation rule: stick to the approved plan, do not invent assumptions, do not silently
  deviate, flag unclear items before implementing, and summarize unclear/skipped/deviated work.
- Terminology: "Upgrade" is the player/doc word; "mutation" is code-only.
- Performance: use the Perf Runner for perf tests; the ~200-entity synthetic ceiling is the known
  bottleneck.
- Commit only after a slice works and validation passes; do not push unless asked.
- Never treat a broken intermediate state as done.

## Documentation Guidelines

- `start-of-day.md` is the fast refresher.
- `current-state.md` is the runtime source of truth for the live `v3/main` runtime.
- `history/` records what changed, why, and what remains open.
- `docs/design/game-direction.md` is the current direction doc.
- Shipped round plans and the old V2 roadmap are archived under `docs/archive/`.
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
  - `docs/design/game-direction.md` if the task touches direction, economy, weapons, or upgrades
  - the active `docs/development/playtest-round-14-plan.md` if implementing or validating the current
    patch
  - any process doc that the task touches
