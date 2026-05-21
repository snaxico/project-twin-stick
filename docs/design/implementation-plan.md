# Implementation Plan — Roadmap Tiers 1–6

This plan is ordered by dependency chain. Each slice is self-contained, testable, and should pass `--headless --quit` before moving to the next.

**Branch:** `v2/core-refactor`
**Working directory:** `D:\GameDev\Project_Twin_stick`
**Godot version:** 4.6.2 stable
**Language:** GDScript only
**Validation:** `& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit`

**Critical rules:**
- All values are placeholder and subject to future balance passes
- GDScript gameplay code only, JSON-first data definitions
- No new scenes unless structurally required
- Update `docs/development/current-state.md` and create a history entry after each completed slice
- Run headless parse check after every slice

---

## Slice 0: Prerequisites (Fix Broken Paths)

**Goal:** Fix the encounter builder so elite rooms actually run as elite, and add a reversible runtime stat modifier layer to Player.gd. These are blockers for Slices 3–7.

### 0a: Fix Elite Debug Path

**Problem:** `RunState._build_single_room_map()` (line 244) overwrites `elite` → `combat`, making it impossible to test elite rooms via the encounter builder.

**`scripts/game/RunState.gd`:**
- Remove the line `if room_type == "elite": room_type = "combat"` (line 244–245)
- Preserve the `elite` room type so it passes through to `CoopManager._start_room()`
- Confirm `CoopManager` already handles `_room_type == "elite"` (it does — line 397 sets gold multiplier, line 471 adds elite_bonus to target enemy count, line 493 sets charger_heavy mix)

**Verification:** Parse check. Open encounter builder, select `elite` room type, launch. Confirm the room runs with charger-heavy mix and 1.3x gold multiplier (visible in gold summary).

### 0b: Add Reversible Player Stat Modifier Layer

**Problem:** `Player.apply_loadout()` (line 176) bakes compiled stats directly into `move_speed`, `projectile_damage`, `weapon_fire_interval`, etc. There is no way to apply temporary modifiers (ice_zone slow, temp buffs, elite_support debuff) and then cleanly remove them without re-calling `apply_loadout()`.

**`scripts/player/Player.gd`:**
- Add base stat storage vars (set once during `apply_loadout()`):
  ```
  var _base_move_speed: float = 390.0
  var _base_weapon_fire_interval: float = 0.33
  var _base_projectile_damage: int = 14
  ```
  Note: primary skill cooldown is NOT tracked here. Skill cooldown is compiled in `CoopManager._build_primary_skill_runtime_stats()` and does not need a reversible modifier layer on Player — no modifier or buff changes skill cooldown at runtime.
- In `apply_loadout()`: store compiled values into `_base_*` vars, then call `_recompute_effective_stats()`
- Add **source-keyed** modifier Dictionaries (NOT single mutable slots — ice_zone and elite_support can be active simultaneously and must not overwrite each other):
  ```
  # Key = source name ("ice_zone", "elite_support", etc.), Value = multiplier float
  var _modifier_move_speed_sources: Dictionary = {}   # product of all values = combined multiplier
  var _modifier_attack_speed_sources: Dictionary = {}
  var _modifier_damage_sources: Dictionary = {}
  var _buff_move_speed: float = 1.0          # temp buff from side objective (single source, no overlap)
  var _buff_attack_speed: float = 1.0        # temp buff from side objective
  var _buff_damage: float = 1.0              # temp buff from side objective
  ```
- Add `_combined_modifier(sources: Dictionary) -> float` helper:
  ```
  func _combined_modifier(sources: Dictionary) -> float:
      var result := 1.0
      for value in sources.values():
          result *= float(value)
      return result
  ```
- Add `_recompute_effective_stats()`:
  ```
  move_speed = _base_move_speed * _combined_modifier(_modifier_move_speed_sources) * _buff_move_speed
  weapon_fire_interval = _base_weapon_fire_interval / (_combined_modifier(_modifier_attack_speed_sources) * _buff_attack_speed)
  projectile_damage = int(round(float(_base_projectile_damage) * _combined_modifier(_modifier_damage_sources) * _buff_damage))
  ```
- Add public modifier API:
  ```
  func apply_zone_modifier(source: String, move_mult: float, attack_mult: float, damage_mult: float = 1.0) -> void:
      _modifier_move_speed_sources[source] = move_mult
      _modifier_attack_speed_sources[source] = attack_mult
      if damage_mult != 1.0:
          _modifier_damage_sources[source] = damage_mult
      _recompute_effective_stats()

  func clear_zone_modifier(source: String) -> void:
      _modifier_move_speed_sources.erase(source)
      _modifier_attack_speed_sources.erase(source)
      _modifier_damage_sources.erase(source)
      _recompute_effective_stats()

  func apply_temp_buff(buff_type: String, value: float) -> void:
      match buff_type:
          "speed": _buff_move_speed = 1.0 + value
          "damage": _buff_damage = 1.0 + value
          "attack_speed": _buff_attack_speed = 1.0 + value
      _recompute_effective_stats()

  func clear_temp_buffs() -> void:
      _buff_move_speed = 1.0
      _buff_attack_speed = 1.0
      _buff_damage = 1.0
      _recompute_effective_stats()
  ```
- Callers always pass a source string: `player.apply_zone_modifier("ice_zone", 0.67, 0.67)`, `player.apply_zone_modifier("elite_support", 0.67, 0.67)`. Clearing one source does NOT clear the other. Simultaneous ice_zone + elite_support stacks multiplicatively (0.67 × 0.67 = 0.45).
- Movement code (line ~265), firing cadence (line ~301), and skill dispatch (line ~321) already read from `move_speed`, `weapon_fire_interval`, `projectile_damage` — they don't need changes because the effective values are recomputed in place

**Verification:** Parse check. Start a run, confirm normal gameplay is unchanged (base stats identical). Manually test via encounter builder that applying/clearing zone modifiers doesn't permanently alter stats.

---

## Slice 1: Economy Flatten (Tier 1 + Tier 5 Economy Changes)

**Goal:** Flatten gold drops to 1g per enemy, remove survival bonus.

### Files to modify

**`scripts/game/CoopManager.gd`:**
- Replace `GOLD_DROP_VALUES` dictionary (lines 27–31) with a single constant: `const GOLD_DROP_PER_ENEMY := 1`
- Replace `SURVIVAL_BONUS_GOLD := 20` with `SURVIVAL_BONUS_GOLD := 0`
- Update `_get_gold_drop_amount()` (line 1252) to return `GOLD_DROP_PER_ENEMY` for all enemy types (ignore `_room_gold_multiplier` for now — modifier gold multipliers come in Slice 5)
- Update `_award_survival_bonus()` (line 1302) — keep the function but it now adds 0g
- Update `_handle_room_clear()` (line 1049) — change the gold summary text to not mention survival bonus since it's 0

**Verification:** Run headless parse check. Start a normal run, kill enemies, confirm 1g per kill, confirm 0g survival bonus.

---

## Slice 2: Mutation Rarity System (Tier 2)

**Goal:** Split mutations into commons (upgradable Lv1–3) and rares (binary one-off). Change scaling formulas to match roadmap.

### Files to modify

**`data/mutations.json`:**
- Restructure each mutation entry to include `"rarity": "common"` or `"rarity": "rare"`
- Add `"max_level": 3` to all common mutations
- Commons: `pierce`, `rapid_fire`, `big_shot`, `split_shot`, `skill_range`, `skill_cooldown`, `knockback`
- Rares: `ricochet`, `fire_trail`, `dash_damage`
- Rename `shockwave_radius` → `skill_range` (id change)
- Rename `shockwave_cooldown` → `skill_cooldown` (id change)
- Update params to match roadmap scaling:
  - `rapid_fire`: remove `fire_rate_mult: 2.0`, add `fire_rate_bonus_per_level: 0.333`
  - `big_shot`: remove `damage_mult: 1.5`, change `size_mult` to `size_bonus_per_level: 0.333`
  - `split_shot`: change `extra_count` from 2 to 1 (now +1 per level)
  - `skill_range`: `range_bonus_per_level: 0.333` (applies to ALL skills)
  - `skill_cooldown`: `cooldown_reduction_per_level: 0.333` (percentage-based, applies to ALL skills)
  - `knockback`: change to `force_bonus_per_level: 0.333` (base 300 → linear 33.3%)

**`scripts/game/MutationSystem.gd`:**
- Add `get_mutation_level(player_index, mutation_id) -> int` — counts how many times a mutation appears, capped at max_level
- Update `_is_stackable()` (line 133) — all commons are stackable (up to max_level 3), all rares are not
- Update `roll_mutation_options()` (line 105) — add `rarity_filter` parameter:
  - `"common"`: only roll from common pool (for combat room-end picks)
  - `"rare"`: only roll from rare pool (for elite room-end picks)
  - `"all"`: roll from both pools (for shop)
- **Fix pool exhaustion (critical):** The current fallback (line 123) blindly pads options by cycling all definitions, which would insert wrong-rarity mutations or duplicates. Replace with:
  - Filter pool by rarity first, THEN by eligibility (`_can_still_pick`)
  - If fewer valid options than `count` requested, return only the valid ones (do NOT pad)
  - The pick UI already handles fewer than 3 options visually — the "Done" card is always present
  - With only 3 rares total, a player who owns 2 rares should see only 1 option + Done
  - With all 3 rares owned, the elite room-end screen should show only Done (no picks available)
  - Shop rolls with `"all"` filter. If rares are exhausted but commons remain, the shop simply offers commons only — no special empty-state message needed. The pool filter already handles this naturally.
- Add `_can_still_pick(player_index, mutation_id) -> bool` — for commons: current level < max_level; for rares: not already owned
- Update `get_compiled_weapon_stats()` (line 63) to use new linear scaling:
  - `rapid_fire`: `fire_rate = base * (1.0 + level * 0.333)` instead of `pow(2.0, count)`
  - `big_shot`: `area = base * (1.0 + level * 0.333)`, remove damage bonus entirely
  - `split_shot`: `split_extra_count = level * 1` instead of `level * 2`
  - `knockback`: `force = 300.0 * (1.0 + level * 0.333)` instead of `300.0 * count`
- Update `get_primary_skill_radius_multiplier()` (line 96) to use `skill_range` id: `1.0 + level * 0.333`
- Update `get_primary_skill_cooldown_reduction()` (line 99) to use `skill_cooldown` id: percentage-based `level * 0.333` (multiply against base cooldown, not flat reduction)

**`scripts/game/CoopManager.gd`:**
- Update `_build_primary_skill_runtime_stats()` (line 277):
  - Reference new `skill_range` and `skill_cooldown` ids instead of `shockwave_radius` and `shockwave_cooldown`
  - **Change the cooldown formula from flat subtraction to percentage-based multiplication.** Current code (line 281):
    ```
    var cooldown: float = maxf(0.5, float(base_stats.get("cooldown", 8.0)) - _mutation_system.get_primary_skill_cooldown_reduction(player_index))
    ```
    Replace with:
    ```
    var cooldown_reduction_pct: float = _mutation_system.get_primary_skill_cooldown_reduction(player_index)
    var cooldown: float = maxf(0.5, float(base_stats.get("cooldown", 8.0)) * (1.0 - cooldown_reduction_pct))
    ```
    Where `get_primary_skill_cooldown_reduction()` now returns `level * 0.333` (a 0.0–1.0 fraction). At Lv3 (0.999), base 5.0s cooldown → ~0.5s (clamped). This matches the roadmap's "66.6% faster cooldowns" at Lv3.

**Known UX gap (accepted):** `PlayerInventoryHUD._update_mutation_icons()` (line 87) renders one chip per mutation entry in the inventory array. With upgradable commons, Lv2 Pierce will show as two Pierce chips and Lv3 as three. This is cosmetically incorrect but not a gameplay blocker. A proper "single chip with level badge" fix is deferred to a HUD polish pass. The plan accepts this gap for now.

**Verification:** Parse check. Start run, pick mutations, confirm they upgrade (Lv1→2→3). Confirm rares don't appear in normal room-end picks. Confirm scaling matches roadmap formulas. Confirm shop doesn't offer already-owned rares. (Elite-specific exhaustion behavior is verified in Slice 3, not here.)

---

## Slice 3: Elite Room Rare-Only Picks (Tier 4)

**Goal:** Elite rooms offer exactly 1 rare mutation at room-end (buy or skip). Combat rooms offer commons only (buy 0–3).

### Files to modify

**`scripts/game/CoopManager.gd`:**
- Update `_show_mutation_pick()` (line 1064):
  - **Fix signal connect order:** move `_mutation_pick_ui.selections_confirmed.connect(...)` (currently line 1074) to BEFORE `configure_for_players()` (currently line 1073). The auto-confirm path can emit during configure, so the listener must already be connected. Current order is configure → connect → add_child. New order: connect → configure → add_child.
  - If `_room_type == "elite"`:
    - Roll 1 rare option per player: `_mutation_system.roll_mutation_options(player_index, 1, "rare")`
    - Pass single-element array to `MutationPickUI`
    - Use a separate cost array for elite picks: `[ELITE_RARE_PICK_COST]` (1 pick max, not 3)
    - Add `const ELITE_RARE_PICK_COST := 50` (placeholder, subject to balance)
  - If `_room_type == "combat"`: pass `"common"` rarity filter, keep existing 3-pick flow
- If the rare pool is exhausted for a player (all 3 rares owned), that player should be **auto-confirmed** so they don't block the other player on the shared pick screen. Passing 0 options produces a Done-only panel, which is correct visually.

**`scripts/game/MutationSystem.gd`:**
- Ensure `roll_mutation_options()` respects the rarity filter (done in Slice 2)
- With `count: 1` and `"rare"` filter: returns 0 or 1 options (0 if all rares owned)

**`scripts/ui/MutationPickUI.gd`:**
- Must handle receiving only 1 option (currently builds cards per option — works naturally)
- The pick UI shows 1 rare card + Done card (buy this rare or skip)
- Add auto-confirm for exhausted players: after `_build()` and `_refresh_panels()` in `configure_for_players()`, iterate all players and auto-confirm any whose options array is empty:
  ```
  for idx in range(_player_configs.size()):
      if (_options_by_player[idx] as Array).is_empty():
          _confirmed[idx] = true
  _refresh_panels()
  if _all_confirmed():
      call_deferred("emit_signal", "selections_confirmed", _build_final_selections())
  ```
  This keeps the logic inside `MutationPickUI` instead of having CoopManager reach into UI internals. The `call_deferred` ensures the emit happens after the current call stack completes, so the signal fires after CoopManager has finished setting up the pick UI (safety belt even though CoopManager now connects the signal before calling configure). If ALL players are exhausted (e.g., both own all 3 rares), the screen emits on the next frame with empty selections.
- Optional: rare mutation cards get a gold border color to distinguish from commons
- Optional: header label says "Elite Reward" instead of "Mutations"

**Verification:** Parse check. Clear a combat room → see 3 common picks. Clear an elite room → see exactly 1 rare pick + Done. Confirm rares are binary (can't pick same rare twice). Confirm with all 3 rares owned, the exhausted player's panel shows Done-only and is auto-confirmed (does not block the other player). If both players are exhausted, the pick screen emits immediately with empty selections.

---

## Slice 4: Spitter Enemy (Tier 5 prerequisite)

**Goal:** Add the Spitter enemy type to `Enemy.gd` and the spawn system.

### Files to modify

**`scripts/enemies/Enemy.gd`:**
- Add `SPITTER` to `EnemyType` enum (line 19): `CHASER, CHARGER, SPITTER, BOSS`
- Add `"spitter"` case to `setup()` (after line 103):
  ```
  "spitter":
      enemy_type = EnemyType.SPITTER
      max_health = 30  # between Chaser (21) and Charger (40)
      move_speed = 312.0  # player (390) * 0.8 = 312
      fire_interval = 0.5
      projectile_speed = 340.0
      projectile_damage = 10  # same as Chaser contact damage
      contact_damage = 8  # low, it's ranged
      preferred_distance = 350.0  # stays at range
      _projectile_burst_count = 1
      _projectile_spread_radians = 0.0
      _projectile_visual_scale = 0.8
  ```
- Add `_update_spitter_behavior()` function:
  - If distance < 180: retreat (move away from player at full speed)
  - If distance > preferred_distance + 50: approach
  - If distance is in comfort zone: circle player (perpendicular movement)
  - Fire projectile at player on `fire_interval` timer (reuse existing `_emit_projectile_burst()`)
- Update `_physics_process()` match block (line 241) to add `EnemyType.SPITTER` case calling `_update_spitter_behavior()`
- Add `_apply_type_visual()` case for SPITTER (after line 506):
  - Color: `Color(0.85, 0.35, 0.85, 1.0)` (magenta)
  - Polygon: hexagon shape, scale ~1.0 (between Chaser 0.78 and Charger 1.28)
  - Collision radius: ~22.0
  - Contact range: ~30.0
- Update `get_type_name()` (line 193) to return `"spitter"` for `SPITTER`
- Update `get_feedback_weight()` (line 184) to return `~1.1` for SPITTER

**`scripts/game/CoopManager.gd`:**
- Update `GOLD_DROP_PER_ENEMY` to also cover spitter (already flat 1g from Slice 1, no change needed)
- Update `_roll_wave_enemy_type()` (line 486): add spitter to the default mixed spawn pool at a low base rate (e.g., 10% chance alongside existing chaser/charger distribution). The `spitter_swarm` modifier will override this to 50% in Slice 5.

**Verification:** Parse check. Start a run, confirm Spitters spawn. Confirm they shoot projectiles, kite away, circle. Confirm gold drop is 1g.

---

## Slice 5: Modifier System (Tier 5)

**Goal:** Implement the full modifier architecture — data, run generation, room application, and all 6 modifiers.

### Sub-slice 5a: Modifier Data + Run Generation

**New file: `data/modifiers.json`:**
```json
{
  "modifiers": [
    {
      "id": "accelerating_waves",
      "name": "Accelerating Waves",
      "category": "minor",
      "gold_bonus": 0.15,
      "description": "Enemy waves accelerate over time."
    },
    {
      "id": "enemy_faster",
      "name": "Enemy Speed",
      "category": "minor",
      "gold_bonus": 0.15,
      "description": "Enemies move and attack 33% faster."
    },
    {
      "id": "spitter_swarm",
      "name": "Spitter Swarm",
      "category": "minor",
      "gold_bonus": 0.15,
      "description": "Ranged enemies dominate the spawn pool."
    },
    {
      "id": "fire_floor",
      "name": "Fire Floor",
      "category": "major",
      "gold_bonus": 0.3,
      "description": "Arena quadrants periodically ignite."
    },
    {
      "id": "ice_zone",
      "name": "Ice Zone",
      "category": "major",
      "gold_bonus": 0.3,
      "description": "Arena quadrants periodically freeze."
    },
    {
      "id": "mine_field",
      "name": "Mine Field",
      "category": "major",
      "gold_bonus": 0.3,
      "description": "Mines spawn in rotating quadrants."
    }
  ],
  "valid_combat_combinations": [
    [],
    ["accelerating_waves"],
    ["enemy_faster"],
    ["spitter_swarm"],
    ["fire_floor"],
    ["ice_zone"],
    ["mine_field"],
    ["accelerating_waves", "fire_floor"],
    ["accelerating_waves", "ice_zone"],
    ["accelerating_waves", "mine_field"],
    ["enemy_faster", "fire_floor"],
    ["enemy_faster", "ice_zone"],
    ["enemy_faster", "mine_field"],
    ["spitter_swarm", "fire_floor"],
    ["spitter_swarm", "ice_zone"],
    ["spitter_swarm", "mine_field"]
  ],
  "valid_elite_combinations": [
    ["accelerating_waves", "fire_floor"],
    ["accelerating_waves", "ice_zone"],
    ["accelerating_waves", "mine_field"],
    ["enemy_faster", "fire_floor"],
    ["enemy_faster", "ice_zone"],
    ["enemy_faster", "mine_field"],
    ["spitter_swarm", "fire_floor"],
    ["spitter_swarm", "ice_zone"],
    ["spitter_swarm", "mine_field"],
    ["accelerating_waves", "enemy_faster", "fire_floor"],
    ["accelerating_waves", "enemy_faster", "ice_zone"],
    ["accelerating_waves", "enemy_faster", "mine_field"],
    ["accelerating_waves", "spitter_swarm", "fire_floor"],
    ["accelerating_waves", "spitter_swarm", "ice_zone"],
    ["accelerating_waves", "spitter_swarm", "mine_field"],
    ["enemy_faster", "spitter_swarm", "fire_floor"],
    ["enemy_faster", "spitter_swarm", "ice_zone"],
    ["enemy_faster", "spitter_swarm", "mine_field"]
  ]
}
```

**`scripts/game/RunState.gd`:**
- Add modifier assignment to `_build_map_node()` (line 301):
  - Add `"modifiers": []` field to each node dictionary
- Add `_assign_modifiers_to_map()` after `_link_rows()` in `_generate_node_map()` (line 275):
  - Load both combination lists from `data/modifiers.json`
  - For each `combat` node: pick randomly from `valid_combat_combinations` (includes empty = no modifiers)
  - For each `elite` node: pick randomly from `valid_elite_combinations` (all entries have 1 major; entries with 2 minors + 1 major satisfy the "1–2 minor + 1 major" rule)
  - For `rest`, `shop`, `boss` nodes: no modifiers (empty array)
- Add `_load_modifiers()` to load modifier definitions from JSON
- Pass modifier list through to `configure_room()` in the room config dictionary

**`scripts/ui/RunFlow.gd` — Map Modifier Display:**
- Update `_build_node_button_text()` (line 129): append modifier count to button text if the node has modifiers. Example: `"Elite [2]"` or `"Survive [1]"`. Nodes with no modifiers show no suffix.
- Update `_on_map_node_hovered()` (line 168): add modifier names to the detail panel body text. Current body is `"%s\nObjective: %s"`. Extend with modifier list:
  ```
  var modifiers: Array = node.get("modifiers", [])
  var mod_names: String = ""
  if not modifiers.is_empty():
      var names: Array = []
      for mod_id in modifiers:
          names.append(_format_modifier_name(str(mod_id)))
      mod_names = "\nModifiers: %s" % ", ".join(names)
  map_detail_body_label.text = "%s\nObjective: %s%s" % [
      str(node.get("description", "")),
      _format_objective(str(node.get("objective", "survive"))),
      mod_names,
  ]
  ```
- Add `_format_modifier_name(mod_id: String) -> String` helper that returns human-readable names (e.g., `"accelerating_waves"` → `"Accelerating Waves"`, `"fire_floor"` → `"Fire Floor"`). Can either load from `data/modifiers.json` or use a simple match/replace on underscores + capitalize.

**Verification:** Parse check. Start a run, inspect map — nodes with modifiers show count on button text. Hovering a node with modifiers shows their names in the detail panel. Nodes without modifiers show no modifier text.

### Sub-slice 5b: Encounter Builder Modifier Support

**Must come before 5c–5g** so that all subsequent modifier sub-slices can be tested via the encounter builder. Without this, there is no debug injection path for modifiers.

**`scripts/ui/Bootstrap.gd`:**
- Add modifier selection to encounter builder UI
- Allow selecting 0–3 modifiers from dropdown/checkbox list
- Pass selected modifiers into room config

**Verification:** Parse check. Encounter builder can launch rooms with any modifier combination. Modifiers appear in room config (print to confirm).

### Sub-slice 5c: Minor Modifiers (Runtime)

**`scripts/game/CoopManager.gd`:**
- Read modifiers from `_room_config.get("modifiers", [])` in `_start_room()` (line 382)
- Store active modifiers in `var _active_modifiers: Array = []`
- Calculate additive gold multiplier: `_room_gold_multiplier = 1.0 + sum of all modifier gold_bonus values`
  - Replace the current `1.3 if elite else 1.0` with this (line 397)
  - The elite room's gold bonus comes from its modifiers now, not a hardcoded 1.3

**`scripts/game/CoopManager.gd` — Arena Modifier HUD (top-right):**
- Add `var _modifier_hud: VBoxContainer = null` to instance vars
- In `_build_hud()` (line 174), after the timer panel and before player HUDs: build a modifier chip container in the top-right:
  ```
  _modifier_hud = VBoxContainer.new()
  _modifier_hud.position = Vector2(1600.0, 24.0)
  _modifier_hud.add_theme_constant_override("separation", 6)
  _modifier_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _hud_root.add_child(_modifier_hud)
  ```
- Add `_populate_modifier_hud()` called from `_start_room()` after `_active_modifiers` is set:
  - Clear all children of `_modifier_hud`
  - For each active modifier id, create a small chip (PanelContainer with Label):
    ```
    var chip := PanelContainer.new()
    chip.custom_minimum_size = Vector2(0.0, 28.0)
    chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = _get_modifier_chip_color(mod_id)
    style.set_border_width_all(1)
    style.border_color = _get_modifier_chip_color(mod_id).lightened(0.3)
    style.corner_radius_top_left = 4
    style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 4
    style.corner_radius_bottom_right = 4
    style.set_content_margin_all(6)
    chip.add_theme_stylebox_override("panel", style)
    var lbl := Label.new()
    lbl.text = _format_modifier_display_name(mod_id)
    lbl.add_theme_font_size_override("font_size", 14)
    chip.add_child(lbl)
    _modifier_hud.add_child(chip)
    ```
  - If `_active_modifiers` is empty, leave `_modifier_hud` empty (no chips)
- Add `_get_modifier_chip_color(mod_id: String) -> Color`:
  - Minor modifiers: `Color(0.85, 0.65, 0.2, 0.6)` (amber)
  - Major modifiers: `Color(0.85, 0.25, 0.2, 0.6)` (red)
  - Determine category from loaded modifier definitions or a simple match on id
- Add `_format_modifier_display_name(mod_id: String) -> String`: same underscore-to-title-case helper as RunFlow
- Remove the stale `"ModifierStatus"` hide reference from the old UI cleanup block (line 161)

**`accelerating_waves` implementation:**
- Add `var _accelerating_waves_active := false` state var
- Apply the multiplier **when the next spawn interval is set**, NOT each frame on the remaining countdown. The current room loop (line 462–465) decrements `_spawn_cooldown_remaining` every frame and only resets it after a spawn:
  ```
  _spawn_cooldown_remaining -= delta
  if _spawn_cooldown_remaining <= 0.0:
      _spawn_enemy_wave()
      _spawn_cooldown_remaining = maxf((0.55 - float(_room_depth) * 0.03) * 0.5, 0.09)
  ```
  Modify the reset line (line 465) only — after the base interval is computed, multiply it by the acceleration factor:
  ```
  var base_interval := maxf((0.55 - float(_room_depth) * 0.03) * 0.5, 0.09)
  if _accelerating_waves_active:
      var elapsed := SURVIVE_DURATION - _room_timer_remaining
      var accel_mult := maxf(1.0 - (minf(elapsed, 40.0) / 40.0) * 0.67, 0.33)
      base_interval *= accel_mult
  _spawn_cooldown_remaining = base_interval
  ```
  This way the multiplier is applied once per spawn cycle to the next interval, not compounded every frame on the remaining timer.

**`enemy_faster` implementation:**
- After spawning each enemy in `_spawn_enemy_wave()` (line 468), if `enemy_faster` is active:
  - Call `enemy.apply_room_modifier(0, 1.33, 1.0 / 1.33, 0.0, 0, 0)` — 1.33x speed, 1/1.33 fire interval (faster attacks)
  - Note: `apply_room_modifier()` already exists on `Enemy.gd` (line 133) and supports speed/fire_interval multipliers

**`spitter_swarm` implementation:**
- Add `var _spitter_swarm_active := false` state var
- Update `_roll_wave_enemy_type()` (line 486):
  - If `_spitter_swarm_active`: 25% chaser, 25% charger, 50% spitter
  - Else: use existing depth-based logic (add spitter at base low rate from Slice 4)

**Verification:** Parse check. Test each minor modifier via encounter builder. Confirm accelerating waves speed up over time. Confirm enemy_faster makes enemies noticeably faster. Confirm spitter_swarm changes spawn mix.

### Sub-slice 5d: Major Modifiers — Fire Floor

**New file: `scripts/modifiers/FireFloorModifier.gd`:**
- Class that manages 4 quadrant fire zones
- Quadrants split the arena: top-left, top-right, bottom-left, bottom-right (each `ARENA_SIZE / 2`)
- Cycle: 10 seconds total (1s ignition → 8s burn → 1s extinguish, repeat)
- During burn phase: check player positions every 0.5s, apply 5 damage to players inside fire zones
- Visual: Red `ColorRect` overlays on active quadrants with alpha transitions for ignite/extinguish
- Does NOT affect enemies (environmental hazard rule)

**`scripts/game/CoopManager.gd`:**
- In `_start_room()`: if `fire_floor` in active modifiers, instantiate `FireFloorModifier` and add as child of the arena
- In `_physics_process()`: fire modifier updates itself via `_process()` or `_physics_process()`
- Pass player node references to the modifier so it can apply damage
- Clean up modifier on room end in `_clear_runtime_nodes()`

**Verification:** Parse check. Test fire_floor in encounter builder. Confirm quadrants light up on cycle. Confirm 5 damage per 0.5s tick. Confirm enemies are unaffected.

### Sub-slice 5e: Major Modifiers — Ice Zone

**New file: `scripts/modifiers/IceZoneModifier.gd`:**
- Same quadrant layout as fire floor
- Cycle: 10 seconds (1s formation → 8s freeze → 1s melt)
- During freeze phase: players inside zones get 33% move speed and 33% attack speed reduction
- Visual: Blue `ColorRect` overlays with alpha transitions
- Implementation: modify player `move_speed` and weapon `fire_interval` while inside zone, restore when outside
- Does NOT affect enemies

**`scripts/game/CoopManager.gd`:**
- Same instantiation pattern as fire floor
- Each physics frame, IceZoneModifier reports which players are inside frozen zones
- CoopManager calls `player.apply_zone_modifier("ice_zone", 0.67, 0.67)` for players inside, `player.clear_zone_modifier("ice_zone")` for players outside (uses Slice 0b source-keyed modifier API)
- Stacking with elite_support debuff is handled automatically — each source writes to its own key in the player's modifier Dictionaries. Clearing `"ice_zone"` does not affect `"elite_support"` and vice versa.

**Verification:** Parse check. Test ice_zone in encounter builder. Confirm slow applies inside zones. Confirm normal speed restores outside zones. Confirm enemies unaffected. Confirm applying/clearing does not permanently alter base stats.

### Sub-slice 5f: Major Modifiers — Mine Field

**New file: `scripts/modifiers/MineFieldModifier.gd`:**
- Manages rotating quadrant mine spawns
- 2 of 4 quadrants active per cycle, rotating: Cycle 1 → Q1+Q2, Cycle 2 → Q2+Q3, etc.
- 5 mines per active quadrant (10 total)
- Cycle: 10 seconds (1s spawn anim → 8s active → 1s despawn)
- Mine activation: player enters trigger radius → 0.5s delay → explode → 10 damage
- Visual: each mine has a light ring that pulses during active phase, flash during 0.5s detonation delay
- Does NOT affect enemies

**New file: `scripts/modifiers/Mine.gd`:**
- Simple Node2D with:
  - `var _armed := false`
  - `var _detonating := false`
  - `var _detonate_timer := 0.0`
  - Trigger radius check against players (distance-based, no Area2D needed — parent modifier handles it)
  - Visual: small circle + light ring line
  - On detonation: apply 10 damage to players in explosion radius, play flash effect, queue_free

**`scripts/game/CoopManager.gd`:**
- Same instantiation pattern as fire/ice modifiers

**Verification:** Parse check. Test mine_field in encounter builder. Confirm mines spawn in 2 quadrants. Confirm quadrants rotate each cycle. Confirm 0.5s detonation delay. Confirm 10 damage. Confirm enemies unaffected.

---

## Slice 6: Elite Mini-Bosses (Tier 6)

**Goal:** Add 3 elite mini-boss enemy types and spawn them in elite rooms.

### Files to modify

**`scripts/enemies/Enemy.gd`:**
- Add to `EnemyType` enum: `ELITE_CHARGER, ELITE_SPITTER, ELITE_SUPPORT`
- Add `setup()` cases for each:

**`elite_charger` setup:**
```
max_health = 1440
move_speed = 371.25
contact_damage = 15
fire_interval = 0.0  # melee only
projectile_speed = 0.0
projectile_damage = 0
preferred_distance = 0.0
```

**`elite_spitter` setup:**
```
max_health = 576
move_speed = 312.0  # same as Spitter
contact_damage = 8
fire_interval = 0.33
projectile_speed = 340.0
projectile_damage = 10
preferred_distance = 400.0
_projectile_burst_count = 3
_projectile_spread_radians = 0.18
_projectile_visual_scale = 0.9
```

**`elite_support` setup:**
```
max_health = 900
move_speed = 280.0
contact_damage = 5
fire_interval = 2.0  # AoE pulse interval
projectile_speed = 0.0
projectile_damage = 0
preferred_distance = 250.0  # maintains 200-300 range
```

- Add `_update_elite_charger_behavior()`:
  - Hybrid of chaser lunge + charger charge
  - Uses chaser-level speed (371.25)
  - Alternates between charge attacks and slam attacks
  - Charge: same as charger but faster windup (0.12s vs 0.18s) and longer dash
  - Slam: AoE damage in small radius on arrival

- Add `_update_elite_spitter_behavior()`:
  - Same kiting behavior as spitter
  - Fires 3-projectile bursts at 0.33s interval
  - Every 4 seconds: emit AoE energy pulse (radius 200, push + 10 damage)
  - AoE pulse: iterate players, check distance, apply damage + knockback

- Add `_update_elite_support_behavior()`:
  - Positioning: maintain 200–300 distance from nearest player
  - If player outside 400 range: advance
  - If player inside 100 range: retreat
  - Otherwise: circle
  - Every 2 seconds: AoE pulse (radius 400):
    - Damage players: 15
    - Heal allies: 20 HP (iterate nearby enemies, add health up to max)
  - Continuous aura (radius 300): applied per-frame to nearby entities
    - Must communicate with CoopManager or directly modify enemy/player stats

- Add `_apply_type_visual()` cases:
  - `elite_charger`: Yellow hexagon (`Color(1.0, 0.85, 0.15, 1.0)`), scale 2.5x charger, internal cross/star pattern, collision radius ~65
  - `elite_spitter`: Cyan hexagon (`Color(0.2, 0.85, 0.95, 1.0)`), scale ~1.6, energy ring detail, collision radius ~35
  - `elite_support`: Purple hexagon (`Color(0.7, 0.25, 0.9, 1.0)`), scale ~1.8, swirl detail, collision radius ~42

- Update `get_type_name()`, `get_feedback_weight()`, `get_feedback_color()` for new types
- Update `is_boss()` — elite mini-bosses are NOT bosses (they don't end the room on death)

**`scripts/game/CoopManager.gd`:**
- Update `_start_room()`: if `_room_type == "elite"`, spawn 1 random mini-boss at room start
- Add `_spawn_elite_miniboss()`:
  - Pick random from `["elite_charger", "elite_spitter", "elite_support"]`
  - Spawn at arena center offset (like boss spawn position but slightly varied)
  - Connect same signals as regular enemies
- Mini-boss spawns ONCE at room start, not repeatedly via waves
- Regular waves continue alongside the mini-boss

**`scripts/enemies/Enemy.gd` — new reversible aura API:**
- **Problem:** The existing `apply_room_modifier()` (line 133) is one-shot and resets `current_health = max_health`. It cannot be used for a per-frame aura because it would full-heal enemies every tick and permanently bake speed buffs.
- **Solution:** Add a separate reversible aura system on Enemy:
  ```
  var _aura_speed_modifier: float = 1.0
  var _aura_attack_modifier: float = 1.0
  var _base_move_speed: float = 0.0       # set once in setup(), after apply_room_modifier()
  var _base_fire_interval: float = 0.0    # set once in setup(), after apply_room_modifier()

  func apply_aura(speed_mult: float, attack_mult: float) -> void:
      _aura_speed_modifier = speed_mult
      _aura_attack_modifier = attack_mult
      move_speed = _base_move_speed * _aura_speed_modifier
      fire_interval = _base_fire_interval / _aura_attack_modifier

  func clear_aura() -> void:
      _aura_speed_modifier = 1.0
      _aura_attack_modifier = 1.0
      move_speed = _base_move_speed
      fire_interval = _base_fire_interval
  ```
- In `setup()`: after all stat assignment, store `_base_move_speed = move_speed` and `_base_fire_interval = fire_interval`
- In `apply_room_modifier()`: after modifying stats, update the base vars too so aura stacks correctly on top of room modifiers

**`scripts/game/CoopManager.gd` — elite_support aura orchestration:**
- Add `var _aura_buffed_enemies: Array = []` and `var _aura_debuffed_players: Array = []` tracking sets
- In `_physics_process()` add `_update_elite_support_auras()`:
  - Find all living `elite_support` enemies in `_enemy_nodes`
  - For each enemy within 300 radius of a support: call `enemy.apply_aura(1.33, 1.33)`; add to tracking set
  - For each enemy NOT in any support's radius AND in tracking set: call `enemy.clear_aura()`; remove from set
  - For each player within 300 radius of a support: call `player.apply_zone_modifier("elite_support", 0.67, 0.67)` (uses Slice 0b source-keyed API)
  - For each player NOT in any support's radius AND in debuff set: call `player.clear_zone_modifier("elite_support")`; remove from set
  - When elite_support dies: iterate all tracked entities and clear aura/modifier
- Stacking with ice_zone is handled automatically by the source-keyed modifier model from Slice 0b. Each source has its own key in the player's modifier Dictionaries. `_combined_modifier()` multiplies all active sources together (ice_zone 0.67 × elite_support 0.67 = 0.45). Clearing one source does not affect the other.

**Verification:** Parse check. Test each mini-boss type via encounter builder (set room type to elite). Confirm elite_charger charges and slams. Confirm elite_spitter fires bursts and AoE pulses. Confirm elite_support heals allies and debuffs players. Confirm mini-boss spawns in normal elite runs.

---

## Slice 7: Hold Zone Side Objective + Temp Buffs (Tier 3)

**Goal:** Add Hold Zone side objective to all combat/elite rooms with a random temporary buff reward.

### New files

**`scripts/objectives/HoldZoneObjective.gd`:**
- Node2D that manages the hold zone
- Properties:
  - `const HOLD_DURATION := 10.0` — total time required
  - `const ZONE_RADIUS := 180.0` — zone radius (placeholder)
  - `var _hold_progress := 0.0` — accumulated hold time
  - `var _is_complete := false`
  - `var _zone_position := Vector2.ZERO` — arena position
- `setup(arena_rect: Rect2)`:
  - Pick a random position inside the arena (away from center, away from walls)
  - Draw the zone visual
- `update_zone(delta: float, player_nodes: Array)`:
  - Check if ANY living player is inside zone radius (distance-based)
  - If yes: `_hold_progress += delta` (co-op — multiple players don't speed it up)
  - If no: timer pauses (does not reset, does not count down)
  - Enemy presence is IRRELEVANT — timer only cares about player presence
  - If `_hold_progress >= HOLD_DURATION`: mark complete, emit signal
- Visual:
  - Glowing circle on the floor (green/teal outline ring)
  - Fill color transitions as progress increases (empty → full)
  - Completion flash effect when done

**`scripts/buffs/TempBuffSystem.gd`:**
- RefCounted class managing active temporary buffs
- Buff pool: `["speed", "damage", "attack_speed"]`
- Buff values: `{"speed": 0.5, "damage": 0.5, "attack_speed": 0.5}` (all +50%)
- `roll_random_buff() -> Dictionary` — returns `{"type": "speed", "value": 0.5}` (random from pool)
- `apply_buff(buff: Dictionary, player_nodes: Array)`:
  - Applies the buff to all living players **through the Slice 0b reversible stat API only**
  - Calls `player.apply_temp_buff(buff.type, buff.value)` on each living player
  - Does NOT directly mutate `move_speed`, `weapon_fire_interval`, or `projectile_damage` — those are computed by `_recompute_effective_stats()` inside Player
  - This ensures buffs stack correctly with zone modifiers (ice_zone, elite_support debuff) and can be cleanly removed
- `clear_all_buffs(player_nodes: Array)`:
  - Calls `player.clear_temp_buffs()` on each player (resets `_buff_*` vars to 1.0 and recomputes)
  - Called on room transition (room end / exit zone)
- Buff persists through player death/revive within the same room
- Buff does NOT persist between rooms

### Files to modify

**`scripts/player/Player.gd`:**
- Uses the `apply_temp_buff()` and `clear_temp_buffs()` API from Slice 0b
- The `_buff_move_speed`, `_buff_damage`, `_buff_attack_speed` modifier vars are already in place
- `_recompute_effective_stats()` already multiplies buff modifiers with base stats and zone modifiers
- No additional Player.gd changes needed for this slice

**`scripts/game/CoopManager.gd`:**
- Add `var _hold_zone: Node2D = null` and `var _temp_buff_system = null`
- In `_start_room()` (line 382):
  - For combat and elite rooms: instantiate `HoldZoneObjective`, add to arena, store reference
  - Instantiate `TempBuffSystem`
  - Roll which buff is on offer, store it
- In `_physics_process()` / `_update_room()`:
  - Call `_hold_zone.update_zone(delta, _player_nodes)` if zone exists and not complete
- On hold zone complete signal:
  - Apply the pre-rolled buff via `_temp_buff_system.apply_buff()` to all players
  - Show brief HUD notification ("Speed Boost!" etc.)
  - Optionally rebuild loadouts if damage/attack speed buff requires recompilation
- In `_end_active_encounter()` (line 1096) and `_close_shop()` (line 792):
  - Call `_temp_buff_system.clear_all_buffs(_player_nodes)` to remove buffs on room exit
  - Clean up hold zone node
- In `_clear_runtime_nodes()` (line 411):
  - Free hold zone if it exists

**`scripts/game/RunState.gd`:**
- Add `"side_objective": "hold_zone"` to `_build_map_node()` (line 301) for all combat and elite rooms
- Do NOT store `buff_on_offer` here — CoopManager is the single owner of buff rolling. The buff is rolled at room start in `_start_room()`, not at run generation. This avoids two competing sources of truth.

**HUD updates in `CoopManager.gd`:**
- Add hold zone progress indicator to combat HUD:
  - Small bar or text showing "Hold Zone: 6.2/10.0s"
  - Changes to "Buff Active: Speed +50%!" after completion
- Position near timer bar area (top-center)

**Verification:** Parse check. Start a run. Confirm hold zone appears in combat rooms. Confirm timer counts when player stands in zone. Confirm timer pauses when player leaves zone. Confirm multiple players in zone don't double-count. Confirm enemies don't affect timer. Confirm buff applies on completion. Confirm buff persists through death/revive. Confirm buff clears on room transition.

---

## Implementation Order Summary

| Order | Slice | Tier | Dependencies | Estimated Scope |
|---|---|---|---|---|
| 0 | Prerequisites | — | None | Small — fix elite debug path + add Player stat modifier layer |
| 1 | Economy Flatten | 1+5 | None | Small — constant changes + text |
| 2 | Mutation Rarity | 2 | None | Medium — data restructure + scaling formulas + pool exhaustion handling |
| 3 | Elite Rare Picks | 4 | Slice 0 (elite debug), Slice 2 | Small — filter parameter in pick flow |
| 4 | Spitter Enemy | 5 | Slice 1 (gold) | Medium — new enemy type + AI behavior |
| 5 | Modifier System | 5 | Slice 0 (Player stat layer), Slice 4 (spitter) | Large — 6 modifiers, data, run gen, 3 new scripts |
| 6 | Elite Mini-Bosses | 6 | Slice 0 (Player stat layer + Enemy aura API), Slice 4, Slice 5 | Large — 3 new AI behaviors, aura system |
| 7 | Hold Zone + Temp Buffs | 3 | Slice 0 (Player stat layer) | Medium — 1 objective type, buff system, HUD |

**Notes:**
- **Slice 0 is a hard prerequisite** — it unblocks elite room testing (Slices 3, 5, 6) and the source-keyed reversible stat modifier layer (Slices 5e ice_zone, Slice 6 elite_support aura, Slice 7 temp buffs)
- Slices 1–2 can run in parallel with Slice 0 (no dependency)
- Slice 3 depends on both Slice 0 and Slice 2
- Slice 5 is the largest and should be broken into sub-slices 5a–5f, with **5b (encounter builder modifier support) before 5c–5f** so modifiers can be tested as they are built
- Slice 6 elite_support aura requires a new reversible `apply_aura()`/`clear_aura()` API on Enemy.gd — do NOT reuse the existing `apply_room_modifier()` which resets health
- Ice_zone (5e) and elite_support debuff (6) both use the source-keyed modifier model from Slice 0b — each source writes to its own key, clearing one does not affect the other, stacking is multiplicative
- Slice 2 changes the cooldown formula in both MutationSystem (percentage return instead of flat) AND CoopManager (multiply instead of subtract) — both must change together
- Slice 3: exhausted rare pool → `MutationPickUI` auto-confirms players with empty options internally (after `_build()` in `configure_for_players()`), NOT skip the screen. CoopManager does NOT reach into UI internals.
- Slice 7 TempBuffSystem applies buffs exclusively through `player.apply_temp_buff()` / `player.clear_temp_buffs()` — does NOT directly mutate player stats
- HUD level display for upgradable commons is an accepted UX gap (Lv2 shows as 2 chips) — deferred to a polish pass
- Slice 7 (Hold Zone + temp buffs) is now medium scope (1 objective type instead of 3) and can be done last
- Each slice must pass headless parse check before moving to the next
- All numerical values are placeholder and subject to balance tuning
