# Playtest Tuning Plan

Seven changes from first playtesting session. Some are tuning within the V3 design; two are **intentional design amendments** that override locked V3 decisions based on hands-on feedback.

## Design Amendments

The following V3 decisions are overridden by this plan:

1. **HP pickups restored** (Task 4). V3 removed all healing pickups. Playtesting showed rooms feel unforgiving with no sustain at all, especially in Act 2 with higher enemy pressure. Health still resets each room. Pickups provide within-room sustain only.
2. **Pause build overlay added** (Task 6). V3 said mutations are hidden during combat (pick/pause only). We keep combat HUD clean — no always-visible chips — but the pause screen now shows a full build summary so the player can check at any time.

Update `docs/design/roadmap.md` and `docs/development/current-state.md` after implementation to reflect these amendments.

## Dependencies

Tasks are **not all independent**. The dependency chain:

```
Task 1 (spawn pressure) → Task 2 (XP curve) → Task 4 (HP sustain)
```

Task 1 changes enemy volume. Task 2 retunes XP around that volume. Task 4 adds sustain that changes survivability under the new pressure. These three must be implemented and playtested as a sequence.

Tasks 3, 5, 6, 7 are independent of each other and of the chain above.

## Implementation Order

1. Task 1 — Spawn pressure
2. Task 2 — XP curve
3. Task 3 — Split shot (independent)
4. Task 4 — HP pickups (depends on Task 1+2 pressure)
5. Task 5 — Map UI (independent)
6. Task 6 — Pause build overlay (independent)
7. Task 7 — Branch rename (independent, do last)

**Validation rule**: Run headless parse check after every task:
```
& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit
```

**Working branch**: `v2/core-refactor` (renamed to `v3/main` in Task 7)

---

## Task 1: Spawn Pressure — Faster Stream + Burst Spikes

**Problem**: Arena feels empty. ~19 enemies in Act 1, peak alive 5-8. No tension.

**Goal**: 20-30 enemies alive at peak. Steady fast stream as baseline with periodic burst spawns for intensity spikes.

### Target values

| Value | Act 1 | Act 2 |
|---|---|---|
| Base stream interval | 0.7s | 0.5s |
| Burst interval | 10s | 8s |
| Burst size | 4-6 enemies | 6-8 enemies |
| Room duration | 35s (unchanged) | 45s (unchanged) |
| Estimated total enemies | ~55-65 | ~100-120 |
| Estimated peak alive | 18-25 | 25-30 |

### File: `scripts/game/CoopManager.gd`

#### 1a. Add burst timer variables

At the member variable block (around line 101, after `_spawning_done`), add:

```gdscript
var _burst_interval := 10.0
var _next_burst_at := 0.0
```

#### 1b. Replace `_get_spawn_interval()` (line 659)

Replace the entire function body:

```gdscript
func _get_spawn_interval() -> float:
    var base := 0.7
    if RunState.get_current_act() >= 2:
        base = 0.5
    if _room_type == "elite":
        base -= 0.1
    if _room_depth >= 10:
        base -= 0.05
    if _room_depth >= 20:
        base -= 0.05
    return maxf(base, 0.25)
```

#### 1c. Initialize burst timer in `_start_room()`

After the line `_spawning_done = false` (around line 431), add:

```gdscript
_burst_interval = 10.0 if RunState.get_current_act() <= 1 else 8.0
_next_burst_at = _burst_interval
```

#### 1d. Replace `_continuous_spawn()` (line 586)

Replace the entire function:

```gdscript
func _continuous_spawn() -> void:
    if _room_elapsed >= _room_duration:
        _spawning_done = true
        return
    var health_multiplier := 0.5 if bool(_minor_modifier_flags["swarm"]) else 1.0
    # --- Stream spawning ---
    if _room_elapsed >= _next_spawn_at:
        var current_interval := _spawn_interval
        if bool(_minor_modifier_flags["accelerating_waves"]):
            var ramp := clampf(_room_elapsed / min(_room_duration, 25.0), 0.0, 1.0)
            current_interval = lerpf(_spawn_interval, _spawn_interval * 0.33, ramp)
        _next_spawn_at = _room_elapsed + current_interval
        var batch := 2 if bool(_minor_modifier_flags["swarm"]) else 1
        for _index in range(batch):
            _spawn_enemy_instance(_roll_wave_enemy_type(_room_enemy_pool), _get_enemy_spawn_position(), health_multiplier)
            _enemies_spawned += 1
    # --- Burst spawning ---
    if _room_elapsed >= _next_burst_at:
        _next_burst_at = _room_elapsed + _burst_interval
        var burst_size := randi_range(4, 6) if RunState.get_current_act() <= 1 else randi_range(6, 8)
        if bool(_minor_modifier_flags["swarm"]):
            burst_size *= 2
        for _index in range(burst_size):
            _spawn_enemy_instance(_roll_wave_enemy_type(_room_enemy_pool), _get_enemy_spawn_position(), health_multiplier)
            _enemies_spawned += 1
```

#### 1e. Update `_estimate_room_total_enemies()` (line 1173)

Replace the function body:

```gdscript
func _estimate_room_total_enemies() -> int:
    var stream := int(ceil(_room_duration / max(_spawn_interval, 0.25)))
    var burst_count := int(floor(_room_duration / max(_burst_interval, 1.0)))
    var avg_burst := 5 if RunState.get_current_act() <= 1 else 7
    var total := stream + burst_count * avg_burst
    if bool(_minor_modifier_flags["swarm"]):
        total *= 2
    if _room_type == "elite":
        total += 1
    return max(total, 8)
```

---

## Task 2: XP Curve — Slower Leveling

**Problem**: Leveling too fast, too many picks banked at once. With Task 1's higher enemy counts this would be even worse.

**Goal**: 12-18 mutation picks per full structured run (~10 rooms). Banking stays unchanged.

### New formula

Old: `xp_to_next_level = 80 + (level * 15)`
New: `xp_to_next_level = 100 + (level * 30)`

| Level | Old XP needed | New XP needed |
|---|---|---|
| 1 | 80 | 100 |
| 5 | 155 | 250 |
| 10 | 230 | 400 |
| 15 | 305 | 550 |

With ~55 enemies in Act 1 averaging ~12 XP → ~660 XP/room → ~4-5 levels in Act 1 (4 rooms).
With ~100 enemies in Act 2 averaging ~14 XP → ~1400 XP/room → ~3-4 levels/room.
Total across a full run: roughly 14-18 picks. Lands in target range.

### File: `scripts/game/RunState.gd`

#### 2a. Update initial value (line 31)

Change `var xp_to_next_level: int = 80` to `var xp_to_next_level: int = 100`

#### 2b. Update reset in `start_new_run()` (line 67)

Change `xp_to_next_level = 80` to `xp_to_next_level = 100`

#### 2c. Update formula in `add_xp()` (line 243)

Change `xp_to_next_level = 80 + (xp_level * 15)` to `xp_to_next_level = 100 + (xp_level * 30)`

---

## Task 3: Split Shot — Always Keep Center Bullet

**Problem**: Split Shot Lv1 fires 2 bullets in a V-shape. Neither hits the target directly in front.

**Goal**: Base bullet always fires straight at the target. Split Shot adds extra bullets to the sides.

- Lv0: 1 center
- Lv1: 1 center + 1 side = 2 total
- Lv2: 1 center + 2 sides = 3 total
- Lv3: 1 center + 3 sides = 4 total

### File: `data/mutations.json`

#### 3a. Reduce spread angle

In the `split_shot` entry, change `"spread_degrees": 15.0` to `"spread_degrees": 10.0`

### File: `scripts/game/CoopManager.gd`

#### 3b. Replace `_build_spread_directions()` (line 1339)

Replace the entire function. The new version keeps the first direction as center and fans extras around it:

```gdscript
func _build_spread_directions(base_direction: Vector2, projectile_count: int, spread_step: float) -> Array:
    var normalized := base_direction.normalized() if base_direction.length() > 0.0 else Vector2.RIGHT
    if projectile_count <= 1 or spread_step <= 0.0:
        return [normalized]
    var directions: Array = [normalized]
    var extras := projectile_count - 1
    for index in range(1, extras + 1):
        var side := 1 if index % 2 == 1 else -1
        var rank := int(ceil(float(index) / 2.0))
        directions.append(normalized.rotated(spread_step * float(rank) * float(side)))
    return directions
```

Result pattern:
- 2 bullets: center, +10°
- 3 bullets: center, +10°, -10°
- 4 bullets: center, +10°, -10°, +20°

---

## Task 4: HP Pickups — Restore with Drop Chance

> **Design amendment**: V3 explicitly removed health pickups. This is an intentional override based on playtesting — rooms felt unforgiving without any within-room sustain. Health still resets each room as per V3.

**Goal**: ~10% drop chance per non-boss enemy kill. 5 HP heal. Magnet pickup behavior.

### File: `scripts/pickups/HealthPickup.gd`

#### 4a. Create the file with full contents

Create `scripts/pickups/HealthPickup.gd` with this exact content:

```gdscript
class_name HealthPickup
extends Area2D

const MAGNET_RADIUS := 160.0
const MAGNET_ACCELERATION := 1200.0
const MAGNET_MAX_SPEED := 600.0
const COLLECT_RADIUS := 48.0

var heal_amount: int = 5
var magnet_speed: float = 0.0
var _collected := false

func _ready() -> void:
    var ring := Polygon2D.new()
    ring.polygon = _build_circle_polygon(12.0, 8)
    ring.color = Color(0.22, 1.0, 0.54, 0.95)
    add_child(ring)

    var cross := Polygon2D.new()
    cross.polygon = PackedVector2Array([
        Vector2(-3.0, -10.0),
        Vector2(3.0, -10.0),
        Vector2(3.0, -3.0),
        Vector2(10.0, -3.0),
        Vector2(10.0, 3.0),
        Vector2(3.0, 3.0),
        Vector2(3.0, 10.0),
        Vector2(-3.0, 10.0),
        Vector2(-3.0, 3.0),
        Vector2(-10.0, 3.0),
        Vector2(-10.0, -3.0),
        Vector2(-3.0, -3.0),
    ])
    cross.color = Color(0.88, 1.0, 0.92, 0.98)
    add_child(cross)

func _process(delta: float) -> void:
    if _collected:
        return
    var tree := get_tree()
    if tree == null:
        return
    var nearest_player: Node2D = null
    var nearest_distance := INF
    for candidate in tree.get_nodes_in_group("player_target"):
        if not is_instance_valid(candidate) or not (candidate is Node2D):
            continue
        if candidate.has_method("is_alive") and not candidate.is_alive():
            continue
        if not candidate.has_method("heal"):
            continue
        var distance := global_position.distance_to((candidate as Node2D).global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_player = candidate as Node2D
    if nearest_player == null:
        return
    if nearest_distance < MAGNET_RADIUS:
        var direction := (nearest_player.global_position - global_position).normalized()
        magnet_speed = minf(magnet_speed + MAGNET_ACCELERATION * delta, MAGNET_MAX_SPEED)
        global_position += direction * magnet_speed * delta
        nearest_distance = nearest_player.global_position.distance_to(global_position)
    if nearest_distance <= COLLECT_RADIUS:
        _collected = true
        nearest_player.heal(heal_amount)
        queue_free()

func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(segments):
        var angle := TAU * float(i) / float(segments)
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    return points
```

Note: this is the original file from git history with `_process()` magnet behavior added (the old version had no self-update, it relied on external calls). The new version follows the same pattern as `CollectorOrb.gd`.

#### 4b. Create UID file

Create `scripts/pickups/HealthPickup.gd.uid` — Godot will auto-generate this on first load if missing, but if the old UID is needed, check `git show HEAD~1:scripts/pickups/HealthPickup.gd.uid` for the original value.

### File: `scripts/game/CoopManager.gd`

#### 4c. Add preload and constant

At the top preload block (around line 1-22), add:
```gdscript
const HealthPickupData = preload("res://scripts/pickups/HealthPickup.gd")
```

Add constant near the other constants (around line 38):
```gdscript
const HEALTH_DROP_CHANCE := 0.10
```

#### 4d. Spawn HP pickup on enemy death

In `_on_enemy_died()` (line 917), after the XP grant block (after line 924) and before the splitter handling (line 925), add:

```gdscript
if not enemy_type_name.begins_with("boss_") and not enemy_type_name.begins_with("elite_") and randf() < HEALTH_DROP_CHANCE:
    var hp_pickup := HealthPickupData.new()
    hp_pickup.global_position = enemy.global_position
    pickups.add_child(hp_pickup)
```

---

## Task 5: Map UI — Top-to-Bottom with Modifier Dots

**Problem**: Map is cramped, overlapping, modifier abbreviations clutter nodes.

**Goal**: Clean vertical progress (top to bottom). Wider nodes. Room type text only on nodes. Colored dots for modifiers (yellow = minor, red = major). Full details on hover/focus in the detail panel.

### File: `scripts/ui/RunFlow.gd`

#### 5a. Change button size (line 27)

Change `var _map_button_size := Vector2(72.0, 36.0)` to `var _map_button_size := Vector2(110.0, 30.0)`

#### 5b. Replace `_get_node_graph_position()` (line 107)

Flip axes — rows go top-to-bottom (Y), columns go left-to-right (X):

```gdscript
func _get_node_graph_position(node: Dictionary, row_count: int) -> Vector2:
    var width := maxf(map_graph_area.size.x, 320.0)
    var height := maxf(map_graph_area.size.y, 280.0)
    var row := int(node.get("row", 0))
    var margin_x := 60.0
    var margin_y := 22.0
    var y := margin_y if row_count <= 1 else margin_y + (height - margin_y * 2.0) * float(row) / float(max(row_count - 1, 1))
    var column_count_in_row := _count_columns_in_row(node, RunState.get_map_rows())
    var column_rank := _get_column_rank(node, RunState.get_map_rows())
    var x := width * 0.5 if column_count_in_row <= 1 else margin_x + (width - margin_x * 2.0) * float(column_rank) / float(max(column_count_in_row - 1, 1))
    return Vector2(x, y)
```

The helper functions `_count_columns_in_row()` and `_get_column_rank()` already exist and remain unchanged.

#### 5c. Simplify node button text

Replace `_build_node_button_text()`:

```gdscript
func _build_node_button_text(node: Dictionary) -> String:
    match str(node.get("room_type", "combat")):
        "boss":
            return str(node.get("boss_type", "Boss")).capitalize()
        "elite":
            return "Elite"
        _:
            return "Fight"
```

#### 5d. Add modifier dots to node buttons

Replace `_build_map_button()` to draw colored dots after the text:

```gdscript
func _build_map_button(node: Dictionary, button_center: Vector2, is_reachable: bool) -> Button:
    var button := Button.new()
    button.custom_minimum_size = _map_button_size
    button.size = _map_button_size
    button.position = button_center - _map_button_size * 0.5
    button.focus_mode = Control.FOCUS_ALL if is_reachable else Control.FOCUS_NONE
    button.text = _build_node_button_text(node)
    button.add_theme_font_size_override("font_size", 12)
    button.alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.modulate = _get_node_color(node, is_reachable)
    button.mouse_entered.connect(_on_map_node_hovered.bind(str(node.get("id", ""))))
    button.focus_entered.connect(_on_map_node_hovered.bind(str(node.get("id", ""))))
    button.pressed.connect(_on_map_node_pressed.bind(str(node.get("id", ""))))
    # --- Modifier dots ---
    var modifiers: Array = node.get("modifiers", []) as Array
    if not modifiers.is_empty():
        var dot_row := HBoxContainer.new()
        dot_row.anchor_left = 1.0
        dot_row.anchor_right = 1.0
        dot_row.anchor_top = 0.0
        dot_row.anchor_bottom = 0.0
        dot_row.offset_left = -6.0 - float(modifiers.size()) * 10.0
        dot_row.offset_top = 2.0
        dot_row.offset_right = -4.0
        dot_row.add_theme_constant_override("separation", 3)
        for mod_id_variant in modifiers:
            var dot := ColorRect.new()
            dot.custom_minimum_size = Vector2(7.0, 7.0)
            dot.color = _get_modifier_dot_color(str(mod_id_variant))
            dot_row.add_child(dot)
        button.add_child(dot_row)
    return button
```

#### 5e. Add modifier dot color function

Add a new function:

```gdscript
func _get_modifier_dot_color(mod_id: String) -> Color:
    var minor_ids := ["accelerating_waves", "enemy_speed", "swarm", "shielded", "explosive_death"]
    if minor_ids.has(mod_id):
        return Color(1.0, 0.82, 0.28, 0.92)
    return Color(0.92, 0.28, 0.22, 0.92)
```

#### 5f. Reduce connection line width

In `_add_connection_line()` (line 137), change `line.width = 4.0` to `line.width = 2.0`

---

## Task 6: Pause Build Overlay + Ability Name Labels

> **Design amendment**: V3 says mutations are only visible on pick/pause screens. We keep combat HUD clean (no always-visible mutation chips). But the pause screen now shows a full build summary so the player can review their build at any time.

**Goal**: Pause screen shows per-player mutation inventory. Cooldown arcs show ability name labels.

### File: `scripts/game/CoopManager.gd`

#### 6a. Add build summary to pause toggle

In the `_unhandled_input()` function (line 1375), where `pause_panel.visible = true` is set, add a call to populate the build overlay:

After `pause_panel.visible = true` and `get_tree().paused = true`, add:
```gdscript
_populate_pause_build_overlay()
```

#### 6b. Add `_populate_pause_build_overlay()` function

Add a new function that dynamically adds a build summary to the pause panel. It finds or creates a VBoxContainer child inside the pause panel's layout, then populates it with per-player mutation lists:

```gdscript
func _populate_pause_build_overlay() -> void:
    var pause_layout := pause_panel.get_node_or_null("MarginContainer/PauseLayout")
    if pause_layout == null:
        return
    var existing := pause_layout.get_node_or_null("BuildOverlay")
    if existing != null:
        existing.queue_free()
    var overlay := VBoxContainer.new()
    overlay.name = "BuildOverlay"
    overlay.add_theme_constant_override("separation", 10)
    pause_layout.add_child(overlay)
    for player_index in range(_player_nodes.size()):
        var player = _player_nodes[player_index]
        var header := Label.new()
        header.text = "P%d Build" % (player_index + 1)
        header.add_theme_font_size_override("font_size", 15)
        header.add_theme_color_override("font_color", _player_configs[player_index].tint.lightened(0.2))
        overlay.add_child(header)
        var ability_text := "Abilities: %s / %s" % [
            str(player.get_ability_hud_data(0).get("name", "?")),
            str(player.get_ability_hud_data(1).get("name", "?")),
        ]
        var ability_label := Label.new()
        ability_label.text = ability_text
        ability_label.add_theme_font_size_override("font_size", 12)
        overlay.add_child(ability_label)
        var mutations: Array = _mutation_system.get_active_mutations(player_index)
        var counts: Dictionary = {}
        for mutation in mutations:
            var mutation_dict: Dictionary = mutation as Dictionary
            var mutation_id := str(mutation_dict.get("id", ""))
            if mutation_id.is_empty():
                continue
            counts[mutation_id] = {"name": str(mutation_dict.get("name", mutation_id)), "count": int(counts.get(mutation_id, {}).get("count", 0)) + 1, "rarity": str(mutation_dict.get("rarity", "common"))}
        if counts.is_empty():
            var empty_label := Label.new()
            empty_label.text = "  No mutations yet"
            empty_label.add_theme_font_size_override("font_size", 11)
            empty_label.modulate = Color(0.7, 0.78, 0.88, 0.7)
            overlay.add_child(empty_label)
        else:
            var chip_flow := FlowContainer.new()
            chip_flow.add_theme_constant_override("h_separation", 6)
            chip_flow.add_theme_constant_override("v_separation", 4)
            overlay.add_child(chip_flow)
            for mutation_id in counts.keys():
                var entry: Dictionary = counts[mutation_id]
                var chip := Label.new()
                var level_text := " Lv%d" % int(entry["count"]) if int(entry["count"]) > 1 and str(entry["rarity"]) != "rare" else ""
                chip.text = "%s%s" % [str(entry["name"]), level_text]
                chip.add_theme_font_size_override("font_size", 11)
                chip.modulate = Color(1.0, 0.86, 0.34, 0.96) if str(entry["rarity"]) == "rare" else Color(0.88, 0.94, 1.0, 0.88)
                chip_flow.add_child(chip)
```

### File: `scripts/ui/PlayerCombatIndicator.gd`

#### 6c. Add ability name storage

Add two member variables (around line 27):

```gdscript
var _slot_1_name := ""
var _slot_2_name := ""
```

#### 6d. Extend `update_state()` signature

Add two optional parameters at the end of `update_state()`:

```gdscript
func update_state(current_health: int, max_health: int, is_downed: bool, slot_1_cooldown_remaining: float, slot_1_cooldown_duration: float, slot_2_cooldown_remaining: float, slot_2_cooldown_duration: float, slot_1_name: String = "", slot_2_name: String = "") -> void:
```

Inside the function body, store them:
```gdscript
_slot_1_name = slot_1_name
_slot_2_name = slot_2_name
```

#### 6e. Draw ability names in `_draw()`

At the end of the `_draw()` function, after the health bar drawing, add:

```gdscript
if not _slot_1_name.is_empty():
    draw_string(ThemeDB.fallback_font, Vector2(COOLDOWN_ARC_CENTER.x - 20.0, 8.0), _slot_1_name, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(_tint.r, _tint.g, _tint.b, 0.62))
if not _slot_2_name.is_empty():
    draw_string(ThemeDB.fallback_font, Vector2(COOLDOWN_ARC_CENTER.x - 20.0, 36.0), _slot_2_name, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(1.0, 0.48, 0.82, 0.62))
```

### File: `scripts/game/CoopManager.gd`

#### 6f. Pass ability names to indicator

In `_update_player_combat_indicators()` (line 1062), update the `update_state()` call to pass ability names:

```gdscript
_player_combat_indicators[index].update_state(
    int(health_state.get("current", 0)),
    int(health_state.get("max", 1)),
    player.is_downed(),
    float(slot_1_hud_data.get("cooldown_remaining", 0.0)),
    float(slot_1_hud_data.get("cooldown_duration", 1.0)),
    float(slot_2_hud_data.get("cooldown_remaining", 0.0)),
    float(slot_2_hud_data.get("cooldown_duration", 1.0)),
    str(slot_1_hud_data.get("name", "")),
    str(slot_2_hud_data.get("name", ""))
)
```

---

## Task 7: Branch Rename + Doc Updates

**Problem**: Branch is `v2/core-refactor` but we're building V3. Confusing.

### 7a. Rename branch

```bash
git branch -m v2/core-refactor v3/main
git push origin --delete v2/core-refactor
git push -u origin v3/main
```

### 7b. Update doc references

In `docs/development/current-state.md`, `docs/development/playtest-tuning-plan.md`, and any other files referencing `v2/core-refactor`, replace with `v3/main`.

### 7c. Update roadmap and current-state for design amendments

In `docs/development/current-state.md`:
- In the Encounter Systems section, add: "HP pickups drop from non-boss enemy kills (~10% chance, 5 HP heal, magnet behavior)"
- In the UI section, add: "Pause screen shows per-player build summary (abilities + mutations with levels)"

In `docs/design/roadmap.md` V3 amendment note at the top, add:
- "Health pickups restored within rooms (design amendment 2026-06-01 playtest)"
- "Pause build overlay added (design amendment 2026-06-01 playtest)"

---

## Files Touched

| File | Tasks |
|---|---|
| `scripts/game/CoopManager.gd` | 1, 3, 4, 6 |
| `scripts/game/RunState.gd` | 2 |
| `data/mutations.json` | 3 |
| `scripts/pickups/HealthPickup.gd` | 4 (new file) |
| `scripts/ui/RunFlow.gd` | 5 |
| `scripts/ui/PlayerCombatIndicator.gd` | 6 |
| `docs/development/current-state.md` | 7 |
| `docs/design/roadmap.md` | 7 |
