# V4 Arena, Tank, Vampiric Wake, and Performance Follow-up

## Goal

Increase WHERE variety/readability, make Tank sustain strong but mortal, implement Vampiric Wake with a
player-owned `4 HP/s` cap, and retain the `160` cover-room enemy cap with bounded flow-field optimizations.
Other classes are observation-only.

## Arena Contract

- Every non-open WHERE has three hidden deterministic variants. Route nodes store `where_variant` and
  `where_seed`; retries reuse them. Immediate repeats are prevented per mechanic, with Fire/Frost/Mine sharing
  one Hazard Floor family history.
- Arena mechanics accept `configure_variant(index, room_seed)` before `setup()`. Normal runs use RunState's RNG,
  profiling uses seed `20260707`, and non-profile debug fallback uses `0`.
- WHERE damage targets players only. Damage cadence is Fire `8/.75s`, Frost `6/.75s` plus slow, Mine `20`,
  Saw `9/.6s`, Tesla `9/.6s`, Cloud `8/.75s`, Pillar `10`, and Laser `9/.5s`.
- Hazard Floor retains its current family and adds the two approved three-phase families. Mine generation uses
  `74021 + family * 2931 + phase * 977`, ten mines, `340px` safe clearance, and `300px` separation.
- Sawblades, Tesla, Clouds, Bastion, Drifting Cover, and Popup Pillars expose the three approved layouts.
- Sweeping Laser Lanes cycles `1.0s` warning, `3.2s` constant sweep, and `1.2s` rest. Its `70px` wall has a fixed
  `420px` opening; warning shows the starting wall, faint path, and three arrows. Variants alternate the approved
  horizontal and vertical sweeps. It appears at equal non-open weight in Horde, Mixed, Splitters, and Gauntlet.

## Combat Contract

- Tank: fix exact-fill overshield double-dip; kill heal `1`, Gorge `+2`, cap `12%`, decay `15/s`, Blood Frenzy
  heal `15`, Overflow unchanged at `1.35`. HUD scales against the real overshield maximum.
- Vampiric Wake: heal `1` only after real enemy HP damage. A player-owned token bucket has capacity/refill `4`,
  begins full, is shared across all casts/segments, and refills only while the living player processes. Loadout
  changes preserve positive-cap fill ratio, fill on `0 -> positive`, and clear on `positive -> 0`. Successful
  normal-health heals alone consume tokens; Wake never creates overshield.

## Performance and Acceptance

- Profiling is deterministic and includes `160` while retaining `200`. Capture three pre/post `160` runs for
  `flowfield_stress` and `entity_ramp`.
- Optimize only bounded flow hot paths: reuse normalized stored vectors and avoid repeated profiling-clock reads.
  Keep `MAX_OBSTACLE_ENEMIES = 160`.
- Every post flow run at `160` must reach `60 FPS`; post entity median must be at least `90%` of its pre median.
  On failure, stop with evidence instead of lowering the cap or beginning a broader refactor.
- Parse and Bootstrap-smoke each slice. Exercise every WHERE variant, hazard team routing, Tank heal boundaries,
  Wake overlap/cap/lifecycle cases, and Hazard Floor geometry. Update current state/history after implementation;
  archive this plan only after live playtest acceptance.

## Implementation Validation

- Focused arena/combat checks pass, and all ten non-open WHERE IDs pass all three variants (`30/30`). The
  reviewed smoke contract requires registered projectile-blocking geometry for Bastion, Popup Pillars, and
  Drifting Cover; all nine physical-cover variants pass in both `1P` and `2P`.
- Entity 160 pre: `101.4/88.6/99.3` (median `99.3`); post: `93.4/90.9/100.8` (median `93.4`). Retention passes.
- Flow 160 pre: `55.2/53.1/57.5`; post: `53.7/50.3/51.3`. The all-runs `>=60` gate fails, so performance work
  stopped at the approved bounded changes with the cap retained at `160`.
