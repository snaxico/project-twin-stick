# V4 — Room & Enemy Redesign — MASTER PLAN

> **THE single canonical document for this work.** Self-contained: design + build sequence + implementation
> specs. Consolidates the working docs (`v4-enemy-tiers-plan`, `v4-flowfield-perf-plan`, `v4-curated-rooms-plan`,
> `v4-room-pool`, `v4-arena-pathfinding-plan`) — if any conflicts with this file, **this file wins.**
>
> Branch `v4/class-system`, active checkout `D:\GameDev\Project_Twin_stick`. **One coordinated patch, built in
> phase order; validate + commit per phase; don't push unless asked.** Parallel Codex may edit the tree —
> **re-read before each edit.**
>
> **Rev 16 (2026-07-07) — resolves review round 14 (1 P2; NO P1 blockers); rounds 1–13 retained.** The
> `shooter_budget` scenario now starts its room with the **`profiling` no-spawn flag** (`WaveDirector` skips
> `spawn_opening_burst` + `_continuous_spawn`) and the smoke **resets `_active_shooter_budget = 0`** before its
> assertions — isolating it from normal wave spawning (P2). Rounds 1–13 retained (budget-smoke on CoopManager +
> real `_on_enemy_died`, `_build_archetype_enemy_pool` deleted, `profiling_where_revision`, Frost once-per-player).
> Verified vs `CoopManager`/`WaveDirector`. **All six phases implementation-ready.**
>
> **Rev 17 (2026-07-10) — implementation note / Phase 4b amendment.** Phase 4's first safe fixes moved
> flow-field cost out of `sample()` but left `update_targets` dominated by vector rebuilds under
> `flowfield_stress`. The implemented amendment replaces per-cell nearest-reachable ring searches with
> reverse-BFS escape-vector generation, rate-limits per-player target-field rebuilds, and coarsens flow-field
> cells from `100px` to `150px`. Latest `flowfield_stress` reached **59.4 avg FPS at 200 enemies** with
> instrumentation showing **physics** as the dominant remaining bucket, not flow-field sampling/rebuilds.
>
> **Validation gate (per phase):**
> ```powershell
> $GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' --quit                    # parse
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=entity_ramp   # perf (avg_fps>=60)
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=flowfield_stress  # Phase 4 only
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=where:fire_grid --smoke  # per-mechanic
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=shooter_budget --smoke   # Phase 1
> ```
> **Phase 1 acceptance requires `--profile=shooter_budget --smoke`** (F2-round11) — a `PerfRunner` scenario that
> **starts a room via `RunFlow` — with the `profiling` no-spawn flag (§Setup: `WaveDirector` skips
> `spawn_opening_burst` + `_continuous_spawn`, so no opening burst / stream / bursts run — P2-round14)** and calls
> **`CoopManager.profiling_run_shooter_budget_smoke() -> bool`** on the live `CoopManager` (the entry lives on
> `CoopManager`, which owns both `_wave_director` and the death hook — resolving the call path since
> `WaveDirector.gd` has no `class_name`, P3-round13). The routine first **resets `_active_shooter_budget = 0`**
> (so any residual state can't perturb the exact assertions — P2-round14), then drives reservation +
> overflow + cancel-release through `_wave_director`, and for **death-release routes through the real
> `CoopManager._on_enemy_died(shooter)` hook** (not a direct `notify_enemy_removed`, so a *missing hook wiring*
> is caught — P2-round13); asserts `_active_shooter_budget` exactly after each. `quit(1)` if it returns false.
> **⚠ Per-WHERE validation (F2–F5, F9, F11)** — in **`PerfRunner`**, scenario **`where:<id>`** (new `_run`
> branch; `entity_ramp` never instantiates a mechanic):
> - **Setup:** load `RunFlow.tscn`, start a real combat room with `where = id` + `Mixed` composition + a
>   `profiling` flag that makes `WaveDirector` **skip `spawn_opening_burst` + `_continuous_spawn`** (no opening
>   burst / stream / timed bursts) so the population is exactly what's injected (F4). These `where`/`profiling`/
>   `composition` fields ride in via `debug_run_setup`; **`_build_single_room_map` (RunState L566) must copy all
>   three into the node** — it currently copies none, so without this the mechanic is Open and waves still spawn (F2).
>   PerfRunner also sets **`side_objective: ""`** in `debug_run_setup` so no random side objective is rolled into
>   the benchmark (F2-round8).
> - **Load (F1, F3, F5):** new **`CoopManager.profiling_inject(seed: int, count: int = 200)`** (required arg
>   first — F1-round8; PerfRunner can't reach the private `_wave_director`) injects a fixed **194 `chaser` + 6
>   `spitter`** — derived from `count` so it's never inconsistent: **`spitter_count = min(6, count)`,
>   `chaser_count = count - spitter_count`** (F3-round9; 6 = the shooter budget → representative
>   projectile load — F3). Determinism (F5): a fixed **`const PROFILING_SEED := 20260707`** seeded RNG for
>   positions (each snapped to `_flow_field.nearest_passable_position` — reproducible + clear of cover); **seed
>   each injected `Enemy._random` BEFORE `setup()`** (which consumes `_random` in `_configure_type` for the
>   initial fire time — so `profiling_inject` seeds between instantiate and `setup()`, or via an optional seed
>   arg on the spawn path — F4), replacing that enemy's `_random.randomize()`; also seed **Drifting Cover's step
>   RNG** under `profiling`, so the whole run is deterministic. Each injected enemy gets **per-enemy `set_profiling_immortal(true)`**:
>   `apply_damage` runs the **full normal path** (hit signals + VFX + particles — the real hazard cost, F1) but
>   **clamps `current_health = max(current_health - dmg, 1)`** so it never dies (per-enemy flag, not global
>   `debug_profiling`) — sustains the load *with* representative damage-path cost.
> - **Lifecycle (F3):** with `--smoke`, run the functional assertions **during `WARMUP_SECONDS`** (load present),
>   record pass/fail; **then** sample `avg_fps` over `SAMPLE_SECONDS` (force a moving-cover step every `STEP`
>   while sampling); print the CSV line and issue **one** exit — `quit(1)` if the smoke assert failed **or**
>   `avg_fps < 60`, else `quit(0)`. Without `--smoke`: warmup → sample → exit on the fps threshold.
> - **`--smoke` assertions** (the dummy is a **normal damageable** enemy — not immortal — F2):
>   - **Batch-A:** a stationary damageable dummy in an active hazard zone → assert **HP drops** (team-neutral),
>     then remove it via a dedicated **`CoopManager.profiling_remove_enemy(enemy)`** (unregisters from
>     `_enemy_nodes` + frees, **no kill/XP/drop effects** — F2-round9; `queue_free` alone leaves it in
>     `_enemy_nodes`, and `_on_enemy_died` would fire death effects) before sampling, and assert the registered
>     count is **exactly 200** (F3-round8).
>   - **Batch-B (all IDs):** an enemy projectile through a cover rect **despawns** (shot-block); initial
>     placement + connectivity validated.
>   - **Batch-B (moving cover only — NOT static Bastion, which has no transition, F1-round10):** call
>     **`CoopManager.profiling_force_where_step() -> bool`** (a profiling facade — `_where_mechanic` is private,
>     so PerfRunner can't force/observe a step directly, F2-round10; it drives one mechanic step and returns
>     whether the snap applied) and read **`CoopManager.profiling_where_revision()`** (F1-round11); assert **the
>     step applied (`true`) and the revision advanced** (not perpetually rejected — F1-round9), then **every live
>     enemy passes the reachability check** (`has_target_field` + `target_reaches_points`, F2) — no soft-lock.
> One `--profile=where:<id>` run per implemented mechanic id is part of that phase's acceptance.

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
- **Automated budget smoke (F5-round10)** — a focused test covering the four paths the profiling injection
  bypasses: (1) **reservation** — rolling a shooter increments the budget; (2) **overflow conversion** — a
  shooter roll over budget spawns melee instead; (3) **cancellation release** — a cancelled deferred spawn
  releases its reservation; (4) **death release** — a shooter's death decrements. Assert `_active_shooter_budget`
  is exact after each. **Entry: `CoopManager.profiling_run_shooter_budget_smoke() -> bool`** (on the live
  CoopManager — resolves the call path, P3-round13); the **death-release case drives the real
  `CoopManager._on_enemy_died` hook** so a missing `notify_enemy_removed` wiring is caught (P2-round13). **Wired
  as `--profile=shooter_budget --smoke`, required for Phase-1 acceptance** (F2-round11).

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
- **CUT `detail_label` (L126-148) entirely:** Room N, `Enemies:` dump, `Objective: Clear`, short_desc,
  reward_hint — **and no side-objective icon** (F6 — there's no glyph mapping for `hold_zone`/`kill_streak`/
  `collector`; the card stays name+icon · danger · ≤2 tags · reward only).
- **Champion card:** name = `Champion: <boss>`; one `Champion` chip; keep danger + reward.
- **Acceptance:** name+icon · danger · ≤2 tags · reward only; no dump/prose; parse clean.

---

## 4. PHASE 2 — Room foundation (`scripts/game/RunState.gd`, `RunFlow.gd`, `data/room_archetypes.json`)

WHO + selection + TWIST loop on **existing** modifiers (WHERE = Open until Phase 3; Elites deferred per §0).

**WHO — 5 archetypes** (populate `composition`):

| Archetype | icon | melee_density | melee_bias | shooters | shooter_ratio | Depth |
|---|---|---|---|---|---|---|
| Horde | `swarm` | high | chaser, chaser, splitter | — | 0.0 | 1+ |
| Mixed | `open` | medium | chaser, charger, splitter, bomber | spitter | 0.20 | 1+ |
| Splitters | `scan` | high | splitter, splitter_mini, chaser | — | 0.0 | 3+ |
| Pressure | `shield` | medium | charger, charger, bomber | — | 0.0 | 3+ |
| Gauntlet | `bolt` | low | chaser | spitter | 0.50 | 4+ |

*(All `icon` IDs resolve in `RunFlow._trait_icon_text` — F6; `open` → the default glyph.)*

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
**`where_pool`**, and a **`twist_pool`**. Add **`const IMPLEMENTED_WHERE: Array` in `RunState.gd`** (the selection owner; pinned so it's not invented at
implementation time — round11-unclear) (grows per phase:
`[]` → P3 adds `fire_grid,frost_grid,mine_grid` → P5 adds `islands,pinwheel,tesla_arcs,drifting_clouds` → P6
adds cover ids).

**Node keys (F10):** `_build_run_node` writes **`where: String`** (the rolled mechanic id, `"open"` default)
and **`modifiers: Array`** (the rolled twist ids). No separate `tags` key — the card builds its ≤2 chips from
`[where] + modifiers` (§3). `where` drives `CoopManager` WHERE activation (§5b); `modifiers` drives the existing
twist/modifier path.

**Selection** (`RunState._build_choice_step` L599 / `_draw_archetypes_for_depth` L880): draw **2** archetypes by
depth gate; **the two must differ from each other** (always satisfiable). **No-repeat-vs-previous applies only
when ≥3 archetypes are eligible** at that depth; with exactly 2 eligible it is dropped. Champion steps unchanged.

**Build node** (`_build_run_node` L614): roll 1 available WHERE + 0–1 TWIST; write `where`, `modifiers`, and
**`composition`** (the archetype's composition dict).

**Composition consumption (F1).** `CoopManager.start_room` (L545) reads `var comp := _room_config.get("composition", {})`
and passes it to `_wave_director.start_room(...)` (add a `composition` arg). `WaveDirector`: store `_composition`;
`_roll_wave_enemy_type` uses the F2 algorithm over `_composition` (`shooters`/`shooter_ratio`/`melee_bias`);
`density_profile` ← `_composition.melee_density` (low/medium/high → the values `_get_density_count_multiplier`
already reads). **Fallback:** if `composition` is empty — **champion, debug, and endless rooms** — keep the
existing `enemy_pool` + `density_profile` path unchanged (those rooms still write `enemy_pool`, archetype rooms
write `composition`). **Danger derived** (`_refresh_route_metadata`): base by density (low/med/high→1/2/3) `+1`
if shooters `+` twist count, clamped to pip max. **Retire** old `_roll_archetype_modifiers` /
`_build_distinct_modifier_load` **and `_ensure_route_options_differ()` + its call in `_build_choice_step`
(RunState L609)** — archetypes are already distinct, and that helper is the last live caller of the retired
`_build_distinct_modifier_load` (L721), so removing it avoids a dangling call (F3). **Fallback migration (F8):**
update `_fallback_archetype()` (RunState L915) to
emit the **new schema** — a `Mixed` `composition`, `where_pool:["open"]`, `twist_pool:[]` — not the old
`enemy_bias`/`themed_modifier_pool`. **Delete `_build_archetype_enemy_pool` with the old `enemy_bias` schema**
(P3-round12): champion/debug/endless rooms already build their `enemy_pool` via `_get_endless_enemy_pool` /
`_enemy_pool_from_debug_mix` (not this helper), and archetype rooms now use `composition` — so it has no caller
in the new model.

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

**TWIST — per-archetype `twist_pool`** (roll 0–1; duplicate entries = weight):

| Archetype | twist_pool |
|---|---|
| Horde | `enemy_speed, accelerating_waves, shielded` |
| Mixed | `enemy_speed, shielded, explosive_death, accelerating_waves` |
| Splitters | `explosive_death, explosive_death, enemy_speed` |
| Pressure | `enemy_speed, explosive_death, shielded` |
| Gauntlet | `shielded, accelerating_waves, enemy_speed` |

*(Existing stat modifiers only; Shrinking Arena excluded — it squeezes the arena, which the model rejects, and
would double as a 2nd arena mechanic (F7).)*

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
modifier refs). `where` comes from the Phase-2 roll; `"open"`/default = no mechanic. **Batch-B cases (F2 — single
owner):** in `setup`, the mechanic calls `_coop.rebuild_obstacles(initial_rects, true)` to place its cover; it
does **not** use `room_config.obstacles` / `_setup_room_obstacles`. The mechanic owns only its logical **state**
(pillars up, gate position, patrol index…) and declares a **rect set** each step; `CoopManager` owns the bodies
and reconciles them (§8b). No `obstacles` key is written to the node.

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
  - `frost_grid` — `apply_damage(3)`; **for the slow, per player per frame compute a single
    `inside_any_live_frost_cell` bool (scan ALL live cells first), THEN apply once:** true →
    `apply_zone_modifier("frost_grid", 0.5, 1.0)`, else `clear_zone_modifier("frost_grid")` (F3-round11 —
    **never clear inside the per-cell loop**, or a later live cell clears the slow a prior cell set; mirrors
    `IceZoneModifier`'s `inside_any_patch` pattern). Clear all on `_exit_tree`. *(Enemy slow out of scope — the
    team-neutral requirement is met by the damage.)*
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
  `apply_damage(4)`. **Enemies** not within a pad → `apply_damage(2)` every `1.0` (iterate a **snapshot**
  `_coop.get_enemy_target_nodes().duplicate()` with `is_instance_valid` guards — F6, since lethal damage mutates
  the backing `_enemy_nodes` mid-iteration; thins the swarm without deleting it — playtest-tune). Draw: sea tint
  + pad rings.
- **Pinwheel** (`PinwheelMechanic`) — `ARM_COUNT:=4` capsules from arena center, length `ARM_LEN:=520`, width
  `ARM_W:=70`, rotating `SPIN:=0.5 rad/s`. Tick `0.4`: collect actors within `ARM_W/2` of any arm segment
  (center→tip at the current angle; point-to-segment distance) into a **dedup set** (so the shared hub isn't
  hit once per overlapping arm — F9), then `apply_damage(5)` once each. Candidates: `_players` +
  `_coop.get_nearby_enemy_target_nodes(center, ARM_LEN + ARM_W/2)` (broad phase covers the rounded tip — F9).
  The 4 wedge gaps are always safe; no telegraph (continuous rotation is readable). Draw: 4 rotating capsules + hub.
- **Tesla Arcs** (`TeslaArcsMechanic`) — 4 fixed pylons (inset positions). `ARC_PERIOD:=2.6`; each period a
  predefined set of node-pairs runs `TELEGRAPH:=0.6` (dim line) → `ACTIVE:=1.0` (live), rotating which pairs
  each period. Tick `0.4`: collect actors within `ARC_W:=46` of **any** live arc segment into a **dedup set**
  (so an actor at the diagonal-schedule crossing takes **one** 6-tick, not two — F6), then `apply_damage(6)`
  once each. Draw: pylons + telegraph/live jagged lines.
- **Drifting Clouds** (`DriftingCloudsMechanic`) — `CLOUD_COUNT:=2` blobs radius `CLOUD_R:=200`, drift
  `DRIFT:=60 px/s`, bounce off `_arena` edges. Tick `0.6`: `damage_circle(cloud_center, CLOUD_R, 4)`. Localized
  ⇒ safe outside the clouds. Draw: soft translucent blobs.

**Acceptance (each):** readable, hits both teams where stated, safe space exists, holds **≥60fps on its
`--profile=where:<id>` run** (§1).

## 8b. PHASE 6 — Batch-B WHERE (physical cover; gated on Phase 4 ≥60fps)

**Runtime obstacle API (F8, F2 — single owner).** The mechanic owns only its logical **state** and declares a
**rect set** each step; `CoopManager` owns the bodies and **reconciles** them (no body refs leak to mechanics).
- `_spawn_arena_obstacle(rect) -> StaticBody2D` — return the body (was `void`), for the internal reconcile.
- `func rebuild_obstacles(rects: Array, initial := false) -> bool`:
  1. **Bounds (F5):** if `initial`, every rect must pass full `_is_obstacle_rect_spawn_safe`. **Else (a moving
     step)** every rect need only clear the **edge bands** — `ARENA_RECT.grow(-OBSTACLE_EDGE_EXCLUSION).encloses(
     rect.grow(_get_flow_obstacle_inflation()))`. The **center-box + player-spawn exclusions are spawn-time
     only**, so moving cover may cross the mid-field mid-game (resolves Bulwark — F5).
  2. **Overlap guard — only NEW or MOVED rects** (diff `rects` vs `_active_obstacle_rects`; unchanged & removed
     rects skip it). `const ACTOR_R := 40.0`. **Reject the step only if a PLAYER overlaps** a new/moved rect
     (`rect.grow(ACTOR_R).has_point(player.global_position)` over `_player_nodes`) → **return false** (we never
     shove a player). **Enemies overlapping a new/moved rect are NOT a rejection (F1-round9):** collect them into
     `to_relocate` and push them out **at snap** (step 5). This is why dense rooms (esp. Shifting Maze, whose
     pillars rise in lanes enemies occupy) never permanently freeze a transition — only a player standing on the
     destination defers it. **Also collect overlapping NON-player actors into `to_relocate` (F3-round10):**
     `pickups.get_children()` (health / collector orbs — else a rising pillar buries one and a **collector**
     side-objective becomes unreachable) **and** the **`player_deployable` group** (turret / summon / mine — else
     embedded inside cover). They're relocated at snap (step 5), not crushed.
  3. `_flow_field.build(rects)`; validate connectivity over `points = spawn-lane points + **current live
     `_player_nodes` positions**` (F5 — not just initial spawns). If it fails → `build(previous_set)` **and call
     `_update_flow_field_targets()`** (F4 — `build` clears all fields, so without this enemies drop to raw
     fallback until the periodic update), **return false**.
  4. Reconcile bodies to `rects`: for a **removed** body, **first set `collision_layer=collision_mask=0` and
     disable its `CollisionShape2D`, THEN `queue_free()`** (F7 — `queue_free` alone leaves it solid until
     frame-end while the field already excludes it). For a **changed** rect, **only reposition if the size is
     unchanged; if the size changed (e.g. Sliding Gates' `gap_y` changes both rect heights), remove+respawn**
     the body — do not reuse it, since its `RectangleShape2D.size` + visual polygon would be stale (F1). Spawn
     new rects fresh. `_active_obstacle_rects = rects`; `_update_flow_field_targets()`.
  5. **Relocate stranded enemies (F1):** a trapped enemy would **soft-lock room-clear** (needs the enemy list
     empty), and raw fallback can't cross physical cover. **Reachability (F2, F4):** add
     **`FlowField.has_target_field(player_index) -> bool`** (`return _fields.has(player_index)`) — needed because
     `target_reaches_points` returns `true` when the field is *absent*, so it can't tell reachable from missing.
     An enemy is stranded iff, over **alive players where `has_target_field` is true**, none returns
     `target_reaches_points(pi, [enemy.global_position]) == true` (**skip relocation entirely if no player has a
     field**). A stranded enemy **and every enemy in the step-2 `to_relocate` set** (destination-overlap) is moved
     via a new **`Enemy.relocate_to(pos)`** that sets position **and resets its cached flow-dir + sample frame**
     (F5 — else the stale direction is reused at the new spot), to a spawn-lane point (connectivity guarantees it
     reaches a player). **Compute the FULL position deterministically under `profiling` (F4-round9):**
     `enemy_spawn_position_for_edge` uses global `randf` for **both** the edge *and* the along-edge coordinate, so
     under `profiling` generate the whole position from the **seeded profiling RNG** (or use a **fixed validated
     lane point**) — no global RNG. **Overlapping pickups + `player_deployable`s in `to_relocate`** are instead
     nudged to `_flow_field.nearest_passable_position(their_pos)` (stay local, just clear of the cover — a
     collector orb must remain collectable; F3-round10). Then set `_enemy_separation_grid_frame = -1` (F5).
     **Return true.** ⇒ a transition never traps **or freezes**: overlapped enemies are pushed to a reachable
     lane, pickups/deployables clear of cover; only a player on
     the destination defers the step.

**Motion — discrete telegraph-then-snap (F6/F7).** Shared `MOVE_TELEGRAPH := 0.5` (Pop-up Pillars use their own
`0.4` up/down). A step = telegraph (ghost outline at destination; block unmoved) → snap
(`rebuild_obstacles(next_rects)`); if rejected, skip + retry. Initial placements are spawn-safe; moving steps are
edge-safe + guarded (§interior `x∈[240,3360]`, `y∈[240,1860]`; physical cover initial placement also clears the
center box `x∈[1340,2260]×y∈[690,1410]`). **Each moving-cover mechanic increments a `revision` on every applied
snap and exposes `profiling_force_step() -> bool` (force one step now, return whether it applied);
`CoopManager.profiling_force_where_step() -> bool`** forwards to the active `_where_mechanic` (private) and
**`CoopManager.profiling_where_revision() -> int`** reads its `revision` (a supported read path — the smoke must
not touch private state, F1-round11). **Static Bastion has no `profiling_force_step`** — it's not a moving cover.

- **Bastion** (F4 — **not a centered lone block**): two off-center static pillars flanking the mid-field,
  `Rect2(700,800,340,500)` + `Rect2(2560,800,340,500)`. Static → build once, no motion. *(The one permitted
  static-cover feature — deliberately off-center for the shooter-LOS puzzle; an explicit scoped exception to
  "no lone static obstacles.")*
- **Pop-up Pillars** — 5 rects `260×260` at `[(620,560),(2720,560),(620,1280),(2720,1280),(1670,1480)]`; each
  raise/lower on staggered `PERIOD:=3.0` (up `1.8`/down `1.2`, `TELEGRAPH:=0.4`, start delays `0,-0.6,-1.2,-1.8,
  -2.4`). Each transition → `rebuild_obstacles` with the current up-set.
- **Sliding Gates** — vertical wall `x=2400`, width `180`, top `Rect2(2400,290,180,gap_y-290)` + bottom
  `Rect2(2400,gap_y+GAP,180,1810-gap_y-GAP)`, `GAP:=420`, `gap_y ∈ [610,900,1190]` stepping `STEP:=1.5`. Wall
  spans `y 290..1810` so `grow(40)` stays clear of the edge bands (F5).
- **Bulwark** — `120×520` at `y=790..1310`, start `x=700`; patrol `x ∈ {700,1000,1300,1600,1900,2200,2500,2800}`
  (`±300`, lands exactly on the `2800` endpoint — F6), reverse at ends, every `STEP:=2.0`. Crosses the mid-field
  via moving-step edge-only safety + clip + connectivity (F5).
- **Drifting Cover** — 2 rects `260×180`, start `[(800,600),(2540,1320)]`; each `STEP:=2.0` picks a **random
  cardinal** offset from `{(+300,0),(-300,0),(0,+300),(0,-300)}` (F6). **Pairwise validation (F4-round10):** the
  step's candidate set must have the **two blocks non-overlapping** (each grown by the inflation); if they'd
  intersect, reroll the offset (a few tries) or skip that block's move. Skip if `rebuild_obstacles` rejects.
- **Shifting Maze** — `220×220` slots, cols `x=[560,1040,2560,3040]` × rows `y=[520,1050,1580]` (12 slots, all
  clear of the center box by x). `up_parity` toggles each `STEP:=2.5`; slot(ci,ri) is up iff
  `(ci+ri)%2 == up_parity` (checkerboard flip — F6) → one `rebuild_obstacles(up_set)`.

Charges go straight (physics-stopped). **Acceptance:** ≥60fps @200 through a forced moving-cover transition
(§1, F9); cover blocks shots; clip guard prevents pop-under; **connectivity revert + stranded-enemy relocation
prevent trapping / room-clear soft-lock** (F1/F7); telegraph-then-snap reads clearly.

---

## 9. Notes
- Canonical tree `D:\GameDev\Project_Twin_stick` on `v4/class-system`; parallel Codex may edit — re-read first.
- Validate + commit **per phase/slice**; **don't push unless asked.** All numbers first-pass, playtest-tuned.
- **Definition of Done (per phase + the final integration slice) — `docs/process/solo-dev-rules.md`:** after a
  phase's code validates, **update `docs/development/current-state.md` and create-or-append the current date's
  `docs/development/history/<date>.md` entry** recording what shipped (F5-round8; **append** if the date file
  already exists — multiple phases can land the same day, F5-round9). Not optional — part of each phase's acceptance.
- **All six phases are implementation-ready** (Rev 3, §§2–8b). Phase 4's outcome is empirical (a perf number);
  its failure branch is bounded to instrumentation + a plan amendment (§7).
- New files: `scripts/arena/ArenaMechanic.gd` (base) + one `<X>Mechanic.gd` per WHERE mechanic.
- Deferred: **Elites archetype** (needs non-champion elite IDs — F4); new ranged types (lobber/sniper);
  boss/champion swarm-separation; ranged LOS/cover.
