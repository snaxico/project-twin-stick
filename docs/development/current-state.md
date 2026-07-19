# Current State

## Project Role

Godot `4.6.2` same-screen local co-op neon roguelite prototype.

The canonical development line is `v4/class-system`. Continue new work from
`D:\GameDev\Project_Twin_stick`; older `v2/*` and `v3/*` branches are archived references only, not the active
project state. V4 Slices 0-7 of `docs/development/v4-implementation-plan.md` are implemented and validated: class
data loads, existing weapons/abilities have tags, the runtime kit stores four abilities, P1/P2 abilities are
bound to face buttons, and the pre-run setup now selects class -> class weapon -> three class abilities with
the class ultimate inserted into slot 4. Mutations now gate through the V4 tag rule: `requires` must be a
subset of the equipped kit's tags, with `apply` describing the effect target layer. Existing player
deployables now share a destructible HP interface and no longer self-expire by lifetime. Class passives now
drive runtime behavior for Mobile, Tank, Controller, and Risk. The three new class weapons now have real
attack kinds instead of placeholder bullets. The new class abilities and ultimates now have first-pass runtime
behavior, and Mobile/Tank/Controller ultimates charge from combat while Risk's Firestorm gates from Heat.
Meta unlocks now gate only premium build-depth mutations; all classes, class-pool weapons, class-pool
abilities, ultimates, and base mutations are free.

## Current Runtime

- Front menu paths:
  - `Play`
  - `Meta`
  - `Settings`
  - `Encounter Builder` in debug builds or when launched with `--debug-menu`
- There is one run mode. The old Structured / Endless split and pre-run mode selector are removed.
- A run is a linear room sequence:
  - normal steps show two next-room cards
  - champion steps show one forced champion card
  - room `10` is the current milestone champion room
  - clearing the milestone banks a win and offers `Continue` or `End Run`
  - continuing keeps generating rooms past the milestone with the same scaling path
- The branching map UI and graph generation are removed.
- Health resets each room because `CoopManager` / `GameWorld` is recreated per room.
- Momentum now persists across the run through `RunState`; it resets only at run start and still drops by two tiers on damaging hits.
- Current run score now lives in `RunState`, displays in-run, and banks once to `ProfileState` on terminal run end.
- Presentation has a dark neon arena with runtime-pulsed grid/walls, player-proximity grid highlights,
  subtle major-hazard room tinting, distinct enemy silhouettes/motion, projectile pulse/spin, broader
  procedural SFX coverage, reactive music contexts, and room-start / room-clear transition polish.

## Progression Loop

- Enemy kills feed one shared XP bar.
- Level-ups bank room-end pick rounds.
- In co-op, both players level together and each gets an independent pick per round.
- Champion rooms grant one additional forced-rare reward pick after XP picks resolve.
- Reward picks support shared-score rerolls and free skips.
- Rare odds now use a continuous depth curve, with a small per-room nudge on the higher-danger route.
- The old purchase loop remains removed; meta progression is now a banked-score unlock pool.
- Upgrade rolls support common / rare / Signature rarity. Signature upgrades include tag amplifiers,
  transformers, and parasites.
- Upgrade eligibility now checks exact equipped abilities for ability-specific upgrades. The generic Area and
  Duration upgrades appear only when the kit contains an explicitly scalable ability and affect only those
  flagged abilities; Piercing Overdrive additionally requires a projectile weapon.
- Tags currently seed Fire, Frost, Toxic, Split, Momentum, and Pierce build axes.
- Retired stat-stick weapon mutations (`rapid_fire`, `velocity`, `high_caliber`, `range`) are removed from
  mutation data and no longer compile into weapon stats.

## Loadout / Combat

- Target player count is `1-2`.
- Every player always has:
  - one active weapon, starting with `Rifle`
  - shared weapon level `1-5` preserved when changing weapons
  - four ability slots on controller face buttons: `A`, `X`, `B`, `Y`
  - keyboard defaults for P1/P2 ability slots on number-row `1`, `2`, `3`, `4`
  - mutation inventory
- V4 removed in-run weapon switching. A run has one active weapon selected before launch.
- Pre-run setup selects each player's class, one weapon from that class pool, and three abilities from that
  class pool; the class ultimate auto-equips into the fourth face-button slot.
- Same-class co-op is allowed.
- Current class data:
  - `mobile` / Stormrunner: rifle or beam; Dash, Shockwave, Afterburn, Momentum Burst, Deflect, Sonic Boom; ultimate Slipstream.
  - `tank`: Shotgun or Whirlwind; Dash, Ground Slam, Quake, Orbit, Overcharge, Blood Lance; ultimate Blood Frenzy.
  - `controller`: Beam or Arc Wand; Dash, Turret, Minefield, Orbit, Summon, Reinforce; ultimate Overload Grid.
  - `risk`: Flamethrower or Rocket Launcher; Dash, Overcharge, Shockwave, Shield, Fireball, Ignite; ultimate Firestorm.
- Forward-referenced Slice 5-6 weapons, abilities, and ultimates have been replaced with first-pass runtime
  behavior.
- Live weapons:
  - `Rifle`
  - `Rocket Launcher`
  - `Shotgun`
  - `Beam`
  - `Whirlwind` (`melee`): short-radius swing that hits all nearby enemies.
  - `Arc Wand` (`chain`): lightning hit that jumps between nearby enemies.
  - `Flamethrower` (`cone`): short forward cone with sustained tick damage and burn.
- Live ability roster:
  - `Shockwave`
  - `Dash`
  - `Overcharge`
  - `Shield`
  - `Turret`
  - `Minefield`
  - `Orbit`
  - `Afterburn`: player-following wake that emits overlapping burning trail segments
  - `Momentum Burst`: radial blast that scales with Momentum tier
  - `Deflect`: destroys nearby enemy projectiles and pulses damage
  - `Sonic Boom`: fast piercing line projectile
  - `Ground Slam`: heavy radial blast
  - `Quake`: persistent damaging rupture field
  - `Blood Lance`: hard piercing line projectile
  - `Summon`: persistent melee constructs using the deployable HP contract
  - `Reinforce`: repairs nearby player deployables
  - `Fireball`: explosive fire projectile with fire pool
  - `Ignite`: applies burn and ignite-on-death bursts
  - `Slipstream`: Mobile ultimate speed/attack/damage burst plus projectile clear
  - `Blood Frenzy`: Tank ultimate damage/attack burst plus immediate Bloodthirst heal
  - `Overload Grid`: Controller ultimate deployable repair plus overcharged constructs
  - `Firestorm`: Risk Heat-gated ultimate that vents into burning zones
- The locked fourth ability slot is the ultimate slot. Mobile/Tank/Controller ultimates use `UltimateCharge`
  and fill from credited damage/kills; Firestorm is gated by Risk Heat. Unready ultimate presses are no-ops,
  and activation resets the relevant meter.
- All class-pool weapons, abilities, ultimates, and base mutations are free from the start. The paid Meta
  pool is limited to premium signature/parasite mutations.
- Mutation offers are filtered by equipped class/passive/weapon/ability/ultimate tags plus selected mutation
  tags. Pierce requires `projectile`, Combustion requires `risk`, and Overgrowth requires a `summon` item.
- The old in-run weapon-switch reward cards are removed; weapon level-up remains as the weapon reward card.
- Existing player deployables (`Turret`, `Orbit`, `Summon`, and player `Minefield` mines) use the shared
  `DeployableNode` HP/damage/death contract and participate in `player_deployable`, not enemy aggro targeting.
- Player deployables persist until destroyed, triggered, or their owner disappears; their old lifetime
  countdown despawn paths are removed.
- Class passives:
  - Mobile Momentum is class-exclusive; non-Mobile players stay at Momentum tier `0`.
  - Tank Bloodthirst heals on kills credited to the Tank and converts full-HP kills into decaying overshield.
  - Controller Radiance boosts summon/deployable stats and applies a nearby ally/self damage aura.
  - Risk Overheat fixes ability cooldowns at `0.5s`, builds Heat on every ability cast, decays Heat after a
    short idle delay, and scales outgoing damage plus incoming damage taken.
- Aim modes are `auto`, `movement`, and `manual`.

## Encounter Systems

- V4 room redesign is implemented on `v4/class-system`:
  - combat rooms are built from WHO (`composition`) + WHERE (`where`) + TWIST (`modifiers`)
  - normal room archetypes are Horde, Mixed, Splitters, Pressure, and Gauntlet
  - former `elite_*` enemies are champion-only and no longer spawn through normal compositions
  - route cards show archetype, danger, up to two WHERE/TWIST chips, and reward odds
  - spitter is now a capped ranged special with a 0.45s telegraphed 3-shot fan
  - WaveDirector reserves the global shooter budget at spawn selection and releases it on cancellation/death
- Implemented WHERE mechanics:
  - Fire/Frost Hazard Floors use deterministic expanding damage patches with telegraph/grow/hold/fade phases;
    Mine Floor retains its roam-and-avoid moving-safe-zone geometry
  - Roaming Sawblades, Tesla Arcs, Drifting Clouds
  - Bastion, Pop-up Pillars, Drifting Cover
  - Sweeping Laser Lanes with a fixed co-op opening and alternating horizontal/vertical sweeps
- Every non-open WHERE has three hidden deterministic layouts with no immediate selected-layout repeat;
  Fire/Frost/Mine share one Hazard Floor family history. Retries reuse the selected layout and seed.
- All WHERE damage targets players only. Fire/Frost patch layouts preserve a traversable safe-cell component;
  Sawblades use a `42px` blade radius, maintain a 120px dodge lane, and cannot pair with Shrinking Arena;
  Pop-up Pillars use three irregular
  nine-pillar layouts with connectivity-gated obstacle rebuilds. Drifting Cover applies moves transactionally
  and retries rejected layouts without desynchronizing visuals from collision.
- Physical cover is owned by `CoopManager.rebuild_obstacles`; mechanics declare rect sets, while CoopManager
  validates bounds/connectivity, rebuilds flow targets, and relocates stranded enemies, pickups, and
  `player_deployable` nodes.
- FlowField Phase 4/4b landed: obstacle inflation is `40`, sample reads precomputed vectors,
  `has_target_field` exists for reachability checks, nearest-reachable escape vectors are built with a
  reverse BFS, target-field rebuilds are rate-limited per player, and the flow grid is `150px`. The latest
  `flowfield_stress` run is no longer flow-field dominated and reached `59.4` avg FPS at 200 enemies; the
  remaining bottleneck is general physics/body movement at the synthetic 200-enemy + 200-projectile load.
- That residual physics cost only occurs with physical cover (enemies bunching around obstacles), so rooms with
  a Batch-B cover WHERE cap concurrent enemies at `WaveDirector.MAX_OBSTACLE_ENEMIES = 160` (gated on
  `CoopManager.has_flow_obstacles()`); open/hazard rooms stay uncapped. Keeps cover rooms ≥60fps and readable;
  the perf probes inject 200 directly and intentionally bypass the cap.
- Rooms support two debug-switchable time-based spawn models:
  - `trickle` remains the normal-run default
  - `pulsed` groups only the continuous stream into `4.0s` pulses spread over `0.8s`; opening and periodic
    bursts are unchanged
  - opening burst at room start
  - enemies spawn on a timer until room duration expires
  - room clears when spawning is done and all enemies are dead
  - modifiers can alter spawn pressure, speed, shields, explosions, and arena hazards
- Enemy pool, room duration, spawn interval, burst pressure, modifier pressure, champion pressure, and
  rare odds now scale by continuous depth.
- Early rooms have stronger chasers/chargers, tighter spawn cadence, larger bursts, fewer HP drops, and a
  higher kill-streak objective target.
- Continuation rooms past the milestone keep escalating through a soft-capped pressure curve instead of
  plateauing at room `10`.
- Arena color is a single fixed neon treatment; acts are removed.
- Champion rooms are normal wave rooms with one champion dropping in partway through the fight.
- Champion pool:
  - `Champion Warden`
  - `Champion Hydra`
  - `Champion Hive`
  - `Champion Pulsar`
  - `Champion Charger`
  - `Champion Spitter`
  - `Champion Support`
- Former elite IDs (`elite_charger`, `elite_spitter`, `elite_support`) are kept internally as stable enemy IDs.
- Former boss IDs (`boss_warden`, `boss_hydra`, `boss_hive`, `boss_pulsar`) are kept internally as stable enemy IDs.
- Dedicated boss rooms, boss phase pips, boss add-wave budgets, boss entrance windup, elite rooms, elite add-waves, and elite act scaling are removed.

## UI / Tooling

- `CoopManager.gd` is still the in-room orchestrator and `Enemy._combat_owner` facade, but the
  decomposition has started with stateless helpers extracted:
  - `CoopFormat.gd` owns room/boss/modifier/buff text, slot color, overbright color, and rarity rank helpers.
  - `EnemyTypes.gd` owns champion ID/classifier helpers.
  - `ArenaGeometry.gd` owns pure spawn-position, spread-direction, and segment-distance math.
  - `ProjectileSystem.gd` owns projectile pooling, beams, homing orb updates, projectile impact/split
    callbacks, and projectile VFX suppression while `CoopManager.gd` keeps the signal entry points and
    combat-owner facade delegators. Player target lookup remains centralized on `CoopManager.gd`.
  - `ArenaVisuals.gd` owns floor polygon setup, grid/wall visuals, collision-bound sizing, exit-zone/camera
    arena setup, arena color application, and the grid pulse tick.
  - `GameHud.gd` owns in-room HUD construction/refresh, player combat indicators, revive markers, bottom
    player cards, modifier chips, boss health, and objective panel presentation. `CoopManager.gd` keeps
    wrapper call sites and exposes read-only room/player/objective accessors for the HUD.
  - `WaveDirector.gd` owns spawn cadence/scaling/progress, deferred enemy spawn queues, opening/burst/stream
    spawns, champion spawn timing, and the active boss pointer. `CoopManager.gd` still owns `_enemy_nodes`,
    enemy death/fire/hit callbacks, room clear handling, and the combat-owner facade.
  - `SideObjectiveController.gd` owns hold-zone / kill-streak / collector state, temp-buff reward
    application, collector orb spawning, side-objective HUD view data, and clear-summary side-objective text.
    `CoopManager.gd` forwards enemy-killed and player-damaged events in the same runtime order.
  - `MomentumTracker.gd` owns per-player momentum progress/tier persistence, momentum tier application,
    tier feedback, and the room max momentum tier used by scoring.
  - `MutationPickFlow.gd` owns Upgrade pick UI lifetime, option rolling, reroll/skip requests, reroll costs,
    and reroll score spending. `CoopManager.gd` keeps the room-progression ladder and `_awaiting_mutation_pick`
    runtime gate.
  - `CombatEffects.gd` owns the enemy-facing combat-effect bodies and scheduled effect queues: shockwaves,
    hazard zones, minion bursts/mixes, support aura, Pulsar EMP, enemy attack trails, enemy death explosions,
    and player shockwave pulses. `CoopManager.gd` keeps facade methods, shared runtime helper lists, and
    hazard registration.
  - `PauseDebugUi.gd` owns pause panel wiring/runtime freeze, the pause Build overlay, encyclopedia launch,
    debug overlay construction/actions, and pause input proxy handling. `CoopManager.gd` exposes only the
    runtime node groups, loadout/HUD callbacks, and restart/menu callbacks that the helper needs.
- `RunFlow.gd` now owns:
  - next-room choice panel
  - room launch
  - clear/fail/milestone resolution screens
- `Bootstrap.gd` now owns:
  - single Play setup
  - player/controller/class/loadout setup
  - Options input binding rows for `Ability 1 A`, `Ability 2 X`, `Ability 3 B`, and `Ability 4 Y`
  - Meta unlock menu backed by `ProfileState`
  - Encounter Builder with `Combat / Champion`
  - champion picker over all seven champions
- Encyclopedia entries label all heavy enemies as champions and show classes, class pools, weapons,
  abilities/ultimates, upgrades, modifiers, and system rules from live catalogs where possible.
- PerfRunner uses `champion:<id>` profiles for champion-in-wave profiling.
- `scripts/ui/MapNodeButton.gd` is deleted.

## Validation

Last validation run in this state:

- `git diff --check`
- Godot warning hygiene is clean for the July 14 patch: the Enemy RNG seed parameter no longer shadows the
  built-in `seed`, WaveDirector no longer mixes Dictionary/Array values in a ternary, and FlowField's nearest
  passable-cell search no longer redeclares parent-scope locals.
- Godot headless parse:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick --quit`
- Bootstrap scene headless smoke boot:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick res://scenes/ui/Bootstrap.tscn --quit`
- PerfRunner Hive champion profile:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick -- --profile=champion:hive --players=2 --build=heavy`
  - Result: `avg_fps=144.4`, `min_fps=143.0`, `max_frame_ms=12.436`.
- Slice 2 data-level tag acceptance:
  - projectile kit: Pierce eligible
  - cone/melee kits: Pierce ineligible
  - Risk kit: Combustion eligible
  - non-Risk kit: Combustion ineligible
  - no-summon kit: Overgrowth ineligible
- Latest PerfRunner result after Slice 2:
  - `avg_fps=144.7`, `min_fps=143.0`, `max_frame_ms=19.251`.
- Original Slice 3 deployable health acceptance:
  - temporary Godot script instantiated the then-current deployable set and verified partial/lethal damage
  - polish later split deployable contact damage from enemy aggro targeting
  - result: `deployable_health_check=passed`
- Latest PerfRunner result after Slice 3:
  - `avg_fps=144.9`, `min_fps=144.0`, `max_frame_ms=6.903`.
- Latest PerfRunner result after Slice 4:
  - `avg_fps=144.9`, `min_fps=144.0`, `max_frame_ms=6.903`.
- Slice 5 weapon-kind acceptance:
  - temporary Godot script verified `melee`, `cone`, and `chain` paths damage expected fake enemies
  - result: `weapon_kind_check=passed`
- Latest PerfRunner result after Slice 5:
  - `avg_fps=144.9`, `min_fps=144.0`, `max_frame_ms=6.944`.
- Slice 6 ability/ultimate acceptance:
  - temporary Godot script verified all new ability/ultimate ids have non-placeholder stats/descriptions
  - `UltimateCharge` fills from damage and resets the player-facing meter
  - result: `ability_slice6_check=passed`
- Latest PerfRunner result after Slice 6:
  - `avg_fps=145.0`, `min_fps=144.0`, `max_frame_ms=6.944`.
- Slice 7 unlock acceptance:
  - retired paid unlock ids are absent from `ProfileState.UNLOCK_TABLE`
  - paid mutation unlock ids all resolve to mutations in `data/mutations.json`
  - premium per-class unlocks are marked `signature`
- Latest PerfRunner result after Slice 7:
  - `avg_fps=144.9`, `min_fps=144.0`, `max_frame_ms=6.944`.
- V4 polish implementation validation:
  - JSON parse for `data/weapons.json`, `data/abilities.json`, and `data/mutations.json`
  - `git diff --check`
  - Godot headless parse:
    `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick --quit`
  - Bootstrap smoke boot:
    `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick res://scenes/ui/Bootstrap.tscn --quit`
  - PerfRunner Hive champion profile:
    `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick -- --profile=champion:hive --players=2 --build=heavy`
    - Result: `avg_fps=145.0`, `min_fps=144.0`, `max_frame_ms=6.944`.
- Post-review PerfRunner rerun for the V4 polish density/VFX check:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick -- --profile=champion:hive --players=2 --build=heavy`
    - Result: `avg_fps=144.9`, `min_fps=144.0`, `max_frame_ms=6.944`.
- V4 arena/balance follow-up acceptance:
  - focused runtime check passed WHERE history/reset, all nine Hazard Floor phase/mine geometries,
    players-only damage routing, Tank exact-fill/cap behavior, and capped real-damage-only Wake healing
  - all `10` non-open WHERE IDs passed variants `0/1/2` through PerfRunner smoke (`30/30`)
  - post-implementation review hardened physical-cover smoke validation so an empty obstacle set fails;
    Bastion, Popup Pillars, and Drifting Cover pass every variant in both `1P` and `2P`
  - deterministic pre entity-ramp 160: `101.4/88.6/99.3` FPS (median `99.3`)
  - deterministic post entity-ramp 160: `93.4/90.9/100.8` FPS (median `93.4`, passes `>=89.4` retention)
  - deterministic pre flow-field 160: `55.2/53.1/57.5` FPS
  - deterministic post flow-field 160: `53.7/50.3/51.3` FPS; the required all-runs `>=60` gate failed
- Clustered contact-swarm performance check after bounding enemy separation:
  - Temporary dev scene spawned `25/50/100/150/200` chasers in a tight contact-range cluster around a dummy
    player.
  - Before fix, the same check collapsed at 100+ enemies (`100` enemies `avg_fps=3.5`, `150` enemies
    `avg_fps=1.5`, `200` enemies `avg_fps=1.0`).
  - After fix, clustered results were: `100` enemies `avg_fps=144.6`, `150` enemies `avg_fps=144.1`,
    `200` enemies `avg_fps=119.3`; normal heavy PerfRunner remained stable.

## V4 Polish Stat Table

- Enemy HP changed: chaser `30 -> 24`, charger `52 -> 36`, spitter `15 -> 14`, splitter `25 -> 22`,
  splitter_mini `8 -> 7`, bomber `30 -> 20`, elite_charger `500 -> 460`, elite_spitter `380 -> 360`,
  elite_support `440 -> 400`; boss HP unchanged.
- Enemy contact/projectile damage changed: chaser contact `12 -> 6`, charger contact `20 -> 10`, spitter
  projectile/contact `12/6 -> 4/4`, splitter contact `8 -> 5`, splitter_mini contact `6 -> 4`,
  elite_charger contact `28 -> 18`, elite_spitter projectile/contact `20/12 -> 8/8`,
  elite_support contact `10 -> 7`, boss contact `35 -> 28`.
- Weapon curves flattened to the V4 polish targets for rifle, beam, shotgun, rocket, Whirlwind, Arc Wand, and
  Flamethrower.
- Ability tuning changed: Shockwave `22 -> 28`, Momentum Burst `24 -> 28`, Orbit `9 -> 14`, Turret `18 -> 16`,
  Afterburn `9 -> 10`, Quake `10 -> 12`.
- The July 14 playtest patch gives Orbit a scalable `20s` lifetime, raises Shockwave Resonance to one delayed
  `1.5x`-radius / `1.3x`-damage slam, sets Shockwave Dash damage to `45`, and converts Afterburn to a moving wake
  (`70px` radius, `0.15s` emission cadence, `1.5s` segment lifetime).
- Passive/ultimate tuning changed: Risk max-Heat vulnerability `+50% -> +25%`, Bloodthirst heal-per-kill
  `8 -> 5`, Gorge bonus `4 -> 3`, combat ultimate charge reduced for higher-density rooms, Slipstream damage
  `1.12 -> 1.3` plus enemy/projectile slow and dash recharge.

## V4 Round 2 + Flow-Field Pathfinding (2026-07-07)

- **Round 2 rebalance (`844d3a3`) — reins in player power, hardens threats:** Arc Wand nerfed (dmg/chain/
  falloff/fire-rate); Summons dmg `14->10`, interval `0.55->0.70`, hard cap `MAX_ACTIVE_SUMMONS=5`; boss HP ~2x
  (1600/2000/1800/1900); Tank overshield cap `0.65->0.25` + decay `5->9` + Bloodthirst heal-per-kill `5->2`,
  Blood Frenzy heal `35->25`; ability base cooldowns +~25% + quick_reflexes trimmed; Overheat decay `14->6` /
  delay `0.75->1.5` (stickier); ult charge `KILL 0.05->0.02` (~1/room); HP-pickup drop chance `0.06->0.03`
  (heal 8 unchanged); homing-projectile cap `MAX_ACTIVE_HOMING=40`.
- The July 14 follow-up further reduces Tank overshield cap to `0.16` and raises decay to `13/s`.
- The arena/balance follow-up reduces Tank kill healing to `1` (`+2` with Gorge), overshield cap to `0.12`,
  decay to `15/s`, and Blood Frenzy healing to `15`; Overflow remains `1.35x`.
- **Enemy projectiles now persist** until they hit a wall/player/summon (ignore lifetime + max_distance for
  `team==enemy`), with an arena-bounds despawn backstop.
- **Element mutations gate by delivery + dedupe** (`c9b9953`): fire_trail/freeze_shot/poison require
  `projectile` (no longer offered on flamethrower/beam/whirlwind/arc_wand) + same-element dedupe.
- **Per-class HUD indicator:** momentum pips only for Mobile; Heat/Overshield/Radiance for the others.
- **Rooms = WHO + WHERE + TWIST** (`data/room_archetypes.json`): 5 normal archetypes (Horde/Mixed/Splitters/
  Pressure/Gauntlet), player picks **2** combat choices per normal step (champion steps stay 1), exactly one
  WHERE mechanic when eligible, and 0-1 existing TWIST modifier. `composition.melee_density` drives spawn scaling;
  former `elite_*` enemies are champion-only and are not in normal compositions.
- **Early-difficulty / perf ease (`da160bb`):** opening burst `6->4`, continuous `5->3`, early spawn interval
  `0.58->0.90s`, early density mult `1.15->1.0` (all ramp back up by mid-run); spitter `fire_interval 1.35->1.8`.
  Fewer early enemies + projectiles for the weak-start phase, and lower concurrent entity count.
- **Flow-field pathfinding (`f2f4ea5` + V4 Phase 4/4b) — LIVE for cover rooms:** `FlowField.gd` now uses
  precomputed vectors, reverse-BFS escape vectors, 40px obstacle inflation, 150px cells, per-player rebuild
  throttling, and `has_target_field` reachability checks. Physical-cover WHERE rooms author obstacles through
  `CoopManager.rebuild_obstacles`. Latest `flowfield_stress` is `59.4` avg FPS at 200 enemies; instrumentation
  now reports physics as dominant rather than flow-field sampling or target rebuilds.

## Known Risks

- QoL/difficulty patch tuning is first-pass and needs a live `1P` / `2P` feel check.
- A fully overlapped 200-enemy contact cluster is now playable in the synthetic check, but still shows a low
  instantaneous FPS monitor reading; watch dense real rooms for residual physics overlap cost.
- Reroll cost, skip frequency, and shared-score spend pressure need live validation.
- The new lean start may feel too thin; tune free unlocks and costs if early runs feel starved.
- Signature values, tag scaling, and parasite downsides are first-pass numbers.
- Phase 4 tuning is first-pass and should get one more live `1P` / `2P` feel check, especially rooms `10+`.
- Champion readability inside dense waves still needs live validation after the cooldown/damage tuning.
- The two next-room cards depend on existing enemy/modifier differentiation; keep watching whether choices feel meaningful.
- Vampiric Wake now heals `1 HP` only after real Afterburn enemy HP damage. One player-owned bucket shared by
  all wake casts/segments caps healing at `4 HP/s`; immunity, misses, full health, and zero damage spend nothing.
- The deterministic July 14 follow-up `flowfield_stress` gate still fails at the retained 160 cover cap after
  the approved bounded hot-path cleanup: pre `55.2/53.1/57.5`, post `53.7/50.3/51.3` FPS. Physics remains
  dominant; do not lower the cap or begin a broad refactor without a separate approved performance plan.
- New V4 polish tuning is still first-pass and needs live 1P/2P feel checks across all four classes.
- Deep runs may exhaust upgrade variety; parked until real run depths are known.
- Objective-panel icons still use simple letter fallback glyphs (`H` / `K` / `C`).
- Pulsar EMP / hazard readability and Hive deflector readability need live feel validation in dense rooms.

## Next Step

The automated portions of the 2026-07-19 feel-polish plan are implemented through Slice 3: aimed abilities,
larger sawblades, Fire/Frost expanding patches, spawn-model A/B, the extended Encounter Builder, overlay
telemetry, and profile sandboxing. Slice 3's acceptance harness passes equal uncapped totals (`75/75`),
seeded sequence reproduction, builder resolution, RNG isolation, and sandbox isolation; both spawn models
measured a `144.9` median in the Hive 2P/heavy perf gate. The impact source audit is recorded in
`v4-feel-polish-findings.md`.

Next work is the live gate: Fireball/toggle/readout visual checks, the Slice 4 paired A/B matrix and sandboxed
full runs, and the structured Slice 5 1P/2P feel check. Do not tune values or choose a spawn-model winner
until those observations produce user-locked 4b/5b subplans.
