# CoopManager Decomposition Plan (for Codex)

Status: PROPOSED — not started. Author handoff from a stability audit on `v3/structure-rework`
(2026-06-24). Read this whole file before touching code. It is self-contained on purpose.

## 1. Why this exists

`scripts/game/CoopManager.gd` is a 3396-line god-object with 224 functions and ~70 fields. It is the
single highest-churn, highest-risk file in the project — the last real runtime bug (Hive permanent
invincibility) and most future ones live here. The rest of the codebase audited clean and defensive.

Goal: break `CoopManager` into cohesive, separately-reasoned modules **without changing runtime
behavior**. This is a pure structural refactor. No gameplay, tuning, or balance changes. The bundled
Phase 0 cleanups are the only behavior-adjacent edits, and they are tiny and clearly scoped.

Non-goal: rewriting systems, changing the per-room recreation model, or touching `Enemy.gd` /
`Player.gd` internals. Where this plan says "extract", it means **move code, keep behavior**.

## 2. Hard constraints — read these first

These are the rules that keep the refactor safe. Violating any of them is a regression.

### C1. CoopManager MUST remain the `_combat_owner` facade
`Enemy.setup(type, combat_owner)` (`scripts/enemies/Enemy.gd:232`) stores CoopManager as
`_combat_owner` and **duck-types** calls against it, e.g.:
`_combat_owner.has_method("spawn_enemy_shockwave")`, `apply_enemy_support_aura`,
`spawn_enemy_hazard_zone`, `spawn_enemy_minions`, `spawn_champion_deflector_minions`,
`handle_enemy_charge_windup`, `handle_enemy_death_explosion`, `spawn_enemy_homing_orbs`,
`get_nearby_enemy_target_nodes`, `get_enemy_target_nodes`, `get_player_target_nodes`, `get_arena_rect`.

Therefore every public `spawn_enemy_*` / `schedule_enemy_*` / `get_*_target_nodes` method must still exist
**on CoopManager with the same name and signature**. When their bodies move into a sub-system, leave a
one-line delegator on CoopManager (`return _combat_effects.spawn_enemy_shockwave(...)`). Do NOT repoint
`Enemy._combat_owner` at a sub-node. **Zero edits to `Enemy.gd` in the decomposition itself (Phases 1–4).**
The only exception is the optional Phase 0 cleanup T0c, which is a pre-refactor behavior tweak, not part
of the structural move — see the explicit note in §4 Phase 0.

Other external callers of CoopManager's public API to preserve identically:
- `scripts/ui/RunFlow.gd`: `configure_players`, `configure_room`, and the signals
  `room_cleared`, `all_players_dead`, `return_to_menu_requested` (also `player_downed`, `player_revived`).
- `scripts/dev/PerfRunner.gd` / `ProfilingHarness.gd`: any methods they call (verify before each task).
- Ability/projectile callbacks wired via signals in `_spawn_players` / `_rebuild_player_loadouts`.

### C2. Extraction pattern = child Node sub-systems owned by CoopManager
Use child `Node` (or `Node2D` where it needs world space) sub-systems, created in CoopManager's `_ready`
and added under the GameWorld root (or the relevant container). Each holds a typed back-reference to its
owner set right after construction (e.g. `_coop = self`). Rationale:
- They are freed automatically when GameWorld is freed each room (matches the existing lifecycle —
  "Health resets each room because CoopManager / GameWorld is recreated").
- A sub-system that needs per-frame work exposes an explicit `tick(delta)` that CoopManager calls from
  `_physics_process` in the existing order. Do NOT give sub-systems their own `_physics_process` in the
  first pass — keeping one pump point in CoopManager preserves exact update ordering. Update order is the
  main behavior risk; preserve it exactly. The current `_physics_process` (`CoopManager.gd:1257`) order,
  which extracted `tick(delta)` calls must reproduce verbatim, is:
  1. `_update_grid_pulse(delta)` — **runs BEFORE the early-returns below** (grid keeps pulsing while
     paused or while a mutation pick is open). T4 (ArenaVisuals) must keep its tick at this position.
  2. early-return if `_awaiting_mutation_pick`.
  3. early-return if `_game_paused or pause_panel.visible or get_tree().paused`.
  4. `_room_elapsed += delta` — **`_room_elapsed` is a SHARED room clock and stays owned by CoopManager**
     (do not move it into any sub-system). It is read by `WaveDirector` (room duration, T6) and by
     `CombatEffects` scheduled effects (`trigger_at = _room_elapsed + delay`, T10). Expose
     `CoopManager.get_room_elapsed()` and have those systems read it; never give a system its own copy.
  5. `_update_screen_atmosphere()`
  6. `_update_scheduled_enemy_shockwaves()`
  7. `_update_scheduled_player_shockwaves()`
  8. `_update_scheduled_enemy_hazards()`
  9. `_update_scheduled_pulsar_emps()`
  10. `_update_homing_projectiles(delta)`
  11. `_update_side_objectives(delta)`
  12. `_update_hazards(delta)`
  13. `_update_revives(delta)`
  14. `_clamp_runtime_nodes()`
  15. `_check_wave_progress()` — **this is where spawning happens** (boss spawn → `_continuous_spawn()`
      → room-clear check), i.e. spawning runs LATE, after objectives/hazards/revives, not first.
  16. `_update_beam_visual_timeouts(now)`
  17. throttled `_refresh_hud()` (gated by `_next_hud_refresh_at` / `HUD_REFRESH_INTERVAL`).
  18. `_update_player_combat_indicator_positions()`
- For pure/stateless helpers (formatting, geometry, color), prefer a `class_name`-less static util script
  (`const Fmt = preload(...)`) instead of a node — no back-reference, lowest risk.

### C3. One task = one commit = one validation pass
Each task below is independently shippable. After each task:
1. `git diff --check` clean.
2. Headless parse:
   `& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit`
3. Bootstrap boot smoke:
   `& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' res://scenes/ui/Bootstrap.tscn --quit`
4. A PerfRunner champion run (exercises the combat-owner API + spawning):
   `& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=champion:hive --players=2 --build=heavy`
   — Hive specifically exercises deflectors, minions, hazard zones, and the support-aura path.
Commit only after all four pass. Never leave a half-extracted state across a commit boundary.

### C4. Parallel-Codex collision protocol
The user sometimes runs Codex in this same working tree concurrently. EVERY task in this plan edits
`CoopManager.gd`, so these tasks **cannot run in parallel with each other or with any other CoopManager
edit**. Before starting a task: `git status` must be clean and no other agent may be mid-edit on
`CoopManager.gd`, `Enemy.gd`, or `GameWorld.tscn`. Do tasks strictly in sequence. If a collision is
detected mid-task, stop and resync rather than force a merge.

### C5. Behavior parity bar
This refactor must be a no-op at runtime. If a task cannot be done without a behavior change, STOP and
flag it instead of guessing — surface the decision rather than silently altering behavior.

## 3. Target module map (end state)

CoopManager shrinks to an orchestrator: lifecycle (`configure_*`, `_ready`, `_start_room`,
`_physics_process` pump, room-clear/fail resolution), the `_combat_owner` facade delegators, and shared
accessors (`get_active_players`, `get_arena_rect`, target-node queries). Extracted modules:

| Module (new file)                         | Owns                                                                 | Approx funcs |
|-------------------------------------------|----------------------------------------------------------------------|--------------|
| `CoopFormat.gd` (static util)             | name/text formatting, color helpers, `rarity_rank`                   | ~11          |
| `EnemyTypes.gd` (static util)             | champion classifiers (`is_champion`, `champion_enemy_id`)            | ~2           |
| `ArenaGeometry.gd` (static util)          | spawn-position math, spread directions, segment distance             | ~8           |
| `ProjectileSystem.gd` (Node)              | projectile pool, beams, homing, split, projectile VFX                | ~16          |
| `ArenaVisuals.gd` (Node2D)                | floor grid, walls, arena color, grid pulse                           | ~10          |
| `GameHud.gd` (Node)                       | HUD build/refresh, objective panel, bottom HUD, combat indicators    | ~30          |
| `WaveDirector.gd` (Node)                  | spawn cadence/scaling, wave progress, boss spawn, spawn positions    | ~22          |
| `SideObjectiveController.gd` (Node)       | hold/kill-streak/collector objective state + orbs                    | ~13          |
| `MomentumTracker.gd` (Node)               | shared momentum gain/drop/tier/store/restore                         | ~9           |
| `MutationPickFlow.gd` (Node)              | pick UI, roll/reroll/skip UI state, option generation (NOT progression) | ~9        |
| `CombatEffects.gd` (Node2D)               | bodies of `spawn_enemy_*` / `schedule_*` / shockwave/hazard updates   | ~22          |
| `PauseDebugUi.gd` (Node)                  | pause panel, build overlay, debug overlay (debug-only)               | ~20          |

CoopManager keeps the thin `spawn_enemy_*`/`get_*_target_nodes` facade (per C1). Each facade method
delegates to whichever owner now holds its body — depending on the method that is `CombatEffects`,
`ProjectileSystem` (e.g. `spawn_enemy_homing_orbs`, whose state lives in the projectile pool), or
CoopManager's own accessors. Route each facade to the single module that owns the underlying state; do
not duplicate state across modules (e.g. homing-orb state stays in `ProjectileSystem`, never copied into
`CombatEffects`).

## 4. Sequenced tasks

Ordered by ascending entanglement / collision risk. Do them in order. Each is bounded; do not bundle.

### Phase 0 — Audit cleanups (tiny, do first)
These come from the 2026-06-24 stability audit and are safe to land before the refactor.

- **T0a — Remove dead structured/endless leftovers in `RunState.gd`.**
  Confirm no live callers first (`grep` the repo), then remove/inline: `run_mode = "structured"`
  (`scripts/game/RunState.gd:30,66`), `is_easy_mode()` (always false, line 119), `is_run_complete()`
  (always false, line 122). If any caller exists, leave the function and note it. Behavior parity: these
  already return constants, so removal is a no-op for real branches.
- **T0b — `ProfileState.is_unlocked` unknown-id warning.**
  In `scripts/meta/ProfileState.gd:127`, when `_find_unlock_index(unlock_id) < 0`, keep returning `true`
  (preserve the unlocked-by-default contract) but add a `push_warning("Unknown unlock id: %s")` so typo'd
  `kind:content_id` ids are visible in logs. Pure diagnostic, no behavior change.
- **T0c — Hive deflector timer defensive tick (optional). This is the ONE task in this file that edits
  `Enemy.gd`, and it is explicitly exempt from the C1 "zero edits to `Enemy.gd`" rule** (that rule governs
  the Phases 1–4 structural move, not this pre-refactor cleanup). The deflector respawn + vulnerable-window
  bookkeeping lives only in `_update_hive_behavior` (`scripts/enemies/Enemy.gd`), which is skipped when
  `_target == null`. Benign today. If done, advance the timer outside the target-gated branch so it cannot
  stall transiently. Behavior-adjacent — only do if it can be proven not to widen/narrow the existing 6s
  window. Otherwise skip and leave the audit note. If you prefer a hard wall between cleanup and refactor,
  split T0c into its own one-commit change reviewed separately before Phase 1.

### Phase 1 — Stateless util extractions (no back-refs, lowest risk)

- **T1 — `CoopFormat.gd` static util.** Move only genuinely pure formatting/color funcs out of CoopManager:
  `_format_room_type`, `_format_boss_type`, `_format_modifier_display_name`, `_format_buff_name`,
  `_get_modifier_chip_color`, `_overbright_color`, `_get_slot_color`, and `_rarity_rank` (a pure
  rarity→int map). Replace call sites with `CoopFormat.xxx(...)`. These take plain args/return values —
  pass needed state in rather than reaching back (e.g. `_format_room_type` takes the room-type string as
  an argument instead of reading `_room_type`). Note `_rarity_rank` has callers in three future modules —
  `_options_contain_rare` (T9), and `_create_mutation_chip` / `_compare_mutation_entries` (T11) — so it
  MUST be the static util, not duplicated; all of them call `CoopFormat.rarity_rank(...)`.

- **T1b — `EnemyTypes.gd` static util.** Move the pure champion classifiers `_is_champion_enemy_type` and
  `_champion_enemy_id` out of CoopManager (they do NOT belong on WaveDirector — see T6). Stateless,
  callable from any module. Replace call sites with `EnemyTypes.is_champion(enemy_type)` /
  `EnemyTypes.champion_enemy_id(...)`. Callers span WaveDirector (T6), CoopManager death/VFX logic
  (`_on_enemy_died`, `_spawn_enemy_death_global_vfx`), and debug spawn (T11).
  **Do NOT move `_format_objective_text` or `_build_side_objective_text` here** — despite their names they
  are NOT pure: they read live side-objective state (`_side_objective_id`, `_side_objective_completed`,
  `_kill_streak_progress`/`_kill_streak_target`, `_collector_collected`, `_hold_zone`, `_hold_buff_offer`).
  They are HUD-facing objective formatters and are handled under T5/T7 (see T5's side-objective accessor
  note).

- **T2 — `ArenaGeometry.gd` static util.** Move spawn-position + geometry math:
  `_get_enemy_spawn_position_for_edge`, `_get_enemy_spawn_position_for_index`, `_build_spread_directions`,
  `_distance_to_segment`, and the arena-rect-derived helpers that take coordinates only. Keep the
  CoopManager wrappers that read instance state (`_get_enemy_spawn_position`, `_get_player_spawn_position`)
  thin, delegating into `ArenaGeometry` with `ARENA_RECT`/margins passed in.

### Phase 2 — Leaf stateful systems (child nodes, clear boundaries)

- **T3 — `ProjectileSystem.gd` (Node).** Move the projectile pool + beam + homing + split machinery and
  the fields `_projectile_pool`, `_active_projectiles`, `_active_homing_projectiles`, `_beam_states`,
  `_projectile_renderer`. Funcs: `_ensure_projectile_renderer`, `_activate_projectile`,
  `_acquire_projectile`, `_on_projectile_split_requested`, `_on_projectile_deactivated`,
  `_cleanup_active_projectiles`, `_should_suppress_combat_vfx` (called by `_on_projectile_impact`; it calls
  `_cleanup_active_projectiles()` and reads `_active_projectiles`, both T3-owned — but also reads
  `_enemy_nodes`, which stays shared, so read the enemy count via the owner back-ref / a
  `CoopManager.get_enemy_count()` accessor, do not copy `_enemy_nodes` into ProjectileSystem),
  `_process_beam_fire`, `_update_beam_*` (3), `_update_homing_projectiles`,
  `_on_projectile_impact`, `_spawn_projectile_hit_effect`, and `spawn_enemy_homing_orbs`
  (`CoopManager.gd:2035`, which appends to `_active_homing_projectiles`). CoopManager keeps
  `_on_player_fire_requested` and `_on_enemy_fire_requested` as the entry points (they’re wired to
  player/enemy signals) but delegates the body. **`spawn_enemy_homing_orbs` is part of the C1 combat-owner
  facade — its body moves here, but a same-signature delegator MUST remain on CoopManager** so
  enemy/champion callers still reach it. Pump beams/homing via `_projectiles.tick(delta)` at position 10
  in the §2 order.

- **T4 — `ArenaVisuals.gd` (Node2D).** Move `_rebuild_arena`, `_rebuild_floor_grid`,
  `_add_arena_wall_visuals`, `_build_grid_line`, `_apply_arena_color`,
  `_apply_collision_bounds_from_floor`, `_set_wall_rect`, `_update_grid_pulse`, `_get_grid_player_glow`,
  and field `_grid_pulse_time`. It needs read access to living player positions (via `get_active_players()`).
  Grid pulse ticks from the existing `_physics_process` call site.

  **Setup-node contract (don't under-list).** `_rebuild_arena()` (`CoopManager.gd:879`) touches MORE than
  the grid/walls: it sets `floor_visual.polygon`, then configures `exit_zone` (position),
  `exit_zone_shape` (new `RectangleShape2D` + size), `exit_zone_visual` (visibility), and `camera`
  (`set_arena_rect(ARENA_RECT)` + `global_position = ARENA_CENTER`). Either pass ALL of those node refs
  (`floor_visual`, `floor_grid`, the four `ArenaBounds` walls, `exit_zone`, `exit_zone_shape`,
  `exit_zone_visual`, `camera`) into ArenaVisuals on setup, OR keep the exit-zone + camera lines in
  CoopManager and let ArenaVisuals own only the floor/grid/wall/collision rebuild. Pick one explicitly;
  do not leave `_rebuild_arena` half-moved with dangling node references.

- **T5 — `GameHud.gd` (Node under UI layer).** The largest single chunk but well-isolated (reads run/room
  state, writes UI). Move `_build_hud`, `_build_objective_panel`, `_create_hud_trigger_label`,
  `_apply_progress_bar_tint`, `_refresh_hud`, `_refresh_boss_hud`, `_refresh_objective_panel`,
  `_get_objective_*` (icon/title/progress) (4), `_update_player_combat_indicators`,
  `_update_player_combat_indicator_positions`, `_refresh_bottom_hud`, `_refresh_momentum_pips`,
  `_update_slot_charge_label`, `_populate_modifier_hud`, `_build_room_status_text`,
  and all HUD fields (`_hud_root`, labels, bars, `_bottom_*`, `_objective_*`,
  `_player_combat_indicators`, `_modifier_hud`, etc.). **Do NOT move `_build_clear_summary()`** — despite
  the name it is not HUD-owned: it reads side-objective state (`_side_objective_id`,
  `_side_objective_completed`, `_hold_buff_offer`) and is called from `_handle_room_clear()`
  (`CoopManager.gd:1482`) into `_pending_clear_summary` before reward progression. Leave it on CoopManager
  until T7, then move it to `SideObjectiveController` (it belongs with that state, not the HUD).
  CoopManager calls `_hud.refresh()` /
  `_hud.refresh_boss()` on the existing `HUD_REFRESH_INTERVAL` cadence. Keep `_boss_health_bar`
  ownership wherever the boss HUD lives today; verify the throttle (`_next_hud_refresh_at`) still gates it.

  **HUD reads spawn state through accessors — introduce them in THIS task (T5), before T6 exists.**
  `_build_room_status_text()` (`CoopManager.gd:2387`) reads `_room_duration`, `_spawning_done`, and
  `_enemy_nodes.size()` — all of which T6 later moves into WaveDirector or keeps shared. So GameHud must
  read them via `CoopManager.get_room_duration()`, `CoopManager.is_spawning_done()`, and
  `CoopManager.get_enemy_count()` (plus `get_room_elapsed()` from §2) from the moment it is extracted. At
  T5 those accessors return CoopManager's own fields; at T6 their bodies are repointed at WaveDirector
  WITHOUT changing the accessor signatures, so GameHud's call sites never break. `_refresh_boss_hud()`
  similarly reads the active boss via `CoopManager.get_active_boss()` (see T6's boss contract), not a
  direct field.

  **Same pattern for side-objective state.** GameHud also owns the objective-text formatters
  `_format_objective_text` and `_build_side_objective_text` (moved out of T1 — they are stateful, not pure)
  alongside `_get_objective_*` and `_refresh_objective_panel`. These read `_side_objective_id`,
  `_side_objective_completed`, `_kill_streak_progress`/`_kill_streak_target`, `_collector_collected`, and
  `_hold_zone` (`CoopManager.gd:2435`+). Introduce stable side-objective READ accessors on CoopManager at
  T5 (e.g. `get_side_objective_id()`, `is_side_objective_complete()`, `get_objective_progress_text()` or a
  single `get_side_objective_view()` dict). At T5 they return CoopManager's own fields; at T7 their bodies
  repoint to `SideObjectiveController` with unchanged signatures, so the HUD never breaks.

### Phase 3 — Core gameplay systems (more entangled; careful, still no behavior change)

- **T6 — `WaveDirector.gd` (Node).** Spawn cadence + scaling + progress + boss. Funcs: `_continuous_spawn`,
  `_spawn_opening_burst`, `_spawn_enemy_instance`, `_queue_enemy_spawn`, `_spawn_queued_enemy_instance`,
  `_spawn_boss`, `_roll_wave_enemy_type`,
  `_check_wave_progress`, `_scale_spawn_count`, `_consume_scaled_stream_count`, `_get_enemy_count_multiplier`,
  `_get_room_duration`, `_get_spawn_interval`, `_get_champion_spawn_delay`, `_get_burst_interval`,
  `_get_burst_size`, `_get_champion_spawn_position`, the enemy spawn-position wrappers, and spawn-tracking
  fields (`_room_duration`, `_spawn_interval`, `_next_spawn_at`, `_next_burst_at`,
  `_enemies_spawned`, `_pending_enemy_spawns`, `_spawning_done`, `_boss_spawned`, `_active_boss`, etc.).
  **Do NOT move `_room_elapsed`** — it stays on CoopManager as the shared room clock (see §2 step 4);
  WaveDirector reads it via `CoopManager.get_room_elapsed()`.
  This owns spawn timing — preserve the exact `_physics_process` ordering and the room-clear trigger
  (`_handle_room_clear` stays on CoopManager; WaveDirector reports "spawning done + all dead").

  **`_enemy_nodes` is single-owned by CoopManager — WaveDirector never holds a second enemy list.**
  Today `_spawn_enemy_instance()` (moving here) appends `_enemy_nodes`, but `_on_enemy_died()` (stays on
  CoopManager, `CoopManager.gd:2216`) erases it. Splitting that list would desync spawn count from death
  removal. Rule: keep `_enemy_nodes` on CoopManager; WaveDirector registers each spawned enemy via
  `CoopManager.register_enemy(node)` and reads liveness via `get_enemy_count()` / `is_enemy_list_empty()`
  (these back the `get_enemy_count()` accessor T3/T5 already rely on). `_check_wave_progress()`'s
  "all dead" test uses those accessors, not a local list.

  **C1 trap — `enemy.setup(...)` must still pass the CoopManager facade, not WaveDirector.**
  `_spawn_enemy_instance()` currently calls `enemy.setup(enemy_type, self)` (`CoopManager.gd:1377`); after
  this body moves into WaveDirector, `self` would be the WaveDirector, which would break C1 (Enemy
  duck-types its `_combat_owner` against the `spawn_enemy_*` facade). The moved body MUST call
  `enemy.setup(enemy_type, _coop)` (the CoopManager back-ref). Likewise the three enemy signal connections
  in that body (`enemy_died → _on_enemy_died`, `fire_requested → _on_enemy_fire_requested`,
  `hit_received → _on_enemy_hit_received`) connect to the CoopManager handlers (`_coop._on_enemy_died`,
  etc.), which stay on CoopManager — do not relocate those callbacks. And the registration uses
  `_coop.register_enemy(enemy)` per the `_enemy_nodes` rule above. The modifier flags the body reads
  (`_minor_modifier_flags` in the `apply_room_modifier` call) stay on CoopManager too; expose them via an
  accessor (e.g. `_coop.get_minor_modifier_flags()`) rather than copying them into WaveDirector.

  **`_active_boss` ownership needs an accessor + death-notification contract.** WaveDirector owns
  `_active_boss` and exposes `CoopManager.get_active_boss()` (delegating to it) for the external readers:
  boss entrance VFX (`_spawn_boss_entrance_vfx`, `CoopManager.gd:1967`), the boss HUD
  (`_refresh_boss_hud`, GameHud T5, `CoopManager.gd:2362`), and enemy death handling. Because
  `_on_enemy_died()` stays on CoopManager and currently nulls `_active_boss` when the boss dies
  (`CoopManager.gd:2218`, with a redundant second clear at 2243 — collapse to one), it must instead call
  `WaveDirector.clear_active_boss_if(enemy)` so the director drops the reference and no stale boss pointer
  survives in the HUD/VFX path. Acceptance: killing a champion clears the boss HUD on the same frame as
  today.

  **Spawn/queue need CoopManager-facing delegators — callers outside the wave loop stay.** Several
  non-wave call sites still drive enemy creation after `_spawn_enemy_instance()` / `_queue_enemy_spawn()`
  move here: splitter death queues minis (`_on_enemy_died`, CoopManager, `CoopManager.gd:2236`); the
  enemy-minion API spawns/queues (`spawn_enemy_minions` `CoopManager.gd:2847`, `spawn_enemy_minion_mix`,
  `spawn_enemy_burst` — all in CombatEffects, T10); and debug spawn (`_on_debug_spawn_pressed`,
  `CoopManager.gd:3187`, T11). Expose thin `CoopManager.spawn_enemy_instance(...)` and
  `CoopManager.queue_enemy_spawn(...)` delegators (same signatures) that forward to WaveDirector, and route
  every remaining caller through them. Do NOT let CombatEffects/debug reach into a private WaveDirector
  method directly.

  **`_is_champion_enemy_type` / `_champion_enemy_id` do NOT move to WaveDirector — they go to the Phase 1
  static util `EnemyTypes.gd` (T1b).** They are stateless (string in, bool/string out) and have callers
  spread across modules: WaveDirector spawn logic (T6), champion death VFX/XP/drop logic (`_on_enemy_died`
  `CoopManager.gd:2223`, `_spawn_enemy_death_global_vfx` `CoopManager.gd:1971`, stay on CoopManager), and
  debug spawn scaling (`CoopManager.gd:3188`, T11). Extracting them as a static util in Phase 1 makes them
  callable from every module with no back-ref or wrapper. Replace all call sites with
  `EnemyTypes.is_champion(enemy_type)` / `EnemyTypes.champion_enemy_id(...)`. (They are intentionally absent
  from the T6 function list above.)

- **T7 — `SideObjectiveController.gd` (Node).** `_setup_side_objective`, `_update_side_objectives`,
  `_complete_side_objective`, `_spawn_collector_orb`, `_cleanup_orbs`, and now `_build_clear_summary`
  (deferred here from T5 — it reads this module's side-objective state and `_hold_buff_offer`), plus
  hold/kill-streak/collector state fields, `_hold_zone`, `_temp_buff_system`, `_hold_buff_offer`. Reports
  completion back to CoopManager. `_handle_room_clear()` (which stays on CoopManager) calls
  `_side_objectives.build_clear_summary()` to populate `_pending_clear_summary` at the same point as today.

  **External event hooks must be preserved (timing-sensitive).** Kill-streak state is mutated from two
  CoopManager callbacks that STAY on CoopManager: `_on_enemy_died()` increments it and may complete the
  objective (`CoopManager.gd:2239`), and `_on_player_damage_taken()` resets it to 0
  (`CoopManager.gd:2283`). When this state moves into SideObjectiveController, add explicit forwarding calls
  `_side_objectives.on_enemy_killed()` and `_side_objectives.on_player_damaged()` from those exact call
  sites, in the same order relative to the surrounding logic (e.g. `on_enemy_killed()` after
  `_enemies_killed += 1` / momentum, matching today's sequence). The completion side-effect
  (`_complete_side_objective` when streak target is hit) must fire from inside the hook, same frame as now.
  Also repoint the T5 side-objective READ accessors to this module here (T7) without changing signatures.

- **T8 — `MomentumTracker.gd` (Node).** `_restore_momentum`, `_gain_shared_momentum`,
  `_drop_player_momentum`, `_update_momentum_tier`, `_on_momentum_tier_gained`, `_store_momentum`,
  `_apply_momentum_to_player`, `_get_min_progress_for_momentum_tier`, plus `_momentum_*_by_player` and
  `_room_max_momentum_tier`. Note it reads/writes `RunState` momentum persistence — keep that contract.
  **Scoring dependency:** `_build_room_score_delta()` (`CoopManager.gd:2338`) reads `_room_max_momentum_tier`
  in its `... + _room_max_momentum_tier * 50` term, and `_record_room_score()` runs on BOTH room clear and
  party wipe. Scoring stays on CoopManager, so expose `MomentumTracker.get_room_max_tier()` and have
  `_build_room_score_delta()` call it. Acceptance check: the score delta must be byte-for-byte identical
  before/after on both a cleared room and a wipe (verify `clear_credit + kills + champion_kills*250 +
  room_max_tier*50` is unchanged in both paths).

- **T9 — `MutationPickFlow.gd` (Node).** Owns the pick UI/roll/reroll/skip ONLY; room-progression
  decisions and the runtime gate stay on CoopManager. This is the most entangled of the Phase 3
  extractions — draw the boundary exactly as below.

  **Moves to MutationPickFlow:** `_show_mutation_pick`, `_roll_initial_mutation_options_for_player`,
  `_roll_reroll_mutation_options_for_player`, `_reset_mutation_pick_reroll_counts`,
  `_build_mutation_pick_reroll_costs`, `_get_mutation_pick_reroll_cost`, `_on_mutation_reroll_requested`,
  `_on_mutation_skip_requested`, `_options_contain_rare` (which calls `_rarity_rank` — that dependency is
  now `CoopFormat.rarity_rank(...)` from T1, so no rank logic is duplicated here), the `MutationPickUI`
  instance + its signal wiring,
  and the pick-UI fields `_mutation_pick_ui`, `_mutation_pick_reroll_counts`,
  `_mutation_pick_round_force_rare`.

  **Stays on CoopManager** (room-progression state machine + runtime gate): `_show_progression_pick_if_needed`,
  `_on_mutation_selections_confirmed`, `_finish_room_progression`, `_rebuild_player_loadouts`, and the
  progression flags `_pending_pick_consumes_levelup`, `_pending_champion_bonus_pick`, `_pending_clear_summary`.

  **Runtime-gate contract (`_awaiting_mutation_pick`).** KEEP this flag on CoopManager — it is a pump/input
  gate (sibling of `_game_paused`), checked at §2 step 2 (`_physics_process`, `CoopManager.gd:1259`) and in
  `_unhandled_input` (`CoopManager.gd:3157`). MutationPickFlow flips it via `CoopManager.set_awaiting_pick(true)`
  when a pick opens and `set_awaiting_pick(false)` when it resolves, preserving the exact position of both
  gates. Do not move the flag into MutationPickFlow and do not read it through a back-ref in the hot pump.

  **Confirm/continuation callback contract.** The `MutationPickUI` confirm signal routes into CoopManager's
  `_on_mutation_selections_confirmed(selections)` (which stays), reproducing today's sequence verbatim:
  (1) apply each player's mutations via `_mutation_system`; (2) `RunState.spend_levelup()` if
  `_pending_pick_consumes_levelup`; (3) free the pick UI + `set_awaiting_pick(false)`; (4)
  `_rebuild_player_loadouts()`; (5) the branch ladder — more pending level-ups →
  `_show_progression_pick_if_needed()`; champion room first resolve → champion-reward
  `MutationPickFlow.show_pick(true, "Champion Reward", …)`; champion-bonus done → `_finish_room_progression()`;
  pending level-ups → `_show_progression_pick_if_needed()`; else `_finish_room_progression()` (emits
  `room_cleared`). CoopManager drives this ladder and calls `MutationPickFlow.show_pick(...)` /
  `reset_reroll_counts()`; MutationPickFlow never decides progression.

  **Reroll score/HUD callback.** `_on_mutation_reroll_requested` spends shared `RunState.run_score` and must
  update the score HUD. After the spend, call `CoopManager.notify_run_score_changed()` (which refreshes the
  GameHud score display, T5) — do not let MutationPickFlow poke HUD nodes directly. Skip
  (`_on_mutation_skip_requested`) consumes the pick the same way it does today. Acceptance: a reroll that
  spends score updates both players' shared score display on the same frame as the current build.

### Phase 4 — Combat-owner API + debug (do last)

- **T10 — `CombatEffects.gd` (Node2D).** Move the BODIES of the enemy-facing combat API while keeping
  thin facade delegators on CoopManager (C1). Bodies: `spawn_enemy_shockwave`, `schedule_enemy_shockwave`,
  `_update_scheduled_enemy_shockwaves`, `_update_scheduled_player_shockwaves`, `schedule_enemy_hazard_zone`,
  `spawn_enemy_hazard_zone`, `_update_scheduled_enemy_hazards`, `spawn_enemy_minions`,
  `spawn_enemy_minion_mix`, `spawn_enemy_burst`, `apply_enemy_support_aura`,
  `spawn_champion_deflector_minions`, `spawn_hive_shield_minions`, `spawn_pulsar_emp`,
  `schedule_pulsar_emp`, `_update_scheduled_pulsar_emps`, `handle_enemy_charge_windup`,
  `spawn_enemy_attack_trail`, `handle_enemy_death_explosion`, `_spawn_player_shockwave`,
  `_schedule_player_shockwave_resonance`, and the scheduled-effect fields
  (`_scheduled_enemy_shockwaves`, `_scheduled_player_shockwaves`, `_scheduled_enemy_hazards`,
  `_scheduled_pulsar_emps`). These scheduled lists read the shared `_room_elapsed` clock
  (`CoopManager.get_room_elapsed()`, see §2 step 4) — do not give CombatEffects its own clock.

  **Player-shockwave callers stay on CoopManager.** `_spawn_player_shockwave` /
  `_schedule_player_shockwave_resonance` are private (not part of the C1 enemy facade) but are invoked from
  `_on_player_ability_activated()`'s `"shockwave"` branch (`CoopManager.gd:1762-1763`), which stays on
  CoopManager (it also touches the shared `_active_decoys`/`_turrets`/`_orbits` lists). Have that branch
  call `_combat_effects.spawn_player_shockwave(...)` / `_combat_effects.schedule_player_shockwave_resonance(...)`
  directly (the child is CoopManager-owned, so no extra wrapper is needed); if you prefer symmetry with the
  enemy facade, add private CoopManager wrappers instead. Either way, preserve the call order: flash + SFX,
  then shockwave, then resonance schedule, exactly as today.

  **Runtime-node lifecycle stays shared on CoopManager.** `spawn_enemy_hazard_zone()` appends
  `_active_hazards` (`CoopManager.gd:2835`), and `_update_hazards()` (pump step 12) ticks that list AND
  calls `_cleanup_helpers()`, which also sweeps `_active_decoys` / `_active_turrets` / `_active_orbits` /
  `_active_mines` — lists fed by player abilities and modifiers, not just enemy effects. To avoid splitting
  that cleanup, KEEP `_active_hazards` (and the other `_active_*` helper lists), `_update_hazards()`,
  `_cleanup_helpers()`, `_cleanup_instance_array()`, and `_clamp_runtime_nodes()` on CoopManager as shared
  runtime bookkeeping. CombatEffects' `spawn_enemy_hazard_zone()` body registers its spawned node via a
  CoopManager accessor (e.g. `register_hazard_zone(node)`) instead of holding its own list. The pump keeps
  calling `_update_hazards(delta)` at step 12 unchanged.

  Validate hard with the `champion:hive` PerfRunner run (C3 step 4) — this is the contract Enemy.gd
  depends on.

- **T11 — `PauseDebugUi.gd` (Node, debug-only, optional).** Pause panel + build overlay + debug overlay:
  `_set_game_paused`, `_set_runtime_pause_state`, `_build_debug_overlay`, `_on_debug_*` (5),
  `_populate_pause_build_overlay`, `_create_build_ability_card`, `_create_mutation_chip`,
  `_toggle_debug_overlay`, `_ensure_debug_overlay_action`, `_open_encyclopedia_overlay`, and debug fields.
  Lowest gameplay risk; lowest priority.

  Status: completed on `v3/structure-rework` as `PauseDebugUi.gd`. `CoopManager.gd` now keeps the runtime
  lifecycle callbacks and exposes pause/runtime/loadout accessors for the helper.

## 5. After each phase

Update all three of:
- `docs/development/current-state.md` "UI / Tooling" section (CoopManager's new ownership boundaries).
- `docs/process/architecture.md` — this refactor changes runtime ownership boundaries, so the module map
  there must reflect each sub-system as it becomes real (not just at the end).
- A dated entry under `docs/development/history/` describing what moved and confirming behavior parity plus
  the four validations.

Do not mark the rework "done" until CoopManager is an orchestrator and the four validations pass on the
final task.

## 6. Risks & rollback

- **Update-order regressions** (highest risk): the single `_physics_process` pump order is load-bearing.
  Mitigation: one pump point in CoopManager (C2); never move a system to its own `_physics_process` in the
  first pass; diff the call order before/after.
- **Combat-owner contract drift** (C1): mitigated by keeping facade delegators and the `champion:hive`
  validation every task in Phases 2–4.
- **Parallel-Codex collisions** (C4): strict serialization; clean `git status` gate per task.
- **Rollback**: each task is one commit. Revert the single commit to undo. Never squash across tasks until
  the whole rework is validated and approved.
