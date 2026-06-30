# Current State

## Project Role

Godot `4.6.2` same-screen local co-op neon roguelite prototype.

The active branch is the structure rework / "trim" branch. The runtime now keeps the Round 14 weapon,
manual aim, Beam, Boomerang, Split, Momentum/Flow, XP, mutation, modifier, side-objective, controller,
and Encounter Builder foundations, but replaces the old structure with one continuable run. The initial
structure-rework playtest was approved, Phase 4 tuning has been applied, the replayability patch
Phases 0/A/B are implemented, the QoL/difficulty patch is implemented, and the game-feel / neon identity
patch is implemented and playtest-approved.

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

## Loadout / Combat

- Target player count is `1-2`.
- Every player always has:
  - one active weapon, starting with `Rifle`
  - shared weapon level `1-5` preserved when changing weapons
  - `1 OFF` ability slot on `LT`
  - `1 DEF` ability slot on `RT`
  - mutation inventory
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
- New profiles start lean: `Rifle`, `Shotgun`, `Overcharge`, `Dash`, and base common upgrades are free;
  the rest enters pre-run and upgrade pools through Meta unlocks.
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
- `RunFlow.gd` now owns:
  - next-room choice panel
  - room launch
  - clear/fail/milestone resolution screens
- `Bootstrap.gd` now owns:
  - single Play setup
  - player/controller/loadout setup
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
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick --quit`
- Bootstrap scene headless smoke boot:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick res://scenes/ui/Bootstrap.tscn --quit`
- PerfRunner Hive champion profile:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick --profile=champion:hive --players=2 --build=heavy --quit`

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

Playtest the QoL/difficulty patch on `v3/structure-rework`:

- reroll/skip reward flow in 1P and 2P
- shared score spend pressure and reroll-cost escalation
- early-room pressure after chaser/charger/spawn tuning
- HP drop frequency and heal amount
- encyclopedia visual preview readability
- Meta unlock flow: earn score, bank once, spend, restart, confirm persistence
- lean-start feel before unlocks
- Signature/parasite offer quality and build divergence
- route-card readability and rare-odds nudge readability
- continuation pressure after room `10`
- champion time-to-kill versus attack threat
- Cannon burst-AOE versus Beam sustained single-target identity
- modifier readability under deeper pressure
