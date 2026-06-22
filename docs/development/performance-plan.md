# Performance Plan — high-density arenas

> Status: **analysis done, fixes not built.** Triggered by playtest lag with "a lot of ice zones or
> projectiles." On `v3/structure-rework`.

## Data (PerfRunner `entity_ramp`, RX 580)

| enemies + projectiles | avg FPS | physics_ms | draw_calls | nodes |
|---|---|---|---|---|
| 50 + 50 | 1217 | 2.8 | 56 | 515 |
| 100 + 100 | 547 | 5.5 | 117 | 1134 |
| 150 + 150 | 209 | 8.3 | 182 | 1952 |
| 200 + 200 | **56** | 11.9 | 266 | 3079 |

`physics_ms` and `draw_calls` scale **linearly** with entity count; FPS falls off a cliff past ~150.

## Finding 1 — Ice Zone: unbounded patches, one per kill *(HIGH impact, EASY fix)*

The reported "lots of ice zones" lag. Root cause:
- `CoopManager._on_enemy_died` calls `_ice_zone_modifier.spawn_patch(enemy.global_position)` for **every
  enemy death** ([CoopManager.gd:2059-2060](scripts/game/CoopManager.gd:2059)).
- `IceZoneModifier` has **no patch cap** — `_patches` grows unbounded (Fire Floor caps at `_max_zones = 7`).
- Each patch lives 5s and is redrawn **every frame**: `queue_redraw()` is called unconditionally in
  `_physics_process`, and `_draw` does a filled `draw_circle` + a **40-segment `draw_arc`** per patch.
- So in a dense room (many kills/sec) you get dozens of patches simultaneously → dozens of per-frame
  immediate-mode arcs + O(players × patches) distance checks.

**Fix:**
1. **Cap** active patches (~10–12); when full, skip-spawn or recycle the oldest.
2. **Throttle** spawning — don't spawn one per kill; use a cadence/chance (like the other modifiers).
3. **Cheaper draw** — drop arc segments (40→~20) and/or stop redrawing every frame (the fade is subtle —
   redraw on change or every few frames, or fade via `modulate` instead of re-emitting geometry).

## Finding 2 — Hazard modifiers redraw every frame *(MEDIUM, quick)*

Both `FireFloorModifier` (≤7 zones × 36-seg arc) and `IceZoneModifier` call `queue_redraw()` every
physics frame and re-emit `draw_circle` + `draw_arc` geometry. The arcs dominate.

**Fix:** reduce segment counts; redraw hazards at a lower cadence; or replace immediate-mode arcs with a
cheap `Sprite2D`/shader ring (drawn once, animated via shader/modulate). Lower priority than Finding 1.

## Finding 3 — Per-node entity/projectile ceiling *(architectural, BIG, deferred)*

The "lots of projectiles" lag is the long-known ~200-entity ceiling. Projectiles are already MultiMesh-
batched, but **enemies are still per-node** (one polygon `_draw` + one physics body each), so `physics_ms`
+ `draw_calls` grow linearly and FPS drops to ~56 at 200+200.

**Fix (a dedicated perf round, not now):** enemy MultiMesh rendering + further AI time-slicing/spatial
batching. Big change; parked since round 11.

## Recommended order

1. **Finding 1** (Ice Zone cap + throttle + cheaper draw) — biggest bang for the buck, directly fixes the
   reported lag, low risk.
2. **Finding 2** (hazard draw cost) — quick follow-on.
3. **Finding 3** (enemy MultiMesh) — schedule as a dedicated perf round when ready.

## Also addressed (this batch, separate from perf)

- **Encyclopedia — all enemies:** added the missing `splitter_mini` entry (the other 11 were present).
- **Encyclopedia in pause screen:** already implemented (`CoopManager._ensure_pause_encyclopedia_button`
  on pause → `_open_encyclopedia_overlay`). Confirm it shows in playtest; if not, that's a separate UI bug.
