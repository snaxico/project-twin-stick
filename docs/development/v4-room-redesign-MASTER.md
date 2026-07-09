# V4 — Room & Enemy Redesign — MASTER PLAN

> **THE single canonical document for this work.** Self-contained: design + build sequence + implementation
> specs. Consolidates the working docs (`v4-enemy-tiers-plan`, `v4-flowfield-perf-plan`, `v4-curated-rooms-plan`,
> `v4-room-pool`, `v4-arena-pathfinding-plan`) — if any conflicts with this file, **this file wins.**
>
> Branch `v4/class-system`, active checkout `D:\GameDev\Project_Twin_stick`. **One coordinated patch, built in
> phase order; validate + commit per phase; don't push unless asked.** Parallel Codex may edit the tree —
> **re-read before each edit.**
>
> **Validation gate (per phase):**
> ```powershell
> $GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' --quit                    # parse
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=entity_ramp   # perf (avg_fps>=60)
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=flowfield_stress  # Phase 4 only
> ```

---

## 0. The model at a glance

**A room = WHO + WHERE + TWIST.**
- **WHO** — 1 of **6 curated archetypes** (the enemy identity).
- **WHERE** — **exactly 1 arena mechanic** (the stage: a grid / moving columns / hazard / cover). Most rooms
  get one; **Open** is the low-weight breather. Never two (they'd fight over the floor).
- **TWIST** — **0–1 stat modifier** (light spice).

**Enemy tiers** (the roster WHO draws from):
- **Trash-melee** (the swarm, density-scaled): chaser · charger · bomber · splitter/mini
- **Ranged specials** (capped, telegraphed): spitter · elite_spitter
- **Elites** (priority): elite_charger · elite_support · elite_spitter
- **Champions**: bosses — separate boss rooms

**Design principle (locked):** rooms are **dynamic, readable, fun-not-punishing** — hazards you weave around
and exploit (they hurt the swarm too) + cover that moves on a rhythm. Rejected: static lone obstacles;
encroaching hazards that chase/squeeze; floor-effect gimmicks; trigger-traps/turrets; objective rooms.

---

## 1. Build sequence (one patch, phased)

| Phase | What | Ships on | Risk |
|---|---|---|---|
| **1** | Enemy tiers (telegraphed spitter + shooter cap) **+** card streamline | existing tech | none — **fixes the bullet-hell** |
| **2** | Room foundation: WHO + selection + TWIST (existing modifiers; WHERE = Open) | existing modifiers | low |
| **3** | First WHERE: **pulsing hazard grid** (Fire/Frost/Mine) | existing fire/ice/mine | low |
| **4** | **Flow-field perf fix** → unblocks cover | — | ⚠ uncertain (9× undiagnosed) |
| **5** | Rest of Batch-A WHERE: Islands · Pinwheel · Tesla Arcs · Drifting Clouds | hazard system | med |
| **6** | Batch-B WHERE (cover): Bastion · Pop-up Pillars · Sliding Gates · Bulwark · Drifting Cover · Shifting Maze | needs Phase 4 | gated |

**Ship seam:** Phases **1–3 + 5** = shippable core (complete new system, no perf risk). Phases **4 + 6** =
gated tail (build only if the flow-field fix holds ≥60fps; else the core ships whole and cover waits).

---

## 2. PHASE 1a — Enemy tiers → ranged "specials" (`scripts/enemies/Enemy.gd`, `scripts/game/WaveDirector.gd`)

Fixes the `ranged_gauntlet` bullet-hell: too many simultaneous shooters. Model = trash-melee swarm (density
scaled) + ranged as **capped, telegraphed, priority** threats.

**Locked values (MC):** spitter → telegraphed **3-shot fan**, ~0.45s wind-up (aim locked at wind-up START),
**scale-pulse** tell, HP **14→30**. elite_spitter → telegraphed **5-shot fan**, cadence **0.8→2.2s** (kills
the machine-gun). Shooter budget base **6**, **+2 for 2P**; cost **spitter=1, elite_spitter=2**; overflow →
**melee from the room's own pool** (fallback chaser). No new ranged types.

### Slice 1 — telegraphed fans (`Enemy.gd`)
The fan already exists: `_emit_projectiles_at(dir, count, spread_radians, scale)` → `_build_spread_directions`
(spread = **per-shot step**; elite already fires count 5 @ 0.16). Add a **wind-up phase**:
- New fields near the windup timers (~L214): `_spitter_windup_until`, `_spitter_aim_dir`,
  `_spitter_windup_active` (reset in the type-reset block ~L269 + `_configure_type`).
- In `_update_spitter_behavior` (~L834), replace the inline fire (L840-843) with:
  - **enter wind-up** when `now >= _next_fire_at and distance > 120 and not _spitter_windup_active`:
    `_spitter_windup_active=true`; `_spitter_windup_until = now + (0.45 if SPITTER else 0.50)`;
    `_spitter_aim_dir = (_get_lead_direction(raw_dir,projectile_speed,0.35) if ELITE_SPITTER else raw_dir)`;
    `_next_fire_at = now + _get_effective_fire_interval()`.
  - **fire** when `_spitter_windup_active and now >= _spitter_windup_until`: SPITTER →
    `_emit_projectiles_at(_spitter_aim_dir, 3, 0.22, 0.7)`; ELITE_SPITTER →
    `_emit_projectiles_at(_spitter_aim_dir, 5, 0.18, 0.9)`; then `_spitter_windup_active=false`.
  - **slow while winding up:** if active, scale returned `desired_velocity` by ~0.35.
- **Scale-pulse tell** (`_update_visual_state`, ~L1264, sets `visual.scale`): while active, multiply a factor
  lerping `1.0→~1.30` over the wind-up window into the `visual.scale` expression; snap back on fire.
- **Stats** (`_configure_type`): `spitter` max_health `14→30`, fire_interval `1.8→2.0`; `elite_spitter`
  fire_interval `0.8→2.2`.
- **Acceptance:** one spitter dodgeable by reading the swell + sidestepping the fan; elite reads as a heavy
  telegraphed burst, not a 0.8s stream; overlapping shooters stay readable; movement split unchanged.

### Slice 2 — global concurrent-shooter budget (`WaveDirector.gd`)
- `const SHOOTER_COST := {"spitter":1, "elite_spitter":2}`; `_shooter_cost(t)->int` (0 = not a shooter).
- `const SHOOTER_BUDGET_BASE := 6`; `_shooter_budget() -> 6 + 2*max(player_count-1,0)`.
- `var _active_shooter_budget := 0`: increment by cost in `spawn_enemy_instance` (~L86) after a shooter
  spawns; **reset in `start_room`** (~L37); decrement on death — add `notify_enemy_removed(type)` called from
  `CoopManager._on_enemy_died` (enemy exposes `get_type_name()`), clamp ≥0.
- **Enforce (overflow→melee):** `_pick_spawn_type(pool)` wraps `_roll_wave_enemy_type`: if the rolled type is a
  shooter and `_active_shooter_budget + cost > _shooter_budget()`, return `_roll_melee_type(pool)` (random
  non-shooter from pool; fallback `"chaser"`). Route all spawn paths (opening burst L79-82, continuous
  L152-155, burst L164-167) through it.
- **Acceptance:** on-screen shooters never exceed budget (6 solo / 8 in 2P, elites double); surplus arrives as
  room-appropriate melee; total enemy count unchanged; counter resets across rooms (no leak).

### Slice 3 — `ranged_gauntlet` data (`data/room_archetypes.json`), interim until Phase 2
`enemy_bias` → add `"charger","chaser"` (its bias has no melee for overflow); `density_profile` → `"low"`.

---

## 3. PHASE 1b — Card streamline (`scripts/ui/RunFlow.gd _build_route_card`, L73-166)

Cut the cluttered card (~9 elements) to four, keeping the panel/glow style. Works on current data now.
- **Row 1 (keep):** `trait_icon + trait_label` (L99-105) left · `danger_pips` (L106-112) right.
- **Row 2 (collapse):** modifier `chip_flow` (L114-124) → **≤2** chips; none → render nothing (drop "Open").
  *(Post Phase 2, feed from the room's authored tags instead of raw modifiers.)*
- **Row 3 (keep):** `rare_label` (L155-162).
- **CUT the `detail_label` block (L126-148):** Room N, `Enemies:` dump, `Objective: Clear`, short_desc,
  reward_hint. Keep only a small icon for a **real** side_objective.
- **Champion card:** name = `Champion: <boss>`; one `Champion` chip; keep danger + reward.
- **Acceptance:** card shows name+icon · danger · ≤2 tags · reward only; no enemy dump / prose; parse clean.

---

## 4. PHASE 2 — Room foundation (`scripts/game/RunState.gd`, `RunFlow.gd`, `data/room_archetypes.json`)

Gets the WHO + selection + TWIST loop working with **existing** modifiers (WHERE = Open until Phase 3).

**WHO — 6 archetypes** (populate `composition`; from the tier roster):

| Archetype | melee_density | melee_bias | shooters / elites | Depth |
|---|---|---|---|---|
| Horde | high | chaser, chaser, splitter | — | 1+ |
| Mixed | medium | chaser, charger, splitter, bomber | shooters: spitter | 1+ |
| Splitters | high | splitter, splitter_mini, chaser | — | 4+ |
| Pressure | medium | charger, charger, bomber | — | 4+ |
| Gauntlet | low | chaser | shooters: spitter, spitter, elite_spitter | 4+ |
| Elites | low | chaser | elites: 1–2 of elite_charger/elite_support | 7+ |

- **Schema** — extend `data/room_archetypes.json`: each archetype has a `composition` (above), a **`where_pool`**
  (arena mechanics — roll **exactly 1**, Open weighted low), and a **`twist_pool`** (stat modifiers — roll
  **0–1**). `elites` is a new composition key (spawn 1–2 named elites once).
- **Selection** (`RunState._build_choice_step` L599 / `_draw_archetypes_for_depth` L880): draw **2** archetypes
  by depth gate, **no-repeat** vs previous + distinct from each other; champion steps unchanged (1 forced).
- **Build node** (`_build_run_node` L614): roll **1** from `where_pool` + **0–1** from `twist_pool`; carry
  name/icon/tags (= the rolled where+twist).
- **Danger derived** (`_refresh_route_metadata`): base by density (low/normal/high→1/2/3) `+1` if shooters
  `+1` if elites `+` twist count, clamped to the pip max.
- **WaveDirector**: consume `composition.melee_density`/`melee_bias`/`shooters`/`elites`; shooter budget
  (Phase 1) governs ranged.
- **Retire** the old `_roll_archetype_modifiers` / `_build_distinct_modifier_load` random logic → the
  where/twist rolls above.
- **Acceptance:** 2 archetype choices/step, no repeats; each plays its identity; danger tracks composition;
  card shows name · danger · ≤2 tags (where+twist) · reward.

---

## 5. WHERE mechanics (the stage deck) — full reference

Each is a full mechanic keyed off the room's `where` field. **1 per room.**

**Batch A — hazard system, ships now (Phases 3 + 5):** Fire Grid · Frost Grid · Mine Grid · Islands ·
Pinwheel · Tesla Arcs · Drifting Clouds · **Open** (no mechanic).
**Batch B — physical cover, needs Phase 4 (Phase 6):** Central Bastion · Drifting Cover · Pop-up Pillars
(moving columns) · Sliding Gates · Shifting Maze · Bulwark.

**Themed `where_pool` per archetype** (roll 1; Open weighted low so most rooms get a mechanic):

| Archetype | where_pool |
|---|---|
| Horde | Fire Grid, Islands, Pinwheel, Tesla Arcs, Drifting Clouds, Sliding Gates, Open |
| Mixed | Fire Grid, Frost Grid, Islands, Pinwheel, Tesla Arcs, Drifting Clouds, Open |
| Splitters | Fire Grid, Mine Grid, Tesla Arcs, Shifting Maze, Open |
| Pressure | Mine Grid, Bulwark, Sliding Gates, Pop-up Pillars, Open |
| Gauntlet | Central Bastion, Drifting Cover, Pop-up Pillars, Frost Grid, Islands, Tesla Arcs, Fire Grid |
| Elites | Drifting Clouds, Central Bastion, Pinwheel, Open |

**TWIST `twist_pool`** (roll 0–1, existing stat modifiers): Enemy Speed · Shielded · Explosive Death ·
Shrinking Arena · Accelerating Waves. Light theming (Pressure↔Shrinking, Splitters↔Explosive Death).

**Mechanic behaviors** (for build):
- **Fire/Frost/Mine Grid** — coarse grid (~6×4), cells alternate safe↔hazard on ~2.5s pulse w/ ~0.5s
  telegraph (glow); active cells spawn the hazard (fire_floor / ice_zone-slow / armed mines). Damages swarm.
- **Islands** — hazard-sea floor + safe pads; pads reshuffle each pulse.
- **Pinwheel** — rotating hazard arms from center; orbit the gaps.
- **Tesla Arcs** — fixed nodes; arcs snap between pairs on a rhythm (temporary hazard lines).
- **Drifting Clouds** — toxic gas blobs drift slowly across; damage what's inside.
- **Central Bastion** — one central `StaticBody2D` block (layer 1) → blocks shots + splits swarm; static.
- **Pop-up Pillars** — cover blocks raise/lower on a rhythm.
- **Sliding Gates** — wall with a passage that slides open/closed.
- **Bulwark** — one big wall patrols a path (mobile shield).
- **Drifting Cover** — small cover blocks wander.
- **Shifting Maze** — pillar field; lanes open/close on a beat.

*Cover verified:* projectiles are `layer2/mask1`, obstacles `StaticBody2D layer1`, `Projectile._on_body_entered`
(L272-277) despawns on any StaticBody2D team-agnostically → **cover blocks shots with no LOS AI.**

---

## 6. PHASE 3 — Pulsing hazard grid (first WHERE)

Build the grid overlay (Fire/Frost/Mine share it). Coarse grid, checkerboard safe↔hazard, ~2.5s pulse +
~0.5s telegraph; active cells spawn the chosen hazard (reuse existing `CoopManager` hazard spawns) + a new
grid/pulse driver, activated when the room's `where` ∈ {Fire,Frost,Mine Grid}. **Acceptance:** pulses readably,
player weaves safe cells, enemies caught; parse + entity_ramp ≥60fps.

---

## 7. PHASE 4 — Flow-field perf fix (`scripts/game/FlowField.gd`)

`flowfield_stress` = 16fps @200 vs 142 baseline — a 9× hit from 4 thin bars, **undiagnosed** (`sample()` is
already O(1) on read). Apply two safe fixes + re-measure (locked); if still <60, add bucket instrumentation.
- **Inflation 84→40** (L4 `OBSTACLE_INFLATION`): enemy radius is 19; 84 was ~4.4× → thinner blocked ring,
  wider passages, less bunching.
- **Precompute nearest-reachable at build** so `sample()` is provably O(1): in `_build_vectors` (L191-219),
  for **blocked or unreachable** cells set `vectors[index] = _nearest_reachable_direction(index, distances)`
  (keep reachable + target-cell cases as-is). Simplify `sample()` (L91-113) to return `vectors[current_index]`
  (drop the `_blocked` guard + the runtime `_nearest_reachable_direction_cached` branch). Delete
  `_nearest_reachable_direction_cached` (L261-271) + the `"nearest_cache":{}` in the field dict (L82); keep
  `distances` + `_nearest_reachable_direction`.
- **Acceptance:** identical routing (open rooms unchanged; enemies route around bars; strays head back on
  field); `flowfield_stress` ≥60 avg_fps @200. **If not:** bucket-time physics vs sample vs update_targets and
  fix the dominant cost (likely rebuild cadence or collider contacts).

---

## 8. PHASES 5 & 6 — remaining WHERE mechanics

- **Phase 5 (Batch-A, ships now):** build Islands · Pinwheel · Tesla Arcs · Drifting Clouds — one at a time
  (validate+commit each), keyed off the `where` field; behaviors in §5; each damages the swarm, readable,
  no perf regression.
- **Phase 6 (Batch-B cover, gated on Phase 4 ≥60fps):** Central Bastion → Pop-up Pillars → Sliding Gates →
  Bulwark → Drifting Cover → Shifting Maze, one at a time. `StaticBody2D` on layer 1 (blocks shots, routed by
  the flow field); moving cover rebuilds the flow field on state change (gated, infrequent). Spawn-safety +
  connectivity validation (keep clear of spawn lanes/center; corridor ≥ 2×inflation). Charges go straight
  (physics-stopped). Acceptance: routes ≥60fps @200, cover blocks shots, no clipping.

---

## 9. Notes
- Canonical tree `D:\GameDev\Project_Twin_stick` on `v4/class-system`; parallel Codex may edit — re-read first.
- Validate + commit **per phase/slice**; **don't push unless asked.** All numbers are first-pass, playtest-tuned.
- Phases 3/5/6 mechanics are spec'd here at design + touchpoint level; expand any to line level just-in-time.
- Deferred: new ranged types (lobber/sniper); boss/champion swarm-separation; ranged LOS/cover.
