# V4 — Flow-Field Perf Fix (Codex-ready)

> **Phase 1** of the room/enemy redesign — unblocks physical obstacle layouts for the curated rooms
> ([[v4-curated-rooms-plan]]). The flow field is currently **inert in normal play** (no room authors
> obstacles) but **perf-blocked** for when they do: `flowfield_stress` = **16 fps @ 200 enemies** vs **142 fps**
> baseline (a 9× / ~55ms-per-frame hit from just 4 thin `StaticBody2D` bars). Branch `v4/class-system`, active
> checkout `D:\GameDev\Project_Twin_stick`.
>
> **Validation gate (per slice):**
> ```powershell
> $GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' --quit                                    # parse
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=flowfield_stress             # perf (avg_fps)
> ```
>
> **Finding (verified in `FlowField.gd`):** `sample()` is **already O(1)** in the common case (enemy cell →
> `vectors[current_index]` → return). The flood (`_nearest_reachable_direction`) only runs for enemies in
> **blocked/unreachable** cells and is cached. So the 9× is **not** obviously `sample()` — but two fixes are
> **safe and defensible regardless of the true cause**, so we apply both and re-measure (LOCKED via MC
> 2026-07-07). If it's still < 60 after, escalate to bucket instrumentation (deferred diagnostic, §Fallback).
>
> **Enemy collision radius = 19px** (`scenes/enemies/Enemy.tscn`) — inflation only needs radius + a small
> margin; the current **84px is ~4.4× the radius**, needlessly fat.

---

## Slice 1 — Reduce obstacle inflation 84 → 40 (`scripts/game/FlowField.gd`)

- **L4:** `const OBSTACLE_INFLATION := 84.0` → **`40.0`** (enemy radius 19 + ~21px clearance; physics
  `move_and_slide` remains the hard-stop backstop for any residual clip).
- **Effect:** each obstacle blocks a thinner ring of cells → **wider passages, less chokepoint funneling**
  (the leading physics-cost suspect) and fewer blocked cells to fill in Slice 2. Also relaxes the
  connectivity min-corridor requirement (was ≥ 2×84 = 168px, now ≥ 80px), enabling tighter authored layouts.
- No API change — `get_obstacle_inflation()` (L30) still returns the const; connectivity checks read it.

**Acceptance:** parse clean; `flowfield_stress` still routes 200 enemies around the 4 bars (they curve, none
stuck pressing a bar); avg_fps improves vs the 16-fps baseline (measure the delta from this slice alone).

---

## Slice 2 — Precompute nearest-reachable at build → `sample()` provably O(1) (`scripts/game/FlowField.gd`)

Move the flood out of the hot path (per-enemy, per-frame) into `build`/`update_targets` (once per rebuild,
gated on the player crossing a cell). Then `sample()` never floods.

**① `_build_vectors` (L191-219)** — currently leaves **blocked** (L196-197 `continue`) and **unreachable**
(L199-200 `continue`) cells as `Vector2.ZERO`. Instead, **fill them with a route-out vector** computed once:
- Keep the reachable case (`current_distance > 0`) exactly as-is.
- Keep the **target cell** (`current_distance <= 0`, L201-202) as `Vector2.ZERO` (enemy on target → caller's
  fallback/raw is fine).
- For a **blocked** or **unreachable** cell, set
  `vectors[index] = _nearest_reachable_direction(index, distances)` (the existing spatial ring-search toward
  the nearest finite-distance cell — pushes a stranded/inside-obstacle enemy back onto the field, which then
  carries it to the target).

**② `sample()` (L91-113)** — simplify to a pure lookup, delete the runtime flood branch:
- After `current_cell` / `current_index`: `if _is_cell_in_bounds(current_cell)`, return
  `vectors[current_index].normalized()` when `length_squared() > 0.0001`, else `fallback`.
- **Remove** the `_blocked[current_index]` guard (blocked cells now carry a route-out vector) and the entire
  `distances[...] >= INF*0.5 → _nearest_reachable_direction_cached(...)` block.

**③ Remove now-dead runtime cache:**
- Delete `_nearest_reachable_direction_cached` (L261-271).
- Drop `"nearest_cache": {}` from the field dict in `update_targets` (L82). **Keep** `distances` (used by
  `_build_vectors` + `target_reaches_points`) and **keep** `_nearest_reachable_direction` (now called at build).

**Build-cost note:** `_build_vectors` now does the ring-search for each blocked/unreachable cell — proportional
to (#such cells × search radius), **once per gated rebuild**, not per frame. Cheap in an open arena (thin bars
→ a reachable neighbor is 1 cell away). A large sealed pocket could spike it, but connectivity validation
should reject fully-partitioned layouts and rebuilds are infrequent — the re-measure will confirm.

**Acceptance:** parse clean; identical routing behavior (open rooms `flow_dir == raw`; enemies route around
bars; a stranded enemy still heads back onto the field); `flowfield_stress` holds **≥ 60 avg_fps @ 200
enemies + obstacles**, no regression vs the obstacle-free 142-fps baseline.

---

## Fallback (only if still < 60 after both slices)

The two fixes didn't target a specific measured cause, so if it's still slow, **then** add the diagnostic:
bucket-time one `flowfield_stress` run into (a) physics (`Performance.TIME_PHYSICS_PROCESS` delta), (b) total
`sample()` time across enemies, (c) `update_targets` (`_build_distances` + `_build_vectors`) — log which owns
the remaining ms, and fix that (likely candidates: rebuild cadence → throttle/hysteresis on the player
cell-change trigger; or obstacle collider contact count).

## Notes

- Canonical tree `D:\GameDev\Project_Twin_stick` on `v4/class-system`; **parallel Codex may edit — re-read
  before each edit.** See [[feedback-parallel-codex]].
- Order: **Slice 1 → 2**, measuring after each so the per-slice contribution is visible. Validate + commit per
  slice; **don't push unless asked.**
- Prereq for authoring obstacle layouts in [[v4-curated-rooms-plan]] Phase 3; the design lives in
  [[v4-arena-pathfinding-plan]].
