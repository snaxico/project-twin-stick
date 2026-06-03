# Playtest Round 4 — Implementation Plan

Historical plan. The current stable `v3/main` baseline also includes the round-5 patch,
so use `playtest-round-5-plan.md` and `playtest-round-5-validation.md` for the build
currently awaiting playtest.

## Context

Fourth playtest of `v3/main` (2026-06-02), after round-3 fixes landed. Fourteen findings. Two notable: #1 and #8 are about features built in earlier rounds (the round-2 level-up VFX is now considered irritating; the round-2/3 deferred settings menu is now wanted).

Target branch: `v3/main` in `D:\GameDev\Project_Twin_stick`. Player max HP 50, base move speed 488 (round 3), base weapon fire_rate 4.0 (round 3).

Plan lives in `docs/development/` only (no `.claude/plans` mirror per user preference).

## Revision history

- **v1** initial plan.
- **v2** (this revision) — code review corrections:
  - **F11** stale numbers: Fire Zone is already `ZONE_RADIUS := 240` / `_max_zones := 5` (not 180/5). Corrected target to radius **280** (genuinely bigger) + max **7**, and `margin` → ≥ radius (existing `margin := 200` already clips past the current 240 radius).
  - **F13** Minefield trigger plumbing: `AbilityMine.configure()` maps the passed `radius` only to `explosion_radius`; `trigger_radius` is hardcoded 52. Plan now adds a `trigger_radius` arg + the `CoopManager` call-site change.
  - **F7** Fire trail compile gap: `MutationSystem.get_compiled_weapon_stats` only compiles the 4 existing trail params; new `impact_pool_*` params must be added there or they never reach the projectile. Added `MutationSystem.gd` to files.
  - **F8** Settings scope: full input rebinding already lives in the main menu (`Bootstrap.gd`, `input_bindings.cfg`). Clarified pause Settings = the in-run legacy screen-effects/aim panel ONLY; rebinding stays a menu feature.
  - **F14** profiling order: split into Phase 0 (baseline profile on current `v3/main`, before any rework) and Phase 5 (optimize + re-measure), so the boss/elite/VFX additions don't contaminate the baseline.

## Decision summary (from `AskUserQuestion` panels)

| # | Decision |
|---|----------|
| 1 | Remove all level-up VFX |
| 2 | Blink: movement-dir + range 240→340 + ~0.2s arrival i-frames + detonation on arrival |
| 3 | Objective HUD: dedicated styled panel (icon + label + progress bar) |
| 4 | Kill streak: true streak (consecutive kills, resets on damage), fixed target |
| 5 | Elites: fix spawn overlap + telegraphed attack patterns + raise threat (kiting not free) |
| 6 | Overcharge: buff baseline toward it, reduce Overcharge to milder spike |
| 7 | Fire trail mutation: trail along path AND bigger pool on impact |
| 8 | Settings: wire up legacy `UI/SettingsPanel` + gamepad nav + Back |
| 9 | Bosses: multi-phase HP-gated + per-boss rebalance + adds + telegraphed heavy attacks |
| 10 | Enemy projectile color: visual fix (red core + red outline), not a per-path color bug |
| 11 | Fire zone: more (max 7) AND bigger (radius 280) |
| 12 | **Deferred** — keep prototype art |
| 13 | Turret + mines buffed (see F13) |
| 14 | Profile + pool projectiles + time-slice AI |

---

## Fix F10 — Enemy projectiles render red (visual fix)

**Root cause (confirmed):** The data layer already unifies enemy projectile color. `CoopManager._on_enemy_fire_requested` (line 1164-1173) ignores the per-enemy `_color` arg and forces `ENEMY_PROJECTILE_COLOR = Color(1.0, 0.0, 0.0, 1.0)` (`CoopManager.gd:48`). The only enemy `fire_requested.emit` is `Enemy.gd:720`, routed through that handler. So the bug is **not** divergent colors per spawn path.

The real problem is in `Projectile._apply_visual_state` (`scripts/weapons/Projectile.gd:250-269`):
- Enemy core: `visual.color = projectile_color.lightened(0.18)` (line 258) → washes pure red toward pink.
- Enemy **outline is hardcoded near-white**: `Color(1.0, 0.94, 0.88, 0.92)` (line 267) → the dominant visible color is cream/white, not red.

**What to change (`Projectile.gd:257-267`):**
- Enemy core: stop lightening, or lighten far less — use `projectile_color` directly or `projectile_color.lightened(0.05)`.
- Enemy outline: replace the hardcoded near-white with a red-derived outline, e.g. `projectile_color.darkened(0.25)` or a deep red `Color(0.55, 0.0, 0.0, 0.95)`.
- Goal: enemy bullets read as unmistakably red at a glance, distinct from the warm/pale player bullets.
- Leave the player-shot branch (`else`) unchanged.

**Files:** `scripts/weapons/Projectile.gd`

---

## Fix F1 — Remove level-up VFX

**Problem:** The round-2 level-up VFX (`CoopManager._on_level_up`, line 1151-1162: per-player ring + burst + gold screen flash) reads as "an ability fired with no effect." User wants it gone entirely.

**What to change:**
- Delete the body of `_on_level_up` (or remove the function) — no ring, no burst, no screen flash.
- Remove the connection in `_ready` (`CoopManager.gd:178-180`).
- Leave the `RunState.level_up` signal definition in place (harmless, no listeners) — avoids touching `RunState.gd`. If preferred for cleanliness, the signal + its `emit` in `add_xp` can also be removed, but it's optional.

**Files:** `scripts/game/CoopManager.gd`

---

## Fix F11 — Fire Zone modifier: more and bigger

**Current state (verified):** `FireFloorModifier.gd` already has `ZONE_RADIUS := 240.0` (line 9) and `_max_zones := 5` (line 15) — NOT the 180/5 the round-2 plan assumed. So "bigger" must go **above 240**, and the previously-suggested 220 would *shrink* the hazard. Also `margin := 200.0` (`_spawn_zone`, line 49) is already **smaller** than the current radius, so zones can clip past the arena edge.

**What to change (`scripts/modifiers/FireFloorModifier.gd`):**
- `ZONE_RADIUS`: 240 → **280** (genuinely bigger than current).
- `_max_zones`: 5 → **7** (more concurrent).
- `SPAWN_INTERVAL`: 2.8 → ~**2.4** so 7 zones fill in faster.
- `margin` in `_spawn_zone`: 200 → **≥ ZONE_RADIUS** (i.e. ≥ 280; use 290). Fixes the existing clip-past-edge issue and keeps the larger zones inside the 4800×2700 arena (plenty of room).
- Note `setup()` opens with two `_spawn_zone()` calls — fine, just starts at 2 of 7.

**Files:** `scripts/modifiers/FireFloorModifier.gd`

---

## Fix F5 — Elite rework (spawn fix + threat + attack patterns)

**Problems:**
- (a) Spawn overlap: `_spawn_elite_miniboss` (`CoopManager.gd:854-857`) spawns at `ARENA_CENTER + Vector2(randf_range(-240,240), randf_range(-120,120))`, which overlaps the player spawn box `ARENA_CENTER ± (80,60)` (`_get_player_spawn_position`, line 1722-1725). Players can spawn on top of an elite.
- (b) Elites feel weak — player can kite freely; their attacks don't pressure. (e.g. `elite_charger` has 1440 HP but isn't threatening — a long, boring damage sponge.)

### Part A — Fix spawn placement
- Spawn elites at a min distance from ALL player spawn points. Simplest: spawn on the opposite side of the arena from `ARENA_CENTER`, or pick a random arena-edge-ish point ≥ 600px from every player spawn position. Reuse `_get_enemy_spawn_position()` logic (edges) rather than the center box.

### Part B — Raise threat + attack patterns (in `Enemy.gd`)
- Audit elite configs (`elite_charger` line 182, `elite_spitter` line 192, `elite_support` line 202). Goal: kiting should NOT be safe.
- Give each elite a telegraphed special attack on a cooldown:
  - **elite_charger:** longer, faster telegraphed charge that covers kiting distance; brief slam shockwave on arrival.
  - **elite_spitter:** burst projectile spread (fan) the player must dodge, not just single shots; lead the target.
  - **elite_support:** already spawns minions (round 1) — add a damaging pulse or buff aura so it's not ignorable.
- Rebalance HP DOWN where it's a slog (e.g. `elite_charger` 1440 is excessive), threat UP (damage/speed/attack frequency). Shorter, scarier fights.
- Pair with an elite-entrance telegraph (reuse boss-entrance VFX `_spawn_boss_entrance_vfx` or a lighter ring) so the player orients to the threat.

**Files:** `scripts/game/CoopManager.gd` (spawn placement, entrance VFX), `scripts/enemies/Enemy.gd` (elite behaviors + stats)

---

## Fix F9 — Boss rework (multi-phase, rebalance, adds, telegraphs)

**Problem:** Bosses are weak; Hydra mini-boss is easier than normal rooms. Current boss configs: warden 800 HP (line 212), hydra 600 HP stationary (line 222), hive 700 HP (line 232), pulsar 1000 HP (line 242).

**What to change (`scripts/enemies/Enemy.gd` boss behaviors + configs):**

### Part A — Per-boss HP/damage rebalance
- Audit each boss so none is trivially easy. Hydra especially (600 HP stationary turret) — raise HP and/or attack density.

### Part B — Multi-phase HP-gated patterns
- Each boss gets 2-3 phases at HP thresholds (e.g. 66%, 33%): more/faster attacks, new mechanics per phase. Track phase in the boss behavior update; transition triggers a brief telegraph.

### Part C — Adds / minion waves
- Bosses summon support enemies on a timer (reuse `spawn_enemy_minions` — already exists, used by Hive). Keeps the fight from being dodge-and-shoot a single target. Gate add waves per phase.

### Part D — Telegraphed heavy attacks with counterplay
- Each boss gets at least one big wind-up attack the player must actively dodge (rotating beam, expanding ring, ground slam, projectile wall). Clear telegraph → dangerous payoff → recovery window. This is the dodge-learn-react loop bosses need.

**Note:** This is the largest item. Implement boss-by-boss; verify each in single-room debug (RunState debug single-room mode supports boss rooms) before moving to the next.

**Files:** `scripts/enemies/Enemy.gd`, possibly `scripts/game/CoopManager.gd` (add-wave plumbing, telegraph VFX)

---

## Fix F6 — Overcharge baseline rebalance

**Problem:** Overcharge (`data/abilities.json`: 2× fire rate, 2× projectiles, 4s, 15s CD) is so fun it feels like it should be the run's baseline. Non-Overcharge play feels flat by comparison.

**Decision:** Buff baseline fire toward the Overcharge feel; reduce Overcharge to a milder (still satisfying) spike.

**What to change:**
- **Baseline (`data/weapons.json` starter rifle):** raise `fire_rate` 4.0 → **5.0** (punchier default). Optionally small projectile-speed/feel bump. The whole run now feels closer to "good."
- **Overcharge (`data/abilities.json`):** reduce `fire_rate_multiplier` 2.0 → **1.5**, keep `projectile_multiplier` 2. Net: still a clear burst on top of the now-stronger baseline, but not a night-and-day cliff.
- **Numbers are a starting point** — tune in playtest. The principle: baseline up, Overcharge delta down, so both states feel good.

**Files:** `data/weapons.json`, `data/abilities.json`

---

## Fix F13 — Turret + Mines buffs

**Problem:** Turret weak; ability Minefield mines don't last long enough.

**What to change (`data/abilities.json`):**
- **Turret:** `damage` 12 → **20**, `fire_rate` 3.2 → **4.5**, `duration` 6 → **9**.
- **Minefield:** `duration` 8 → **14**, `mine_count` 5 → **7**, bump `radius` and `damage`, and **add a `trigger_radius`** param (~80) so each mine matters. Consider: mines persist until triggered within the duration window.

**Required plumbing (verified gap):** `AbilityMine.configure(duration, radius, mine_damage, color)` (`AbilityMine.gd:14-20`) maps the passed `radius` to `explosion_radius` only — `trigger_radius` stays hardcoded at `52.0` (`AbilityMine.gd:7`). And `CoopManager` calls `configure(duration, radius, damage, color)` (`CoopManager.gd:1088`) with no trigger value. So "bigger trigger range" requires actual plumbing, not just JSON:
- Extend `AbilityMine.configure(...)` to accept a `trigger_radius` argument and assign it to the `trigger_radius` field.
- Update the `CoopManager` call site (`~line 1088`) to read `trigger_radius` from the ability stats and pass it through.
- Decide explosion vs trigger separately: `explosion_radius` (damage area) and `trigger_radius` (detection range) are distinct — buff both from stats.

**Files:** `data/abilities.json`, `scripts/game/AbilityMine.gd`, `scripts/game/CoopManager.gd`

---

## Fix F2 — Blink rework

**Problem:** Blink teleports in AIM direction (bug — `Player.gd:457` uses `direction`, the ability's aim arg) and feels redundant with Dash (which has i-frames, making Blink strictly worse).

**Decision:** Movement-direction + longer range + arrival i-frames + detonation on arrival. Identity = aggressive blink-strike (engage toward movement, protected landing, clears space around you).

**What to change:**
- **`data/abilities.json` blink:** `distance` 240 → **340**. Add stats for the new behavior: `arrival_iframes` (~0.2), `detonation_radius` (~120), `detonation_damage` (~24).
- **`Player.gd` blink case (line 453-459):**
  - Use **movement input** direction, not aim `direction`. Find the move-input vector used elsewhere (the movement code uses `move_input` / `_move_facing`). Use the current movement direction; fall back to `_move_facing` (last faced) if the player is standing still, then `Vector2.RIGHT` as last resort.
  - After teleport, grant arrival i-frames: set `_contact_invuln_until = now + arrival_iframes` (reuses the round-3 invuln field) — or a dedicated timer if cleaner.
  - Trigger a detonation at the arrival point: emit an ability event / call into CoopManager to spawn an AoE damage burst (reuse the shockwave/explosion damage helper). The blast hits enemies in `detonation_radius` for `detonation_damage`.
- **`CoopManager._spawn_blink_effect` (line 1068)** + ability-activation path: add the detonation damage + a clear arrival VFX (ring/flash at the landing point, tinted to player color).
- Keep Dash as the short, frequent pure-dodge; Blink is the longer-CD aggressive reposition with payoff.

**Files:** `data/abilities.json`, `scripts/player/Player.gd`, `scripts/game/CoopManager.gd`

---

## Fix F7 — Fire Trail mutation rework

**Problem:** Tiny (~10px, `collision_half_width * 1.6`) dots along the flight path, 30% dmg / 0.5s tick / 1.5s life (`data/mutations.json:129`, `Projectile._spawn_fire_trail_zone` line 163-176). Useless — the projectile already kills what it hits.

**Decision:** Trail along path AND a bigger pool on impact. Becomes area-denial / group damage. Tune damage to avoid being overpowered (it's a rare mutation).

**What to change:**
- **`data/mutations.json` fire_trail params:** raise `trail_lifetime` 1.5 → **3.0**, `tick_interval` 0.5 → **0.35**, `damage_percent` 0.3 → **0.4**. Add an impact-pool param set: `impact_pool_radius` (~90), `impact_pool_lifetime` (~3.0), `impact_pool_damage_percent` (~0.5).
- **`scripts/game/MutationSystem.gd` (verified gap — REQUIRED):** `get_compiled_weapon_stats` currently only compiles `leaves_fire_trail`, `trail_lifetime`, `trail_tick_interval`, `trail_damage_percent` (lines 93-97). The new impact-pool params will **never reach the projectile** unless they're compiled here too. Add:
  ```gdscript
  compiled["impact_pool_radius"] = float(_get_param("fire_trail", "impact_pool_radius", 90.0))
  compiled["impact_pool_lifetime"] = float(_get_param("fire_trail", "impact_pool_lifetime", 3.0))
  compiled["impact_pool_damage_percent"] = float(_get_param("fire_trail", "impact_pool_damage_percent", 0.5))
  ```
  (plus pass the raised trail values through as before).
- **`Projectile.gd`:**
  - Read the new compiled params in `setup_from_config` (alongside the existing `leaves_fire_trail` / `trail_*` reads at line ~114) into instance fields.
  - Trail-along-path zones: increase radius from `collision_half_width * 1.6` to a real size (~40-54px).
  - On impact/expiry (`_on_body_entered` / `_attempt_hit_target` / lifetime expiry), spawn ONE larger `FireTrailZone` pool at the impact point using the impact-pool fields (radius, lifetime, damage = `round(damage * impact_pool_damage_percent)`).
- **`FireTrailZone.gd`** already supports radius/lifetime/tick/damage via `configure()` — no structural change needed, just larger values from the caller.
- **Balance watch:** with trail + impact pool + faster ticks this can stack hard. Start conservative on damage %, tune down if it trivializes rooms.

**Files:** `data/mutations.json`, `scripts/game/MutationSystem.gd`, `scripts/weapons/Projectile.gd` (FireTrailZone reused as-is)

---

## Fix F3 — Secondary objective HUD panel

**Problem:** Secondary objective text (`_objective_label`, formatted by `_format_objective_text` line 1356-1367) lacks visibility/readability.

**Decision:** Dedicated styled panel — icon + label + progress bar.

**What to change (`scripts/game/CoopManager.gd` HUD build + refresh):**
- Build a bordered `PanelContainer` (top area, near existing objective/score) containing:
  - An icon (per objective type — hold_zone / kill_streak / collector). Reuse `IconFactory` if it has suitable glyphs, else a simple `_draw`/Polygon2D icon.
  - A label ("Kill Streak", "Hold Zone", "Collect").
  - A `ProgressBar` showing fraction (progress/target). Reuse `_apply_progress_bar_tint` helper from round 2/3.
- Drive it from the existing objective state each frame (replace/augment the plain `_objective_label` update).
- Hide the panel when there's no side objective (`_side_objective_id.is_empty()`).

**Files:** `scripts/game/CoopManager.gd`, possibly `scripts/ui/IconFactory.gd`

---

## Fix F4 — Kill Streak → true streak

**Problem:** "Kill Streak" is actually a hidden cumulative quota: target = `round(estimated_total_enemies * 0.65)` (`_setup_side_objective` line 688-689), increments on each kill (`_on_enemy_died` path line 1245-1248), resets only at room start (line 626), never on damage. Misnamed and the target looks arbitrary.

**Decision:** Make it a TRUE streak — consecutive kills without taking damage; taking damage resets progress to 0; fixed sensible target.

**What to change (`scripts/game/CoopManager.gd`):**
- `_kill_streak_target`: replace the 65%-of-room formula with a fixed target (e.g. **15-20**; tune). Independent of room size.
- On player damage taken: reset `_kill_streak_progress = 0`. Hook into the existing player `damage_taken` signal handler (CoopManager already connects player damage for VFX — add the reset there). Guard so it only resets while the kill_streak objective is active and not yet complete.
- Keep the increment on kill and the completion check at target.
- Update `_format_objective_text` "Kill Streak %d/%d" — now accurate. Consider showing it resetting visibly (ties into F3 panel pulse).

**Edge:** decide whether contact-invuln-absorbed hits count as "taking damage." Recommend: only reset when `apply_damage` actually reduces HP (a fully-blocked/invuln hit does not break the streak) — cleaner feel.

**Files:** `scripts/game/CoopManager.gd`

---

## Fix F8 — Wire up Settings in pause menu

**Problem:** Settings button in the round-2 pause rebuild is `disabled` ("Coming soon", `CoopManager.gd:193`). A legacy `UI/SettingsPanel` exists in `scenes/game/GameWorld.tscn` (screen-effects toggle, per-player aim mode, Back button) but is force-hidden via `CoopManager._hide_legacy_ui` (line ~199).

**Decision:** Wire up the existing legacy panel.

**Scope clarification (verified):** Input/key/controller **rebinding already exists in the main menu** — `Bootstrap.gd` has a full binding system (`INPUT_BINDINGS_PATH := "user://input_bindings.cfg"`, `INPUT_BINDING_ACTIONS`, `MENU_BINDING_ACTIONS`, lines 10-24) with persistence. The pause Settings this round is **NOT** that rebind editor. Scope here is strictly the **in-run legacy SettingsPanel** (screen-effects toggle + per-player aim mode). Rebinding stays a main-menu feature; do not duplicate or relocate it into pause. If we later want rebinding in pause, that's a separate task that should reuse Bootstrap's `input_bindings.cfg` persistence rather than reimplement it.

**What to change:**
- **`CoopManager.gd`:**
  - Remove `"SettingsPanel"` from the `_hide_legacy_ui` force-hide list (or stop hiding it after bind).
  - Enable the pause Settings button (`pause_settings_button.disabled = false`, clear the "Coming soon" tooltip), connect `pressed` → show SettingsPanel (and hide the pause button list or overlay it).
  - Wire the SettingsPanel's existing `SettingsBackButton` → hide SettingsPanel, return focus to the pause menu.
  - Gamepad nav: `grab_focus()` on the first settings control when the panel opens; ensure focus neighbors are set on the settings controls (OptionButtons + Back). On Back, restore focus to the Settings button.
  - Ensure the SettingsPanel has `process_mode = ALWAYS` (or inherits) so it works while the tree is paused, same as the pause panel.
- **Behavior:** verify the existing settings controls (screen effects, per-player aim mode) are actually hooked to real settings logic; if they're dead stubs, at minimum make screen-effects toggle affect the screen-shake/flash, and aim-mode persist to player config. (If deeper wiring is out of scope this round, get the panel showing/navigable and flag any non-functional control.)

**Files:** `scripts/game/CoopManager.gd`, possibly `scenes/game/GameWorld.tscn` (focus neighbors / process_mode)

---

## Fix F14 — Performance: profile + cheap wins

**Problem:** Frame drops at 150+ enemies/projectiles.

**Decision:** Profile first, then object-pool projectiles + time-slice enemy AI. Re-measure before any bigger rewrite (MultiMesh / server-side bullets deferred).

**What to do:**

### Step 1 — Profile (do this FIRST, before Phase 1 work)
- **Capture the baseline before any other round-4 changes land.** The boss/elite/projectile/VFX work in phases 1-4 adds entities and per-frame cost, which would contaminate the measurement if profiling happens after. Run a stress scenario (endless deep room or debug spawn) at **current `v3/main` state** and record the dominant cost: render-bound (draw calls) vs script/physics-bound (`_physics_process`, targeting, collisions). Save the numbers.
- This is listed as "Phase 0" in the implementation order below. Steps 2-4 (the actual optimizations + re-measure) stay in Phase 5 so they build on the now-heavier post-rework game and can be compared against the saved baseline.

### Step 2 — Object-pool projectiles
- Replace per-shot `ProjectileSceneData.instantiate()` / `queue_free()` (`CoopManager.gd:986`, `1167`) with a reusable pool: pre-allocate a fixed array of Projectile nodes, deactivate (hide + disable processing/monitoring + move offscreen) instead of freeing, reactivate on next shot. Cuts allocation churn and GC spikes.
- `MAX_ACTIVE_PROJECTILES` already caps count — the pool size can match it.

### Step 3 — Time-slice enemy AI
- Heavy per-enemy work (target acquisition `_find_target`, retargeting) doesn't need to run every physics frame for every enemy. Stagger it: each enemy refreshes its target every N frames (e.g. 3-4), offset by instance id so the load spreads across frames. Movement still updates every frame using the cached target.
- The separation grid (`_enemy_separation_grid`, round 2) already rebuilds once per frame and is shared — keep as-is.

### Step 4 — Re-measure
- Confirm the cheap wins moved the needle. Only if still insufficient, schedule a follow-up for MultiMeshInstance2D rendering (one draw call for identical projectiles/enemies) or server-side bullets. Do NOT do those this round.

**Files:** `scripts/game/CoopManager.gd` (projectile pool, AI scheduling), `scripts/enemies/Enemy.gd` (cached-target / staggered refresh)

---

## Deferred: F12 — Visual/asset upgrade

Per user: keep prototype art for now; revisit after combat/balance rounds. Recommendation when revisited: prototype a **procedural rubberhose vertical slice** (player + 1 enemy via Skeleton2D + Polygon2D noodle limbs) before committing the full roster — it matches the existing procedural `_draw`/Polygon2D codebase and the core player-tinting system, with zero asset pipeline. Hybrid (procedural bodies + small hand-drawn/AI face details) is a viable middle path. Not in scope this round.

---

## Implementation Order

### Phase 0 — Baseline profiling (before any changes)
0. **F14 Step 1** Profile current `v3/main` under a 150+ entity stress scenario; record render-bound vs script-bound and save the numbers. This baseline is the comparison point for Phase 5.

### Phase 1 — Quick fixes & numeric tuning (low risk, isolated)
1. **F10** Enemy projectile red visual (`Projectile.gd`)
2. **F1** Remove level-up VFX (`CoopManager.gd`)
3. **F11** Fire zone bigger + more (`FireFloorModifier.gd`)
4. **F5 Part A** Elite spawn placement fix (`CoopManager.gd`)
5. **F6** Overcharge/baseline rebalance (`weapons.json`, `abilities.json`)
6. **F13** Turret + mine buffs (`abilities.json`, `AbilityMine.gd`, `CoopManager.gd`)

### Phase 2 — Ability reworks
7. **F2** Blink rework (`abilities.json`, `Player.gd`, `CoopManager.gd`)
8. **F7** Fire trail rework (`mutations.json`, `MutationSystem.gd`, `Projectile.gd`)

### Phase 3 — HUD / clarity
9. **F3** Objective HUD panel (`CoopManager.gd`, `IconFactory.gd`)
10. **F4** Kill streak true-streak (`CoopManager.gd`)
11. **F8** Settings wire-up (`CoopManager.gd`, `GameWorld.tscn`)

### Phase 4 — Enemy/boss combat rework (biggest scope)
12. **F5 Part B** Elite threat + attack patterns (`Enemy.gd`)
13. **F9** Boss multi-phase + rebalance + adds + telegraphs (`Enemy.gd`, `CoopManager.gd`) — boss-by-boss

### Phase 5 — Performance
14. **F14 Steps 2-4** Pool projectiles → time-slice AI → re-measure against the Phase 0 baseline (`CoopManager.gd`, `Enemy.gd`). (Step 1 profiling already done in Phase 0.)

---

## Verification

After each phase:
```powershell
& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit
```

After all phases, manual playtest:
- Enemy bullets clearly red; no white-washed projectiles
- No level-up flash; leveling is silent/clean
- Blink goes toward movement, blink-strike feels distinct from dash, detonation + arrival i-frames land
- Fire trail leaves usable burning zones + impact pools (not OP)
- Fire zone noticeably denies more arena
- Elites don't spawn on the player, can't be freely kited, have readable attacks
- Bosses have phases, telegraphed heavy attacks, adds; Hydra no longer trivial
- Objective HUD panel readable; kill streak resets on damage and shows a fixed target
- Pause → Settings opens the panel, gamepad-navigable, Back returns
- Overcharge still fun but baseline also feels good
- Turret/mines feel impactful
- Profiler: confirm cheap-win perf gains at 150+ entities
