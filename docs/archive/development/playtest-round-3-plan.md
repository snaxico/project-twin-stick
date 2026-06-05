# Playtest Round 3 — Implementation Plan

## Context

Third playtest of `v3/main` (2026-06-02), after round-2 fixes landed. Seven findings, all active — none deferred this round.

Target branch: `v3/main` in `D:\GameDev\Project_Twin_stick`. Player max HP is `50` (default).

Status: implemented on `v3/main` and parse-clean as of 2026-06-02. Follow-up also added main-menu keyboard/controller binding settings after the round-3 patch.

## Revision history

- **v1** initial plan.
- **v2** (this revision) — code review corrections:
  - **F4** boss speed table mislabeled: Hydra is stationary (line 225), Hive is moving at 100 (line 235), Pulsar is stationary (line 245). Hydra ↔ Hive swap corrected in the table; speed bump applies to Hive (100 → 125), Hydra stays at 0.
  - **F3** scope correction: V3 target is 1-2P per `current-state.md:9` and `start-of-day.md:29`; 3-4P is deferred. Plan now scopes F3 to "1-2P robust now, code parameterized for future 3-4P" — no 3-4P wiring this round.
  - **F6c** tooltip data source: `MutationSystem.gd` has no public `get_definition()`. Plan now uses the description that's already inside the dicts returned by `get_active_mutations()` — captured during the existing aggregation pass into the `counts` dict. No `MutationSystem` API change required.

## Decision summary (from `AskUserQuestion` panels)

| # | Decision |
|---|----------|
| F1 | Widen contact range, check ALL players, **+0.35s player-side invuln** after contact hit |
| F2 | "LT" / "RT" text labels above each slot bar in bottom HUD |
| F3 | Bottom HUD stays left-to-right; 1-2P robust now, parameterized for future 3-4P |
| F4 | **+25% movement speed** across the board (player + all enemies) |
| F5 | Remove `mutation_badge` from arena HUD card; mutations live only in pause Build HUD |
| F6 | Build HUD: weapon stats + rarity-styled mutation chips + derived-stats line |
| F7 | Menu picker: LT/RT labels + tint selected cards to match in-game HUD (no drag-drop) |

---

## Fix F1 — Reliable contact damage (Vampire Survivors / Brotato style)

**Problem:** `Enemy.gd._attempt_contact_damage` (line 471-486) only checks the enemy's `_target` (the nearest player from `_find_target`) at `collision_shape.radius + 20.0` distance. Misses fire when:
- Physics collision pushes the player out of range before the distance check runs (most common cause).
- An enemy is physically touching a non-nearest player in co-op.

**What to change:**

### Part A — Iterate all players + wider contact range (in `Enemy.gd`)

- `_get_contact_range()` (line 488-491): bump padding from `+20.0` → `+45.0`. Fallback when no `CircleShape2D`: `42.0` → `60.0`.
- Rewrite `_attempt_contact_damage(now: float)`:
  - Remove the `_target == null` early-return — instead iterate `get_tree().get_nodes_in_group("player_target")`.
  - For each player in range and alive, call `apply_damage` + `apply_knockback` (gated by `can_receive_damage()` as today).
  - Keep the per-enemy `_next_contact_at` cooldown — it still gates the *enemy's* swing rate.
  - Sketch:
    ```gdscript
    func _attempt_contact_damage(now: float) -> void:
        if now < _next_contact_at:
            return
        var tree := get_tree()
        if tree == null:
            return
        var any_hit := false
        var range_squared := _get_contact_range() * _get_contact_range()
        for candidate in tree.get_nodes_in_group("player_target"):
            if not is_instance_valid(candidate) or not (candidate is Node2D):
                continue
            if candidate.has_method("is_alive") and not candidate.is_alive():
                continue
            if global_position.distance_squared_to((candidate as Node2D).global_position) > range_squared:
                continue
            if not candidate.has_method("apply_damage"):
                continue
            var can_feedback := true
            if candidate.has_method("can_receive_damage"):
                can_feedback = bool(candidate.can_receive_damage())
            candidate.apply_damage(contact_damage)
            if can_feedback and candidate.has_method("apply_knockback"):
                var direction := ((candidate as Node2D).global_position - global_position).normalized()
                if direction.length() <= 0.0:
                    direction = Vector2.RIGHT
                candidate.apply_knockback(direction, _get_contact_knockback_force())
            any_hit = true
        if any_hit:
            _next_contact_at = now + (0.65 if is_boss() else 0.45)
    ```
- The `any_hit` gate means the cooldown only ticks when contact actually landed — if the player dashed out at the last frame, the enemy can re-attempt next physics tick instead of waiting 0.45s for nothing.

### Part B — Player-side invuln window (in `Player.gd`)

- Add state:
  - `const CONTACT_INVULN_DURATION := 0.35`
  - `var _contact_invuln_until: float = 0.0`
- In `apply_damage(amount)` (line 257-267): after the existing `_is_damage_immune` check, set `_contact_invuln_until = _current_time_seconds() + CONTACT_INVULN_DURATION` **only when amount > 0 and damage actually applied** (i.e. after the early-returns but before `current_health -= amount`).
- Extend `_is_damage_immune(now)` (line 379-385): add `if now < _contact_invuln_until: return true` to the immunity check chain.
- Net effect: every damage hit grants a 0.35s blanket invuln. Surround-by-many-enemies → first one lands, the rest tick during invuln and do nothing, then 0.35s later the next hit can land. VS/Brotato feel.
- This also naturally protects against multi-source damage (mine + sweep + contact on same frame).

**Files:** `scripts/enemies/Enemy.gd`, `scripts/player/Player.gd`

---

## Fix F2 — LT/RT labels above ability slots in bottom HUD

**Problem:** Players can't tell which ability is bound to LT vs RT from the in-game HUD.

**What to change in `CoopManager.gd._build_hud` (around line 368-400):**

- Each slot box (`slot_1_box`, `slot_2_box`) currently has structure: `Label → ProgressBar` (label shows ability name, set by `_refresh_bottom_hud`).
- Add a **new dedicated trigger label** above the existing label:
  ```gdscript
  var slot_1_trigger := Label.new()
  slot_1_trigger.text = "LT"
  slot_1_trigger.add_theme_font_size_override("font_size", 9)
  slot_1_trigger.add_theme_color_override("font_color", slot_1_color.lightened(0.25))
  slot_1_trigger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  slot_1_box.add_child(slot_1_trigger)
  slot_1_box.move_child(slot_1_trigger, 0)  # ensure it's the first child (top)
  ```
- Repeat for slot 2 with text "RT".
- New box order: `LT/RT trigger label → ability name label → cooldown progress bar`.
- Keep using existing `slot_1_color` / `slot_2_color` from `_get_slot_color(tint, slot_index)` so the LT/RT labels match the bar color.

**Files:** `scripts/game/CoopManager.gd`

---

## Fix F3 — HUD layout robust for 1-2P now, design-ready for 3-4P later

**Scope correction:** V3 is currently a **1-2 player** target per `docs/development/current-state.md:9` and `docs/development/start-of-day.md:29` (3-4P explicitly deferred). The main-menu ability picker also only builds 2 ability rows (`scripts/ui/Bootstrap.gd:359` — `for player_index in range(2):`). So this fix should:
- Make the 1-2P case look correct and centered today.
- Use scaling code patterns (parameterize by `_player_configs.size()`, no hardcoded "if 2 players" branches) so that when 3-4P is enabled later, the HUD code doesn't need a rewrite.
- **Not** ship 3-4P wiring (menu rows, input bindings, etc.) — that's a separate roadmap item.

**Problem (1-2P today):** Bottom HUD card width is fixed at `260px` (line 315). At 2P, cards center fine. The structure is robust, but uses several hardcoded numbers (card width, font size, separation) that would have to change if 4P ever lands.

**What to change in `CoopManager.gd._build_hud`:**

- Parameterize the values that would need to shrink at higher player counts, even if today they always evaluate to the 1-2P branch:
  ```gdscript
  var player_count := _player_configs.size()
  var card_width := 260.0 if player_count <= 2 else 200.0
  var card_separation := 14 if player_count <= 2 else 8
  var ability_font_size := 10 if player_count <= 2 else 9
  ```
- Use `card.custom_minimum_size = Vector2(card_width, 72.0)` instead of hardcoded 260.
- Apply `card_separation` to `_bottom_hud.add_theme_constant_override("separation", card_separation)` (currently 14).
- Apply `ability_font_size` to the ability-name labels.
- Keep `_bottom_hud.alignment = BoxContainer.ALIGNMENT_CENTER` (already set at line 272).

**Verification (1-2P only this round):**
- 1P: single card centers correctly, doesn't stretch.
- 2P: two cards center together, gap looks right.
- 3-4P scaling is **not** playtested this round — code paths exist for future use but are unreachable until menu wiring lands.

**Future work (not part of this plan):**
- Enable 3-4 player rows in `Bootstrap.gd._build_ability_rows` (change `range(2)` → `range(player_count)` with player count selectable in menu).
- Player count selection UI in main menu.
- Verify input mappings exist for P3/P4 in `project.godot`.

**Files:** `scripts/game/CoopManager.gd`

---

## Fix F4 — +25% movement speed across the board

**Problem:** Everything feels too slow.

**What to change:**

### Player (`scripts/player/Player.gd`)
- Line 30 export default: `move_speed: float = 390.0` → `488.0` (390 × 1.25)
- Line 67 `_base_move_speed: float = 390.0` → `488.0`
- `RunState.gd` line 232 `"move_speed": 390.0` (in `get_player_runtime_loadout_for`) → `488.0`

### Enemies (`scripts/enemies/Enemy.gd` _configure_* blocks, lines 125-245)
Bump every `move_speed = X` by 1.25× (rounded to nearest integer):

| Enemy | Line | Current | New |
|---|---|---|---|
| chaser | 125 | 120 | 150 |
| charger | 135 | 157 | 196 |
| spitter | 145 | 280 | 350 |
| splitter | 155 | 100 | 125 |
| splitter_mini | 165 | 200 | 250 |
| bomber | 175 | 80 | 100 |
| elite_charger | 185 | 175 | 219 |
| elite_spitter | 195 | 240 | 300 |
| elite_support | 205 | 160 | 200 |
| boss_warden | 215 | 130 | 162 |
| boss_hydra | 225 | **0** | **0** *(stationary turret, skip)* |
| boss_hive | 235 | **100** | **125** |
| boss_pulsar | 245 | 0 | 0 *(stationary teleporter, skip)* |

**Verification:** Run headless parse + a single-room debug to confirm no enemy gets stuck on collision because of the speed bump (unlikely at +25%, but worth eyeballing).

**Files:** `scripts/player/Player.gd`, `scripts/enemies/Enemy.gd`, `scripts/game/RunState.gd`

---

## Fix F5 — Remove mutation count from arena HUD

**Problem:** Mutation badge clutters the per-player card with redundant info (mutations are visible in Build HUD on pause).

**What to change in `CoopManager.gd._build_hud` (around line 348-353):**

- Delete the `mutation_badge` Label creation block entirely.
- Remove `"mutation_badge": mutation_badge` from the `_bottom_player_hud_cards.append({...})` dict (line 404).
- Find `_refresh_bottom_hud` (referenced at line 1153, defined at 1231 — verify exact line) and remove any code that reads/writes the `mutation_badge` entry.
- Top row of card then contains only the `P#` header — let it `size_flags_horizontal = SIZE_EXPAND_FILL` and re-center the text.

**Files:** `scripts/game/CoopManager.gd`

---

## Fix F6 — Build HUD improvements

**Problem:** Pause-time Build HUD (`_populate_pause_build_overlay`, line 1826) currently shows: `P# Build` header + `Abilities: X / Y` plaintext + plain mutation chips. Needs more info and better polish.

**What to change in `CoopManager.gd._populate_pause_build_overlay` (line 1826-end):**

### Sub-fix 6a — Weapon line
Add immediately under the `P# Build` header:
```gdscript
var weapon: Dictionary = RunState.get_weapon(player_index)
var weapon_stats: Dictionary = weapon.get("stats", {}) as Dictionary
var weapon_label := Label.new()
weapon_label.text = "%s — %d dmg @ %.1f/s" % [
    str(weapon.get("name", "Rifle")),
    int(round(float(weapon_stats.get("damage", 16.0)))),
    float(weapon_stats.get("fire_rate", 4.0)),
]
weapon_label.add_theme_font_size_override("font_size", 12)
weapon_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 0.9))
overlay.add_child(weapon_label)
```
- If the weapon has `projectile_count > 1` or other notable stats, append them (e.g. `" × 3"`).

### Sub-fix 6b — Ability cards with LT/RT
Replace the `ability_text = "Abilities: %s / %s" % [...]` block (line 1848-1855) with two side-by-side cards in an `HBoxContainer`:
- Each ability card: small bordered PanelContainer with:
  - Trigger label ("LT" or "RT") tinted to `_get_slot_color(player_tint, slot_index)`
  - Ability name label
  - Cooldown value text (e.g. "CD 8.0s") pulled from `player.get_ability_hud_data(slot_index).get("base_cooldown", ...)` — verify the method returns a `base_cooldown` key; if not, use `_ability_registry.get_definition(ability_id).get("cooldown", 0.0)`.

### Sub-fix 6c — Rarity-styled grouped mutation chips
Current chip code (line 1881-1885) uses plain Labels with two-tone colors. Upgrade:
- Sort `counts` keys by rarity (rare first), then alphabetically by name, before rendering.
- Replace plain `Label` chips with `PanelContainer` chips:
  - Background `StyleBoxFlat` tinted by rarity: gold (`Color(1.0, 0.78, 0.32, 0.18)`) for rare, blue (`Color(0.48, 0.74, 1.0, 0.14)`) for common.
  - 4px corner radius.
  - Border 1px in the same rarity color at full alpha.
- Use `tooltip_text` on each chip to show the mutation's effect description.
- **Tooltip data source:** `MutationSystem.gd` does **not** expose a public `get_definition(id)`. But the existing loop already iterates `_mutation_system.get_active_mutations(player_index)` which returns full mutation dictionaries (`MutationSystem.gd:61-66` — each entry is a `duplicate(true)` of the definition from the JSON, so it already contains `name`, `rarity`, `description`, etc.). Store `description` into the `counts[mutation_id]` dict during the existing aggregation pass:
  ```gdscript
  counts[mutation_id] = {
      "name": str(mutation_dict.get("name", mutation_id)),
      "count": int(counts.get(mutation_id, {}).get("count", 0)) + 1,
      "rarity": str(mutation_dict.get("rarity", "common")),
      "description": str(mutation_dict.get("description", "")),  # add this
  }
  ```
  Then on each chip: `chip.tooltip_text = str(entry["description"])`. No `MutationSystem` API changes needed.

### Sub-fix 6d — Derived stats line
Below the mutation chips, add a one-liner showing computed values:
```gdscript
var stats_line := Label.new()
var move_speed := float(player.move_speed)
var max_hp := int(player.max_health)
var fire_interval := float(player._get_current_weapon_fire_interval())  # or expose via public getter
stats_line.text = "Move %d  •  HP %d  •  Fire %.1f/s" % [
    int(round(move_speed)),
    max_hp,
    1.0 / max(fire_interval, 0.01),
]
stats_line.add_theme_font_size_override("font_size", 11)
stats_line.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0, 0.78))
overlay.add_child(stats_line)
```
- Prefer using a public getter over `_get_current_weapon_fire_interval()` (which is prefixed `_` = private). If no public method exists, add one to `Player.gd`:
  ```gdscript
  func get_current_fire_rate() -> float:
      return 1.0 / max(_get_current_weapon_fire_interval(), 0.01)
  ```

**Files:** `scripts/game/CoopManager.gd`, possibly `scripts/player/Player.gd` (for public fire-rate getter)

---

## Fix F7 — Main menu ability picker: LT/RT mapping + matching colors

**Problem:** When picking abilities in the main menu (`scripts/ui/Bootstrap.gd._build_ability_rows`, line 354+), the player can't see which pick = LT and which = RT. Once in-game, slot 1 uses player tint and slot 2 uses purple (`HUD_SLOT_2_COLOR`), but the menu shows undifferentiated toggle buttons.

**What to change in `scripts/ui/Bootstrap.gd`:**

### Sub-fix 7a — Show LT/RT badges on the two selected cards

- `_on_ability_card_toggled` already maintains `selection_order` (line 437) — first picked = slot 0 (LT), second picked = slot 1 (RT).
- In `_sync_ability_row_buttons(player_index)` (line 445+), after updating button toggled state, iterate `selection_order`:
  - For `selection_order[0]` (LT pick): set the card's `text` (or add a child Label overlay) to show "LT — {ability_name}".
  - For `selection_order[1]` (RT pick): same with "RT — {ability_name}".
  - For unselected cards: just the ability name.
- If the card type is a custom Control, add child Label overlays positioned in the top-left corner. If it's a vanilla Button, prepend "LT • " / "RT • " to the button text.

### Sub-fix 7b — Tint selected cards to match in-game

- Move `HUD_SLOT_2_COLOR` from `CoopManager.gd:45` into a shared constants script (e.g. `scripts/game/HudPalette.gd`) so both `CoopManager.gd` and `Bootstrap.gd` import it. Add the same for any other shared HUD colors used.
  - Alternative (simpler if time-constrained): duplicate the constant in `Bootstrap.gd` with a comment pointing to `CoopManager.gd`. Note tech-debt.
- For each selected card:
  - LT pick: apply player tint as the card background `modulate` or `StyleBoxFlat.border_color`.
  - RT pick: apply `HUD_SLOT_2_COLOR` as the card background/border.
- Unselected cards keep their default styling.

### Sub-fix 7c — Player tint source

- Player tints in the menu come from `player_configs` (probably a default palette). Verify `Bootstrap.gd` has access to per-player tint at the time of `_sync_ability_row_buttons` — if not, expose the same per-index tint logic CoopManager uses (or import the constant array if it's static).

**Files:** `scripts/ui/Bootstrap.gd`, optionally `scripts/game/HudPalette.gd` (new shared constants file), `scripts/game/CoopManager.gd` (if extracting the constants)

---

## Implementation Order

Grouped by risk and dependency.

### Phase 1 — Quick numeric tunings (low risk, isolated)
1. **F4** +25% movement speed (Player.gd + Enemy.gd + RunState.gd)
2. **F5** Remove mutation badge from arena HUD

### Phase 2 — Combat correctness
3. **F1 Part A** Iterate-all-players contact damage (Enemy.gd)
4. **F1 Part B** Player-side invuln window (Player.gd)

### Phase 3 — HUD layout
5. **F2** LT/RT labels above slot bars
6. **F3** Multi-player HUD scaling

### Phase 4 — Build HUD overhaul (biggest scope inside CoopManager)
7. **F6a** Weapon line in Build HUD
8. **F6b** Ability cards with LT/RT in Build HUD
9. **F6c** Rarity-styled grouped mutation chips
10. **F6d** Derived stats line (+ public getter on Player.gd if needed)

### Phase 5 — Menu picker (separate scene, independent)
11. **F7a** LT/RT badges in Bootstrap.gd ability picker
12. **F7b** Color-tint selected cards to match in-game
13. **F7c** Wire player tint into the menu (if not already accessible)

---

## Verification

After each phase:
```powershell
& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit
```

After all phases, manual playtest:
- 1P structured: confirm contact damage feels reliable when surrounded, +25% speed feels good, LT/RT labels readable
- 2P structured: confirm bottom HUD fits cleanly, both players see LT/RT correctly, contact damage hits non-nearest player when surrounded
- Main menu: confirm LT/RT visible during picking, colors match in-game when entering combat
- Pause: confirm Build HUD shows weapon + abilities + mutations + derived stats correctly
