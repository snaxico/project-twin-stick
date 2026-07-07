# V4 — Arena Obstacles + Flow-Field Pathfinding (plan)

> The "room geometry" feature deferred from Round 2. Prereq for physical room layouts (obstacles / cover /
> chokepoints). Branch `v4/class-system`, checkout `D:\GameDev\Project_Twin_stick`. Standalone feature —
> independent of the Round 2 slices.
>
> **Decisions (LOCKED with the user 2026-07-06):**
> - **Pathfinding = flow field** (not Godot NavigationAgent — too slow at 200 agents; not steering — gets stuck
>   on concave obstacles). Scales O(1) per enemy, handles chokepoints/corridors.
> - **Soft collision** — enemies stay in **ghost mode** (`collision_mask = 0`, physics skips them → preserves
>   the 200-enemy budget); the flow field routes them around walls; a cheap nudge if one slips into a wall cell.
>   **No hard enemy↔obstacle physics** (that would re-add physics for 200 bodies — the exact cost we disabled).
> - **All enemies** use the field for their base "toward player" direction.
> - **Minimal first** — build the tech + a few test obstacles, prove it at 200 enemies; per-archetype layouts
>   are a later follow-up.

---

## Why flow field (the constraint)

100–200 enemies all chase the player. Recomputing per-agent A* (NavigationAgent2D) for 200 agents every frame
drops frames. A flow field computes **one grid of "which way to the player, around walls" arrows per player**,
once; every enemy just **samples the arrow under it = O(1)**. Cost is independent of enemy count. This is the
standard swarm-vs-target solution.

## Pieces

### 1. `scripts/game/FlowField.gd` (new; owned per-room, e.g. by `CoopManager`)
- **Grid** over `ARENA_RECT` at **`CELL_SIZE := 100.0`** (3600×2100 → ~36×21 ≈ **756 cells**).
- **`build(obstacle_rects: Array[Rect2])`** — mark cells overlapping an obstacle as **blocked**.
- **`update_targets(player_positions: Array[Vector2])`** — per player: BFS/Dijkstra **integration field**
  (distance-to-player over passable cells), then a **flow field** (each cell → unit vector toward its
  lowest-distance passable 8-neighbor). One field per player.
  - **Recompute cadence:** rebuild a player's field **only when that player enters a new cell** (track last
    cell/player). BFS over ~756 cells is microseconds; gating avoids per-frame cost.
- **`sample(world_pos, target_index) -> Vector2`** — bilinear-interpolate the 4 nearest cell arrows for smooth
  motion (skip blocked neighbors in the blend). **Fallback:** outside grid / no field → straight-to-player
  vector (so open rooms behave exactly like today).
- **`is_blocked(world_pos) -> bool`** + **`nearest_passable_dir(world_pos) -> Vector2`** — for the soft nudge.

### 2. Enemy integration (`scripts/enemies/Enemy.gd`)
- In `_physics_process`, replace the straight-line `direction` (toward `_target`) with
  **`FlowField.sample(global_position, target_index)`**. Open-room result ≈ straight line → **behavior
  unchanged where there are no obstacles.**
- Keep separation on top: `desired_velocity = flow_dir * _get_effective_move_speed() + _apply_separation()`.
- **Soft wall-correction:** if `FlowField.is_blocked(global_position)`, add a small push along
  `nearest_passable_dir()` so ghost-mode enemies don't sit inside a wall. (Cheap grid lookup.)
- **Enemies stay `collision_mask = 0`** (ghost mode — no physics collision; 200-enemy budget preserved).
- **Special behaviors keep working:** charger dash, spitter kite, boss patterns layer *on top* of the field's
  "toward player" base direction (they use the field for approach; their attack/kite logic is unchanged).
- **Multi-player:** each enemy samples the field of **its target player** (nearest, per existing
  `_find_target`). 1–2 players → 1–2 fields, each gated on cell-change. Still cheap.

### 3. Obstacles (minimal first)
- An obstacle = a **`StaticBody2D` rectangular block** on the obstacle collision layer. **Player (mask 1) +
  projectiles already collide with `StaticBody2D`** — obstacles slot into that with no extra work (shots stop
  at walls, player can't walk through).
- **Test layout:** a handful of blocks in a debug/test room — include at least **one concave case** (an L / a
  short corridor / a gap between two blocks) to prove the field routes around it (the thing steering couldn't).
- Feed the obstacle `Rect2`s to `FlowField.build`.
- **Not now:** per-archetype curated layouts (later — ties into the Round 2 room archetypes once the tech holds).

### 4. Perf validation (the whole point of "soft")
- Add obstacles + the flow field to `ProfilingHarness` (or a `flowfield_stress` scenario) and confirm **200
  enemies hold ≥60 `avg_fps`** — i.e. near-current, since soft adds only grid math (per-enemy O(1) sample +
  gated BFS). If it regresses, the field build/sample is the suspect, not physics.

## Acceptance
- A test room with a few obstacles (incl. a concave one): **200 enemies route around them** — visibly curve
  around walls, funnel through gaps, **none stuck pressing into a wall**, none sitting inside a wall.
- **Player + projectiles collide** with obstacles.
- **Rooms with no obstacles behave identically to today** (flow-field fallback = straight-to-player; zero
  regression).
- **200 enemies + obstacles hold ≥60 `avg_fps`** (ProfilingHarness).

## Out of scope (follow-ups)
- Per-archetype / curated room layouts (author real rooms once the tech is proven).
- Hard enemy↔obstacle collision (only if soft's corner-clipping looks bad in playtest).
- Ranged-enemy line-of-sight / cover mechanics (shooting only when they can see you).

## Notes
- Codex may be editing this tree in parallel (Round 2 is implementing) — **re-read before edits.** See
  [[feedback-parallel-codex]].
- Validate + commit per piece; don't push unless asked.
