# V4 Feel & Polish Round 2 — Performance, Kit A/B, Fixes (plan, 2026-07-20)

> From the 2026-07-20 playtest of the implemented Round-1 patch (`c728aa0` + `9afac67`). Parent roadmap:
> `docs/development/v5-roadmap.md`. Branch `v4/class-system`, checkout `D:\GameDev\Project_Twin_stick`.
> Supersedes the open remainder of `v4-feel-polish-plan.md` (its Slice-4/5b outputs fold in here).

## Playtest Findings Driving This Patch (2026-07-20)

- Performance is still not fixed in live play; the user has requested a **real solution**.
- Classes play very differently AND are very differently balanced.
- Kit-size question: would 2 abilities (+ ultimate) beat the current 3?
- Signature mutations are unreliable — the summon Signature did not create an extra construct.
  **Root-caused:** `legion` defines `params.construct_count_bonus` but no code reads it (dead data).
  **Correction after plan review:** `aegis` is NOT dead — `CoopManager._reinforce_deployables`
  (~line 1552) reads `shield_amount` and applies it via `apply_deployable_shield()`, absorbed in
  `DeployableNode`. The audit below verifies live behavior against descriptions for everything else.
- Sweeping Laser Lanes use fixed gap positions; they should vary while strictly alternating
  vertical/horizontal.
- Stormrunner/Mobile reads as "the default class".

## Locked Decisions (2026-07-20)

- **Spawn-model verdict is OPEN.** Both `trickle` and `pulsed` stay behind the toggle; the Slice-6
  playtest decides. No model is removed this patch.
- **Performance scope is PRE-AUTHORIZED for structural work.** Measurement comes first, but the
  evidence-pointed structural fix proceeds immediately within this patch — no separate approval loop.
  The lag is FELT in: summon-heavy Controller play, dense hordes anywhere (cover or open), and
  champion-in-dense-wave moments. Cover rooms are NOT assumed to be the primary case.
- **Kit size: prototype 2 vs 3** behind a debug Run-Setup option; the Slice-6 playtest decides.
- **Mobile is the official baseline class.** It is the game's default/starter kit; other classes are
  balanced AROUND it. This is a design principle for all future balance work.
- **Upgrade fun-pass deferred to Phase 3.** This patch does only the wiring audit + fixes (make every
  mutation do what its description says); the variety/fun redesign happens in the Content phase.
- **5b weapon-identity juice is IN** (full scope from the Round-1 audit).
- Risk class and beam/cone remain parked (shared-systems boundary unchanged).

## Validation Framework

Identical to Round 1 (`v4-feel-polish-plan.md`): `git diff --check`, headless parse, Bootstrap smoke
boot every slice; JSON checks when data files are touched; 3-run same-session pre/post baselines with
the 95%-median / min-60 tolerance for every perf comparison; `FeelPolishAcceptance.tscn` must stay
green all patch.

---

## Slice 1 — Performance Instrumentation of the FELT Scenarios (dev tooling; no gameplay changes)

The existing synthetic probes (`flowfield_stress`, `entity_ramp`) do not reproduce what the user
feels. Build three PerfRunner profiles that do:

Exact definitions (every parameter fixed so before/after comparisons are strong; all three use
**spawn model `trickle`** — the live default — and the standard PerfRunner measurement: `40s`
scenario duration, first `5s` excluded from sampling, `min_fps` per the existing PerfRunner metric,
**3 runs per scenario**):

- `felt:summons` — `2P`, both Controller, weapon `arc_wand`, abilities `summon`/`turret`/`orbit`,
  `--build=heavy` plus `starting_mutations = ["overgrowth"]` (**current code only — no `legion`**:
  Slice 1 baselines the game as it exists; Legion lands in Slice 3). The harness script recasts
  Summon on cooldown until the **shared global summon cap is saturated (`MAX_ACTIVE_SUMMONS = 5`
  total — one shared array trimmed by `_enforce_summon_cap()`, not per-player)** and casts
  Overload Grid whenever either ultimate is ready. Enemy load: `gauntlet` composition at depth `8`,
  shooter budget saturated (`6` active spitters), continuous respawn holding **`100` live
  enemies**. No WHERE, no modifiers. **Slice 3 re-runs this profile after Legion lands** (Legion
  adds summon pressure inside the same cap) and must stay within the Slice-2 gate.
- `felt:horde` — `1P`, Mobile, weapon `rifle`, `--build=heavy`. `horde` composition at depth `10`,
  `open` WHERE (no cover, uncapped), continuous respawn holding **`200` live enemies**.
  No modifiers.
- `felt:champion_wave` — `2P` (Mobile + Tank), `--build=heavy`. `mixed` composition at depth `10`,
  modifiers exactly `["enemy_speed", "shielded"]`, Hive champion spawned at `t = 10.0s`,
  continuous respawn holding **`150` live enemies** alongside the champion. `open` WHERE.

**Instrumentation prerequisite (explicit):** the current harness samples only Godot aggregate
monitors (FPS / process / physics / draw calls / nodes, `PerfRunner.gd` ~line 182); the only
subsystem timer that exists is FlowField-specific. The subsystem buckets this slice promises do
not exist yet, so Slice 1 **first builds a timing collector**: a `PerfProbe` static utility
(`PerfProbe.begin(bucket)` / `end(bucket)` via `Time.get_ticks_usec()`, per-frame accumulation,
per-bucket avg/max reported by PerfRunner), active **only when `RunState.debug_profiling` is set**
(zero overhead in normal play — the call sites early-out on one bool). Probe call sites wrap:
enemy `_physics_process` (aggregated across enemies), summon/deployable tick, `ProjectileSystem`
tick, `CombatEffects` tick; draw/physics come from the engine monitors. The three felt scenarios
are **not valid until the collector exists** — coarse engine buckets alone cannot rank subsystems
and must not gate Slice 2.

**Output:** ranked per-bucket cost table per scenario in
`docs/development/v4-feel-polish-findings.md` (Round 2 section). **Gate:** collector implemented
and probe overhead verified negligible (hive profile within tolerance vs pre-collector baseline);
three runs per scenario recorded; the dominant bucket identified per scenario; no gameplay
behavior touched.

## Slice 2 — Structural Performance Fix (PRE-AUTHORIZED)

Implement the fix(es) the Slice-1 evidence points at. Candidate set (ranked by prior evidence;
the measurements pick):

1. **Enemy movement off `move_and_slide`:** manual position integration for enemies (velocity +
   collision checks against walls/obstacles via direct space queries), spatial-hash separation
   instead of per-enemy neighbor scans. CharacterBody2D cost at high counts is the long-standing
   dominant bucket.
2. **Summon/deployable tick cost:** shared cached target lists (one scan per frame for all
   deployables, not per-deployable), attack-interval batching, Radiance aura interval reduction.
3. **Champion+wave effect load:** extend the existing VFX suppression policy with hard particle/
   effect budgets under load; cap concurrent CombatEffects bodies.
4. **Enemy rendering via MultiMesh** if draw is the bucket (previously deferred with V3-era data —
   re-decide on V4 numbers only).

Rules: behavior parity is required (enemy paths/feel unchanged within tolerance — verified by the
existing WHERE smokes, `FeelPolishAcceptance`, and a live feel check); changes land behind the
smallest practical seam so a revert stays cheap.

**Gate:** all three `felt:*` scenarios hold **min-FPS ≥ 60 across 3 runs** at their defined loads;
full existing PerfRunner suite + smokes pass; no acceptance regressions.

## Slice 3 — Playtest Fixes (implementation)

### 3a. Sweeping Laser Lanes: varied deterministic positions

- Axis **strictly alternates** every sweep (start axis = variant parity, preserving three distinct
  layouts).
- The gap center is **rolled per sweep** from a mechanic-owned RNG seeded with route seed + variant
  (lazy draw, same pattern as hazard patches): uniform within the arena inset by
  `GAP_SIZE * 0.5 + 60px`, re-drawing while within `300px` of the previous same-axis gap center
  (deterministic rejection).
- Unchanged: `1.0s` warning, `3.2s` sweep, `1.2s` rest, `70px` width, `420px` co-op opening,
  players-only damage.

**Gate:** WHERE smoke, 3 variants × 1P/2P: axis alternation asserted, same-seed runs reproduce
identical gap sequences, opening width holds.

### 3b. Mutation wiring audit + fixes

- **Fix `legion`:** `construct_count_bonus` is read at summon time and adds one construct
  (respecting `MAX_ACTIVE_SUMMONS` — Legion competes within the cap, it does not raise it).
- **`aegis` needs no fix** (review correction: it is wired — `_reinforce_deployables` reads
  `shield_amount` and deployables absorb from the applied pool). The audit still covers it like
  every other mutation: verify live behavior matches its published description. Its shield is a
  permanent absorb pool, which matches "Reinforced deployables gain a shield" — no change unless
  the audit or a playtest contradicts that.
- **Full param audit:** enumerate every `params` key in `data/mutations.json` and verify each is
  read by runtime code. Any other dead key: implement per its description when unambiguous;
  ambiguous items are listed for MC — no silent cuts.
- **Regression guard:** extend `FeelPolishAcceptance` (or a sibling scene) with a data-wiring check
  that scans mutation `params` keys against script sources and **fails on data-only keys**
  (explicit allowlist, each entry justified in a comment, for keys read via dynamic access).

**Gate:** acceptance check green; a headless functional check confirms Legion spawns +1 construct
and Aegis applies/absorbs; JSON + parse + smoke pass.

## Slice 4 — Weapon-Identity Juice (the locked 5b)

From the Round-1 audit (all seven weapons currently fire/impact as Rifle):

- **Wire weapon feedback from the equipped weapon — with a split weight contract.** Today
  `_weapon_impact_weight` feeds BOTH the muzzle fire beat (`Player.gd` ~line 724) and the
  projectile impact config (~line 739), so a fire/impact table cannot land on one field. This
  slice **adds `_weapon_fire_weight`** (muzzle SFX/VFX weight, consumed at the ~724 call site)
  and keeps `_weapon_impact_weight` for impact configs (~739); both are assigned, together with
  `_weapon_feedback_profile`, when the equipped weapon is set/compiled. First task: enumerate the
  SfxEngine's actual profile set; then assign one profile per weapon with these first-pass weights
  (fire / impact): Rifle `1.0/1.0`, Shotgun `1.25/1.2`, Rocket `1.5/1.5`, Beam `0.85/0.8`,
  Whirlwind `1.1/1.0`, Arc Wand `0.9/0.9`, Flamethrower `0.95/0.9` (Flamethrower/Beam values are
  shared-system pass-through, not Risk/beam-specific work).
- **Single impact-audio owner:** profiled projectile impact wins; the generic `hit 0.85` fires only
  when no profiled impact played (kills the double-beat).
- **Kill-pop grouping:** minor / heavy / splitter-family death cues (three tiers, not per-enemy).
- **Cast-layer dedupe:** Dash no longer stacks the generic activation explosion under its dash cue.

**Gate:** audit table updated with the new wiring; hive perf 3-run tolerance; 1P/2P feel check
confirms each weapon reads distinct.

## Slice 5 — Kit-Size Prototype (2 vs 3, debug A/B)

- Debug-gated Run-Setup row **Kit Size: `3 + ultimate` (default) / `2 + ultimate`**.
- **Runtime storage seam (explicit — UI hiding alone is insufficient):** the current pipeline
  normalizes every loadout back to exactly three non-ultimate slots regardless of what the UI
  offers: `RunState` pads/truncates chosen abilities to 3 before appending the ultimate
  (~line 568), and `Bootstrap` both pads selections to 3 (~line 1664) and rejects non-size-3
  loadouts in validation (~line 1844). This slice adds `debug_run_setup.kit_size` (default `3`,
  clamped to `{2, 3}`) and makes **all three call sites kit-size-aware**: RunState normalizes to
  `kit_size` non-ultimate slots + ultimate; Bootstrap pads to `kit_size` and validates against
  `kit_size`. Normal runs never set the option and keep behaving exactly as today.
- **Slot layout in 2-mode (explicit — input is slot-index based):** slot 3 uses `p*_ability_3`/`B`
  and slot 4 uses `p*_ability_4`/`Y` (`Player.gd` ~line 984), so removing the third slot would
  shift the ultimate from index 3 to index 2 and change bindings mid-A/B. Instead, 2-mode keeps
  the four-slot structure: slots 1–2 hold the two picks, **slot 3 holds an explicit empty sentinel**
  (presses are no-ops, HUD hides it, upgrade eligibility ignores it — eligibility reads actual
  equipped ability IDs, already exact-gated), and **the ultimate stays at slot 4 / `Y`** with
  unchanged bindings and muscle memory across both A/B modes. RunState normalization in 2-mode =
  two picks + empty sentinel + ultimate.
- No pool/data changes — a pick-count seam through the three named call sites, cheap to remove
  after the verdict.

**Gate:** both modes bootable 1P/2P; encyclopedia/HUD render correctly in 2-mode;
`FeelPolishAcceptance` green.

## Slice 6 — Deciding Playtest (measurement gate; closes three open questions)

One structured 1P/2P playtest, after Slices 1–5 land, decides:

1. **Spawn model** — trickle vs pulsed (Builder A/B configs A1/A2/A3 from Round 1 + full runs).
2. **Kit size** — 3+ult vs 2+ult (same rooms, both modes).
3. **Perf reality check** — the three felt scenarios in live play (does it FEEL fixed).

**Output:** verdicts recorded in the findings doc; the losing spawn model and losing kit size are
removed in a small follow-up slice; then the **class-balance tuning plan** (4b successor) is drafted
against the winning configuration — exact values, **Mobile-baseline principle**, MC-locked before
implementation. No balance numbers change before that lock.

---

## Notes

- Order: **Perf instrument → Perf fix → Fixes → Juice → Kit prototype → Deciding playtest.** Perf
  first because a structural change invalidates any balance/feel testing done before it.
- Class balance ("very differently balanced") is deliberately LAST as the post-verdict tuning plan —
  balancing before the spawn-model + kit-size + perf ground shifts would be wasted work.
- Parallel Codex may edit the tree — re-read files before each edit; check `git status` before
  commit/revert. Validate + commit per slice.
