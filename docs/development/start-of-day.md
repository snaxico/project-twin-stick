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
- `docs/design/game-direction.md` is the source of truth for game direction. The old V2 `roadmap.md` is archived under `docs/archive/design/` (superseded).
- `history/` records what changed, why, and what remains open.
- If `start-of-day.md` and `current-state.md` ever disagree, treat `current-state.md` as correct and update this file.

## Project Snapshot

- Same-screen local co-op twin-stick roguelite prototype in Godot `4.6.2`.
- Current target is the active `1-2` player V3 runtime.
- The live runtime now follows the `Feature Roadmap V3` redesign captured in `current-state.md`.
- Current local runtime includes the round-10 implementation on top of the round-9 Mutation-to-Weapon system rework.
- Current focus is manual round-10 validation, especially route cards, room-end freeze, Hive pressure, boss windups/tells, rare pity, Minefield stacking, audio fatigue, debug gating/overlay, starting weapon selection, and 2P camera feel.
- **Active patch plan:** `docs/development/playtest-round-10-plan.md` has been implemented locally and awaits playtest approval; do not treat it as fully stable until the manual playtest passes.
- **Perf Runner** (`scripts/dev/PerfRunner.gd`, committed) profiles any scenario unattended (`--profile=boss:<id>|room:<type>|entity_ramp`). Known ~200-entity FPS ceiling is parked for a dedicated perf round.
- Shipped round plans/validations now live in `docs/archive/`; `history/` is the canonical change log.

## Live Runtime Summary

- Player count target:
  - `1-2` players only
  - `3-4` players deferred
- Current run modes:
  - `Structured`
  - `Endless`
- Current live loadout structure:
  - one auto-firing active weapon, starting with `Rifle`
  - five peer weapons: `Rifle`, `Rocket Launcher`, `Scattergun`, `Cannon`, `Railgun`
  - shared weapon level `1-5`, preserved when changing weapons
  - `1 OFF` ability on `LT`
  - `1 DEF` ability on `RT`
- Current main-menu settings:
  - VSync toggle persisted in `user://video_settings.cfg`; first-run project default is enabled
  - Master / Music / SFX audio sliders persisted in `user://audio_settings.cfg`
  - keybinding editor
  - controller binding editor for menu and Player 1 gameplay actions
  - rebindable debug overlay toggle, default `F4`
  - Player 2 is temporarily keyboard-only; stale P2 controller bindings are stripped on startup/reset
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
  - heavy boss add-waves are enabled in normal boss rooms with a `25` non-boss enemy cap
  - live playtest feedback reports a massive performance improvement
- Current round-7 state:
  - ability data and UI are split into OFF and DEF slots
  - defaults and migrated old loadouts normalize to `LT = OFF`, `RT = DEF`
  - bloom/glow is enabled through HDR 2D and `WorldEnvironment`
  - hit-stop is managed by `HitStopManager.gd` as the sole `Engine.time_scale` owner
  - boss fights show a top-center HP bar with phase pips
  - behavior-changing weapon mutations have distinct projectile shape/trail/accent/SFX
  - ability rare pilot includes `oc_piercing_overdrive` for Overcharge and `sw_resonance` for Shockwave
- Current round-8 state:
  - starter Rifle damage/fire-rate is buffed for stronger baseline offense
  - room duration, spawn interval, opening burst, and burst interval use `RunState.get_run_progress()` instead of binary Act 1/Act 2 cadence branches
  - enemy pools still swap by act; pool ramp is deferred by plan
  - player core, projectiles, enemy visuals, and generated VFX use render-local `x1.45` over-bright bloom
  - generated SFX stay on `AudioStreamGenerator` with richer synthesis and an idempotent `SFX` bus limiter/reverb chain
- Current round-9 state:
  - HP/damage model is rescaled around player HP `100` and lower base weapon damage
  - reward cards now include weapon level-up and rare weapon swap cards
  - old weapon-shape mutations became weapon identities
  - upgrades are visually grouped as `Weapon`, `Effect`, `Attribute`, and `Ability`
  - `High Caliber` and `Range` are new attribute commons
  - ability signatures are live for Dash, Blink, Shield, Decoy, Turret, Orbit, Minefield, Overcharge, and Shockwave
  - Player 2 controller gameplay input is disabled for now because shared pad bindings could control both players
- Current round-10 state:
  - route selection uses next-choice cards instead of the dense full graph
  - room clear pauses active runtime hazards/enemies/projectiles during reward/map UI
  - rare odds are `15%` Act 1, `25%` Act 2, `35%` Endless, with per-player pity after `4` dry pick rounds
  - Minefield is instant/stacking with `7s` cooldown and `mine_lifetime`
  - generated adaptive music uses the `Music` bus and procedural SFX are softened on `SFX`
  - Hive gets extra target-position pressure adds under the boss add cap
  - bosses have a `2.5s` invulnerable entrance windup plus delayed heavy attack tells
  - Scanline sweeps are capped/spaced out with wider gaps
  - starting weapon selection is in setup/debug launch
  - debug menu is available only in debug builds or `--debug-menu`; in-room overlay toggles with `F4`
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
- Validate the current round-9 local build in live play:
  - shared XP and room-end pick cadence
  - structured map flow pacing
  - endless scaling past room `20`
  - elite reward value, spawn distance, Act 2 scaling, add waves, and new pressure patterns
  - boss escalation, phase transitions, adds, heavy-attack feel, and round-5 boss-specific mechanics
  - modifier readability
  - projectile pooling / AI time-slicing / boss entity-load performance at `100-150+` enemies/projectiles
  - real boss-room stress validation for shipped capped boss add-waves
  - OFF/DEF picker usability and controller mapping
  - bloom/hit-stop feel and performance
  - boss HP bar readability
  - mutation projectile readability and SFX distinctness
  - ability rare pilot behavior
  - weapon level-up cards and rare weapon swap cards
  - shared weapon level persistence when switching weapons
  - all five weapon profiles and their projectile visuals/SFX
  - new ability signatures and loadout gating
  - P2 keyboard-only behavior; one controller must not drive both players
  - smooth cadence progression, over-bright bloom readability/performance, and generated SFX fatigue from the round-8 baseline
  - controller usability for P1/menu only; P2 controller remains intentionally disabled
- Tune:
  - rifle cadence (`6.5` shots/sec in the current build)
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
  - active weapon id and shared weapon level
  - single-room debug setup for Encounter Builder runs
- `scripts/game/CoopManager.gd`:
  - room runtime
  - continuous time-based spawning
  - pooled projectile runtime
  - ability dispatch
  - reward sequencing
  - boss helper attacks
  - elite add waves
  - capped boss add-wave budget
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
  - weapon card generation and active weapon stat compilation
  - loadout-gated ability rare filtering and effect exposure
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
  - main-menu VSync setting and input remapping
  - temporary Player 2 keyboard-only enforcement
  - run launch

## Round-4 + Round-5 Build Notes

- Round-4 and round-5 code are the previous stable baseline on `v3/main`.
- Round-6 is a historical stable baseline, now superseded by Round 9.
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
- Treat the round-6 patch as historical context; the current stable branch state is Round 9.
- Heavy boss add-waves are enabled in normal boss rooms and capped at `25` non-boss enemies including pending spawns.
- Live playtest feedback after the patch reported a massive performance improvement.
- B3 Pulsar deflector-spawned adds are still open because the plan does not specify the desired Pulsar deflector count/pattern.
- Non-headless profiling harness after A2/B1 reported:
  - `50+50`: `1174.6 FPS`, `154` draw calls
  - `100+100`: `461.3 FPS`, `316` draw calls
  - `150+150`: `191.9 FPS`, `487` draw calls
  - `200+200`: `73.8 FPS`, `651` draw calls
- Headless harness output has `0` draw calls and should not be used for render profiling.
- Warning cleanup after implementation removed Godot local-name conflicts in `FireTrailZone.gd` and `MineFieldModifier.gd`.

## Current Round-7 Build Notes

- `docs/development/playtest-round-7-plan.md` is the round-7 implementation and validation guide.
- Treat the round-7 patch as historical context; the current stable branch state is Round 9.
- A8 fire-rate bump remains deferred by plan.
- Expansion ability rares remain deferred; only the two pilot rares are live.
- Manual validation still needs to cover `1P` and `2P` feel/performance with DebugOverlay F3.
- Headless parse passed after implementation and `FireTrailZone.gd` warning cleanup.

## Current Round-8 Build Notes

- `docs/development/playtest-round-8-plan.md` is the round-8 implementation and validation guide.
- Treat the round-8 patch as historical context; the current stable branch state is Round 9.
- Starting Rifle is now `20` damage / `6.5` shots/sec; projectile speed and range are unchanged.
- Cadence ramp uses normalized progress:
  - structured depth over last combat-row depth
  - endless room number over a room-20 soft horizon
  - Encounter Builder `step_index + 1` over a fixed horizon of `10`
- Cadence-only ramp is implemented; enemy pool ramp remains deferred and the old act-based pool step is expected.
- Bloom is applied render-locally with `x1.45` over-bright colors; source player tints, enemy feedback colors, and UI palette remain unchanged.
- SFX still use generated `AudioStreamGenerator` buffers, now routed through an idempotent `SFX` bus with limiter then reverb.
- Pickup SFX frame generation exists as `play_pickup()`, but no pickup call site was wired because the plan did not specify one.
- Validation passed:
  - `git diff --check`
  - headless project parse
  - headless main scene boot with `--quit-after 1`

## Current Round-9 Build Notes

- `docs/development/playtest-round-9-plan.md` is the round-9 implementation and validation guide.
- Treat the round-9 patch as the current stable branch state for future work.
- Weapons are now first-class runtime state:
  - `Rifle`
  - `Rocket Launcher`
  - `Scattergun`
  - `Cannon`
  - `Railgun`
- Reward screens can include `Level Up Weapon` and rare `Change Weapon` cards.
- Shared weapon level is global per player and stays when switching weapons.
- Upgrade cards are grouped as `Weapon`, `Effect`, `Attribute`, and `Ability`.
- Player 2 controller gameplay input is disabled for now:
  - P2 setup is keyboard-only
  - P2 controller binding buttons are disabled
  - stale P2 controller events are stripped after loading/resetting input bindings
- Validation passed:
  - `git diff --check`
  - headless project parse
  - headless main scene boot with `--quit-after 1`

## Round-9 Open Validation

- Manual playtest must validate weapon card frequency, weapon swap readability, shared level preservation, and all five weapon profiles.
- Validate all ability signatures: Shockdash, Twin Charge, Aegis Burst, Volatile Decoy, Twin Turret, Expanding Orbit, Extra Mines, plus the existing Overcharge/Shockwave pilots.
- Validate the new HP/damage model in `1P` and `2P`.
- Validate that one controller no longer controls Player 2.
- Continue checking bloom, SFX, projectile pooling, boss add-wave performance, and dense-room readability.

## Validation Reminder

- Headless validation executable:
  - `D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`
- Standard parse check:

```powershell
& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit
```

## Development Guidelines

Canonical guidelines live in `docs/process/solo-dev-rules.md`. Key rules:

- **Workspace:** work in `D:\GameDev\Project_Twin_stick` on `v3/main`; **no new worktrees**; keep
  all output on `D:` (never write to the small `C:` SSD).
- Build one vertical slice at a time; give AI one bounded task at a time; review generated code.
- **Codex implementation rule:** stick to the approved plan, do not invent assumptions, do not
  silently deviate, flag unclear items before implementing, and summarize any unclear/skipped/deviated
  work after implementation.
- **Terminology:** "Upgrade" (= Weapon + Effect + Attribute + Ability) is the player/doc word;
  "mutation" is code-only.
- **Performance:** use the Perf Runner for perf tests; the ~200-entity ceiling is the known bottleneck.
- Commit only after a slice works + validation passes; don't push unless asked.
- Never treat a broken intermediate state as done.

## Documentation Guidelines

- `start-of-day.md` is the fast refresher.
- `current-state.md` is the runtime source of truth for the live `v3/main` runtime.
- `history/` records what changed, why, and what remains open.
- `docs/design/game-direction.md` is the current direction doc; shipped round plans + the V2 `roadmap.md` are archived under `docs/archive/`.
- `docs/process/` stays the source of truth for scope, architecture, and workflow rules.
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
  - the active `docs/development/playtest-round-10-plan.md` if implementing the current patch
  - any process doc that the task touches
