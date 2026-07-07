# V4 — Arena Obstacles + Flow-Field Pathfinding (plan)

> The "room geometry" feature deferred from Round 2. Prereq for physical room layouts (obstacles / cover /
> chokepoints). Branch `v4/class-system`, checkout `D:\GameDev\Project_Twin_stick`. Standalone feature —
> independent of the Round 2 slices.
>
> **Decisions (LOCKED 2026-07-06; collision premise CORRECTED after review):**
> - **Pathfinding = flow field** (not NavigationAgent — too slow at 200 agents; not steering — gets stuck on
>   concave obstacles). Scales O(1) per enemy, handles chokepoints/corridors.
> - **⚠ Correction — there is NO "ghost mode."** Alive enemies are already `CharacterBody2D` with
>   `collision_layer = 1`, `collision_mask = 1` (`Enemy.tscn`); they **already collide** with the arena walls,
>   the player, and each other via `move_and_slide()`. `Enemy.gd` only zeroes collision **on death** (~L1183).
>   So there is **no soft-vs-hard perf tradeoff — physics is already on.**
> - **Model = keep existing physics + flow field for ROUTING.** Obstacles go on **layer 1**; enemies, player
>   (mask 1), and projectiles (mask 1) collide with them **with no mask changes and no added cost.** The flow
>   field only **steers enemies around obstacles** (so they don't press into a wall forever); **physics gives the
>   hard stop** (no clipping). No perf regression (physics unchanged, field cheap, obstacles = a few statics).
> - **Flow field drives BASE LOCOMOTION only, never aim/charge.** Split `raw_target_dir` (straight-to-player, for
>   aiming/attacks/distance checks/charge/kite) from `flow_dir` (the field sample, for where the enemy *walks*).
> - **Charge attacks (charger / boss dashes) go STRAIGHT** (raw dir) and are **stopped by physics** at obstacles
>   — not flow-routed.
> - **All enemies** use the field for base locomotion; **minimal first** (tech + a room-config test layout,
>   proven at 200 enemies).

---

## Why flow field (the constraint)

100–200 enemies all chase the player. Recomputing per-agent A* (NavigationAgent2D) for 200 agents every frame
drops frames. A flow field computes **one grid of "which way to the player, around walls" arrows per player**,
once; every enemy just **samples the arrow under it = O(1)**. Cost is independent of enemy count. This is the
standard swarm-vs-target solution.

## Pieces

### 1. `scripts/game/FlowField.gd` (new; owned per-room, e.g. by `CoopManager`)
- **Grid** over `ARENA_RECT` at **`CELL_SIZE := 100.0`** (3600×2100 → ~36×21 ≈ **756 cells**).
- **`build(obstacle_rects: Array[Rect2])`** — mark cells **blocked** where they overlap an obstacle rect
  **inflated by (enemy contact radius + a clearance margin)**, so routing keeps a gap and enemies aim for
  passable cell centers (physics stops any residual clipping). Empty obstacle list ⇒ no blocked cells.
- **`update_targets(player_positions: Array[Vector2])`** — per player: BFS/Dijkstra **integration field**
  (distance-to-player over passable cells), then a **flow field** (each cell → unit vector toward its
  lowest-distance passable 8-neighbor). One field per player.
  - **Recompute cadence:** rebuild a player's field **only when that player enters a new cell** (track last
    cell/player). BFS over ~756 cells is microseconds; gating avoids per-frame cost.
- **`sample(world_pos, target_player_index, fallback_dir: Vector2) -> Vector2`** — bilinear-interpolate the 4
  nearest cell arrows (skip blocked neighbors). **Returns `fallback_dir`** when there's no field / outside grid /
  invalid target. *(The function can't derive raw dir itself — the caller passes `raw_target_dir`.)*
- **`has_obstacles() -> bool`** — rooms with none skip flow entirely (enemies just use `raw_target_dir` — zero
  cost, identical to today).

### 2. Enemy integration (`scripts/enemies/Enemy.gd`) — split direction, keep collision
**⚠ Do NOT globally overwrite the existing `direction`** — it's reused for aim, lead, kiting, and charge. Split it:
- Compute **`raw_target_dir`** = `(_target.global_position - global_position).normalized()` (today's value), and
  **`flow_dir`** = `FlowField.sample(global_position, _target_player_index, raw_target_dir)` when
  `FlowField.has_obstacles()`, else `flow_dir = raw_target_dir`.
- **Split by MOVEMENT vs AIM, not by enemy type.** Several behaviors (`_update_spitter_behavior`, the boss
  behaviors, `_update_charger_behavior`) derive *both* movement and aim from the single `direction` today — so
  pass **both** `raw_target_dir` and `flow_dir` in:
  - **Locomotion *toward* the player → `flow_dir`:** chaser approach, spitter *approach* (when too far), boss
    *approach* movement — all of it routes around obstacles.
  - **Aim / lead / distance checks / committed charge / retreat-away → `raw_target_dir`:** projectile fire dir +
    `_get_lead_direction`, the `distance` range checks, the charger/boss **charge** commit (straight,
    physics-stopped), and spitter **kite-retreat** (`-raw_target_dir`; obstacle-aware retreat is a follow-up —
    physics stops one that backs into a wall).
  - e.g. `_update_spitter_behavior(raw_dir, flow_dir, distance, now)` → approach `flow_dir * speed`, retreat
    `-raw_dir * speed`, fire `raw_dir`. Base chaser velocity = `flow_dir * speed`.
- **Keep `_apply_separation()`:** `velocity = flow_dir * _get_effective_move_speed() + _apply_separation()` →
  `move_and_slide()`.
- **Enemies keep existing collision** (`layer/mask = 1`) — physics stops them at obstacles/walls. **No collision
  changes, no ghost mode.** (Physics handles clipping, so no wall-nudge needed.)
- **Target player index:** resolve when the target is set. In `_refresh_target_if_due`, store
  **`_target_player_index`** from the target Player node (Players expose `player_index`; add
  `CoopManager.get_player_index_for_node(node) -> int` if cleaner than reading the property). Enemies whose target
  isn't a player (edge) fall back to `raw_target_dir`.
- **Open-room parity:** no obstacles ⇒ `flow_dir == raw_target_dir` ⇒ behavior identical to today.

### 3. Obstacles — room-config field (decision 2026-07-06: room-config now)
- **Obstacle = `StaticBody2D` rectangular block on layer 1.** Everything already masks layer 1, so **enemies +
  player (mask 1) + projectiles (layer 2/mask 1) collide with it with NO mask changes** (shots stop at it, player
  and enemies can't pass through).
- **Source = room config:** add an **`obstacles`** field to the room config — a list of arena-coordinate rects
  (`{ x, y, w, h }`). `CoopManager` (room setup) spawns one `StaticBody2D` block per rect (layer 1), adds each to
  an **`arena_obstacle`** group, and passes the rects to `FlowField.build`. **Reusable:** the Round-2 archetypes
  can later populate `obstacles` per archetype (that's the follow-up).
- **⚠ Lifecycle — spawn under a cleared container:** `_clear_runtime_nodes` currently frees children of only
  `[projectiles, enemies, pickups, effects]` (`CoopManager.gd`). Spawn obstacle blocks under a **dedicated
  `arena_obstacles` container node** and **add it to that cleanup list** (or spawn under `effects`) so obstacles
  are rebuilt per room and **don't leak between rooms**. Rebuild `FlowField` when the room's obstacles change.
- **⚠ Spawn safety — validate rects against placement zones:** before spawning, **reject or relocate** any
  obstacle rect (inflated) that overlaps **player spawn points**, the **enemy edge-spawn lanes/margins**
  (`ArenaGeometry.enemy_spawn_position_for_edge`), or **side-objective / pickup placement zones** — otherwise an
  actor can be trapped inside a wall on spawn. Alternatively, relocate the affected spawn to the nearest passable
  cell. Author test layouts to keep clear of the arena edges + center spawn.
- **Test/profiling layout:** a debug room config with a handful of blocks including **at least one concave case**
  (an L / a short corridor / a gap) — proves the field routes around it (the thing steering couldn't).

### 4. Perf validation
- **Physics is already on** for 200 enemies (current baseline), so this adds only a few static colliders + the
  flow field (per-enemy O(1) sample + gated BFS over ~756 cells). Add the test obstacles to `ProfilingHarness`
  (or a `flowfield_stress` scenario) and confirm **200 enemies hold ≥60 `avg_fps` — no regression vs current.**
  If it regresses, the field build/sample or obstacle-collider count is the suspect.

## Acceptance
- A test room with a few obstacles (incl. a concave one): **200 enemies route around them** (visibly curve, funnel
  through gaps), **none stuck pressing into a wall**; enemies **physically stop** at obstacles (no clipping).
- **Aim/charge unaffected:** spitters still shoot *at the player* (not along corridor-flow); chargers still charge
  *straight at the player* (stopped by walls). Only walking paths bend.
- **Player + projectiles collide** with obstacles (both already mask layer 1).
- **Rooms with no obstacles behave identically to today** (`flow_dir == raw_target_dir`; zero regression).
- **200 enemies + obstacles hold ≥60 `avg_fps`** (no regression vs the current physics baseline).

## Out of scope (follow-ups)
- Per-archetype / curated room layouts (populate `obstacles` per archetype once the tech is proven).
- Obstacle-aware charging (charges are straight + physics-stopped for now).
- Ranged-enemy line-of-sight / cover mechanics.

## Notes
- Codex may be editing this tree in parallel (Round 2 is implementing) — **re-read before edits.** See
  [[feedback-parallel-codex]].
- Validate + commit per piece; don't push unless asked.
