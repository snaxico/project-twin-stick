# Playtest Round 2 — Implementation Plan

## Context

Second playtest of `v3/main` (2026-06-02), after the round-1 fixes from `snug-scribbling-fiddle.md` landed. Seven active findings; one deferred (F6 map alignment — kept for later, functional).

Target branch: `v3/main` in `D:\GameDev\Project_Twin_stick`. Player max HP is `50` (default; some loadouts override).

## ⚠ Pre-implementation note: uncommitted deferred-spawn fix

The working tree currently has an **uncommitted** modification to `scripts/game/CoopManager.gd` that introduces a deferred-spawn pipeline:
- New counter `_pending_enemy_spawns` tracks in-flight `call_deferred` spawns.
- New function `_queue_enemy_spawn(enemy_type, position, health_multiplier)` defers the actual `_spawn_enemy_instance` call to avoid mutating the scene tree during a physics step.
- New function `_spawn_health_pickup(position)` does the same for HP drops.
- `_check_wave_progress()` now also waits for `_pending_enemy_spawns <= 0` before signaling room clear.
- Splitter children (`_on_enemy_died`) and HP drops now route through these deferred helpers.

**Implications for round 2:**
- **Do not lose this change.** Commit it before starting round-2 implementation (or rebase round-2 on top of it).
- F8c's `_spawn_opening_burst()` must use `_queue_enemy_spawn()` — not direct `_spawn_enemy_instance()` — to match the deferred pattern.
- F3 Part B's `_get_enemy_spawn_position_for_index()` is fine; it just returns a position. Callers using it inside a deferred-spawn loop are still correct.

## Revision history

- **v1** initial plan
- **v2** — first code review corrections:
  - **F1** sweep cooldown: store hit timestamps inside each sweep dict (per-sweep × per-player), not a shared player-keyed dict — sweeps coexist.
  - **F4c** level-up VFX: `RunState.level_up` signal does not exist; plan now adds it to `RunState.gd`.
  - **F5/F7** pause rebuild: legacy `UI/SettingsPanel` already exists in `GameWorld.tscn:348-430` (force-hidden, unused). Decision: leave hidden, do not wire new pause Settings button to it. Concrete scene path documented.
  - **F8b** spawn ramp: existing ramp is gated behind `accelerating_waves` modifier — only that modifier sees ramping today. Plan now adds a separate base ramp for ALL rooms and leaves the modifier ramp untouched.
  - **F8c** opening burst: no initial spawn pulse exists today (room start just sets `_next_spawn_at = 0.4`). Plan now adds a new `_spawn_opening_burst()` function called from `_start_room`.
- **v3** (this revision) — second code review corrections:
  - **F8c** function name: actual function is `_start_room()` (line 532), not `_start_room_internal`. Corrected.
  - **F3 Part B** edge helper: clarified signature to `_get_enemy_spawn_position_for_index(spawn_index: int, start_edge: int)` and specified that `start_edge` is rolled once per pulse and passed in, not held as hidden state.
  - **F4a** death VFX owner: clarified that enemy death particles live in `Enemy.gd._spawn_death_particles()` (line 746). `CoopManager._on_enemy_died()` only handles XP/drops/splitter/objectives. Primary VFX upgrade work goes in `Enemy.gd`; `CoopManager` handles only camera shake / screen flash on elite/boss deaths.
  - **F4c** signal connect: connect `RunState.level_up` in `_ready()` once, with optional `is_connected` guard — do NOT connect from `_start_room()` (rooms restart frequently → duplicate connections → duplicate VFX).
  - **F2** bottom HUD: card already has `border_color = tint.lightened(0.18)` (`CoopManager.gd:289`) — frame tint is **already done**. Real work is tinting the per-slot `ProgressBar` fills (not "slot icon backgrounds" — there are no icon frames in the current HUD).
  - **Process note:** an uncommitted deferred-spawn fix exists in `scripts/game/CoopManager.gd` adding `_pending_enemy_spawns` counter and `_queue_enemy_spawn()` / `call_deferred` pipeline. Round-2 spawn changes (F3 multi-angle, F8c opening burst) must use `_queue_enemy_spawn()` for consistency with this pending pipeline. Do not bypass it with direct `_spawn_enemy_instance()` calls inside loops.
- **v4** (this revision) — third code review correction:
  - **F3 Part B** swarm stream coverage: when `_minor_modifier_flags["swarm"]` is active, the normal stream loop at line 713-718 spawns `batch := 2` enemies per tick — also a multi-enemy pulse. Plan now applies the `start_edge` distribution to that path too via an inline `batch == 1` guard. Single-spawn ticks still use the unmodified `_get_enemy_spawn_position()`.

---

## Fix F1 — Minefield damage softened

**Problem:** Mine sweeps feel like 1-shot kills. Two sources stack:
- `scripts/modifiers/Mine.gd:9` — `DAMAGE := 10` (placed mine instance)
- `scripts/modifiers/MineFieldModifier.gd:7` — `DAMAGE := 15` (sweep modifier)

`_apply_sweep_damage` in `MineFieldModifier.gd:52-59` applies damage every physics frame the player is within `TRIGGER_RADIUS` of any mine position in the sweep. Sweeps spawn every ~5-6s (`_spawn_at = 5.0 + randf_range(0.0, 1.0)`, line 27) and travel the arena over many seconds, so **multiple sweeps coexist**. That's the real 1-shot source.

**What to change:**
- `MineFieldModifier.gd`:
  - `DAMAGE`: 15 → **12** (~24% max HP on a clean hit)
  - Add a **per-sweep, per-player** hit cooldown so `_apply_sweep_damage` doesn't tick every physics frame. **Do not** key by player instance id alone — that creates one shared cooldown across all active sweeps and lets a second sweep hit you mid-cooldown of the first. Instead, store hit timestamps **inside each sweep dictionary**:
    - When `_spawn_sweep()` builds the sweep dict (line 44-50), add `"player_hit_times": {}` (Dictionary keyed by `player.get_instance_id()` → last hit time).
    - In `_apply_sweep_damage`, before calling `apply_damage`, check `sweep["player_hit_times"].get(player.get_instance_id(), -INF)`; only apply if `current_time - last_hit >= 0.6`.
    - Use `Time.get_ticks_msec() / 1000.0` for the timestamp.
  - This way each sweep gates damage independently, and walking out of one sweep into another still applies a fresh hit.
- `Mine.gd`:
  - `DAMAGE`: 10 → **8** (~16% max HP). Already gated by `queue_free()` after explosion so per-frame stacking isn't an issue.
- Verify final combined worst-case (mine + sweep on same frame) ≤ 20 dmg = ~40% HP, well under 1-shot.

**Files:** `scripts/modifiers/MineFieldModifier.gd`, `scripts/modifiers/Mine.gd`

---

## Fix F3 — Anti-clumping (separation + multi-angle spawn)

**Problem:** Enemies converge into a single blob at the player.

### Part A — Soft separation force (in `Enemy.gd`)

- Add a `_apply_separation()` helper called from `_physics_process` *after* normal velocity is computed.
- Iterate nearby enemies (use `_combat_owner.get_enemy_target_nodes()` already exposed via `CoopManager.gd:1515`).
- For each neighbor within `SEPARATION_RADIUS = 64.0` of same family (skip bosses):
  - Add a push vector `(self.pos - neighbor.pos).normalized() * (1.0 - dist/radius) * SEPARATION_STRENGTH`
- Cap total push to avoid overpowering pursuit; clamp magnitude to ~80% of `move_speed`.
- O(N²) is fine for current enemy counts (typically <40 on screen); short-circuit if `_enemy_nodes.size() < 3`.

### Part B — Multi-angle spawn (in `CoopManager.gd`)

- `_get_enemy_spawn_position()` (line 1521) currently picks ONE random edge per call. Apply multi-angle distribution to every code path that can spawn 2+ enemies in a single tick:
  - **Recurring burst** at line 719-728 (4-8 enemies per pulse).
  - **F8c opening burst** (6-8 enemies at room start).
  - **Stream loop** at line 713-718 when `_minor_modifier_flags["swarm"]` is true (`batch := 2`) — under swarm this path is also multi-enemy per tick and would otherwise stack both spawns on the same edge.
- Implementation:
  - Add `_get_enemy_spawn_position_for_index(spawn_index: int, start_edge: int) -> Vector2` — explicit `start_edge` param, no hidden state. The edge picked is `(start_edge + spawn_index) % 4`. Same body as `_get_enemy_spawn_position` but uses the deterministic edge instead of `randi() % 4`.
  - In **each** pulse caller (including the swarm stream loop), **roll `start_edge` once before the loop**: `var start_edge := randi() % 4`, then pass `start_edge` into every `_get_enemy_spawn_position_for_index(i, start_edge)` call.
  - For the stream loop, an inline guard keeps the non-swarm path cheap:
    ```gdscript
    var batch := 2 if bool(_minor_modifier_flags["swarm"]) else 1
    var stream_start_edge := randi() % 4
    for index in range(batch):
        var enemy_type := _roll_wave_enemy_type(_room_enemy_pool)
        var spawn_position := _get_enemy_spawn_position() if batch == 1 else _get_enemy_spawn_position_for_index(index, stream_start_edge)
        _queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)
        _enemies_spawned += 1
    ```
  - Leave the single-spawn tick (`batch == 1`, non-swarm) calling the original `_get_enemy_spawn_position()` — fully random per tick is fine when there's only one enemy in the pulse.
- Net effect: any pulse of N enemies arrives from N different sides (capped at 4); the starting edge varies pulse-to-pulse so the pattern doesn't always start "from the north."

**Files:** `scripts/enemies/Enemy.gd`, `scripts/game/CoopManager.gd`

---

## Fix F8 — Early game punch (stronger start + faster ramp + more starting enemies)

**Problem:** Beginning feels slow. Mid-game is fun; we need to frontload that feel.

### Sub-fix 8a — Stronger starter weapon (higher fire rate)

- `scripts/player/Player.gd:31` — `weapon_fire_interval: float = 0.33` (3 shots/sec). Drop default to **0.25** (4 shots/sec). Confirm `_base_weapon_fire_interval` follows from `_weapon_stats.get("fire_rate", 3.0)` at line 178 — bump that default fallback to **4.0**.
- Check `data/weapons.json` (or wherever starter weapon stats live) — find the default/starter weapon entry and bump its `fire_rate` from whatever it is now to ~4.0. This is the source of truth; the `@export` default is just fallback.

### Sub-fix 8b — Faster spawn ramp for ALL rooms (not just accelerating_waves)

**Important correction:** The existing ramp at `CoopManager.gd:707-711` is gated behind `if bool(_minor_modifier_flags["accelerating_waves"])` — it only fires when that *specific minor modifier* is active. Unmodified rooms keep `current_interval = _spawn_interval` (a flat 1.6s) for the whole room. Also, the modifier's existing ramp uses `min(_room_duration, 25.0)` (already fast); rewriting it to 45.0 would *slow it down*.

So this needs two separate changes:

**1. Add a base ramp for ALL rooms** (the actual fix for "early game feels slow")
- Restructure the spawn block in `_continuous_spawn()` around line 707:
  ```gdscript
  var current_interval := _spawn_interval
  # Base early-game ramp: 1.0x -> 0.55x over the first BASE_RAMP_DURATION seconds.
  var base_ramp := clampf(_room_elapsed / BASE_RAMP_DURATION, 0.0, 1.0)
  current_interval = lerpf(_spawn_interval, _spawn_interval * 0.55, base_ramp)
  # accelerating_waves modifier ramps further, stacking on top.
  if bool(_minor_modifier_flags["accelerating_waves"]):
      var ramp := clampf(_room_elapsed / min(_room_duration, 25.0), 0.0, 1.0)
      current_interval = lerpf(current_interval, current_interval * 0.6, ramp)
  ```
- Add `const BASE_RAMP_DURATION := 45.0` near the other spawn constants.
- Numbers: base 1.0× → 0.55× means a vanilla room goes from 1.6s spawns at start to ~0.88s spawns by 45s. With `accelerating_waves` it compounds further (~0.53s). Tweak after playtest.

**2. Leave the existing `accelerating_waves` ramp alone** (do not change line 710's `min(_room_duration, 25.0)` — that modifier is intentionally aggressive).

### Sub-fix 8c — Opening burst at room start (new function)

**Important correction:** There is no existing "initial spawn pulse" to bump. Room start at `CoopManager.gd:532-554` (function `_start_room`, **not** `_start_room_internal`) just sets `_next_spawn_at = 0.4` and lets `_continuous_spawn()` handle everything via the timer. The burst spawn at line 719-728 is recurring (every `_burst_interval = 8-10s`), not an opening burst.

**What to add:**
- New function `_spawn_opening_burst()` in `CoopManager.gd`. **Must use `_queue_enemy_spawn()` (deferred pipeline) — not direct `_spawn_enemy_instance()`** — to match the pending deferred-spawn fix already in the working tree (see process note in revision history):
  ```gdscript
  func _spawn_opening_burst() -> void:
      if _room_type == "boss":
          return  # Boss rooms handle their own spawning
      var burst_size := 6 if RunState.get_current_act() <= 1 else 8
      if bool(_minor_modifier_flags["swarm"]):
          burst_size *= 2
      var health_multiplier := 0.5 if bool(_minor_modifier_flags["swarm"]) else 1.0
      var start_edge := randi() % 4
      for index in range(burst_size):
          var enemy_type := _roll_wave_enemy_type(_room_enemy_pool)
          var spawn_position := _get_enemy_spawn_position_for_index(index, start_edge)  # F3 multi-angle
          _queue_enemy_spawn(enemy_type, spawn_position, health_multiplier)
          _enemies_spawned += 1
  ```
- Call it from `_start_room()` (line 532) at the end of the function body, after the existing `_next_spawn_at = 0.4` setup.
- Pair with F3 Part B multi-angle spawn so the 6-8 enemies arrive from 4 sides simultaneously.

**Files:** `scripts/player/Player.gd`, `data/weapons.json` (or equivalent), `scripts/game/CoopManager.gd`

---

## Fix F4 — Spectacle (three sub-pieces)

### Sub-fix 4a — Beefier enemy death VFX

**Important correction:** Enemy death particles are owned by `Enemy.gd._spawn_death_particles()` (line 746), called from `Enemy.gd:721` during death handling. `CoopManager._on_enemy_died()` (line 1058) handles XP / health drops / splitter children / objective tracking / modifier hooks — **not** death VFX. The primary VFX upgrade lives in `Enemy.gd`; `CoopManager` adds only the global/camera layer.

- **In `Enemy.gd._spawn_death_particles()`** — the primary upgrade point:
  - Normal enemy: 2× particle count, slight outward burst velocity, brief tint flash.
  - Elite: bigger particle burst, debris ring (radial line segments fading out).
  - Boss: even bigger burst + debris ring with longer fade.
- **In `CoopManager._on_enemy_died()` or a new `_on_enemy_died` post-hook** — global/camera layer:
  - Elite death: `apply_camera_shake(0.25, 6.0)` (assuming there's a camera shake helper — if not, add a small one).
  - Boss death: bigger shake (`0.6, 14.0`), full-screen white flash overlay (200ms fade) via the spectacle VFX layer.
- Keep ownership clean: per-entity VFX (particles, debris) stays in `Enemy.gd`; cross-cutting feedback (camera, screen overlay) stays in `CoopManager` / `SpectacleVFX.gd`.

### Sub-fix 4b — Player ability VFX upgrade

- Audit each of the 9 abilities (decoy / turret / orbit / mine / shield / dash / etc.) — for each:
  - Bigger activation flash at cast position.
  - Color-tinted to the player's color (ties into F2).
  - Hit sparks per enemy struck (not just one generic flash).
- Don't rewrite ability behavior — just amp visuals. Probably 10-15 lines touched per ability.

### Sub-fix 4c — Screen-wide milestone events

**Important correction:** `RunState.gd` has no signals at all today — `add_xp()` (line 235-243) just mutates `xp_level` / `xp_pending_levelups` silently. The plan needs to add a signal explicitly.

- **Level-up:** 
  - Add `signal level_up(new_level: int)` near the top of `RunState.gd` (after the `extends Node` line).
  - In `add_xp()`, after `xp_level += 1` (line 241), emit the signal: `level_up.emit(xp_level)`.
  - In `CoopManager.gd`, connect `RunState.level_up.connect(_on_level_up)` **in `_ready()` once** — NOT in `_start_room()`. Rooms restart frequently and per-room connections duplicate, which would fire the level-up VFX N times per level after N rooms. If a per-room connect must be used for any reason, wrap it with `if not RunState.level_up.is_connected(_on_level_up): RunState.level_up.connect(_on_level_up)`.
  - The handler triggers the VFX: brief radial flash from each player position, screen edge glow in player tint, 0.3s.
- **Boss entrance:** when a boss spawns, camera punch + 0.5s dim + a "WARNING" banner sweep (or a quick red border pulse). Hook into `_spawn_boss` (referenced around `CoopManager.gd:768`).
- **Modifier activation:** when a major modifier (fire floor, ice zone, mine field, shrinking arena) activates, single arena-wide ripple wave in the modifier's signature color. Hook into the modifier activation block already used by F12 from round-1.

**Files:** `scripts/game/CoopManager.gd`, plus likely a new `scripts/effects/SpectacleVFX.gd` to keep this organized.

---

## Fix F2 — HUD color coding (per-player tint on loadout slots, rings, HP bar, card frame)

**Problem:** HUD is generically colored; cooldown rings use mixed colors (slot 2 hardcoded pink in `PlayerCombatIndicator.gd:109,120,135,150`). Need all per-player UI tinted to that player's color.

### Changes in `scripts/ui/PlayerCombatIndicator.gd`:
- Replace the hardcoded `Color(1.0, 0.48, 0.82, …)` slot-2 colors at lines 109, 120, 150 with `_tint` (or `_tint.lerp(Color.WHITE, 0.2)` if we want slot 2 visually distinct but still in-family).
- The two slot rings can be the **same tint** but at different radii (already different — slot 1 outer at `COOLDOWN_ARC_RADIUS = 16.0`, slot 2 inner at `DASH_ARC_RADIUS = 10.0`). That's enough visual separation.
- Health bar fill (`fill_color` at line 131) already uses `_tint`. Good.

### Changes in `scripts/game/CoopManager.gd` (bottom HUD per-player cards):
- Card construction is in `_build_hud()` around `CoopManager.gd:285-323+`. Current state:
  - **Card border** (`StyleBoxFlat.border_color`, line 289): **already tinted** with `tint.lightened(0.18)`. ✅ Done.
  - **Card background** (line 288): already a dim tint of the player color. ✅ Done.
  - **Header label "P1/P2"** (line 316): already `tint.lightened(0.18)`. ✅ Done.
- What's still needed:
  - **Per-slot ProgressBar fill colors** for ability cooldowns: find the `ProgressBar` nodes added per card in `_build_hud` / `_refresh_bottom_hud` (line 1231). Apply `add_theme_stylebox_override("fill", ...)` with a `StyleBoxFlat` colored to `tint` (slot 1) and `tint.lerp(Color.WHITE, 0.25)` (slot 2 — same family, slightly desaturated for visual separation).
  - **Health ProgressBar fill** on the card: same pattern, color = `tint`.
  - **Mutation badge label** (line 319-323): optionally tint to `tint.lightened(0.3)` for consistency.
- Note: there are **no slot icon backgrounds / icon frames** in the current bottom HUD — only labels and progress bars. Do not add icon frames as part of F2; that's a separate scope.

### Player tint source:
- Should already exist as `player.tint` or similar property. If not centrally exposed, add a helper `_get_player_tint(index: int) -> Color` keyed off the same data used by `PlayerCombatIndicator.configure_player()`.

**Files:** `scripts/ui/PlayerCombatIndicator.gd`, `scripts/game/CoopManager.gd`

---

## Fix F5 — Pause menu rebuild (structured)

**Problem:** Existing pause panel children aren't properly aligned. Current scene path: `$UI/PausePanel/MarginContainer/PauseLayout/{ResumeButton, PauseRetryButton, PauseMainMenuButton}` in `scenes/game/GameWorld.tscn`.

**Note on legacy SettingsPanel:** The scene also contains `UI/SettingsPanel` (`GameWorld.tscn:348-430`) — a fully built settings panel with screen effects toggle, per-player aim mode, and a back button. It is **referenced only once** in `CoopManager.gd:199` where it's force-hidden on startup, and never shown anywhere else. It's legacy dead UI from v2.

**Decision on legacy panel:** Leave it in the scene, keep it force-hidden, do **not** wire the new pause "Settings" button to it. Reasons:
- The legacy panel's controls (screen effects, aim mode) are useful and we'll likely want them later — deleting now would mean rebuilding.
- F7 explicitly defers settings, so we don't want it accidentally reachable from the rebuilt pause.
- Document as a known dead-UI item: a follow-up task can either repurpose the panel for the real settings menu, or remove it.

**What to change:**
- Rebuild the pause panel as a centered structured menu:
  - **Outer:** `Panel` (full-screen, semi-transparent backdrop `Color(0, 0, 0, 0.65)`)
  - **Inner:** `CenterContainer` filling the panel
  - **Inside CenterContainer:** `VBoxContainer` (custom theme: 16px separation)
    - `Label` — "PAUSED" — title style, 40pt, centered
    - `VSeparator` or spacer
    - `Button` — Resume
    - `Button` — Settings (`disabled = true`, tooltip "Coming soon" — see F7)
    - `Button` — Retry
    - `Button` — Main Menu
  - All buttons same width (~280px), same height (~52px), themed consistently.

**Implementation approach:** Edit `scenes/game/GameWorld.tscn` to restructure the pause panel. Update the `@onready` paths in `CoopManager.gd:80-83` to match the new node paths. Add `@onready var pause_settings_button` even if disabled, so future F7 wiring is ready. Confirm legacy `UI/SettingsPanel` is still in the `node_path` hide-list at line 199 (it should remain).

**Files:** `scenes/game/GameWorld.tscn`, `scripts/game/CoopManager.gd`

---

## Fix F7 — Pause menu gamepad navigation (defer settings menu)

**Problem:** Pause panel doesn't work with gamepad. No settings menu exists.

**Decision:** Fix gamepad nav only. Settings stays deferred.

**What to change:**
- When pause panel opens (in `_set_game_paused(true)` around `CoopManager.gd:1551-1554`):
  - Call `resume_button.grab_focus()` after `pause_panel.visible = true`.
- Set explicit `focus_neighbor_top/bottom` on each button so D-pad up/down cycles through Resume → Retry → MainMenu → Resume.
- Verify `focus_mode = Control.FOCUS_ALL` on each button (default for Button, but confirm).
- Ensure `PauseInputProxy` (already exists) is the only thing eating the pause action while paused — buttons should still receive `ui_accept` / `ui_down` / `ui_up` since their process_mode allows it.
- Settings button: present in layout (per F5) but `disabled = true`. Tooltip: "Coming soon."

**Note:** Legacy `UI/SettingsPanel` (in `scenes/game/GameWorld.tscn:348-430`) stays force-hidden — Settings button stays `disabled`. Do NOT connect the button to that panel. See F5 for the legacy-UI decision rationale.

**Files:** `scripts/game/CoopManager.gd`, `scenes/game/GameWorld.tscn` (for focus_neighbor wiring done in editor — or set programmatically in `_ready`)

---

## Deferred: F6 — Map tree alignment

Per user: functional, not game-breaking. Revisit in a later pass after the bigger UI work settles.

---

## Implementation Order

### Phase 1 — Quick numeric tunings (low risk)
1. **F1** Minefield damage softening (`MineFieldModifier.gd`, `Mine.gd`)
2. **F8a** Starter weapon fire rate (`Player.gd`, `data/weapons.json`)
3. **F8b** Faster spawn ramp (`CoopManager.gd`)

### Phase 2 — Spawn pipeline rework
4. **F3 Part B** Multi-angle spawn (`CoopManager.gd:_get_enemy_spawn_position`)
5. **F8c** Bigger opening burst (`CoopManager.gd` room start)
6. **F3 Part A** Enemy separation force (`Enemy.gd`)

### Phase 3 — UI coloring + pause restructure
7. **F2** HUD color coding (`PlayerCombatIndicator.gd`, `CoopManager.gd` bottom HUD)
8. **F5** Pause panel rebuild (scene file + `CoopManager.gd`)
9. **F7** Pause gamepad nav (`CoopManager.gd`)

### Phase 4 — Spectacle (biggest scope)
10. **F4a** Beefier death VFX
11. **F4c** Screen-wide milestone events (level-up, boss entrance, modifier activation)
12. **F4b** Ability VFX pass (touches all 9 abilities)

---

## Verification

After each phase:
```powershell
& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit
```

After all phases: full playtest pass — 1P structured, 2P structured, 1P endless. Specifically validate:
- Minefield no longer 1-shots
- First 30s of room 1 feels active (multiple enemies, multiple angles, starter weapon punchy)
- Cooldown rings + bottom HUD slots + HP bar all share player tint
- Pause menu D-pad navigable, Resume grabs focus on open
- Boss entrance has visible camera punch
