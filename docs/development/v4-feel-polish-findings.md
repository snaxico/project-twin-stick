# V4 Feel & Polish Findings

Evidence collected while executing `docs/development/v4-feel-polish-plan.md`.

## Slice 1 — Performance Measurement Gate (2026-07-19)

Quiet-session deterministic `flowfield_stress` baseline, Godot `4.6.2`, target bucket `160` enemies +
`160` projectiles:

| Run | Avg FPS | Process ms | Physics ms | Flow sample ms | Target update ms | Dominant |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | 105.9 | 48.888 | 13.453 | 0.089 | 2.005 | physics |
| 2 | 106.1 | 51.571 | 14.775 | 0.089 | 2.055 | physics |
| 3 | 101.1 | 49.742 | 15.751 | 0.090 | 2.208 | physics |

- Median average FPS: `105.9`.
- Physics/body movement is the dominant measured bucket at 160.
- Flow-field sampling is negligible at about `0.09ms`; target updates remain about `2.0-2.2ms`.
- The same harness falls sharply at its synthetic 200 bucket (`32.8`, `33.9`, `46.8` average FPS), where
  physics remains dominant.
- The live physical-cover cap remains `160`. This quiet-session baseline is comfortably above 60 FPS, so
  no performance implementation is justified inside Phase 1 without a separately reviewed Slice 1b.

Candidate future work, only if live cover rooms contradict this baseline:

- Profile enemy separation/body movement specifically at the 160 cap.
- Consider a bounded near-obstacle separation-query experiment in a user-locked Slice 1b.

Decision: no Slice 1b proposed now; proceed to the concrete feel fixes.

## Slice 2 — Concrete Feel Fixes (2026-07-19)

- Directional abilities now resolve the same refreshed manual/auto aim used by weapons, with last
  `_aim_facing` as the nonzero fallback. Dash keeps its movement-specific direction path.
- Roaming Sawblades use a `42px` blade radius (was `30px`).
- Fire and Frost Hazard Floors now use deterministic expanding patches: `0.8s` telegraph,
  `120px → 260px` growth over `6s`, `4s` hold, `1s` fade, one patch every `2.5s`, maximum eight.
  Mine Floor remains on its existing roam-and-avoid behavior.
- Automated validation passed for all three variants in 1P and 2P:
  - Sawblade `120px` dodge lane remains valid.
  - Fire/Frost apply no damage during telegraph/fade, retain at least 50% safe cells, and keep at
    least 95% of safe cells in one traversable component on the specified inflated grid.
  - Repeated Fire/Frost runs with the same seed produce identical center sequences.
  - Mine Floor's existing smoke remains unchanged.
- Post-review correction: the Fire/Frost "no damage during telegraph/fade" smoke now wires
  `_profiling_invalid_damage_phase` from the actual hazard damage path, so the profiler assertion is no
  longer vacuous. Focused Fire/Frost WHERE smokes still pass after the correction.
- Aimed-ability acceptance covered auto target, manual aim, fallback aim, and movement independence.
- Hive 2P/heavy post-slice runs: `145.0`, `144.9`, `144.9` average FPS versus pre-slice
  `145.0`, `144.9`, `145.0`; no regression.

Live visual check still required: Fireball cast direction/readability with a controller in a real room.

## Slice 3 — Spawn A/B and Debug Tooling (2026-07-19)

Implemented surfaces:

- `trickle` (default) and `pulsed` spawn models; the pulsed stream groups the same schedule into a pulse
  every `4.0s`, spread over `0.8s` and at most two edges.
- Encounter Builder controls for archetype, constrained WHERE, variant, depth, seed, and spawn model.
- Debug Run Setup spawn-model row.
- Pause debug overlay active/pending model toggle plus FPS, enemy, active-projectile, and player-deployable
  counts.
- `PerfRunner --spawn-model=<trickle|pulsed>`.
- `--profile-sandbox=<fresh|keep>` profile isolation.
- Reusable headless acceptance scene:
  `res://scenes/dev/FeelPolishAcceptance.tscn`.

Automated gate evidence:

| Check | Result |
| --- | --- |
| Open, uncapped, shooter-light total | PASS — `75` trickle, `75` pulsed |
| Seeded trickle sequence repeated | PASS — exact time/type/position equality |
| Seeded pulsed sequence repeated | PASS — exact time/type/position equality |
| A1 Horde/Open/d3/s1001 builder resolution | PASS — real high-density composition |
| A2 Gauntlet/Bastion-v0/d6/s1002 builder resolution | PASS — real low-density composition |
| A3 Mixed/Fire Grid-v0/d8/s1003 builder resolution | PASS — real medium-density composition |
| Seeded spawn global-RNG isolation | PASS — next global draw unchanged |
| Sandbox `fresh` then `keep` (`banked_score=321`) | PASS — value retained; sandbox bytes unchanged on keep |
| Real profile isolation | PASS — SHA-256 byte-identical before/after both sandbox modes |
| Debug-menu boot and project parse | PASS |

Performance gate, Hive 2P/heavy:

| Model | Run 1 | Run 2 | Run 3 | Median | Pre-slice median |
| --- | ---: | ---: | ---: | ---: | ---: |
| Trickle | 144.9 | 145.0 | 144.9 | 144.9 | 144.9 |
| Pulsed | 144.9 | 144.9 | 144.9 | 144.9 | 144.9 |

One pulsed run recorded a `143` minimum and `7.069ms` maximum frame; all other minimums were `144`.
No performance regression.

Live checks still required: inspect all three toggle surfaces in a rendered game and confirm the overlay
counts against a visible room.

## Slice 4 — Balance Measurement Gate

Status: **awaiting live playtest**. No balance numbers were changed.

The Encounter Builder and deterministic spawn log now make A1/A2/A3 reproducible, and the sandbox makes
paired full runs safe. The plan requires 60 primary 1P single-room runs (five weapons × three rooms ×
two models × two paired seeds), A2 2P spot-checks, and six full runs through room 12/death. Headless
automation cannot provide the required clear-feel, burst-vs-sustain, economy-pressure, champion-readability,
or experienced-player verdicts. Those observations must be recorded before a 4b tuning proposal or a
spawn-model winner can be locked.

## Slice 5 — Impact Audit

Source audit complete; structured 1P/2P feel ratings remain part of the live gate. No source values were
changed by this audit.

### Shared systems

| System | Current value/behavior |
| --- | --- |
| Hit stop | Scale `0.05`, max `70ms`, minimum retrigger interval `120ms`; lower-weight requests cannot replace a stronger active stop |
| Camera shake | One shared camera; `max_shake=34`, trauma decay `3.4/s`, quadratic intensity |
| Combat sparks | Suppressed under the existing high-load VFX policy; weights feed particle count/scale |
| Screen flashes/shake | Gated by the existing screen-effects level; flashes tween to zero |
| SFX | Procedural 16-voice pool at 22.05kHz; per-call pitch variation |

### Event coverage

| Event/tier | Hit stop | Trauma | Flash / particles | SFX |
| --- | --- | --- | --- | --- |
| Ordinary enemy hit under 90 damage | none | none | enemy hit punch + weight `1.0` sparks; projectile adds weighted sparks/ring | generic hit `0.85`; projectile paths also request their profiled impact |
| Big non-champion hit (`>=90`) | `0.45 / 35ms` when nonlethal | `0.08` | ordinary hit visuals | generic hit `0.85` plus projectile impact where applicable |
| Champion hit (throttled) | `0.55 / 35ms` when nonlethal | `0.10` | champion feedback color/weight | generic hit `0.85` plus projectile impact where applicable |
| Ordinary enemy death | none | none | type-color death burst at enemy feedback weight × `1.25`; `32px` pop ring | enemy death `0.8` for every ordinary type |
| Champion death | `0.85 / 52ms` | `0.42` | weight `2.2` burst, `150px` ring/debris, white `0.18` flash for `0.2s` | boss explosion `1.45` |
| Boss entrance | `0.65 / 42ms` | `0.32` | red `0.18` flash for `0.32s`, `260px` ring | boss explosion `1.35` |
| Player damage | `0.7 / 48ms` | `0.12 + 0.30 × clamp(damage/20, 0.5, 1.0)` | sparks `1.1`, player shader flash `0.12s`, red screen flash alpha `0.18-0.34` for `0.22s` | damage cue |
| Shockwave-family impact | none beyond big-hit rule | `0.18` per pulse | target sparks `1.0`, expanding ring; projectile clears use `0.75` sparks | generic ability activation explosion `0.85` |
| Room clear | none | `0.18` | green `0.14` flash `0.24s`, `220px` ring, debris | room-clear cue |
| Level up | none | `0.12` | green `0.18` flash `0.22s` | level-up cue |

Enemy visual weights by tier:

| Tier | Current weights |
| --- | --- |
| Minor enemies | Chaser `0.9`; Charger `1.1`; Spitter/Splitter `1.0`; Splitter Mini `0.65`; Bomber `1.15` |
| Elite champion IDs | Charger `1.75`; Spitter `1.6`; Support `1.55` |
| Named champions | Warden `2.2`; Hydra/Hive/Pulsar `2.0` |

Weapon coverage:

| Weapon | Fire SFX / muzzle | Impact VFX / SFX | Hit stop / shake |
| --- | --- | --- | --- |
| Rifle, Rocket Launcher, Shotgun, Beam, Whirlwind, Arc Wand, Flamethrower | all currently retain Player defaults: profile `rifle`, weight `1.0` (`+0.2` muzzle weight during Overcharge) | all pass profile `rifle`, weight `1.0`; target feedback color changes the sparks | only the shared big-hit/champion rule |

Ability coverage:

| Ability group | Current activation | Current impact |
| --- | --- | --- |
| Every ability | burst/ring plus generic explosion SFX weight `0.85` keyed by ability ID | shared enemy hit/death feedback |
| Dash | generic activation plus dash burst and dash SFX `1.0` | no impact |
| Shockwave, Momentum Burst, Ground Slam | radial ring, target sparks `1.0`, trauma `0.18` | shared big-hit/champion rule |
| Sonic Boom, Blood Lance, Fireball | projectile impact, default weight `1.25`; profiles `beam`, `rifle`, `rocket` | weighted sparks/ring + profiled impact SFX |
| Turret / Summon / Orbit | target sparks `0.9` / `0.9` / `0.72` | shared generic hit SFX; Turret projectiles use rifle `0.9` |
| Minefield | per-target sparks `0.9` and explosion ring | no dedicated detonation SFX or shake |
| Persistent zones / buffs / utility / ultimates | cast pulse/ring; damage routes through shared enemy feedback | no identity-specific recurring impact beat |

### Gaps and proposed 5b scope

1. **Weapon identity is not wired.** `_weapon_feedback_profile` and `_weapon_impact_weight` are never
   assigned from the equipped weapon, so all seven weapons fire and impact as a Rifle despite the SFX
   engine already supporting differentiated shapes. A 5b should define one profile and weight per weapon.
2. **Projectile impacts can request two SFX beats.** ProjectileSystem plays a profiled impact, then the
   enemy `hit_received` route also plays generic `hit` at `0.85`. A 5b should establish one owner for
   high-frequency impact audio and retain a separate exceptional big-hit cue if desired.
3. **Ordinary kill audio is flat.** Visual death weight varies by enemy, but every non-champion death uses
   the same `0.8` cue. A 5b should group minor/heavy/split death pops without adding per-enemy noise.
4. **Ability casts are overly generic.** Every ability emits the same activation explosion call, including
   Dash before its dedicated dash cue. A 5b should group mobility, deployable, radial, projectile, and
   ultimate casts and remove redundant layers.
5. **Mine and persistent-zone impacts lack distinct beats.** Their visuals exist, but detonation/tick audio
   identity is absent. Any high-frequency zone cue needs strict throttling/voice-budget rules.
6. **Weapon hitstop/shake has no identity.** Only damage threshold and champion status matter. The live
   1P/2P check should decide whether a small heavy-weapon-only tier is warranted without making rapid
   weapons stutter.

No exact 5b values are proposed until the required 1P/2P feel check is recorded and user-locked.

## Round 2 Implementation Findings (2026-07-20)

Implemented the Round-2 plan slices 1-5 in code. Headless validation is green for parser and
`FeelPolishAcceptance`.

Perf measurements from this machine after the Slice-2b correction pass. Each row is the 3-run protocol
from the locked Round-2 plan; values are reported as `run1 / run2 / run3`.

| Scenario | Load | avg_fps | min_fps | max_frame_ms | Dominant probe bucket | Status |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `felt:summons` | 2P Controller, heavy Arc Wand, Overgrowth, 100 held enemies, deployable loop | 144.1 / 144.0 / 143.3 | 141.0 / 136.0 / 135.0 | 15.071 / 20.158 / 30.976 | `enemy_physics` avg 2.315 / 2.425 / 2.538ms | Green |
| `felt:horde` | 1P Mobile, heavy Rifle, 200 held enemies | 144.9 / 144.8 / 144.3 | 144.0 / 140.0 / 139.0 | 6.944 / 20.688 / 23.705 | `enemy_physics` avg 1.309 / 1.294 / 1.336ms | Green |
| `felt:champion_wave` | 2P Mobile+Tank, heavy, Hive at 10s, 150 held enemies | 130.1 / 140.3 / 139.0 | 68.0 / 117.0 / 80.0 | 87.787 / 96.440 / 109.725 | `enemy_physics` avg 1.349 / 1.187 / 1.169ms | Green by min-FPS gate |

Structural changes that moved the results:

- `PerfProbe` now reports subsystem buckets from real-room runs.
- Open-room high-count enemies use soft crowd movement above the 120-enemy physics wall, so the pinned
  150-enemy champion profile is covered.
- Dense-cluster soft movement staggers non-champion expensive AI/contact refreshes while preserving per-frame
  movement.
- `CoopManager.get_nearby_enemy_target_nodes()` caches same-frame cell/radius queries.
- Deployables cache target/candidate scans briefly, reducing repeated per-frame spatial scans.
- Cosmetic-only transient nodes are tagged by `ParticleFactory` and capped during runtime clamping. Gameplay
  nodes such as FireTrailZone / AfterburnWake are not tagged and are not trimmed.
- Projectile/effect VFX suppression now engages earlier under load; audio still plays.

Important caveat: `felt:champion_wave` still reports isolated high `max_frame_ms` samples during Hive
deflector activity, but the locked Round-2 min-FPS gate is now green across all three runs on this machine.
Keep Slice 6 as the live-feel check for whether those isolated frames are perceptible.

Other completed wiring:

- Sweeping Laser Lanes now roll deterministic varied gap centers while strictly alternating axes.
- `legion.construct_count_bonus` is live at summon time and competes within shared
  `MAX_ACTIVE_SUMMONS`.
- Weapon identity is wired with split fire/impact weights and new SFX profiles for Beam/Whirlwind/Arc
  Wand/Flamethrower. Projectile impacts own high-frequency impact audio; generic hit audio is suppressed
  when the profiled projectile impact already fired in the same physics frame.
- Dash no longer stacks the generic cast explosion under its dash cue.
- Debug Encounter Builder can A/B `3 + ultimate` vs `2 + ultimate`; 2-mode preserves slot 4/Y for the
  ultimate with an empty hidden slot-3 sentinel.
