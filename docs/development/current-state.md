# Current State

## Project Role

Godot `4.6.2` same-screen local co-op neon roguelite prototype.

The active branch is the structure rework / "trim" branch. The runtime now keeps the Round 14 weapon,
manual aim, Beam, Boomerang, Split, Momentum/Flow, XP, mutation, modifier, side-objective, controller,
and Encounter Builder foundations, but replaces the old structure with one continuable run. The initial
structure-rework playtest was approved, and Phase 4 tuning has been applied.

## Current Runtime

- Front menu paths:
  - `Play`
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

## Progression Loop

- Enemy kills feed one shared XP bar.
- Level-ups bank room-end pick rounds.
- In co-op, both players level together and each gets an independent pick per round.
- Champion rooms grant one additional forced-rare reward pick after XP picks resolve.
- Rare odds now use a continuous depth curve instead of act/endless buckets.
- Gold, shops, rest nodes, and the old purchase loop remain removed.

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
- Aim modes are `auto`, `movement`, and `manual`.

## Encounter Systems

- Rooms use continuous time-based spawning:
  - opening burst at room start
  - enemies spawn on a timer until room duration expires
  - room clears when spawning is done and all enemies are dead
  - modifiers can alter spawn pressure, speed, shields, explosions, and arena hazards
- Enemy pool, room duration, spawn interval, burst pressure, modifier pressure, champion pressure, and
  rare odds now scale by continuous depth.
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

- `RunFlow.gd` now owns:
  - next-room choice panel
  - room launch
  - clear/fail/milestone resolution screens
- `Bootstrap.gd` now owns:
  - single Play setup
  - player/controller/loadout setup
  - Encounter Builder with `Combat / Champion`
  - champion picker over all seven champions
- Encyclopedia entries label all heavy enemies as champions.
- PerfRunner uses `champion:<id>` profiles for champion-in-wave profiling.
- `scripts/ui/MapNodeButton.gd` is deleted.

## Validation

Last validation run in this state:

- `git diff --check`
- Godot headless parse:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick --quit`
- Champion dense-wave perf:
  - `--profile=champion:hive --players=2 --build=heavy`
  - result after Phase 4 tuning: completed, attack markers emitted, average `144.9 FPS`, max frame `6.944 ms` in headless profile
- Cleanup greps over runtime paths returned zero hits for removed map/endless/mode/phase/elite-tier symbols.
- Post-implementation code review passed; three minor hardening fixes applied (bounded `node_map`/lookup
  growth, removed vestigial `"elite"` UI branch, defensive champion-must-spawn-before-clear guard).
  Headless parse + boot (`--quit-after 1`) clean after the fixes.

## Known Risks

- Phase 4 tuning is first-pass and should get one more live `1P` / `2P` feel check, especially rooms `10+`.
- Champion readability inside dense waves still needs live validation after the cooldown/damage tuning.
- The two next-room cards depend on existing enemy/modifier differentiation; keep watching whether choices feel meaningful.
- Cannon was moved toward burst-AOE and Beam was softened as the sustained champion-killer; confirm both roles read correctly.
- Deep runs may exhaust upgrade variety; parked until real run depths are known.
- Objective-panel icons still use simple letter fallback glyphs (`H` / `K` / `C`).
- Pulsar EMP / hazard readability and Hive deflector readability need live feel validation in dense rooms.

## Next Step

Playtest the Phase 4 tuned structure rework on `v3/structure-rework`:

- continuation pressure after room `10`
- champion time-to-kill versus attack threat
- Cannon burst-AOE versus Beam sustained single-target identity
- modifier readability under deeper pressure
