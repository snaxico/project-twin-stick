# Current State

## Project Role

Godot `4.6.2` same-screen local co-op neon roguelite prototype.

The active V4 implementation work is in `D:\GameDev\Project_Twin_stick_v4` on branch `v4/class-system`.
The original `D:\GameDev\Project_Twin_stick` checkout remains the untouched V3 playtest baseline for A/B
testing. V4 Slices 0-2 of `docs/development/v4-implementation-plan.md` are implemented and validated: class
data loads, existing weapons/abilities have tags, the runtime kit stores four abilities, P1/P2 abilities are
bound to face buttons, and the pre-run setup now selects class -> class weapon -> three class abilities with
the class ultimate inserted into slot 4. Mutations now gate through the V4 tag rule: `requires` must be a
subset of the equipped kit's tags, with `apply` describing the effect target layer.

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
- Tags currently seed Fire, Frost, Toxic, Split, Momentum, and Pierce build axes.
- Retired stat-stick weapon mutations (`rapid_fire`, `velocity`, `high_caliber`, `range`) are removed from
  mutation data and no longer compile into weapon stats.

## Loadout / Combat

- Target player count is `1-2`.
- Every player always has:
  - one active weapon, starting with `Rifle`
  - shared weapon level `1-5` preserved when changing weapons
  - four ability slots on controller face buttons: `A`, `X`, `Y`, `B`
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
- Forward-referenced Slice 5-6 weapons, abilities, and ultimates exist as stubs so loadouts resolve:
  Whirlwind, Arc Wand, Flamethrower, the new class abilities, and the four ultimates.
- Live weapons:
  - `Rifle`
  - `Rocket Launcher`
  - `Shotgun`
  - `Cannon`
  - `Railgun`
  - `Beam`
  - `Boomerang`
  - Stubbed class weapons: `Whirlwind`, `Arc Wand`, `Flamethrower`
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
- Stubbed class abilities / ultimates are present for loadout resolution and go on cooldown with activation
  feedback until their content slices replace them.
- All class-pool weapons, abilities, and ultimates are free from the start; premium mutation/unlock trimming
  remains a later V4 slice.
- Mutation offers are filtered by equipped class/passive/weapon/ability/ultimate tags plus selected mutation
  tags. Pierce requires `projectile`, Combustion requires `risk`, and Overgrowth requires a `summon` item.
- The old in-run weapon-switch reward cards are removed; weapon level-up remains as the weapon reward card.
- Aim modes are `auto`, `movement`, and `manual`.

## Encounter Systems

- Rooms use continuous time-based spawning:
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
  - Options input binding rows for `Ability 1 A`, `Ability 2 X`, `Ability 3 Y`, and `Ability 4 B`
  - Meta unlock menu backed by `ProfileState`
  - Encounter Builder with `Combat / Champion`
  - champion picker over all seven champions
- Encyclopedia entries label all heavy enemies as champions and show visual previews for enemies, weapons,
  abilities/mutations, and modifiers.
- PerfRunner uses `champion:<id>` profiles for champion-in-wave profiling.
- `scripts/ui/MapNodeButton.gd` is deleted.

## Validation

Last validation run in this state:

- `git diff --check`
- Godot headless parse:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick_v4 --quit`
- Bootstrap scene headless smoke boot:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick_v4 res://scenes/ui/Bootstrap.tscn --quit`
- PerfRunner Hive champion profile:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick_v4 -- --profile=champion:hive --players=2 --build=heavy`
  - Result: `avg_fps=144.4`, `min_fps=143.0`, `max_frame_ms=12.436`.
- Slice 2 data-level tag acceptance:
  - projectile kit: Pierce eligible
  - cone/melee kits: Pierce ineligible
  - Risk kit: Combustion eligible
  - non-Risk kit: Combustion ineligible
  - no-summon kit: Overgrowth ineligible
- Latest PerfRunner result after Slice 2:
  - `avg_fps=144.7`, `min_fps=143.0`, `max_frame_ms=19.251`.

## Known Risks

- QoL/difficulty patch tuning is first-pass and needs a live `1P` / `2P` feel check.
- Reroll cost, skip frequency, and shared-score spend pressure need live validation.
- The new lean start may feel too thin; tune free unlocks and costs if early runs feel starved.
- Signature values, tag scaling, and parasite downsides are first-pass numbers.
- Phase 4 tuning is first-pass and should get one more live `1P` / `2P` feel check, especially rooms `10+`.
- Champion readability inside dense waves still needs live validation after the cooldown/damage tuning.
- The two next-room cards depend on existing enemy/modifier differentiation; keep watching whether choices feel meaningful.
- Cannon was moved toward burst-AOE and Beam was softened as the sustained champion-killer; confirm both roles read correctly.
- Deep runs may exhaust upgrade variety; parked until real run depths are known.
- Objective-panel icons still use simple letter fallback glyphs (`H` / `K` / `C`).
- Pulsar EMP / hazard readability and Hive deflector readability need live feel validation in dense rooms.

## Next Step

Continue `docs/development/v4-implementation-plan.md` with Slice 3 in the V4 worktree:

- add the shared deployable HP / damage / death interface
- make Turret, Orbit, Decoy, and player AbilityMine persistent destructible units
- remove time-expiry despawn from those player deployables
