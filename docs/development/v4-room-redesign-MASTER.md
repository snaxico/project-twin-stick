# V4 — Room & Enemy Redesign — MASTER PLAN

> **THE single canonical document for this work.** Self-contained: design + build sequence + implementation
> specs. Consolidates the working docs (`v4-enemy-tiers-plan`, `v4-flowfield-perf-plan`, `v4-curated-rooms-plan`,
> `v4-room-pool`, `v4-arena-pathfinding-plan`) — if any conflicts with this file, **this file wins.**
>
> Branch `v4/class-system`, active checkout `D:\GameDev\Project_Twin_stick`. **One coordinated patch, built in
> phase order; validate + commit per phase; don't push unless asked.** Parallel Codex may edit the tree —
> **re-read before each edit.**
>
> **Rev 4 (2026-07-07) — resolves review round 2 (findings 1–11); round 1 already resolved.** `elite_spitter`
> removed from all normal-room paths (it's a champion) + its rework dropped; **shooter selection algorithm**
> defined (`shooter_ratio` + roll); **Open is always a weighted WHERE candidate**; **Bastion redesigned
> off-center** (2 spawn-safe flanking pillars); **concrete spawn-safe coordinates for every mechanic**; atomic
> **`rebuild_obstacles`** API with a **clip guard** (no pop-under) + connectivity-revert (no trap); **discrete
> telegraph-then-snap** motion for all moving cover; `_spawn_arena_obstacle` returns the body; initial-target
> rebuild after Batch-B activation (F9); `where`/`modifiers` node keys + card wiring; per-`--where` smoke tests.
> Verified against `ArenaGeometry` spawn positions + `CoopManager` exclusion constants + obstacle API. Round 1
> (F1–10) fixes retained: WHERE whitelist, no-repeat relax, budget reservation, team-neutral hazard, dynamic
> pulse, twist removal, bounded Phase-4 failure. **All six phases implementation-ready.**
>
> **Validation gate (per phase):**
> ```powershell
> $GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' --quit                    # parse
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=entity_ramp   # perf (avg_fps>=60)
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=flowfield_stress  # Phase 4 only
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --where=fire_grid --smoke   # per-mechanic
> ```
> **⚠ Per-WHERE validation (F11).** `entity_ramp` only checks generic perf. Add a debug entry point
> **`--where=<id>`** (in `ProfilingHarness`/debug bootstrap) that forces a combat room with that WHERE id + a
> fixed composition, and **`--smoke`** that (a) spawns a **stationary dummy enemy at a known hazard location**
> and **asserts its HP drops** (team-neutral damage, F5), (b) for Batch-B, asserts `validate_connectivity` holds
> after a forced moving-cover transition and no actor is trapped. One `--where` run per implemented mechanic id
> is part of that phase's acceptance.

---

## 0. The model at a glance

**A room = WHO + WHERE + TWIST.**
- **WHO** — 1 of the curated archetypes (the enemy identity).
- **WHERE** — **exactly 1 arena mechanic** (the stage). Most rooms get one; **Open** is the low-weight
  breather. Never two. **Only mechanics whose phase has shipped are eligible** (F1).
- **TWIST** — **0–1 stat modifier** (light spice).

**Enemy tiers** (the roster WHO draws from):
- **Trash-melee** (the swarm, density-scaled): chaser · charger · bomber · splitter/mini
- **Ranged specials** (capped, telegraphed): **`spitter` only.** ⚠ `elite_spitter` is an `elite_*` **champion**
  and must **not** spawn through normal composition (F1) — it is removed from the shooter budget, all compositions,
  and `ranged_gauntlet`; it appears only via champion/boss paths. A non-champion elite ranged variant waits for
  the deferred Elites work.
- **Champions** (`boss_*`, `elite_*`): bosses — **separate boss rooms only.** ⚠ **All `elite_*` IDs are
  champions** (`EnemyTypes.is_champion` matches the `elite_` prefix) and carry the champion contract (no
  XP/health-drop, champion VFX + ultimate-charge credit, knockback immunity, separation disabled). They
  **must not** be spawned through normal composition. The **Elites archetype is therefore deferred** — it needs
  new *non-champion* elite enemy IDs (a dedicated future slice); until then it is **not in the WHO pool** (F4).

**Design principle (locked):** rooms are **dynamic, readable, fun-not-punishing** — hazards you weave around
and exploit (they hurt the swarm too) + cover that moves on a rhythm. Rejected: static lone obstacles;
encroaching/squeezing hazards; floor-effect gimmicks; trigger-traps/turrets; objective rooms.

---

## 1. Build sequence (one patch, phased)

| Phase | What | Ships on | Risk |
|---|---|---|---|
| **1** | Enemy tiers (telegraphed spitter + shooter cap) **+** card streamline | existing tech | none — **fixes the bullet-hell** |
| **2** | Room foundation: WHO + selection + TWIST (existing modifiers; WHERE = Open) | existing modifiers | low |
| **3** | First WHERE: **pulsing hazard grid** (Fire/Frost/Mine) | new hazard driver | low–med |
| **4** | **Flow-field perf fix** → unblocks cover | — | ⚠ uncertain (9× undiagnosed) |
| **5** | Rest of Batch-A WHERE: Islands · Pinwheel · Tesla Arcs · Drifting Clouds | hazard system | med |
| **6** | Batch-B WHERE (cover): Bastion · Pop-up Pillars · Sliding Gates · Bulwark · Drifting Cover · Shifting Maze | needs Phase 4 | gated |

**Ship seam:** Phases **1–3 + 5** = shippable core. Phases **4 + 6** = gated tail (build only if the flow-field
fix holds ≥60fps; else the core ships whole and cover waits).

**All six phases are specified to implementation level** (Rev 3). Phases 3/5/6 mechanics get concrete values
(damage+team, tick, geometry, telegraph, motion, flow-field rebuild) in §§5b–8 — built on the verified
`ArenaMechanic` pattern. Phase 4's *outcome* is empirical (a perf number), not a spec gap; its failure branch
is bounded (§7).

---

## 2. PHASE 1a — Enemy tiers → ranged "specials" (`scripts/enemies/Enemy.gd`, `scripts/game/WaveDirector.gd`)

Fixes the `ranged_gauntlet` bullet-hell. Trash-melee swarm (density scaled) + ranged as **capped, telegraphed,
priority** threats.

**Locked values:** spitter → telegraphed **3-shot fan**, ~0.45s wind-up (aim locked at wind-up START),
**scale-pulse** tell, HP **14→30**, fire_interval **1.8→2.0**. Shooter budget base **6**, **+2 for 2P**; cost
**spitter=1** (the only budgeted shooter — F1); overflow → **melee from the room's own pool** (fallback chaser).
No new ranged types. *(No `elite_spitter` changes — it's a champion, out of normal rooms.)*

### Slice 1 — telegraphed fans (`Enemy.gd`)
The fan already exists: `_emit_projectiles_at(dir, count, spread_radians, scale)` → `_build_spread_directions`
(spread = **per-shot step**). Add a **wind-up phase**:
- New fields near the windup timers (~L214): `_spitter_windup_until`, `_spitter_aim_dir`,
  `_spitter_windup_active`, `_spitter_windup_len` (reset in the type-reset block ~L269 + `_configure_type`).
- In `_update_spitter_behavior` (~L834), the wind-up applies **only to `enemy_type == EnemyType.SPITTER`**;
  leave the `ELITE_SPITTER` branch (L842-843 + its ability at L844-847) **unchanged** — it's a champion now.
  For SPITTER, replace the inline fire:
  - **enter wind-up** when `now >= _next_fire_at and distance > 120 and not _spitter_windup_active`:
    set active; `_spitter_windup_len = 0.45`; `_spitter_windup_until = now + 0.45`; `_spitter_aim_dir = raw_dir`;
    `_next_fire_at = now + _get_effective_fire_interval()`.
  - **fire** when active and `now >= _spitter_windup_until`:
    `_emit_projectiles_at(_spitter_aim_dir, 3, 0.22, 0.7)`; clear active.
  - **slow while winding up:** if active, scale returned `desired_velocity` by ~0.35.
- **Scale-pulse tell — ⚠ in the DYNAMIC path (F8):** `visual.scale` is rewritten every physics frame in
  `_update_dynamic_visuals` (~L1296: `visual.scale = Vector2(_visual_anim_base.x * spawn_scale * breathe *
  squash_x, …)`). `_update_visual_state` only sets the static base and would be overwritten. Add a wind-up
  factor there: compute `windup_k = 1.0 + 0.30 * clamp((now-(windup_until-windup_len))/windup_len,0,1)` when
  `_spitter_windup_active` (else 1.0) and **multiply it into both scale components** in that L1296 expression.
- **Stats** (`_configure_type`): `spitter` max_health `14→30`, fire_interval `1.8→2.0`. (`elite_spitter`
  unchanged — champion.)
- **Acceptance:** one spitter dodgeable by reading the swell + sidestep; overlapping spitters readable;
  movement split unchanged; parse clean.

### Slice 2 — global concurrent-shooter budget (`WaveDirector.gd`) — reserve at SELECTION (F3)
Burst/stream loops **select and queue** all enemies via `queue_enemy_spawn` → `call_deferred`, so counting only
in `spawn_enemy_instance` lets a whole burst of shooters through before any increment. **Reserve at selection:**
- `const SHOOTER_COST := {"spitter":1}`; `_shooter_cost(t)->int` (0 = not a shooter). *(elite_spitter is a
  champion, never budgeted.)*
- `const SHOOTER_BUDGET_BASE := 6`; `_shooter_budget() -> 6 + 2*max(player_count-1,0)`.
- `var _active_shooter_budget := 0` = reserved (pending) **+** live cost combined. Reset in `start_room` (~L37).
- `_pick_spawn_type(pool)` wraps `_roll_wave_enemy_type`: if rolled type is a shooter and
  `_active_shooter_budget + cost > _shooter_budget()` → return `_roll_melee_type(pool)` (random non-shooter;
  fallback `"chaser"`). **Otherwise, if it stays a shooter, `_active_shooter_budget += cost` right here**
  (the reservation). Route all spawn paths (opening burst L79-82, continuous L152-155, burst L164-167) through it.
- **Release:** decrement `_active_shooter_budget` by the enemy's cost (a) on death — add
  `notify_enemy_removed(type)` called from `CoopManager._on_enemy_died`; **and** (b) if the deferred spawn is
  **cancelled** — in `_spawn_queued_enemy_instance`'s early-return (room clear / not in tree), release the
  reservation for that queued type. To release correctly, **queue the resolved type + its cost** (store cost in
  the deferred call args) so cancel/death both know what to subtract. Clamp ≥0.
- **Acceptance:** even a full opening burst never exceeds the budget on screen; surplus arrives as melee; total
  enemy count unchanged; `_active_shooter_budget` returns to 0 across rooms and after cancelled spawns (no leak).

### Slice 3 — `ranged_gauntlet` data (`data/room_archetypes.json`), interim until Phase 2
`enemy_bias`: `["spitter","spitter","elite_spitter"]` → `["spitter","spitter","charger","chaser"]` (**remove
`elite_spitter`** — F1; add melee for overflow); `density_profile` → `"low"`.

---

## 3. PHASE 1b — Card streamline (`scripts/ui/RunFlow.gd _build_route_card`, L73-166)

Cut the cluttered card (~9 elements) to four, keep the panel/glow style. Works on current data now.
- **Row 1 (keep):** `trait_icon + trait_label` (L99-105) · `danger_pips` (L106-112) right.
- **Row 2 (collapse):** the `chip_flow` (L114-124) currently reads only `node.modifiers`. Change it to build
  chips from **`[node.where] + node.modifiers`**, skip `"open"`, map ids to display names (a small
  `WHERE_DISPLAY`/`_format_modifier_name` lookup), and **cap at 2** (WHERE first). None → render nothing.
  *(Pre-Phase-2, `where` is absent → falls back to `modifiers` as today.)*
- **Row 3 (keep):** `rare_label` (L155-162).
- **CUT `detail_label` (L126-148):** Room N, `Enemies:` dump, `Objective: Clear`, short_desc, reward_hint. Keep
  only a small icon for a **real** side_objective.
- **Champion card:** name = `Champion: <boss>`; one `Champion` chip; keep danger + reward.
- **Acceptance:** name+icon · danger · ≤2 tags · reward only; no dump/prose; parse clean.

---

## 4. PHASE 2 — Room foundation (`scripts/game/RunState.gd`, `RunFlow.gd`, `data/room_archetypes.json`)

WHO + selection + TWIST loop on **existing** modifiers (WHERE = Open until Phase 3; Elites deferred per §0).

**WHO — 5 archetypes** (populate `composition`):

| Archetype | melee_density | melee_bias | shooters | shooter_ratio | Depth |
|---|---|---|---|---|---|
| Horde | high | chaser, chaser, splitter | — | 0.0 | 1+ |
| Mixed | medium | chaser, charger, splitter, bomber | spitter | 0.20 | 1+ |
| Splitters | high | splitter, splitter_mini, chaser | — | 0.0 | 3+ |
| Pressure | medium | charger, charger, bomber | — | 0.0 | 3+ |
| Gauntlet | low | chaser | spitter | 0.50 | 4+ |

*(elite_spitter removed — F1. Gates eased so ≥3 archetypes are eligible by depth 3. Elites archetype returns
post-Phase-6 with non-champion elite IDs.)*

**Roll semantics:**
- **Shooter selection algorithm (F2)** in `WaveDirector._roll_wave_enemy_type(comp)`:
  `if not comp.shooters.is_empty() and randf() < comp.shooter_ratio: return comp.shooters[randi()%comp.shooters.size()]`
  `else: return comp.melee_bias[randi()%comp.melee_bias.size()]` — duplicate entries in either list act as
  weights. Then `_pick_spawn_type` (Slice 2) applies the budget check: if the rolled type is a budgeted shooter
  and over budget → re-roll to `_roll_melee_type` (uniform over the non-shooter entries of `melee_bias`;
  fallback `chaser`); else reserve its cost. So `shooter_ratio` is the per-spawn shooter probability, `shooters`
  is the weighted roster, and the budget is the hard ceiling.
- **WHERE roll (F3)** = weighted pick of **exactly 1** from
  `candidates = ["open"] + [w for w in archetype.where_pool if IMPLEMENTED_WHERE.has(w)]`, weights **Open = 1,
  each mechanic = 3** (Open is always a weighted candidate, a genuine minority breather; before any mechanic
  ships, `candidates == ["open"]`).
- **TWIST roll** = **55% one** (uniform over `twist_pool`) / **45% none**.

**Schema** — extend `data/room_archetypes.json`: each archetype has `composition` (incl. `shooter_ratio`), a
**`where_pool`**, and a **`twist_pool`**. Add a global **`const IMPLEMENTED_WHERE: Array`** (grows per phase:
`[]` → P3 adds `fire_grid,frost_grid,mine_grid` → P5 adds `islands,pinwheel,tesla_arcs,drifting_clouds` → P6
adds cover ids).

**Node keys (F10):** `_build_run_node` writes **`where: String`** (the rolled mechanic id, `"open"` default)
and **`modifiers: Array`** (the rolled twist ids). No separate `tags` key — the card builds its ≤2 chips from
`[where] + modifiers` (§3). `where` drives `CoopManager` WHERE activation (§5b); `modifiers` drives the existing
twist/modifier path.

**Selection** (`RunState._build_choice_step` L599 / `_draw_archetypes_for_depth` L880): draw **2** archetypes by
depth gate; **the two must differ from each other** (always satisfiable). **No-repeat-vs-previous applies only
when ≥3 archetypes are eligible** at that depth; with exactly 2 eligible it is dropped. Champion steps unchanged.

**Build node** (`_build_run_node` L614): roll 1 available WHERE + 0–1 TWIST; write `where` + `modifiers`.
**Danger derived** (`_refresh_route_metadata`): base by density (low/med/high→1/2/3) `+1` if shooters `+` twist
count, clamped to pip max. **WaveDirector** consumes `composition`. **Retire** old `_roll_archetype_modifiers` /
`_build_distinct_modifier_load`.

**Acceptance:** 2 distinct archetype choices/step, no impossible-repeat stalls; each plays its identity; WHERE
never rolls an unbuilt mechanic; danger tracks composition; card shows name · danger · ≤2 tags · reward.

---

## 5. WHERE mechanics (the stage deck) — reference

**1 per room**, gated by `IMPLEMENTED_WHERE`.
**Batch A (Phases 3 + 5):** Fire Grid · Frost Grid · Mine Grid · Islands · Pinwheel · Tesla Arcs ·
Drifting Clouds · **Open**. **Batch B (Phase 6, needs Phase 4):** Central Bastion · Drifting Cover ·
Pop-up Pillars · Sliding Gates · Shifting Maze · Bulwark.

**Themed `where_pool` per archetype** (Shrinking removed per F7):

| Archetype | where_pool |
|---|---|
| Horde | Fire Grid, Islands, Pinwheel, Tesla Arcs, Drifting Clouds, Sliding Gates, Open |
| Mixed | Fire Grid, Frost Grid, Islands, Pinwheel, Tesla Arcs, Drifting Clouds, Open |
| Splitters | Fire Grid, Mine Grid, Tesla Arcs, Shifting Maze, Open |
| Pressure | Mine Grid, Bulwark, Sliding Gates, Pop-up Pillars, Open |
| Gauntlet | Central Bastion, Drifting Cover, Pop-up Pillars, Frost Grid, Islands, Tesla Arcs, Fire Grid |

**TWIST `twist_pool`** (roll 0–1): Enemy Speed · Shielded · Explosive Death · Accelerating Waves.
*(Shrinking Arena removed — it squeezes the arena, which the model rejects, and would double as a 2nd arena
mechanic (F7).)* Light theming (Splitters↔Explosive Death).

**⚠ Team-neutral hazard contract (F5).** Existing hazards damage **players only** (`FireFloorModifier` /
`IceZoneModifier` / `MineFieldModifier` iterate `_player_nodes`), and `MineFieldModifier` is a moving
**scanline**, not armed mines. Any WHERE that claims to "hurt the swarm" must implement a **team-neutral damage
contract**: the hazard damages *both* players and enemies inside its active area (query enemies + players; call
`apply_damage`). "Mine Grid" needs **new armed-mine-on-grid** behavior, not the scanline. This is part of each
mechanic's bounded slice, not a free reuse.

**Mechanic design intent** (full implementation specs in §§6, 8, 8b): Fire/Frost/Mine Grid = coarse grid,
cells alternate safe↔hazard on a pulse w/ telegraph, active cells damage both teams · Islands = hazard-sea +
reshuffling safe pads · Pinwheel = rotating hazard arms · Tesla Arcs = timed arcs between nodes · Drifting
Clouds = drifting damage blobs · Bastion = static `StaticBody2D` (layer 1) blocks shots + splits swarm ·
Pop-up Pillars / Sliding Gates / Bulwark / Drifting Cover / Shifting Maze = moving cover (see §8).

*Cover verified:* projectiles `layer2/mask1`, obstacles `StaticBody2D layer1`, `Projectile._on_body_entered`
(L272-277) despawns on any StaticBody2D team-agnostically ⇒ **cover blocks shots with no LOS AI.**

---

## 5b. Shared infrastructure (build once, in Phase 3)

**`scripts/arena/ArenaMechanic.gd`** — base for every WHERE mechanic (mirrors the `FireFloorModifier` pattern:
`Node2D`, `setup`, `_physics_process`, `_draw`, parented to `effects`):
```
class_name ArenaMechanic extends Node2D
var _arena: Rect2
var _players: Array
var _coop: Node                    # CoopManager
func setup(arena: Rect2, players: Array, coop: Node) -> void:
    _arena = arena; _players = players; _coop = coop
    set_physics_process(true); queue_redraw()
# Team-neutral damage (F5): both players and enemies within radius.
func damage_circle(center: Vector2, radius: float, dmg: int, hit_players := true) -> void:
    var r2 := radius * radius
    if hit_players:
        for p in _players:
            if p != null and is_instance_valid(p) and p.has_method("is_alive") and p.is_alive() \
               and p.global_position.distance_squared_to(center) <= r2:
                p.apply_damage(dmg)
    for e in _coop.get_nearby_enemy_target_nodes(center, radius):   # broad-phase; distance-checked below
        if e != null and is_instance_valid(e) and e.has_method("is_alive") and e.is_alive() \
           and e.has_method("apply_damage") and e.global_position.distance_squared_to(center) <= r2:
            e.apply_damage(dmg)
```

**WHERE activation** — in `CoopManager._apply_active_modifiers` (~L818), after the existing modifier branches,
add a `match str(_room_config.get("where","open"))` that instantiates the matching mechanic, calls
`setup(ARENA_RECT, _player_nodes, self)` (+ `set_variant(...)` for the grid), `effects.add_child(...)`, and
stores a `_where_mechanic` ref (null it in the room-reset block L585-588 so it clears per room, like the other
modifier refs). `where` comes from the Phase-2 roll; `"open"`/default = no mechanic. Batch-B cases additionally
spawn obstacles + build the flow field (§8b).

**⚠ Ordering fix (F9):** room-start (`start_room` ~L544) runs `_update_flow_field_targets()` (L565) →
`_apply_active_modifiers()` (L566) → `spawn_opening_burst()` (L567). Batch-B cover created at L566 mutates the
obstacles *after* the targets were built and *before* enemies spawn. **Insert `_update_flow_field_targets()`
between L566 and L567** so the opening wave routes around the new cover. (Batch-A hazards don't touch obstacles,
so they're unaffected.)

## 6. PHASE 3 — Pulsing Hazard Grid (`scripts/arena/PulsingGridMechanic.gd extends ArenaMechanic`)

One mechanic, three variants (`fire_grid`/`frost_grid`/`mine_grid`) via `set_variant(id)`.
- **Grid:** `COLS:=6, ROWS:=4` over `_arena` → cell `(600, 525)`. Cell(c,r) rect =
  `Rect2(_arena.position + Vector2(c*cw, r*ch), Vector2(cw, ch))`.
- **Pulse:** `PHASE_PERIOD:=3.0`, `TELEGRAPH:=0.5`. `_t += delta`; `phase := int(_t/PHASE_PERIOD)%2`;
  `phase_t := fmod(_t, PHASE_PERIOD)`. Cell(c,r) is **armed** if `(c+r)%2 == phase`; **telegraphing** while
  `phase_t < TELEGRAPH` (glow, no damage); **live** while `phase_t >= TELEGRAPH` (damage). Parity alternates
  each phase ⇒ the complementary half is **always safe** — safe-space guaranteed by construction; the player
  always has an adjacent safe cell.
- **Damage** (`DAMAGE_INTERVAL:=0.5`, accumulate `_dmg_at -= delta`): for each **live** cell, damage actors
  whose position is inside that cell rect —
  - `fire_grid` — `apply_damage(5)`; enemies via `_coop.get_nearby_enemy_target_nodes(cell_center, 400)`
    filtered to point-in-cell; players via point-in-cell over `_players`.
  - `frost_grid` — `apply_damage(3)`; **and** each frame, players inside a live cell get
    `apply_zone_modifier("frost_grid", 0.5, 1.0)` (slow), else `clear_zone_modifier("frost_grid")` (mirrors
    `IceZoneModifier`; clear all on `_exit_tree`). *(Enemy slow out of scope — the team-neutral requirement is
    met by the damage.)*
  - `mine_grid` — no per-tick damage. Each live cell has an armed mine at its center; each frame, if any player
    or nearby enemy is within `MINE_TRIGGER:=110` of it → `damage_circle(mine_center, MINE_BLAST:=150,
    MINE_DMG:=22)` and mark that cell **spent** until it re-arms next armed phase.
- **Draw:** telegraphing cells = variant-colored warning fill (low alpha, growing); live cells = full fill +
  border; mine variant draws the mine dot + trigger ring.
- **`IMPLEMENTED_WHERE` += ["fire_grid","frost_grid","mine_grid"]** once this lands.
- **Acceptance:** cells telegraph 0.5s → damage 2.5s, alternating parity; player always has safe cells;
  **enemies in live cells take damage** (fire/frost) or detonate mines (mine); parse + `entity_ramp` ≥60fps.

---

## 7. PHASE 4 — Flow-field perf fix (`scripts/game/FlowField.gd`)

`flowfield_stress` = 16fps @200 vs 142 baseline — 9× hit, **undiagnosed** (`sample()` already O(1) on read).
Apply two safe fixes + re-measure.
- **Inflation 84→40** (L4 `OBSTACLE_INFLATION`): enemy radius 19; 84 was ~4.4× → thinner blocked ring, wider
  passages.
- **Precompute nearest-reachable at build** so `sample()` is provably O(1): in `_build_vectors` (L191-219), for
  **blocked or unreachable** cells set `vectors[index] = _nearest_reachable_direction(index, distances)` (keep
  reachable + target-cell cases). Simplify `sample()` (L91-113) to return `vectors[current_index]` (drop the
  `_blocked` guard + the runtime `_nearest_reachable_direction_cached` branch). Delete
  `_nearest_reachable_direction_cached` (L261-271) + `"nearest_cache":{}` (L82); keep `distances` +
  `_nearest_reachable_direction`.
- **Acceptance:** identical routing; `flowfield_stress` ≥60 avg_fps @200.
- **⚠ Failure branch is bounded (F10).** If still <60, **do NOT apply further optimizations under this plan.**
  Add only **instrumentation** — bucket one `flowfield_stress` run into exactly three timers: **(a) physics** =
  `Performance.TIME_PHYSICS_PROCESS` delta/frame, **(b) sample** = summed `FlowField.sample` time across
  enemies, **(c) update_targets** = `_build_distances` + `_build_vectors` time — and log which dominates. Any
  fix beyond the two above **requires a plan amendment** (a new bounded slice) before coding.

---

## 8. PHASE 5 — Batch-A WHERE mechanics

Each is `scripts/arena/<X>Mechanic.gd extends ArenaMechanic`, keyed off WHERE, built one at a time
(validate+commit each), and **`IMPLEMENTED_WHERE` += its id** on landing. All damage is team-neutral via
`damage_circle` (§5b).

**Concrete layout constants (F5)** — arena `3600×2100`, center `C=(1800,1050)`:
- **Islands `PAD_SETS`** (each 4 centers; **set 0 covers C so spawning players are safe**; `START_GRACE:=1.5`
  before the sea deals any damage): `[[(1800,1050),(760,620),(2840,620),(1800,1620)],
  [(760,1480),(2840,1480),(1360,760),(2240,760)], [(1360,1340),(2240,1340),(1800,700),(700,1050)]]`; cycle 0→1→2→0.
- **Tesla `PYLONS`** = `[(820,560),(2780,560),(820,1540),(2780,1540)]`; **`PAIR_SCHEDULE`** (cycle):
  `[[[0,1],[2,3]], [[0,2],[1,3]], [[0,3],[1,2]]]` (horizontals → verticals → diagonals).
- **Clouds** `START:=[(700,700),(2900,1400)]`, initial unit dirs `[(0.86,0.51),(-0.89,-0.45)]` × `DRIFT`,
  reflect off `_arena` edges.
- Pinwheel needs only `C` (arms radiate from center).

- **Islands** (`IslandsMechanic`) — floor is a hazard sea except `PAD_COUNT:=4` safe circles (`PAD_R:=150`) at a
  fixed set of positions; every `RESHUFFLE:=4.0` the pads jump to the next fixed set, with `TELEGRAPH:=0.6`
  where the new pads glow before the old expire. Damage tick `0.5`: any **player** not within a pad →
  `apply_damage(4)`. **Enemies** not within a pad → `apply_damage(2)` every `1.0` (iterate `_coop._enemy_nodes`;
  thins the swarm without deleting it — playtest-tune). Draw: sea tint + pad rings.
- **Pinwheel** (`PinwheelMechanic`) — `ARM_COUNT:=4` capsules from arena center, length `ARM_LEN:=520`, width
  `ARM_W:=70`, rotating `SPIN:=0.5 rad/s`. Tick `0.4`: any actor within `ARM_W/2` of an arm segment
  (center→tip at the current angle; point-to-segment distance) → `apply_damage(5)` (players over `_players`,
  enemies over `_coop.get_nearby_enemy_target_nodes(center, ARM_LEN)`). The 4 wedge gaps are always safe; no
  telegraph needed (continuous rotation is readable). Draw: 4 rotating capsules + hub.
- **Tesla Arcs** (`TeslaArcsMechanic`) — 4 fixed pylons (inset positions). `ARC_PERIOD:=2.6`; each period a
  predefined set of node-pairs runs `TELEGRAPH:=0.6` (dim line) → `ACTIVE:=1.0` (live), rotating which pairs
  each period. While live, any actor within `ARC_W:=46` of the arc segment → `apply_damage(6)` every `0.4`.
  Draw: pylons + telegraph/live jagged lines.
- **Drifting Clouds** (`DriftingCloudsMechanic`) — `CLOUD_COUNT:=2` blobs radius `CLOUD_R:=200`, drift
  `DRIFT:=60 px/s`, bounce off `_arena` edges. Tick `0.6`: `damage_circle(cloud_center, CLOUD_R, 4)`. Localized
  ⇒ safe outside the clouds. Draw: soft translucent blobs.

**Acceptance (each):** readable, hits both teams where stated, safe space exists, no perf regression on
`entity_ramp`.

## 8b. PHASE 6 — Batch-B WHERE (physical cover; gated on Phase 4 ≥60fps)

**Runtime obstacle API changes (F8), `CoopManager`:**
- `_spawn_arena_obstacle(rect) -> StaticBody2D` — **return the created body** (was `void`) so a mechanic can
  retain / reposition / disable it.
- New `func rebuild_obstacles(rects: Array) -> bool` (atomic apply):
  1. reject if any rect fails `_is_obstacle_rect_spawn_safe`;
  2. **clip guard (F6):** reject if any rect grown by the actor radius (~40) intersects a **live** actor —
     iterate `_player_nodes` + `get_nearby_enemy_target_nodes(rect.get_center(), rect_half_extent+60)`;
  3. `_flow_field.build(rects)`; if `not validate_connectivity(_build_flow_connectivity_points())` → rebuild
     with the **previous** rect set and **return false**;
  4. else spawn/reposition/enable bodies to match `rects`, set `_active_obstacle_rects = rects`, call
     `_update_flow_field_targets()`, **return true**.
  A mechanic **never applies a step `rebuild_obstacles` rejected** — the block stays where it was; retry next step.

**Motion model — LOCKED: discrete telegraph-then-snap (F7).** All moving cover is stationary between steps.
A step = `TELEGRAPH` (a ghost outline drawn at the destination; block unmoved, collision unchanged) → **snap**
(one `rebuild_obstacles` call with the new rect set). No continuous motion ⇒ no continuous flow updates; each
step is a single gated rebuild (microseconds post-Phase-4). Initial obstacles register via `_setup_room_obstacles`
(unsafe rects rejected there). Coords below pass `_is_obstacle_rect_spawn_safe` — interior `x∈[240,3360]`,
`y∈[240,1860]`; physical cover also clears the center box `x∈[1340,2260]×y∈[690,1410]`.

- **Bastion** (F4 — **not a centered lone block**): two off-center static pillars flanking the mid-field,
  `Rect2(700,800,340,500)` + `Rect2(2560,800,340,500)`. Static → build once, no motion. *(The one permitted
  static-cover feature — deliberately off-center for the shooter-LOS puzzle; an explicit scoped exception to
  "no lone static obstacles.")*
- **Pop-up Pillars** — 5 rects `260×260` at `[(620,560),(2720,560),(620,1280),(2720,1280),(1670,1480)]`; each
  raise/lower on staggered `PERIOD:=3.0` (up `1.8`/down `1.2`, `TELEGRAPH:=0.4`, start delays `0,-0.6,-1.2,-1.8,
  -2.4`). Each transition → `rebuild_obstacles` with the current up-set.
- **Sliding Gates** — off-center vertical wall at `x=2400`, width `180`, split into top `Rect2(2400,240,180,
  gap_y-240)` + bottom `Rect2(2400,gap_y+GAP,180,1860-gap_y-GAP)`, `GAP:=420`; `gap_y` steps among `[520,900,
  1280]` every `STEP:=1.5`.
- **Bulwark** — 1 rect `120×520`, start `Rect2(700,790,120,520)`; patrol `x∈[700,2900]` stepping `±300` every
  `STEP:=2.0` (reverse at ends). The clip + connectivity guards let it cross the mid-field only when clear.
- **Drifting Cover** — 2 rects `260×180`, start `[(800,600),(2540,1320)]`; each `STEP:=2.0` targets a spot
  `±300` from current (skip if `rebuild_obstacles` rejects).
- **Shifting Maze** — `220×220` pillar slots on an off-center grid, cols `x=[560,1040,2560,3040]`, rows
  `y=[520,1050,1580]` (12 slots, all clear of the center box by x); each `STEP:=2.5` a checkerboard subset is
  up, the rest down → one `rebuild_obstacles`.

Charges go straight (physics-stopped). **Acceptance:** routes ≥60fps @200 (Phase 4 holds), cover blocks shots,
clip guard prevents pop-under (F6), connectivity revert prevents trapping, telegraph-then-snap reads clearly;
`--where=<id> --smoke` (F11) asserts connectivity + no-trap after a forced step.

---

## 9. Notes
- Canonical tree `D:\GameDev\Project_Twin_stick` on `v4/class-system`; parallel Codex may edit — re-read first.
- Validate + commit **per phase/slice**; **don't push unless asked.** All numbers first-pass, playtest-tuned.
- **All six phases are implementation-ready** (Rev 3, §§2–8b). Phase 4's outcome is empirical (a perf number);
  its failure branch is bounded to instrumentation + a plan amendment (§7).
- New files: `scripts/arena/ArenaMechanic.gd` (base) + one `<X>Mechanic.gd` per WHERE mechanic.
- Deferred: **Elites archetype** (needs non-champion elite IDs — F4); new ranged types (lobber/sniper);
  boss/champion swarm-separation; ranged LOS/cover.
