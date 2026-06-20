# Current State

## Project Role

Godot `4.6.2` same-screen local co-op neon roguelite prototype.

The live runtime is now aligned to the `Feature Roadmap V3` redesign:

- target player count is `1-2`
- run modes are `Structured` and `Endless`
- the core economy is shared XP with room-end picks
- health resets at the start of every room
- meta progression and pre-run weapon unlock/selection remain deferred
- the round-14 weapon system is live: seven peer weapons, one active weapon, shared weapon level, and categorized upgrade cards

Current local runtime includes the playtest round-14 implementation on top of the round-13
tool-validated baseline and the round-9 Mutation-to-Weapon system rework. Boss rooms still run as
normal combat rooms with continuous add spawns, spawn the boss after `25s`, and clear immediately when
the boss dies. Round 14 adds manual aim, per-player controller ownership, Beam, Boomerang, Split, and
Momentum/Flow. Round 14 is implemented and tool-validated, including the follow-up controller movement
regression fix; manual playtest with real controllers is still pending.

## Current Runtime

- front menu paths:
  - `Play`
  - `Settings`
  - `Encounter Builder` in debug builds or when launched with `--debug-menu`
- pre-run setup now supports:
  - `1P` or `2P`
  - `Structured` or `Endless`
  - per-player starting weapon selection
  - per-player ability loadouts restricted to `1 OFF + 1 DEF`
  - slot order is fixed: `LT = OFF`, `RT = DEF`
- main-menu settings now support:
  - VSync toggle persisted via `user://video_settings.cfg`; first-run project default is enabled
  - keyboard rebinding for menu and active `1-2P` gameplay actions
  - controller button / axis rebinding for menu and active `1-2P` gameplay actions
  - per-player gamepad layouts persist device-agnostic; runtime gameplay actions are stamped to the assigned gamepad device
  - wildcard controller bindings are now polled against the assigned device at runtime, so saved layouts
    stay portable without one pad cross-driving both players
  - saved runtime bindings via `user://input_bindings.cfg`
  - reset to default bindings
  - audio sliders for Master / Music / SFX
  - rebindable debug overlay toggle, default `F4`
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
  - Act 1: `20%`
  - Act 2: `30%`
  - Endless: `40%`
- rare bad-luck protection is per-player and forces rare options after `3` non-rare pick rounds
- elite rooms grant one additional free pick round after XP picks resolve
- elite bonus rounds force at least one rare option per player if any legal rare remains
- gold, shops, rest nodes, and the old purchase loop are removed from the live runtime

## Loadout / Combat

- every player always has:
  - one active weapon, starting with `Rifle`
  - shared weapon level `1-5` that is preserved when changing weapons
  - faster base movement (`560` default speed)
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
- weapon fire defaults to nearest-target auto-targeting, with seamless right-stick / mouse manual override
- aim modes are `auto` (auto + manual override), `movement`, and `manual` (manual only)
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
- current round-8 tuning changed:
  - starter Rifle damage/fire-rate is buffed to make level-1 offense feel stronger
  - room duration, spawn interval, opening burst, and burst cadence now scale by normalized run progress instead of binary Act 1/Act 2 branches
  - enemy pool escalation remains the old act-based step; pool ramp is an explicit follow-up, not part of round 8
  - player/enemy/projectile/VFX colors use render-local `x1.45` over-bright bloom without mutating source tints or UI colors
  - generated SFX stay procedural through `AudioStreamGenerator`, with richer frame synthesis and an idempotent `SFX` bus limiter/reverb chain
- current round-9 tuning changed:
  - player HP is now `100`; enemy HP/damage and flat ability damage were rescaled around the new weapon model
  - active weapons are `Rifle`, `Rocket Launcher`, `Scattergun`, `Cannon`, and `Railgun`
  - reward screens can show `Level Up Weapon` common cards and rare `Change Weapon` cards
  - old weapon-shape mutations (`Split Shot`, `Big Shot`, `Pierce`, `Explosive Rounds`) were removed and folded into weapon identities
  - upgrade cards are grouped as `Weapon`, `Effect`, `Attribute`, and `Ability`
  - `High Caliber` and `Range` were added as attribute commons
  - seven new loadout-gated ability signatures were added: `Shockdash`, `Twin Charge`, `Aegis Burst`, `Volatile Decoy`, `Twin Turret`, `Expanding Orbit`, and `Extra Mines`
  - Player 2 can select and rebind gamepad controls; runtime gameplay actions are stamped to each player's assigned gamepad device
- current round-10 tuning changed:
  - room clear freezes runtime hazards/enemies/projectiles while reward/map UI is active
  - generated adaptive music runs on a dedicated `Music` bus; SFX are softer and routed through `SFX`
  - reward cards are denser and use a shared confirm hint
  - map route selection now shows only current route-choice cards with boss/elite/modifier/objective/enemy details
  - starting weapon selection is available before launch
  - `Minefield` is now instant, has `7s` cooldown, stacks mines, and uses `mine_lifetime` for duration scaling
  - Hive applies extra player-position pressure adds while respecting the boss add cap
  - bosses have a `2.5s` invulnerable entrance windup and delayed heavy attack tells
  - `Scanline` density is capped at `2` active sweeps with wider safe gaps and longer intervals
  - 2P camera tuning allows closer zoom and less padding
  - debug menu is gated by debug build / `--debug-menu`; in-room debug overlay supports live spawn, clear enemies, god mode, and weapon-level cheat
- current round-11 tuning changed:
  - arena size is reduced to `3000x1700`
  - shared 2P camera zoom is retuned to `0.60-0.80` while keeping padding unchanged
  - route options are guarded against identical room/enemy/modifier signatures
  - in-room debug overlay lists the full enemy/elite/boss roster and can set Player 1's active weapon live
  - boss rooms show an edge indicator when the active boss is off-screen
  - loadout ability cards are name-only while the selected summary keeps full descriptions
  - reward-card descriptions are one-line ellipsized
  - projectile visuals are rendered by reusable `ProjectileRenderer` MultiMesh batches keyed by `projectile_shape`
  - per-projectile `Visual` / `Outline` drawing and `GPUParticles2D` projectile trails are disabled; collision/state remain on pooled projectile nodes
- current round-12 tuning changed:
  - arena size is increased to `3600x2100`, shared camera zooms out to `0.45-0.65`, and player visuals are scaled `1.3x`
  - Rocket, Shotgun, Cannon, Shockwave, Overcharge, Blink, Shield, Decoy, Turret, Orbit, and HP pickup tuning are updated
  - Decoy is invincible for `3s` and taunts nearby enemies; Orbit visuals are larger and orbit bodies block enemy projectiles
  - 2P scales room spawns plus generic elite/boss add-waves by `1.5x` based on configured player count; boss-specific minion attacks remain unscaled
  - Scanline display names come from `modifiers.json`, and sweep spawning alternates vertical/horizontal axes when possible
  - Pulsar teleports more aggressively toward player movement, attacks sooner after telegraph, and leads player-position hazards in all phases
  - rendered combat VFX/projectile/enemy prewarm removes the first-use boss-attack hitch measured by PerfRunner heavy boss profiles
  - reward cards are compact with a selected-upgrade detail panel; Encyclopedia opens from the main menu and pause menu
  - downed players show an explicit revive progress marker
  - Encounter Builder removes starting-primary, room-step, starting mutation, starting level/XP, and launch-cheat controls
- current round-13 tuning changed:
  - camera padding is wider and close-player zoom is lowered to `0.52`; player visuals are `1.5x`
    and enemy visuals gain a draw-only `1.3x` readability multiplier
  - Overcharge cooldown is `16s`; Shockwave Resonance pulses are staggered by `0.4s`
  - revive radius is `150`
  - Ice Zone uses one shared `ice_zone` slow source so overlapping patches do not stack
  - Railgun uses explicit infinite pierce; the round-13 Ricochet wall-bounce behavior was superseded by
    round-14 Split
  - boss rooms spawn normal adds continuously, delay boss spawn by `25s`, disable generic boss
    add-waves, and clear immediately on boss death
  - reward picks stay locked per confirmed player until `ui_cancel` unconfirms them; finalization still
    requires all players confirmed
  - Encyclopedia ability entries show active duration/cooldown; the round-13 boss marker behavior was
    superseded by round-14 removal of the boss off-screen arrow
  - boss-hit shake/hit-stop feedback is throttled to reduce perceived screen-shake stutter under
    sustained fire
- current round-14 tuning changed:
  - active weapons are now `Rifle`, `Rocket Launcher`, `Shotgun`, `Cannon`, `Railgun`, `Beam`, and `Boomerang`
  - Cannon is slower/heavier with no pierce or knockback; Shotgun spread is tighter and no longer has weapon knockback
  - Dash cooldown is `1.5s`; Overcharge cooldown is `12s`
  - player visuals are `1.35x`, enemy readability scale is `1.2x`, close-player zoom is `0.56`, and floor-grid lines are antialiased
  - boss off-screen arrow indicator is removed; boss health/phase HUD remains
  - Ricochet is repurposed as `Split`: projectile hits spawn one pooled follow-up shot at the nearest other enemy
  - Beam is a continuous line weapon with `0.1s` ticks, per-target dwell-ramp damage, Beam-specific upgrade compilation, and one refreshed fire pool per beam when Fire Bullets is active
  - Boomerang travels out and returns, with separate outbound/return hit tracking so enemies can be hit once per leg
  - Momentum/Flow is live: shared kill gain, per-player damaging-hit tier loss, four HUD pips, player aura, and additive uncapped move/fire-rate bonuses
  - weapon/player percent bonuses now use additive accumulation (`base * (1 + sum(percent bonuses))`) for move speed, fire rate, and damage sources
  - controller movement/aim/abilities now use `PlayerConfig.uses_gamepad()` / `uses_keyboard()` so `Hybrid` remains hybrid and `Gamepad` remains device-owned
  - mutation-pick direction/confirm/cancel also respects controller-capable configs after the movement regression fix
- player mutation visuals are now partially wired:
  - projectile streaks for high `Rapid Fire` / `Velocity`
  - speed-line feedback for `Move Speed`
  - cooldown crackle feedback for `Quick Reflexes`
  - stronger player glow for `Tough` / `Overcharge`
  - behavior-changing projectile mutations now alter projectile shape, trail/accent, and impact SFX while keeping the player-tint core

## Content State

- live common mutations:
  - `rapid_fire`
  - `velocity`
  - `high_caliber`
  - `range`
  - `quick_reflexes`
  - `wide_pulse`
  - `duration`
  - `move_speed`
  - `tough`
- live weapons:
  - `Rifle`
  - `Rocket Launcher`
  - `Shotgun`
  - `Cannon`
  - `Railgun`
  - `Beam`
  - `Boomerang`
- live universal weapon rares:
  - `ricochet` / `Split`
  - `fire_trail`
  - `freeze_shot`
  - `poison`
- live loadout-gated ability rares:
  - `oc_piercing_overdrive` requires `Overcharge`
  - `sw_resonance` requires `Shockwave`
  - `dash_shockdash` requires `Dash`
  - `blink_twin_charge` requires `Blink`
  - `shield_aegis_burst` requires `Shield`
  - `decoy_volatile` requires `Decoy`
  - `turret_twin` requires `Turret`
  - `orbit_expanding` requires `Orbit`
  - `mf_extra_mines` requires `Minefield`
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
  - one-line ellipsized reward descriptions
- map UI now shows:
  - vertical bottom-to-top branching paths
  - custom-drawn combat / elite / boss nodes
  - colored modifier dots below nodes
  - per-node modifier shorthand on hover detail panel
  - nodes positioned by actual row membership (not fixed 5-column grid)
- pre-run UI now shows compact text-only ability selection with name-only cards, `LT` / `RT` selected-slot labels, slot-colored selected cards, and selected OFF/DEF summary descriptions
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
  - projectile mutation shapes/SFX make weapon mutations read more distinctly; projectile trails are currently removed for readability/performance

## Active Systems

- `RunState.gd`
  - structured + endless generation
  - shared XP / banked picks
  - boss assignment
  - modifier assignment
  - side-objective assignment
  - player inventory and loadout state
  - active weapon id and shared weapon level
- `CoopManager.gd`
  - room runtime
  - continuous time-based spawning
  - deferred enemy spawn pipeline for physics-safe child spawns
  - pooled projectile activation/deactivation
  - dedicated slow homing projectile path for Hydra orbs
  - capped boss add-wave budget for normal boss rooms
  - Beam, Boomerang, Split, Momentum, boss health/phase HUD, and controller-owned local co-op input
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
  - weapon card generation for level-up and weapon swap rewards
  - active weapon stat compilation
  - loadout-gated ability rare filtering
  - ability rare effect compilation for equipped ability ids
  - act-weighted rare rolls
  - elite force-rare support
- `Bootstrap.gd`
  - run setup
  - per-player ability selection
  - main-menu VSync setting and runtime input rebinding
  - per-player controller ownership and main-menu input rebinding
  - encounter builder wiring
- `RunFlow.gd`
  - structured map flow
  - endless room chaining
  - resolution screens

## Deferred / Missing

- no meta progression
- no meta weapon unlocks
- no additional ability signatures beyond the round-9 set
- no `3-4` player support
- no final art pass
- no formal automated gameplay validation

## Known Risks

- full live playtesting and balance validation still have not been run after the full V3 integration
- round-2 through round-14 tuning have passed headless validation; round-6, round-11, round-12, and
  round-13 also have non-headless profiling data, but round-14 still needs full
  balance/readability/performance playtesting
- boss and elite behavior is implemented, but still likely needs feel tuning against real runs
- modifier stacking, projectile pooling, AI time-slicing, new boss add pressure, homing orbs, and endless pressure have not been manually stress-tested yet
- the rebuilt pause menu, new VFX density, swarm performance optimization, slot-colored HUD, Build HUD overhaul, and input binding menu have passed parse validation but still need controller/manual readability testing
- Pulsar teleport / EMP / beam, Hydra homing orbs, Hive shield/burrow, Warden leap pressure, and Elite Support minion spawning need live feel validation
- spawn timing values, opening burst size, base ramp, and anti-clump separation are first-pass and need playtesting
- the map UI is functional but compact — may need further polish for controller navigation
- `GoldPickup.gd` remains deleted; `RunState.gd` is already clean of gold (no stub functions remain)
- `wave_count` fields in RunState node data are now unused dead data (harmless)
- objective-panel icons currently use simple letter fallback glyphs (`H` / `K` / `C`); acceptable for the current local build, but a later IconFactory/drawn-glyph polish pass would improve presentation
- Pulsar beam currently uses angle/range damage and does not raycast line-of-sight through walls; accept for now unless playtest reads unfair
- Hive shield and boss add pressure may make boss fights feel too long; validate before further tuning
- round-6 heavy boss add-waves are now shipped by default in normal boss rooms and still need focused balance/performance validation
- round-7 bloom, hit-stop, projectile mutation visuals/SFX, boss HP bar, and ability rare pilots are implemented but still need manual `1P` / `2P` feel and performance validation
- B3 Pulsar deflector-spawned adds remain unimplemented until the desired Pulsar deflector count/pattern is specified; B2 Pulsar spitter add-waves are shipped
- enemy visual draw reduction needs a manual readability check because shadow/outline nodes were removed
- `FireTrailZone` distance checks passed parse validation and warning cleanup but still need focused in-game correctness validation for player Fire Bullets damaging enemies and no friendly fire
- round-9 weapon cards, active weapon switching, shared weapon level, weapon-specific fire patterns, and ability signatures are implemented but still need manual `1P` / `2P` feel validation
- Round 14 controller ownership, manual aim, Momentum, Beam, Boomerang, Split, and the controller movement regression fix have passed headless validation but still need live 1P/2P feel testing with real controllers
- round-11 `entity_ramp` at `200 enemies + 200 projectiles` still reports roughly `40-50 FPS` because enemies remain per-node; real round-11 `boss:pulsar --players=2 --build=heavy` measured far above target, so enemy MultiMesh remains deferred unless live playtest contradicts the real-room result

## Next Step

Round 14 is playtested and committed (`5bf529a`), including the three post-playtest fixes (faint aim
reticle, continuous beam, HP-as-ring-after-damage). The active direction is now the **structure rework
("trim")** in `docs/development/structure-rework-plan.md` — design-locked, not implemented. Next
implementation task is **Phase 1: strip the branching map** (linear room sequence + flat risk/reward
choice card), then choice card → champions → mode framing → enemy re-tune (last).

The round-14 checklist below remains valid for any further balance/feel passes:

Manual validation focus for the round-14 build (`docs/development/playtest-round-14-plan.md`): P1/P2 controller ownership, controller movement after the regression fix, manual aim feel, Momentum pacing/loss, Beam ramp behavior, Boomerang double-hit readability, Split targeting, additive stat balance, and the smaller player/enemy/zoom readability pass.

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
- real boss-room stress validation for delayed boss combat rooms in `1P` and `2P`
- boss HP bar visibility, phase pips, and readability in `1P` and `2P`
- OFF/DEF picker usability and `LT = OFF` / `RT = DEF` mapping for both players
- hit-stop feel, especially that trash kills do not stutter dense rooms
- bloom readability and performance with DebugOverlay F3
- distinct projectile mutation visuals/SFX and player-green core readability
- loadout-gated ability rare pilots: `oc_piercing_overdrive` and `sw_resonance`
- projectile pooling / AI time-slicing / boss entity-load performance at `100-150+` enemies/projectiles
- ability selection usability on controller
- remapped keyboard/controller binding behavior from main-menu Settings
- P1/P2 controller ownership; one controller must not move/control both players
- controller movement, right-stick aim, OFF/DEF triggers, and mutation-pick confirm/cancel in `1P` and `2P`
- weapon level-up cards, weapon swap cards, shared weapon level preservation, and all seven weapon firing profiles
- new ability signatures: Shockdash, Twin Charge, Aegis Burst, Volatile Decoy, Twin Turret, Expanding Orbit, Extra Mines
- map node readability at the new compact size
- Round 11 arena shrink + camera retune in `1P` and `2P`
- Encounter Builder full spawn list and live weapon selector
- loadout/reward text density after truncation
- route choices are actually differentiated
- real Pulsar-heavy projectile performance after MultiMesh projectile rendering
