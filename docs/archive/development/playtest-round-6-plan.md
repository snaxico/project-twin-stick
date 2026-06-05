# Round 6 Plan — Performance + Gameplay

## Context

Playtest of the round-5 build surfaced new findings, plus performance has now recurred across
rounds 4 (F14), 5 (#3), and 6 (#3). This single plan covers both **Part A — Performance** (the
prerequisite) and **Part B — Gameplay**.

Round-6 findings:
1. Duration mutation unclear interaction with Blink/Dash. → **B4**
2. Pulsar still trivial — wants more trash mobs, mobility, defensive capability. → **B3**
3. Performance still bad with the sweep modifier + 80+ entities. → **Part A**
4. "Mine Field" modifier misnamed — reads like a laser/sweep, not mines. → **B1**
5. Boss fights still trivial across the board. → **B2** (add-heavy direction)

**Gating:** Part B §2 (heavy boss add-waves, on-screen cap ~25 on top of a boss + swarm +
projectiles) is **gated behind Part A** — do not ship heavy add-waves until the cheap-win perf
work lands and a deep room holds frame rate. The other B items are independent and can land
first.

**Project philosophy — gameplay first, art later:** lock in content and feel now; decide the
art style (keep the current vector/neon look, or move to hand-drawn **rubberhose/Cuphead**) only
*after* gameplay is settled. This shapes the performance sequencing (see A: Sequencing).

---

# Part A — Performance (prerequisite)

## A0. Root cause & target

The game uses a **node-per-entity** model:
- **Enemy** = `CharacterBody2D` + 3 `Polygon2D` draws (`Shadow`, `BodyRoot/Outline`,
  `BodyRoot/Visual`) + `CollisionShape2D` + per-frame `_physics_process` / `_update_visual_state`.
- **Projectile** = `Area2D` + 2 `Polygon2D` draws, pooled.
- **Hazards** = mixed: `scripts/game/HazardZone.gd` is already a `Node2D` driven by external
  distance checks (efficient), but `scripts/weapons/FireTrailZone.gd` is an `Area2D`.

At ~80 enemies + ~50 projectiles this produces **~350+ Polygon2D draw calls/frame** (Polygon2D
does not batch), ~80 `move_and_slide` calls, ~50 `Area2D` overlap monitors, plus immediate-mode
`_draw` in some modifiers. Each content patch adds entities, so frames regress again — prior
fixes lowered the constant factor but not the model. **Target:** a boss + heavy add-waves (~25)
+ swarm + projectiles (~150-250 active entities) holding acceptable frame rate at 1P and 2P.

### Go/no-go gate (numeric — gates B2)

The synthetic harness is for **before/after diagnosis only**, NOT the shipping gate — it is
optimistic (no HUD, boss AI, particles, player weapons, multiple modifiers), so "stable in the
harness" does not mean "stable in a real boss room." The gate to unlock heavy boss add-waves is a
**real boss-room stress test** (Encounter Builder boss room with HUD + particles + boss AI +
player weapons + at least one modifier), measured at **1P and 2P**:

> **Stable = holds ~60 FPS at the intended capped density (start ~150-200 entities, tune the
> exact number) with no obvious frame spikes during Scanline + Fire Bullets + boss add pressure,
> at both 1P and 2P.**

If the real-room test fails this, do not ship B2 at the heavy cadence — lower the cap, finish
more A2 wins, or pull MultiMesh (A3) forward.

**Resolving the gate's circularity:** the gate measures FPS "during boss add pressure," but B2
*is* the add pressure — so the pressure must exist to run the test, without being "shipped."
Resolve by **building the `_update_boss_add_waves()` mechanism first, behind a debug/dry-run
toggle** (e.g. an Encounter Builder flag or a `debug_run_setup` key), run the real-room gate with
it enabled at the intended heavy cadence + cap, and only **promote it to "shipped"** (on by
default in normal runs) after it passes. A dry-run behind a debug flag is *not* considered
shipped. (Optionally also extend the harness to instantiate a real boss + adds as a closer proxy,
but the debug dry-run in a real room is the authoritative gate.)

## A1. Profile — Phase-0 baseline (MEASURED 2026-06-03)

Captured via a profiling harness (`scenes/dev/ProfilingHarness.tscn` +
`scripts/dev/ProfilingHarness.gd`). **Keep these committed as dev tooling** — they are needed to
re-measure after each perf change (through A3) and for future profiling. They are inert (not in
the main scene, no game-system coupling); remove only once all perf work is finished, if desired.
Captured with mixed enemy types +
player projectiles, camera framing the whole arena, **vsync off** to expose the ceiling. Each
step holds N enemies + N projectiles; two passes (with/without the sweep "Mine Field" modifier):

| entities (enemy+proj) | FPS w/ minefield | FPS no minefield | process ms | physics ms | draw calls |
|---|---|---|---|---|---|
| 100 | 603 | 716 | 4-4.4 | 4.5-7.7 | 254-309 |
| 200 | 113 | 190 | 6-7 | 9-11 | 518-643 |
| 300 | **7.8** | **33.1** | 9.6-17.5 | 13.8-18.2 | 780-1038 |
| 400 | 5.1 | 6.6 | 22.9-26.4 | 18.6-23.5 | 1037-1284 |

**Findings (drive the priorities):**
- **Render-bound at scale.** At 400 entities frame time ≈151ms but `process+physics` ≈41ms —
  the ~110ms gap is rendering; draw calls scale linearly with entity count. → MultiMesh (A3) is
  the durable fix, **deferred to the art decision**.
- **The sweep/"Mine Field" modifier is a ~4× multiplier** (300 entities: 33→7.8 FPS) via
  per-frame immediate-mode `_draw`. → A2 + the **Scanline rework (B1)** is the single biggest
  cheap win.
- **Physics is NOT the bottleneck** (`physics_ms` modest, ~linear). → **A4 dropped.** Harness is
  optimistic (no HUD/boss/particles/weapons), so the real-gameplay cliff sits below these counts
  — consistent with in-game lag at ~80+ entities.

*(For a fully reproducible manual re-measure: all RNG uses `randomize()` — no seed support; pin
the Encounter Builder config (1P, single_room, combat, `enemy_mix=mixed`, max `step_index`, no
modifiers) and average over a 10s steady-state window. Optional 1-line hardening: honor a
`debug_run_setup["seed"]`. Re-run the harness after each fix to measure deltas.)*

## A2. Cheap wins — do now (low risk)

Art-agnostic (✅ carry over regardless of vector/sprite) except where flagged. Also establish the
**rendering seam** here.

- ✅ **Split `_update_visual_state` (`Enemy.gd:1100`), don't blanket-throttle it.** It mixes
  *static* work (scale, `visual.color`, `outline.color`, collision radius ~1116-1122) with
  *per-frame* work that must keep running: `body_root.rotation` velocity-lerp (1120) + fuse
  modulation. Extract static parts into `_refresh_static_visuals()` called on
  spawn/hit/phase/shield/status change; leave rotation + fuse in `_physics_process`. (Biggest
  script-side win; throttling the whole method would freeze enemy facing.)
- ✅ **Convert `FireTrailZone` to the `HazardZone` model** — only `FireTrailZone.gd` is an
  `Area2D`; mirror `HazardZone.gd`'s `Node2D` + external distance-check pattern so heavy Fire
  Bullets stops adding physics bodies. **Target routing is team-dependent** (unlike `HazardZone`,
  which only checks players): a player-team zone must damage **enemies** via
  `CoopManager.get_nearby_enemy_target_nodes(pos, radius)`, while an enemy-team zone damages
  **player** nodes. Preserve the existing `team` / `get_team() == team` friendly-skip already in
  `FireTrailZone`. (Include `HazardZone.gd` if also batching hazard `_draw`s.)
- ✅ **Confirm pooled projectiles fully sleep** when inactive (`_finish_projectile` already
  disables monitoring/process — verify no residual cost).
- ✅ **Fewer draws per enemy — DO NOW** (moved out of "deferred"). Drop `Shadow` / merge
  `Outline` into `Visual` (`Enemy.tscn`): 3→1-2 draws. This is one of the **few immediate wins
  that directly cuts the per-enemy render cost** — and since the profile is render-bound with
  draw calls scaling per enemy, it's exactly what heavy add-waves need. **Not meaningful rework
  if the art changes later:** if we move to sprites, the whole visual subtree is replaced anyway,
  so this is superseded, never "redone" (unlike MultiMesh, which is a genuine art-coupled
  architecture). The only real cost is a **readability change** (shadow/outline aid legibility) —
  so it needs a quick **visual check**, not an architectural decision.
  **Must update `Enemy.gd` too, not just the `.tscn`:** there are typed `@onready` refs
  `shadow: Polygon2D = $Shadow` and `outline: Polygon2D = $BodyRoot/Outline` (`Enemy.gd:33,36`)
  plus usages (`shadow.scale`, `outline.color` at ~1117-1119). Deleting the nodes without
  changing the script makes `$Shadow`/`$BodyRoot/Outline` resolve to null → runtime crash. Remove
  the refs + their usages (or switch to `get_node_or_null()` + null guards) in the same change.
- ✅ **Rendering seam:** keep gameplay state (`Enemy.gd`/`Projectile.gd`: position, HP, action)
  separate from *how* it's drawn, so a later art swap + MultiMesh stays localized.
- Re-profile after these (re-run the harness); they may buy ~1.5-2× headroom alone.

## A3. MultiMesh rendering — DEFERRED to the art-decision phase

The durable fix for linear draw-call growth, **built once around the final art**. Render all
instances of one enemy type in a single `MultiMeshInstance2D`, all projectiles in another —
collapsing hundreds of draw calls into a handful.
- **Hybrid:** keep `CharacterBody2D`/`Area2D` for physics; move only *drawing* to MultiMesh,
  writing each live entity's transform + per-instance color/scale into the buffer each frame.
- **Rubberhose-compatible:** if art goes sprite-based, instances become textured quads with
  per-instance animation frame via `INSTANCE_CUSTOM` + a sprite-atlas shader (one draw call for
  a whole animated swarm). Bosses/elites (few, unique) stay individual `AnimatedSprite2D`.
- **Decision gate:** start only once the art style is chosen; until then A2 + the rendering seam
  is sufficient for gameplay iteration.

## A4. Spatial-hash collision — DROPPED (Phase-0 data)

Physics is not the bottleneck (`physics_ms` modest/linear; the wall is rendering). The highest-
risk work is not justified — skip unless a future post-A2/A3 profile shows physics dominating.

## A: Sequencing & the art-style decision

- **MultiMesh's form depends on the art** (instancing Polygon2D vs textured sprites) — building
  it now around vector shapes risks building it twice, so it's deferred (A3).
- **Do the art-agnostic cheap wins now** (A2); they fix frames today and carry over regardless.
- **Keep a clean rendering seam** — the single cheapest thing to keep both art doors open; with
  it, a later vector→sprite swap is localized to the rendering layer and never touches gameplay.
- The art **production** cost (drawing/animating assets) is art labor, unaffected by these code
  choices — paid whenever the switch happens regardless.

## A: Out of scope
- Full data-oriented / ECS rewrite. Overkill for a 1-2 player game at our target counts.

---

# Part B — Gameplay

## B1. Scanline modifier (rename + redesign of "Mine Field")

**Why (#3/#4):** Current modifier places a damage point every `MINE_SPACING=100px` with
`TRIGGER_RADIUS=34px` → ~32px gaps (an unfair near-solid wall) that *also* redraws ~48 circles +
48 24-segment arcs **per sweep per frame** (the ~4× perf multiplier from A1). Reads like a laser,
not mines.

**Design — Model A: sweeping wall with wide moving gaps.**
- Replace dense dot-mines with **2-3 wide (~150-180px) safe openings** to run/dash through. **Gap
  count parameterized; tuned in play.**
- Draw the wall as a few `draw_line` **segments** (skip gap spans) instead of per-mine
  circles/arcs — readable safe path *and* ~95% cheaper to draw. Keep the 1s telegraph; optionally
  drift the gaps.
- **Naming:** display name "Mine Field" → **"Scanline"** (`data/modifiers.json:54` + description
  line 57). **Keep id `mine_field`** + the `MineFieldModifier` class / `CoopManager` preload
  (`_mine_field_modifier`, ~line 780) to avoid data/preload churn (same as Fire Trail keeping its
  id).
- **Files:** `scripts/modifiers/MineFieldModifier.gd`, `data/modifiers.json`.
- **Reuse:** sweeping-wall-with-gaps tech doubles as a boss arena-control attack (deny free
  kiting), complementing B2.

## B2. Boss add-waves — "add-heavy" boss direction (GATED on Part A)

**Why (#5):** In an auto-fire, high-mobility game a lone high-HP boss is a trivial DPS check you
out-kite. Genre-leaders (Vampire Survivors, Brotato, Geometry Wars) create threat via density +
space denial, not 1v1 dueling. Direction: keep current boss kits, **layer a managed swarm**.

**Design — heavy cadence, capped:**
- Add `_update_boss_add_waves()` in `CoopManager.gd`, modeled on `_update_elite_add_waves()`
  (~842), called from the room tick (~801).
- **Heavy:** 4-5 every 5-6s. **Hard on-screen cap ~25** (top-up, never exceed).
- **Cap is over ALL non-boss enemies in the boss room, not just add-wave spawns.** Bosses
  already spawn minions natively (Hive shield/minions, Hydra phase adds, Pulsar minions), so the
  budget must count the live enemies container minus the boss — otherwise the real on-screen
  count blows past the perf gate. Either (a) `_update_boss_add_waves()` only tops up to
  `cap − boss_native_live_count`, or (b) route boss-native minion spawns through the same budget.
  Pick one; the cap is the hard ceiling the Part-A gate is validated against.
- **Count pending/reserved spawns, not just live nodes.** Spawning is deferred via
  `_queue_enemy_spawn()` → `_pending_enemy_spawns` (`CoopManager.gd:935/939`). The budget must be
  `live_non_boss_enemies + _pending_enemy_spawns` — checking only `_enemy_nodes` lets queued
  native + add-wave spawns overshoot the cap in the same frame.
- **Per-boss flavor** (keyed off `_room_config.boss_type`): Warden→chargers, Hydra→splitters,
  Hive→fold its existing minion spawns into this shared budget (avoid double-spawn),
  Pulsar→spitters (see B3).
- Stop topping up when the boss dies; let remaining adds be mopped up for room clear.
- **Files:** `scripts/game/CoopManager.gd`.

## B3. Pulsar rework (still-trivial fix)

**Why (#2):** Needs more trash, mobility, defense. (Lighter touch, on top of B2.) **Split by the
Part-A gate** — see below.

- **Mobility — reactive teleport (pre-A2, no entity-count impact):** in addition to the timed
  teleport (`_update_pulsar_behavior`, `Enemy.gd:883`), teleport when a player closes within
  ~250px. Keep the ~0.5s telegraph/invuln.
- **Defense — generalize the shield/immunity into boss-agnostic deflector state (pre-A2; the
  immunity *mechanism*, not the adds).** The Hive shield/immunity is currently **type-gated to
  `BOSS_HIVE`**: `_spawn_hive_shield()` early-returns unless `BOSS_HIVE`, and the `apply_damage`
  immunity check is wrapped in `if enemy_type == EnemyType.BOSS_HIVE` (`Enemy.gd:400-404`). So
  reusing it for Pulsar **requires generalizing first**: rename `_hive_shield_nodes` →
  `_boss_shield_nodes`, drop the `BOSS_HIVE` gate (make it "any boss with an active deflector"),
  and parameterize so both Hive and Pulsar share it. Pulsar is then immune while its deflector is
  up, regenerating on phase transition.
- **Trash + deflector-spawned adds (post-A2, entity-count increasers — GATED with B2):** the
  heaviest add cadence of the four (B2 flavor = spitters) and any deflector minions count against
  the B2 cap and must wait for the Part-A perf gate. Do **not** ship these before A2.
- **Files:** `scripts/enemies/Enemy.gd` (generalize shield state + Pulsar teleport),
  `scripts/game/CoopManager.gd` (deflector spawn helper if needed).

## B4. Duration mutation — exclude instant/movement abilities

**Why (#1):** `duration` (+33%/level) is applied in `_build_runtime_ability`
(`CoopManager.gd:565-571`). For **Blink** (instant, duration 0) it's a **dead stat** (its
`arrival_iframes` aren't scaled either); for **Dash** it lengthens the active = **invulnerable**
window (strongest/least-intended interaction).

**Design:** gate the duration scaling by ability `type` in `_build_runtime_ability` — **skip when
type is `instant` or `movement`** (Blink/Dash ignore it); only sustained abilities (Overcharge,
Shield, Turret, Minefield, Orbit, Decoy) scale. Update `data/mutations.json` `duration`
description to say it affects **sustained** uptime.
- **Files:** `scripts/game/CoopManager.gd`, `data/mutations.json`.

---

## Combined execution order

1. **B1 Scanline perf redraw** — line-segment draw + simple usable gaps. (Biggest measured perf
   win; land the perf redraw even before final gap-feel tuning — they share a file but are
   different work.)
2. **A2: split enemy static/per-frame visuals** (`_refresh_static_visuals()`; keep rotation/fuse
   per-frame).
3. **A2: convert `FireTrailZone`** carefully with **team-correct distance checks** — verify Fire
   Bullets still damage enemies and there's no friendly fire (correctness, not just FPS).
4. **A2: reduce enemy Polygon2D draw count now** (drop Shadow / merge Outline) — also
   remove/null-guard the typed `$Shadow`/`$BodyRoot/Outline` refs in `Enemy.gd` + visual check.
5. **Build `_update_boss_add_waves()` behind a debug/dry-run toggle**, then **re-profile BOTH**
   the harness (before/after diagnosis) **and a real boss-room stress setup** with the dry-run
   add pressure enabled (the go/no-go gate above — HUD + particles + boss AI + weapons +
   modifier, 1P and 2P). A dry-run behind a flag is not "shipped."
6. **Only if the real-room gate passes:** promote B2 to shipped (heavy cadence on by default) and
   add **B3's trash/deflector-spawned adds** (both share the B2 cap over all non-boss enemies,
   counting live + `_pending_enemy_spawns`).
7. **Keep A3 MultiMesh deferred** unless the real-room profile still shows render-bound failure;
   then build it once around the chosen art. **A4 spatial-hash stays dropped.**

*Independent, land anytime in steps 1-4 (no entity-count impact):* **B4 Duration fix** and **B3
mobility (reactive teleport) + the generalized deflector *immunity mechanism***.

## Combined files touched

| File | Part | Change |
|------|------|--------|
| `scripts/enemies/Enemy.gd` | A2 | Split static visuals → `_refresh_static_visuals()`; keep rotation/fuse per-frame (✅) |
| `scripts/weapons/FireTrailZone.gd` + `CoopManager.gd` | A2 | `FireTrailZone` `Area2D` → `Node2D` distance-check (✅) |
| `scripts/game/HazardZone.gd` | A2 (opt) | Only if batching hazard `_draw`s (✅) |
| `scenes/enemies/Enemy.tscn` **+ `scripts/enemies/Enemy.gd`** | A2 | ✅ Drop/merge Polygon2D draws (3→1-2) — **do now** + visual check. Must also remove/null-guard the typed `@onready $Shadow`/`$BodyRoot/Outline` refs + usages or it crashes |
| `CoopManager.gd` + entities | A3 (deferred) | MultiMesh draw buffers — built once around final art |
| `scripts/modifiers/MineFieldModifier.gd`, `data/modifiers.json` | B1 | Scanline: gap mechanic + segment draw + rename |
| `scripts/game/CoopManager.gd` | B2 | `_update_boss_add_waves()` + cap over **all non-boss enemies** + per-boss flavor |
| `scripts/enemies/Enemy.gd` (+ `CoopManager.gd`) | B3 | Generalize Hive shield/immunity → boss-agnostic deflector (drop `BOSS_HIVE` gate); Pulsar reactive teleport |
| `scripts/game/CoopManager.gd`, `data/mutations.json` | B4 | Duration type-guard + copy |

## Verification

1. Headless parse: `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick --quit`
2. **Diagnosis:** re-run `scenes/dev/ProfilingHarness.tscn` after A2 to measure the gain vs the
   Phase-0 baseline (before/after only — NOT the shipping gate).
3. **Shipping gate (gates B2):** real boss-room stress test per the Go/no-go gate above —
   Encounter Builder boss room with HUD + particles + boss AI + player weapons + ≥1 modifier,
   at **1P and 2P**, holding ~60 FPS at the capped density with no obvious spikes during
   Scanline + Fire Bullets + boss add pressure.
4. **FireTrailZone correctness** (not just frames): player Fire Bullets still damage enemies,
   enemy zones still damage players, no friendly fire.
5. Manual playtest checklist (write after implementation):
   - Scanline has clearly visible safe gaps; threadable/dashable; reads as a laser/sweep; no
     longer a perf hot spot.
   - Enemy readability still fine after dropping Shadow/Outline (visual check).
   - Boss add-waves create real density pressure; on-screen count (all non-boss enemies) stays
     ≤ cap; frames hold per the real-room gate.
   - Pulsar can't be cornered (reactive teleport); deflector forces clearing adds before damage.
   - Duration mutation does nothing to Blink/Dash; still works for sustained; copy accurate.
   - Deep-room frame rate holds at the target entity counts at 1P and 2P.
