# Playtest Round 6 - Performance + Gameplay Validation Checklist

Manual validation for the current stable round-6 patch.

Heavy boss add-waves are **debug dry-run only** through `debug_boss_add_waves`. Do not treat
them as shipped until the real boss-room stress gate passes.

Headless parse: **passing**.
Follow-up Godot warning cleanup: **passing target** for reported local-name conflicts.
Live performance feedback: **massive improvement reported**.

---

## Scanline
- [ ] Modifier appears as `Scanline` in UI while keeping the `mine_field` id internally.
- [ ] Sweep reads like a scanline / laser wall, not mines.
- [ ] Each sweep has visible safe gaps.
- [ ] Gaps are threadable/dashable.
- [ ] Damage does not feel like an unavoidable solid wall.
- [ ] Sweep no longer causes obvious frame drops.

## Duration Mutation
- [ ] Duration copy says sustained uptime.
- [ ] `Dash` duration / invulnerability does not increase from Duration.
- [ ] `Blink` remains unaffected by Duration.
- [ ] Sustained abilities still scale duration: `Overcharge`, `Shield`, `Decoy`, `Turret`, `Minefield`, `Orbit`.

## Fire Bullets Pools
- [ ] Player Fire Bullets impact pools still damage enemies.
- [ ] Player Fire Bullets impact pools do not damage players.
- [ ] Enemy-team pools, if spawned, damage players.
- [ ] Pools expire cleanly and do not leave ghost damage.
- [x] Performance remains stable with many Fire Bullets pools in the reported live performance pass.

## Enemy Visuals
- [ ] Enemies remain readable after removing Shadow / Outline nodes.
- [ ] Elite and boss scale/readability remain acceptable.
- [ ] Shielded enemies are still visually distinguishable enough.
- [ ] Bomber fuse visual still updates while moving.
- [ ] Enemy facing still updates while moving.

## Pulsar
- [ ] Pulsar still performs timed teleport.
- [ ] Pulsar starts a teleport when a player gets within roughly `250px`.
- [ ] Reactive teleport has readable telegraph/invulnerability.
- [ ] Pulsar does not chain-teleport in a way that feels broken.
- [ ] EMP and beam behavior still work.

## Boss Add-Wave Dry Run
- [ ] Normal boss rooms do **not** spawn heavy B2 add waves by default.
- [ ] Encounter Builder / debug run with `debug_boss_add_waves` enabled spawns boss add waves.
- [ ] Add-wave cap counts all non-boss enemies in the boss room.
- [ ] Cap includes pending/deferred spawns.
- [ ] Hive native minions/deflector minions do not blow past the cap during dry run.
- [ ] Splitter death minis do not blow past the cap during dry run.
- [ ] Real boss-room stress gate holds around `60 FPS` at the intended capped density in `1P` and `2P` before promotion.

## Profiling
- [x] Non-headless `scenes/dev/ProfilingHarness.tscn` runs and prints FPS/process/physics/draw-call data.
- [x] Live playtest feedback reports a massive performance improvement after the patch.
- [ ] Harness is used for before/after diagnosis only, not as the shipping gate.
- [ ] Real boss-room stress test is used as the B2 go/no-go gate.

## Notes
- Run:
- Player count:
- Boss:
- Modifiers:
- Entity count:
- FPS / frame spikes:
- Bugs:
