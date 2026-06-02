# Current State

## Project Role

Godot `4.6.2` same-screen local co-op neon roguelite prototype.

The live runtime is now aligned to the `Feature Roadmap V3` redesign:

- target player count is `1-2`
- run modes are `Structured` and `Endless`
- the core economy is shared XP with room-end picks
- health resets at the start of every room
- meta progression, multiple starting weapons, and ability-specific rare mutations remain deferred

## Current Runtime

- front menu paths:
  - `Play`
  - `Encounter Builder`
- pre-run setup now supports:
  - `1P` or `2P`
  - `Structured` or `Endless`
  - per-player `pick 2` ability loadouts from the full 9-ability roster
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
  - faster starter `Rifle` (`~4 shots/sec`)
  - `2` equal ability slots
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
- player mutation visuals are now partially wired:
  - projectile streaks for high `Rapid Fire` / `Velocity`
  - speed-line feedback for `Move Speed`
  - cooldown crackle feedback for `Quick Reflexes`
  - stronger player glow for `Tough` / `Overcharge`

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
- high-count combat target lookups now use the same nearby-enemy grid for player auto-targeting, turret targeting, orbit hits, ability mine checks, ricochets, and player AOE explosions where applicable
- nonessential combat hit VFX are throttled during very dense fights to reduce particle/ring allocation spikes
- HP pickups now drop from non-boss enemy kills:
  - `~10%` chance
  - `5 HP` heal
  - magnet pickup behavior
- side objectives now use the roadmap set:
  - `Hold Zone`
  - `Kill Streak`
  - `Collector`
- completing a side objective grants one temporary room buff:
  - `Speed`
  - `Damage`
  - `Attack Speed`
- live modifiers now use the roadmap set:
  - minors: `Accelerating Waves`, `Enemy Speed`, `Swarm`, `Shielded`, `Explosive Death`
  - majors: `Fire Floor`, `Ice Zone`, `Mine Field`, `Shrinking Arena`
  - `Gravity Wells` was removed after playtesting because its effect was not readable enough
- `Mine Field` sweeps now use softened damage with a per-sweep/per-player hit cooldown to prevent frame-stacked one-shots

## UI / Presentation

- combat HUD now shows:
  - top-center XP bar + level + pending picks
  - near-player cooldown arcs
  - persistent near-player health bars
  - bottom loadout overview cards with green health, slot-colored ability cooldowns, ability names, and mutation count
  - slot 1 cooldown color uses the player tint, slot 2 cooldown color is purple, and near-player cooldown rings match those bottom-HUD slot colors
  - side objective progress
  - active modifier chips
  - endless room score label when applicable
- pause screen now shows:
  - full-screen dimmed backdrop with centered menu
  - per-player build summary
  - equipped abilities
  - current mutations with levels
  - disabled `Settings` placeholder (`Coming soon`)
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
- pre-run UI now shows compact text-only ability selection (no large icons)
- arena visuals now use:
  - pure black floor
  - neon grid
  - act-colored border treatment
  - stronger enemy hit / death particles, including elite/boss debris rings
  - ability-specific activation flashes and hit sparks
  - level-up, boss-entrance, and major-modifier screen/ring feedback
  - enemy projectiles are rendered bright red for readability
  - Fire Floor hazard zones are larger than the first round-2 implementation

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
  - ability dispatch
  - reward sequencing
  - boss helper attacks
  - modifier orchestration
  - side-objective orchestration
  - manual pause freeze / resume handling
- `Enemy.gd`
  - full enemy / elite / boss roster
  - slow / poison / shield / explosive-death handling
  - boss escalation logic
- `MutationSystem.gd`
  - mutation compilation
  - act-weighted rare rolls
  - elite force-rare support
- `Bootstrap.gd`
  - run setup
  - per-player ability selection
  - encounter builder wiring
- `RunFlow.gd`
  - structured map flow
  - endless room chaining
  - resolution screens

## Deferred / Missing

- no meta progression
- no multiple starting weapons
- no ability-specific rare mutation pass
- no `3-4` player support
- no final art pass
- no formal automated gameplay validation

## Known Risks

- full live playtesting and balance validation still have not been run after the full V3 integration
- round-2 tuning has passed headless validation but still needs live playtesting
- boss behavior is implemented, but still likely needs feel tuning against real runs
- modifier stacking and endless pressure have not been manually stress-tested yet
- the rebuilt pause menu, new VFX density, swarm performance optimization, and slot-colored HUD have passed parse validation but still need controller/manual readability testing
- Pulsar teleport and Elite Support minion spawning need live feel validation
- spawn timing values, opening burst size, base ramp, and anti-clump separation are first-pass and need playtesting
- the map UI is functional but compact — may need further polish for controller navigation
- `GoldPickup.gd` remains deleted; gold stub functions in `RunState.gd` remain (no-ops)
- `wave_count` fields in RunState node data are now unused dead data (harmless)

## Next Step

Run manual validation across:

- continuous spawn pacing in `1P` and `2P` — does `35-45s` room duration feel right?
- first `30s` pressure — do the opening burst, faster rifle, spawn ramp, and multi-edge spawns feel active without overwhelming?
- minefield survivability — no sweep/mine one-shot behavior
- endless difficulty scaling past room 20
- elite reward value
- boss escalation feel
- modifier readability under stacked late-game rooms
- ability selection usability on controller
- map node readability at the new compact size
