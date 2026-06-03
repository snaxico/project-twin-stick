# Current State

## Project Role

Godot `4.6.2` same-screen local co-op neon roguelite prototype.

The live runtime is now aligned to the `Feature Roadmap V3` redesign:

- target player count is `1-2`
- run modes are `Structured` and `Endless`
- the core economy is shared XP with room-end picks
- health resets at the start of every room
- meta progression, multiple starting weapons, and ability-specific rare mutations remain deferred

Current stable runtime includes the playtest round-7 spectacle / ability-slot / mutation patch on
top of the round-6 performance baseline. Heavy boss add-waves remain enabled in normal boss rooms
with a `25` non-boss enemy cap that includes pending spawns.

## Current Runtime

- front menu paths:
  - `Play`
  - `Settings`
  - `Encounter Builder`
- pre-run setup now supports:
  - `1P` or `2P`
  - `Structured` or `Endless`
  - per-player ability loadouts restricted to `1 OFF + 1 DEF`
  - slot order is fixed: `LT = OFF`, `RT = DEF`
- main-menu settings now support:
  - VSync toggle persisted via `user://video_settings.cfg`; first-run project default is enabled
  - keyboard rebinding for menu and active `1-2P` gameplay actions
  - controller button / axis rebinding for menu and active `1-2P` gameplay actions
  - saved runtime bindings via `user://input_bindings.cfg`
  - reset to default bindings
- structured runs use a `2-act` branching map:
  - Act 1 combat rows + optional elites + mid-boss
  - Act 2 combat rows + optional elites + final boss
- boss rooms spawn players below the center boss spawn with horizontal co-op spread
- endless runs use sequential rooms with:
  - no map
  - boss every 5 rooms
  - score = rooms cleared

## Progression Loop

- enemy kills feed one shared XP bar
- level-ups bank room-end pick rounds
- in co-op, both players level together and each gets an independent pick per round
- rare weighting is act-based:
  - Act 1: `10%`
  - Act 2: `20%`
- elite rooms grant one additional free pick round after XP picks resolve
- elite bonus rounds force at least one rare option per player if any legal rare remains
- gold, shops, rest nodes, and the old purchase loop are removed from the live runtime

## Loadout / Combat

- every player always has:
  - faster starter `Rifle` (`~5 shots/sec`)
  - faster base movement (`488` default speed)
  - `1 OFF` ability slot on `LT`
  - `1 DEF` ability slot on `RT`
  - mutation inventory
- live ability roster:
  - `Shockwave`
  - `Dash`
  - `Overcharge`
  - `Blink`
  - `Shield`
  - `Decoy`
  - `Turret`
  - `Minefield`
  - `Orbit`
- weapon fire is automatic via nearest-target auto-targeting
- aim mode remains in code but the in-run pause Settings panel was removed; active runtime defaults to auto-target aim
- current round-4 + round-5 tuning changed:
  - `Overcharge` is now a smaller boost (`22s` cooldown, `4s` duration, `1.3x` fire-rate, no extra projectiles)
  - `Blink` uses movement direction, longer range, short arrival i-frames, and an arrival detonation
  - `Turret` and `Minefield` are stronger; mines now use separate trigger and explosion radii
  - `Fire Bullets` replaces the old Fire Trail behavior and creates only a smaller burning impact pool on hit / expiry
- current round-6 tuning changed:
  - `Duration` now scales sustained abilities only; instant and movement abilities such as `Blink` and `Dash` ignore it
- current round-7 tuning changed:
  - ability selection and migration enforce `LT = OFF` and `RT = DEF`
  - `Overcharge`, `Turret`, `Minefield`, and `Orbit` are OFF abilities
  - `Dash`, `Shield`, `Blink`, `Decoy`, and `Shockwave` are DEF abilities
  - `oc_piercing_overdrive` and `sw_resonance` are loadout-gated ability rare pilots
- player mutation visuals are now partially wired:
  - projectile streaks for high `Rapid Fire` / `Velocity`
  - speed-line feedback for `Move Speed`
  - cooldown crackle feedback for `Quick Reflexes`
  - stronger player glow for `Tough` / `Overcharge`
  - behavior-changing projectile mutations now alter projectile shape, trail/accent, and impact SFX while keeping the player-tint core

## Content State

- live common mutations:
  - `split_shot`
  - `pierce`
  - `big_shot`
  - `rapid_fire`
  - `knockback`
  - `velocity`
  - `quick_reflexes`
  - `wide_pulse`
  - `duration`
  - `move_speed`
  - `tough`
- live universal weapon rares:
  - `ricochet`
  - `fire_trail`
  - `explosive_rounds`
  - `freeze_shot`
  - `poison`
- live loadout-gated ability rare pilots:
  - `oc_piercing_overdrive` requires `Overcharge`
  - `sw_resonance` requires `Shockwave`
- live enemy roster:
  - `Chaser`
  - `Charger`
  - `Spitter`
  - `Splitter`
  - `Splitter Mini`
  - `Bomber`
- live elite mini-bosses:
  - `Elite Charger`
  - `Elite Spitter`
  - `Elite Support`
- live bosses:
  - `Warden`
  - `Hydra`
  - `Hive`
  - `Pulsar`

## Encounter Systems

- rooms use continuous time-based spawning:
  - combat / elite rooms begin with a 6-8 enemy opening burst
  - enemies spawn on a timer throughout the room duration
  - Act 1 rooms: `~35s`, Act 2 rooms: `~45s`, elite rooms: `+10s`
  - spawn interval starts at `~1.8s` (Act 1) / `~1.3s` (Act 2), tightens with depth, and now ramps down to `~55%` over the first `45s`
  - when the timer expires spawning stops; room clears when all remaining enemies are dead
  - `Accelerating Waves` modifier stacks an additional aggressive ramp on top of the base ramp
  - `Swarm` modifier spawns 2 at a time with half HP
- multi-enemy spawn pulses now distribute enemies across multiple arena edges instead of clumping on one edge
- enemies apply soft local separation to reduce blob stacking while pursuing players
  - separation uses a per-frame spatial grid lookup instead of each enemy scanning the full enemy list
- enemy target acquisition is staggered across physics frames to reduce high-count AI spikes while movement still updates every frame
- high-count combat target lookups now use the same nearby-enemy grid for player auto-targeting, turret targeting, orbit hits, ability mine checks, ricochets, and player AOE explosions where applicable
- player and enemy projectiles now use a reusable projectile pool instead of per-shot instantiate/free churn
- nonessential combat hit VFX are throttled during very dense fights to reduce particle/ring allocation spikes
- enemy contact damage now checks all nearby player targets instead of only the current nearest target, uses a wider contact range, and grants a short player-side damage invulnerability window after a landed hit
- round-3 tuning increased player and enemy movement speeds by `25%` while keeping stationary bosses stationary
- HP pickups now drop from non-boss enemy kills:
  - `~10%` chance
  - `5 HP` heal
  - magnet pickup behavior
- side objectives now use the roadmap set:
  - `Hold Zone`
  - `Kill Streak` (true consecutive kills, fixed target, resets on actual player damage)
  - `Collector`
- completing a side objective grants one temporary room buff:
  - `Speed`
  - `Damage`
  - `Attack Speed`
- live modifiers now use the roadmap set:
  - minors: `Accelerating Waves`, `Enemy Speed`, `Swarm`, `Shielded`, `Explosive Death`
  - majors: `Fire Floor`, `Ice Zone`, `Scanline`, `Shrinking Arena`
  - `Gravity Wells` was removed after playtesting because its effect was not readable enough
- `Scanline` keeps the `mine_field` id but now draws segmented sweeping lines with safe gaps instead of many mine circles/arcs
- `Fire Floor` now uses larger, more numerous hazard zones (`280px`, up to `7` active)
- elite mini-bosses now spawn away from the player center-spawn box and have stronger telegraphed pressure patterns
- Act 2 elites now get `1.5x` HP, `1.3x` contact/projectile damage, and `25%` faster elite cooldowns
- elite rooms now spawn 2-3 regular add enemies every `6-8s` while the elite is alive
- bosses now have higher HP, HP-threshold phase telegraphs, add pressure, and clearer heavy-attack tells
- boss rooms now show a top-center boss HP bar with phase pips while a boss is alive
- current boss reworks:
  - `Warden`: leap gap-closer, multi-charge combo, ground-pound shockwave, phase speed ramp
  - `Hydra`: aimed snipes, rotating sweep, phase-transition minions, slow homing orbs
  - `Hive`: phase shield minions, poison cloud, burrow relocate, escalating minion mix
  - `Pulsar`: teleport repositioning, EMP ability lockout, sweeping beam, faster phase-3 pressure
- Hive shield safeguard after review:
  - shield count is fixed at `4`
  - phase transitions only spawn a new shield if the previous shield is already cleared
- round-6 boss/performance state:
  - `FireTrailZone` is now a `Node2D` distance-check pool instead of an `Area2D`, with player-team pools damaging nearby enemies and enemy-team pools damaging players
  - enemies now use a reduced one-polygon visual subtree; static visual updates are split from per-frame facing/fuse updates
  - Hive shield internals are generalized into boss deflector state; Pulsar has reactive close-range teleport
  - boss add-wave pressure is enabled in normal boss rooms for Warden, Hydra, and Pulsar; it caps all non-boss boss-room enemies including pending spawns
  - reported live playtest performance improved massively after the round-6 patch

## UI / Presentation

- combat HUD now shows:
  - top-center XP bar + level + pending picks
  - near-player cooldown arcs
  - persistent near-player health bars
  - bottom loadout overview cards with green health, `LT` / `RT` trigger labels, slot-colored ability cooldowns, and ability names
  - slot 1 cooldown color uses the player tint, slot 2 cooldown color is purple, and near-player cooldown rings match those bottom-HUD slot colors
  - side objective progress
  - dedicated side-objective panel with icon fallback, label, progress text, and progress bar
  - active modifier chips
  - endless room score label when applicable
- pause screen now shows:
  - full-screen dimmed backdrop with centered menu
  - per-player build summary
  - weapon stats
  - `LT` / `RT` ability cards
  - rarity-styled mutation chips with levels/tooltips
  - derived move / HP / fire-rate stats
  - no in-run Settings panel; main-menu Settings remains the binding surface
- mutation pick UI now shows:
  - simultaneous per-player picks
  - rare highlighting
  - current mutation inventory per player
  - leveled common progression (`Lv X -> Lv Y`)
- map UI now shows:
  - vertical bottom-to-top branching paths
  - custom-drawn combat / elite / boss nodes
  - colored modifier dots below nodes
  - per-node modifier shorthand on hover detail panel
  - nodes positioned by actual row membership (not fixed 5-column grid)
- pre-run UI now shows compact text-only ability selection with inline descriptions, `LT` / `RT` selected-slot labels, and slot-colored selected cards
- pre-run ability UI is split into `LT / OFF` and `RT / DEF` pickers per player
- arena visuals now use:
  - pure black floor
  - neon grid
  - act-colored border treatment
  - stronger enemy hit / death particles, including elite/boss debris rings
  - ability-specific activation flashes and hit sparks
  - boss-entrance and major-modifier screen/ring feedback
  - enemy projectiles are rendered bright red for readability
  - Fire Floor hazard zones are larger and more numerous than the first round-2 implementation
  - level-up VFX were removed because they read like a no-effect ability
  - round-7 level-ups now use a lightweight screen flash and procedural sting without mid-combat slow-mo
  - bloom/glow is enabled through HDR 2D plus a `WorldEnvironment`
  - managed hit-stop is routed through `HitStopManager.gd`; trash kills do not trigger it
  - projectile mutation shapes/trails/SFX make weapon mutations read more distinctly

## Active Systems

- `RunState.gd`
  - structured + endless generation
  - shared XP / banked picks
  - boss assignment
  - modifier assignment
  - side-objective assignment
  - player inventory and loadout state
- `CoopManager.gd`
  - room runtime
  - continuous time-based spawning
  - deferred enemy spawn pipeline for physics-safe child spawns
  - pooled projectile activation/deactivation
  - dedicated slow homing projectile path for Hydra orbs
  - capped boss add-wave budget for normal boss rooms
  - ability dispatch
  - reward sequencing
  - boss helper attacks
  - Pulsar EMP / beam helpers
  - elite add-wave spawning
  - modifier orchestration
  - side-objective orchestration
  - manual pause freeze / resume handling
- `Enemy.gd`
  - full enemy / elite / boss roster
  - slow / poison / shield / explosive-death handling
  - boss escalation logic, phase telegraphs, round-5 boss behavior reworks, boss deflector state, elite pressure patterns, elite Act 2 scaling, and staggered target refresh
- `MutationSystem.gd`
  - mutation compilation
  - loadout-gated ability rare filtering
  - ability rare effect compilation for equipped ability ids
  - act-weighted rare rolls
  - elite force-rare support
- `Bootstrap.gd`
  - run setup
  - per-player ability selection
  - main-menu VSync setting and runtime input rebinding
  - encounter builder wiring
- `RunFlow.gd`
  - structured map flow
  - endless room chaining
  - resolution screens

## Deferred / Missing

- no meta progression
- no multiple starting weapons
- no expanded ability-specific rare mutation pass beyond the two round-7 pilots
- no `3-4` player support
- no final art pass
- no formal automated gameplay validation

## Known Risks

- full live playtesting and balance validation still have not been run after the full V3 integration
- round-2 through round-7 tuning have passed headless validation; round-6 also has non-headless profiling harness data and a strong live performance report, but round-7 still needs full balance/readability/performance playtesting
- boss and elite behavior is implemented, but still likely needs feel tuning against real runs
- modifier stacking, projectile pooling, AI time-slicing, new boss add pressure, homing orbs, and endless pressure have not been manually stress-tested yet
- the rebuilt pause menu, new VFX density, swarm performance optimization, slot-colored HUD, Build HUD overhaul, and input binding menu have passed parse validation but still need controller/manual readability testing
- Pulsar teleport / EMP / beam, Hydra homing orbs, Hive shield/burrow, Warden leap pressure, and Elite Support minion spawning need live feel validation
- spawn timing values, opening burst size, base ramp, and anti-clump separation are first-pass and need playtesting
- the map UI is functional but compact — may need further polish for controller navigation
- `GoldPickup.gd` remains deleted; gold stub functions in `RunState.gd` remain (no-ops)
- `wave_count` fields in RunState node data are now unused dead data (harmless)
- objective-panel icons currently use simple letter fallback glyphs (`H` / `K` / `C`); acceptable for the current local build, but a later IconFactory/drawn-glyph polish pass would improve presentation
- Pulsar beam currently uses angle/range damage and does not raycast line-of-sight through walls; accept for now unless playtest reads unfair
- Hive shield and boss add pressure may make boss fights feel too long; validate before further tuning
- round-6 heavy boss add-waves are now shipped by default in normal boss rooms and still need focused balance/performance validation
- round-7 bloom, hit-stop, projectile mutation visuals/SFX, boss HP bar, and ability rare pilots are implemented but still need manual `1P` / `2P` feel and performance validation
- B3 Pulsar deflector-spawned adds remain unimplemented until the desired Pulsar deflector count/pattern is specified; B2 Pulsar spitter add-waves are shipped
- enemy visual draw reduction needs a manual readability check because shadow/outline nodes were removed
- `FireTrailZone` distance checks passed parse validation and warning cleanup but still need focused in-game correctness validation for player Fire Bullets damaging enemies and no friendly fire

## Next Step

Run manual validation for the current round-7 local build. Use `docs/development/playtest-round-7-plan.md` verification and checklist sections as the active playtest guide.

- continuous spawn pacing in `1P` and `2P` — does `35-45s` room duration feel right?
- first `30s` pressure — do the opening burst, `~5/s` rifle, spawn ramp, and multi-edge spawns feel active without overwhelming?
- Scanline readability, safe gaps, and performance
- endless difficulty scaling past room 20
- elite reward value, Act 2 scaling, add-wave pressure, spawn distance, and telegraphed pressure patterns
- boss escalation, phase transition, adds, heavy-attack feel, and round-5 boss-specific mechanics
- modifier readability under stacked late-game rooms
- Fire Floor `280px` / `7` zone pressure
- Blink movement-direction, arrival i-frames, and detonation feel
- Fire Bullets impact-pool balance, correctness, and performance
- real boss-room stress validation for shipped capped boss add-waves in `1P` and `2P`
- boss HP bar visibility, phase pips, and readability in `1P` and `2P`
- OFF/DEF picker usability and `LT = OFF` / `RT = DEF` mapping for both players
- hit-stop feel, especially that trash kills do not stutter dense rooms
- bloom readability and performance with DebugOverlay F3
- distinct projectile mutation visuals/SFX and player-green core readability
- loadout-gated ability rare pilots: `oc_piercing_overdrive` and `sw_resonance`
- projectile pooling / AI time-slicing / boss entity-load performance at `100-150+` enemies/projectiles
- ability selection usability on controller
- remapped keyboard/controller binding behavior from main-menu Settings
- map node readability at the new compact size
