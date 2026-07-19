# V4 Feel & Polish Patch — Phase 1 of the V5 Roadmap (plan, 2026-07-19, rev 6 after fifth review)

> Decided with the user on 2026-07-19 from the live playtest findings. Rev 2 fixed the first review's six
> framing blockers; rev 3 fixed the second review's six implementation blockers; rev 4 fixed the third
> review's findings (trickle-preservation over strict equality, launchable Slice-4 configs + Builder
> extension, lazy deterministic hazard sequence, profile sandbox, exact connectivity geometry); rev 5
> fixed the fourth review's findings (Builder reproducibility, archetype resolution, sandbox modes +
> snapshots, paired repetitions); rev 6 fixes the fifth review's findings (Builder-only WaveDirector RNG
> instead of seeding the shared global RNG, per-type distribution gating, lazy-sequence wording,
> Upgrade terminology). Parent roadmap:
> `docs/development/v5-roadmap.md`. Branch `v4/class-system`, checkout `D:\GameDev\Project_Twin_stick`.
> **Plan only — nothing below is implemented yet.**
>
> **Slice pattern:** implementation slices (2, 3) contain exact changes. Measurement slices (1, 4, 5)
> change no behavior/values; each produces evidence and, if action is warranted, a follow-up subplan
> (1b / 4b / 5b) with exact changes that is **locked with the user (MC) before implementation**.

## Playtest Findings Driving This Patch (2026-07-19)

- Sawblades are too small.
- Aimed abilities (e.g. Fireball) are clunky to use.
- Fire floor forces camping in one safe spot; should be mostly-normal floor with spreading hazard patches.
- Weapons feel uneven (some very strong, some weak); suspicion that **how enemies appear** (continuous
  trickle) is the structural cause, not the numbers.
- Gameplay loop itself is validated; missing pieces are visuals, SFX, and balance.

## Locked Decisions

- **Risk class parked.** No Risk-specific work (mechanic, numbers, ability presentation, flamethrower).
  **Boundary:** shared/global systems (juice tuning, spawn model, arena changes) still apply to Risk;
  playing Risk to *measure* (e.g. Rocket Launcher data) is allowed. Beam also parked.
- **Hazard Floor inversion applies to Fire and Frost.** Mine already plays roam-and-avoid and stays
  exactly as-is.
- **Spawn-model toggle applies at next room start.** No mid-room switching.
- **Hazard patch placement is fully deterministic** (locked 2026-07-19): lazily generated deterministic
  per-seed sequences (drawn on demand from a dedicated RNG — see Slice 2c), independent of player
  positions; fairness comes from the telegraph, not proximity exclusions.
- **Directional abilities use a nonzero fallback** (locked 2026-07-19): weapon direction when nonzero,
  else last facing — a pressed ability never emits a zero vector.
- **Trickle preservation wins over strict spawn equality** (locked 2026-07-19): trickle stays
  byte-identical as the A/B control; pulsed reuses trickle's own cap semantics (shooter-budget melee
  substitution, blocked-batch discard) at its pulse moments. No backlog semantics anywhere. Equality is
  claimed only for uncapped scenarios.
- **The Encounter Builder is extended in Slice 3** (locked 2026-07-19) with archetype, WHERE + variant,
  depth, and seed controls so the Slice-4 configs launch reproducibly from the UI.
- Out of scope: full artstyle change, broad pathfinding/physics refactor, external playtesting.

## Validation Framework

```powershell
$GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
$PROJ  = 'D:\GameDev\Project_Twin_stick'
git -C $PROJ diff --check                                                        # every slice
& $GODOT --headless --path $PROJ --quit                                          # parse, every slice
& $GODOT --headless --path $PROJ res://scenes/ui/Bootstrap.tscn --quit           # smoke boot, every slice
```

- If a slice touches any `data/*.json`, run a JSON parse check on the touched files first.
- **Baseline rule (applies to every slice claiming the tolerance):** immediately before the slice's
  first change, take a **3-run pre-baseline in the same quiet session** of every profile that slice's
  gate compares (always including `champion:hive --players=2 --build=heavy`). If the session is
  interrupted, retake the baseline. Pass = post **median** `avg_fps` ≥ **95%** of pre median, and, where
  the profile emits `min_fps`, post `min_fps` ≥ **60** in all 3 runs. `flowfield_stress` is exempt from
  the 60 floor (its gate is documented as failed) but must pass the 95% rule.

---

## Slice 1 — Performance Measurement Gate (no implementation changes)

- In one quiet session: 3 deterministic `flowfield_stress` runs at 160 (recorded individually), plus a
  profiling breakdown of where cover-room frame time goes (physics/body movement vs flow-field sampling
  vs rendering), using the existing harness instrumentation.
- Output: a short findings section in `docs/development/v4-feel-polish-findings.md` — baseline numbers,
  the dominant cost with evidence, and **candidate** bounded optimizations (described, not implemented).
- **Then:** if any candidate looks worthwhile, subplan **1b** lists the exact change(s), is locked with
  the user, and is implemented/validated separately. If none, the ceiling is documented and Phase 1
  proceeds without perf work.

**Slice gate:** findings section exists with 3 recorded baseline runs + cost breakdown; no source files
changed by this slice (`git status` clean of code edits).

## Slice 2 — Concrete Feel Fixes (implementation)

### 2a. Aimed-ability direction

- Today `Player._try_activate_ability` (~line 778) computes ability direction from movement facing and
  never consults the auto-target, while the weapon uses `_get_weapon_fire_direction` (~line 509).
- **Exact behavior of the helper today (verified):** manual aim active → manual vector; else auto-target
  found → toward target; else `manual` mode with no input → **zero**, `auto` mode with no target →
  **zero** (unless movement fallback applies), `movement` mode → move facing. The weapon simply holds
  fire on zero; an ability must not eat a cooldown on a zero vector.
- **Fix (exact rule, locked):** at cast time, refresh `_find_auto_target` and compute
  `_get_weapon_fire_direction(manual_aim_active)`; if the result is **nonzero**, use it; if **zero**,
  fall back to `_aim_facing` (last facing, initialized to `RIGHT`, never zero). The ability always casts;
  the cooldown is consumed exactly as today.
- **Dash is excluded** — it keeps `DashData.get_direction()`.
- Affected: `fireball`, `blood_lance`, `sonic_boom`, and any ability consuming the emitted direction.

**Gate 2a:** temporary headless acceptance script covering: mocked auto-target + no manual aim → direction
equals weapon direction (toward target); manual vector active → equals manual vector; `manual` mode, no
input, stationary → equals last `_aim_facing` (nonzero); `movement` mode → move facing while moving.
Plus a live check: Fireball visibly launches at the auto-targeted enemy.

### 2b. Sawblades larger

- Increase sawblade radius (first-pass `+40%`, one tunable constant). Re-validate the guaranteed `120px`
  dodge lane across all 3 layouts and the no-pair rule with Shrinking Arena.

**Gate 2b:** WHERE smoke, Roaming Sawblades, 3 variants × 1P/2P, dodge-lane assertion at the new radius.

### 2c. Fire/Frost Hazard Floor inversion (spreading-patch model)

Replace the off-safe-zone model in `HazardFloorMechanic.gd` for `fire_grid` / `frost_grid` with
mostly-safe floor + spreading patches. `mine_grid` untouched. First-pass spec (single tunable constants):

- **Lifecycle:** telegraph `0.8s` (existing telegraph visual language, no damage) → grow `120px → 260px`
  over `6.0s` → hold `4.0s` → fade `1.0s` (no damage during fade).
- **Cadence & cap:** first patch at `START_GRACE` (`1.5s`); one new patch every `2.5s`; max **8**
  concurrent non-faded patches (≈22% of the 3600×2100 arena at worst — majority-safe by construction).
- **Damage (existing values):** inside any active patch — fire `8` per `0.75s` tick; frost `6` per tick
  plus the existing `frost_grid` zone slow (`0.5`) while inside, clearing on exit. Overlaps deal one tick
  per interval per player. Players-only.
- **Placement (fully deterministic, lazy):** the mechanic owns one `RandomNumberGenerator` seeded once
  at setup with the stored route seed + variant index (same seeding pattern as `_build_mine_sets`) and
  used for **nothing else**. Each time a new patch is due, the next center is drawn **on demand** from
  this RNG: uniform over the arena inset `200px`, re-drawing while the candidate is closer than `250px`
  to the previous accepted center (the rejection loop consumes draws deterministically). No pre-roll
  length is needed — room duration has no fixed maximum (continuation rooms extend it), and the lazy
  sequence is identical for a given seed regardless of how many patches a room ends up needing.
  **No player-relative terms.** Fairness = the `0.8s` telegraph. Retries reproduce the identical
  sequence (existing stored-seed behavior).
- **Hidden layouts preserved:** 3 variants per skin = 3 distinct sequences; the shared family no-repeat
  history and retry stability are untouched.

**Gate 2c:** WHERE smoke, Fire + Frost, 3 variants × 1P/2P, with assertions: (1) patch count ≤ 8;
(2) no damage during telegraph/fade; (3) reachability, sampled `1/s`, on an exactly specified grid:
cells of `60px` spanning the arena rect (origin = arena position, 3600×2100 → 60×35 cells); a cell is
**safe** iff its center's distance to every active (non-telegraph, non-fade) patch center exceeds that
patch's current radius **+ `40px` player-clearance inflation** (matching the obstacle-inflation
convention); assert safe cells ≥ 50% of all cells AND the largest 4-connected safe component contains
≥ 95% of safe cells — the inflation term ensures a "connected" corridor is actually traversable by a
player body, not a zero-width gap; (4) two runs with the same route seed + variant produce **identical
center sequences** (exact position equality). Mine floor re-runs its existing smoke unchanged.

## Slice 3 — Spawn-Model A/B Prototype + Debug Tooling (implementation)

### Prototype rules (exact)

- `RunState.spawn_model`: `"trickle"` (default) | `"pulsed"`. **The trickle code path is not modified.**
- **Pulsed model:** opening burst and periodic `_burst_interval` bursts are identical in both models.
  Only the stream changes: the same schedule (identical interval/ramp/`melee_density` math, identical
  `_consume_scaled_stream_count` accounting) accumulates into a group; the group spawns as one pulse
  every `PULSE_PERIOD := 4.0s`, spread over `PULSE_SPREAD := 0.8s` from up to `PULSE_EDGES := 2` edges,
  then a lull. Constants in one `SpawnModel` block in `WaveDirector.gd`.
- **Cap semantics (exact, locked — trickle preservation wins):** trickle's live behavior at caps is
  substitution/discard, not deferral (shooter budget full → melee substitute; a cap-blocked stream batch
  is dropped). Pulsed introduces **no new backlog semantics**: at each pulse's spawn moments it applies
  **exactly trickle's substitution/discard rules** via the same code paths. All caps stay authoritative
  in both models; trickle's code path and event log remain byte-identical.
- **RNG (exact):** trickle's RNG usage is untouched. Pulsed draws its composition/edge/jitter rolls from
  a **dedicated RNG stream** seeded from the room seed so its sequences are reproducible run-to-run;
  cross-model type-sequence identity is **not** claimed (both models draw from the same weight tables —
  verified by code inspection, not runtime assertion).
- **Equality definition (exact, weakened deliberately):** pulsed consumes the **same stream schedule**
  (identical interval/ramp/`melee_density`/`_consume_scaled_stream_count` math), so in an **uncapped
  scenario** (open room, no cover cap, shooter budget never saturated, no combat) both models spawn the
  **same total enemy count**, asserted by the harness. In capped rooms, outcomes may legitimately diverge
  because cap state depends on timing — that divergence is part of the rhythm difference the A/B tests,
  and Track A includes capped configs on purpose.
- **Switching (locked):** model read once at room start; overlay toggle sets a pending value shown as
  `active / pending`.

### Toggle surfaces + perf readout

1. Encounter Builder row; 2. pause debug overlay (active/pending display + toggle); 3. debug-gated Run
Setup row; 4. debug overlay perf readout: FPS + enemies / active projectiles / player deployables.

### Encounter Builder extension + profile sandbox (locked, this slice)

- The Encounter Builder gains debug-gated controls for **archetype** (the five IDs from
  `data/room_archetypes.json`), **WHERE + variant** (constrained to the selected archetype's
  `where_pool`, variants `0/1/2`), **depth** (numeric), and **seed** (numeric) — so any Slice-4 config
  is launchable and reproducible from the UI. Invalid archetype/WHERE pairs are not selectable.
- **Builder archetype resolution (exact):** the Builder must not construct an empty-archetype node.
  A Builder launch builds its single-room node through the **same generation path normal runs use**
  (forced archetype ID → the archetype's composition, `density_profile`, and twist handling with
  modifiers forced empty; WHERE + variant as selected; depth as entered), so the room is
  indistinguishable from a normal-run room of that archetype at that depth.
- **Debug determinism (exact — no global-RNG seeding):** live trickle spawning draws from Godot's
  **global** `randf`/`randi`, and seeding that shared RNG would affect every other consumer (combat
  effects, health drops, side objectives), let player-dependent calls perturb later spawn rolls, and
  leak seeded state into a subsequent normal run in the same process. Instead, **WaveDirector's
  spawn-decision rolls go through a tiny internal indirection** (`_randf()` / `_randf_range()` /
  `_randi_range()` helpers):
  when `RunState.debug_spawn_seed` is `0` (default, all normal runs) the helpers call the global
  `randf`/`randi` exactly as today — behavior-identical, proven by the trickle event-log check; when the
  Builder sets a nonzero seed, the helpers draw from a **WaveDirector-owned `RandomNumberGenerator`**
  seeded once at room start. `ArenaGeometry.enemy_spawn_position_for_edge()` and
  `enemy_spawn_position_for_index()` gain an optional RNG parameter; when supplied they use that RNG
  for coordinate rolls, and when omitted they retain today's global `randf_range()` behavior.
  WaveDirector supplies its owned RNG only for seeded Builder/pulsed spawn decisions, so edge and
  coordinate rolls share the isolated stream while normal trickle remains behavior-identical. The
  global RNG is never seeded, nothing leaks across rooms or into normal runs, and non-spawn consumers
  are unaffected. **Reproducibility scope (explicit):** what reproduces is the **spawn sequence**
  (time, type, position) — every WaveDirector edge/type/coordinate roll; whole-room randomness outside
  spawn decisions (drops, VFX) is out of scope. The pulsed model's dedicated stream is seeded from the
  same field in Builder launches (its usual room-seed derivation otherwise).
- **PerfRunner gains a `--spawn-model=<trickle|pulsed>` argument** (parsed alongside `--profile`, sets
  `RunState.spawn_model` before the scenario builds) — required by this slice's gate and Slice 4.
- **Profile sandbox (exact, two modes):** a `--profile-sandbox=<fresh|keep>` launch argument redirects
  `ProfileState` load/save to a sandbox file (`user://profile_sandbox.cfg`); the real profile file is
  **never read or written** in either mode. `fresh` deletes the sandbox at launch (genuinely fresh
  profile); `keep` loads the existing sandbox file as-is (enables controlled snapshots: copy a saved
  sandbox state into place, then launch with `keep`). Every Track B run uses one of these modes.

**Slice gate:** (1) uncapped-equality harness — open room, no cover cap, shooter-light composition, no
combat, same seed + config under both models: **equal total spawn count**; (2) trickle no-change proof —
spawn event log (time, type) under `trickle` identical before vs after the slice for a fixed seed;
(3) Builder extension check — each Slice-4 config (A1/A2/A3 below) launches from the Builder with its
composition/density/depth resolved from the archetype table (not an empty node), and reproduces its
WHERE layout **and spawn sequence (time, type, position)** across two launches with the same seed (via
`debug_spawn_seed` + the WaveDirector-owned RNG); a normal run after a seeded Builder launch in the
same process is verified to spawn normally (no seeded-state leak — the global RNG is never seeded);
(4) sandbox check — `fresh` starts with a fresh profile, `keep` loads a pre-placed sandbox file
unchanged, and both leave the real profile file byte-identical; (5) perf, 3 runs each, against this
slice's pre-baseline per the framework:

```powershell
& $GODOT --headless --path $PROJ -- --profile=champion:hive --players=2 --build=heavy --spawn-model=trickle
& $GODOT --headless --path $PROJ -- --profile=champion:hive --players=2 --build=heavy --spawn-model=pulsed
```

(6) all three toggle surfaces work and the overlay readout matches reality.

## Slice 4 — Balance Measurement & Playtest Gate (no value changes)

Two evidence tracks; neither changes numbers.

### Track A — single-room weapon A/B (Encounter Builder)

- **Room configs (exact; IDs verified against `data/room_archetypes.json` `where_pool`s):**
  A1 = `horde` + `open`, no modifiers, depth 3, seed `1001` (open baseline).
  A2 = `gauntlet` + `bastion` variant 0, no modifiers, depth 6, seed `1002` (physical-cover WHERE —
  Bastion is only in Gauntlet's pool; Gauntlet's `depth_gate` 4 ≤ 6).
  A3 = `mixed` + `fire_grid` variant 0, no modifiers, depth 8, seed `1003` (inverted Hazard Floor —
  `fire_grid` is in Mixed's pool).
  All three launch from the extended Encounter Builder (Slice 3).
- **Loadouts (exact, reproducible):** weapon level 1, zero Upgrades (code: `starting_mutations = []`),
  no temp buffs. Rifle → Mobile
  (Dash / Shockwave / Afterburn), Shotgun → Tank (Dash / Ground Slam / Orbit), Whirlwind → Tank (same
  abilities), Arc Wand → Controller (Dash / Turret / Orbit), Rocket Launcher → Risk (Dash / Overcharge /
  Shield; measurement only, no Risk tuning).
- Matrix: 5 weapons × 3 configs × both spawn models × 1P (2P spot-checks on A2 only). Notes per cell:
  clear feel, weak/strong moments, burst-vs-sustain read.
- **Noise control (exact):** the two models use different RNG streams and do not promise matching enemy
  sequences, so single runs can mistake a lucky/unlucky composition for a rhythm effect. Each cell is
  therefore played as **two paired repetitions** (seeds `S` and `S+1000`, both models at both seeds),
  and every run logs its **actual spawn composition** (per-type counts, via the Slice-3 spawn event
  log). A cell's feel notes count toward the verdict only when, for that seed, the two models' logged
  totals are within **10%** AND the normalized per-type distribution matches (each enemy type's share
  of the total differs by ≤ **5 percentage points** between models — equal totals with a substantially
  different charger/spitter/splitter mix must not pass); cells outside either band are marked
  *quantity-confounded* and their notes
  weigh rhythm + quantity together (expected mainly on the capped A2 config). A1 (open, uncapped) is
  the primary evidence config since totals must match there.

### Track B — full-run scenarios (economy / lean start / deep rooms)

- 2 full 1P runs **per spawn model** + 1 full 2P run per model, each played to at least room 12 or
  death. **Every Track B run uses the sandbox** (the real profile is never read or written), with
  paired starting states (exact protocol):
  1. Trickle 1P run 1: `--profile-sandbox=fresh` (lean-start observation). Afterwards, copy
     `user://profile_sandbox.cfg` → `profile_snapshot_S1.cfg` (snapshot S1 = post-first-run state).
  2. Pulsed 1P run 1: `--profile-sandbox=fresh` (identical fresh start to step 1).
  3. Trickle 1P run 2: copy S1 into place, launch `--profile-sandbox=keep`.
  4. Pulsed 1P run 2: copy S1 into place, launch `--profile-sandbox=keep` — both second runs start
     from the **same immutable snapshot**.
  5. 2P run per model: copy S1 into place, `keep` — again identical paired starts.
- Observations recorded per run: reroll/skip usage and cost pressure, lean-start pool feel, rooms-10+
  pressure and champion readability.

**Output:** `docs/development/v4-feel-polish-findings.md` — Track A matrix, Track B notes, and the
**spawn-model verdict**. **Then:** subplan **4b** with exact tuning values, locked with the user (MC),
implemented and validated as its own slice. The verdict also decides whether the losing spawn model is
removed in 4b or carried to Phase 2.

**Slice gate:** findings doc complete (all Track A cells + Track B runs recorded) and states the verdict;
4b drafted and user-locked before any number changes.

## Slice 5 — Impact Audit Gate (no tuning in this slice)

The juice infrastructure already exists and is wired: `HitStopManager`, `ScreenShake` trauma, sparks /
flashes / kill effects / room-clear flourish (`CoopManager.gd` ~1680–1930), procedural `SfxEngine`.
This slice **audits only**:

- Inventory every hitstop weight, trauma value, spark/flash call site, and SFX event into a coverage
  table (event → effect → current value, per weapon/ability/enemy tier).
- Mark gaps (candidates to confirm: per-weapon-identity fire SFX differentiation, kill-pop distinctness)
  and flat-feeling values from a structured 1P/2P feel check.
- **Then:** subplan **5b** lists exact value changes + gap-fill beats, locked with the user (MC),
  implemented/validated separately. Shared systems apply to all classes including Risk; no Risk-specific
  beats. Single shared dynamic camera; existing screen-effects settings respected.

**Slice gate:** coverage table + proposed-change list committed to the findings doc; no source changes
from this slice; 5b drafted and user-locked before any tuning.

---

## Notes

- Order: **Perf gate → Feel fixes → Spawn A/B → Balance gate → Impact gate**, with 1b/4b/5b subplans
  entering only after user lock. Implementation happens in slices 2, 3, and the approved subplans.
- Parallel Codex may edit the tree — re-read files before each edit; check `git status` before
  commit/revert.
- Validate + commit per slice; never leave a broken intermediate state.
