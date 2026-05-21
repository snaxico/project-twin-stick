# V3 Gold Economy — Historical Implementation Plan

## Status

- This file is a historical implementation plan/record for the economy slice.
- Some parts were implemented, but the live runtime may differ from the exact step-by-step plan below.
- Do not treat this as the source of truth for current branch behavior.
- Use `docs/development/current-state.md` and `docs/design/roadmap.md` for active follow-up work.

## Context

This plan implements the gold economy designed in `docs/design/v3-economy-encounters.md`. It is structured as sequential phases that each produce a testable, parse-clean result. Each phase lists the exact files to change, what to add/modify/remove, and how to verify.

Design document: [v3-economy-encounters.md](v3-economy-encounters.md)
Current runtime docs: `docs/development/current-state.md`

## Validation Command

After every phase, run the headless parse check:

```powershell
& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit
```

The engine must exit cleanly with no script errors.

---

## Phase 1 — Gold State in RunState + PlayerInventory

**Goal:** Add per-player gold tracking to the run state. No gameplay changes yet.

### Files to change

**`scripts/game/PlayerInventory.gd`**

Add property:

```gdscript
var gold: int = 0
```

**`scripts/game/RunState.gd`**

Add functions:

```gdscript
func get_player_gold(player_index: int) -> int:
    var inventory = get_player_inventory(player_index)
    if inventory == null:
        return 0
    return inventory.gold

func add_gold_to_all_players(amount: int) -> void:
    for inventory in player_inventories:
        if inventory != null:
            inventory.gold += amount

func spend_player_gold(player_index: int, amount: int) -> bool:
    var inventory = get_player_inventory(player_index)
    if inventory == null:
        return false
    if inventory.gold < amount:
        return false
    inventory.gold -= amount
    return true
```

Note: `add_gold_to_all_players()` adds the full amount to every player's wallet. This is the co-op model: shared pickups, personal wallets. When anyone collects a gold pickup, all players receive the full amount.

Update `get_run_summary_text()` to include gold per player in the summary string.

### What stays untouched
- CoopManager.gd
- MutationPickUI.gd
- Enemy.gd
- All scene files

### Verification
- Headless parse check passes.
- `RunState.get_player_gold(0)` returns `0` on a fresh run.

---

## Phase 2 — Gold Pickup Scene

**Goal:** Create a pickup node that represents gold on the ground, with magnet behavior and collection.

### New file: `scripts/pickups/GoldPickup.gd`

```gdscript
class_name GoldPickup
extends Area2D

signal collected(amount: int, collector)

var amount: int = 5
var _magnet_target = null
var _magnet_speed: float = 0.0

const MAGNET_RADIUS := 80.0
const MAGNET_ACCELERATION := 1200.0
const MAGNET_MAX_SPEED := 600.0
const COLLECT_RADIUS := 24.0

func _ready() -> void:
    # Build visual: small glowing circle, gold/yellow color
    var visual := Polygon2D.new()
    visual.polygon = _build_circle_polygon(6.0, 8)
    visual.color = Color(1.0, 0.85, 0.2, 0.95)
    add_child(visual)
    # No collision shape needed — pickup uses distance checks from CoopManager

func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(segments):
        var angle := TAU * float(i) / float(segments)
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    return points
```

Note: GoldPickup does NOT use Area2D collision detection for player proximity. The CoopManager will handle distance checks in `_physics_process` to keep pickup logic centralized and avoid signal wiring per pickup. GoldPickup is an Area2D only for future extensibility (e.g., magnet powerups). The visual is a simple Polygon2D circle.

### New file: `scenes/pickups/GoldPickup.tscn`

Minimal scene with root node `GoldPickup` (Area2D) using the script above. No CollisionShape2D child needed since CoopManager handles distance checks.

### Verification
- Headless parse check passes.
- Scene loads without errors.

---

## Phase 3 — Enemy Death Drops Gold

**Goal:** When an enemy dies, spawn a GoldPickup at their death position.

### Files to change

**`scripts/game/CoopManager.gd`**

Add preload at top:

```gdscript
const GoldPickupSceneData = preload("res://scenes/pickups/GoldPickup.tscn")
```

Add a new node container for pickups. In `_ready()`, create a `Node2D` child named `pickups` (similar to how `projectiles`, `enemies`, `effects` are organized):

```gdscript
@onready var pickups: Node2D = $Pickups
```

This requires adding a `Pickups` Node2D child to the `GameWorld.tscn` scene, positioned after `Effects` in the scene tree.

Add gold value lookup and modifier multiplier:

```gdscript
const GOLD_DROP_VALUES := {
    "chaser": {"min": 3, "max": 5},
    "charger": {"min": 8, "max": 12},
    "boss": {"min": 0, "max": 0},
}

var _room_gold_multiplier: float = 1.0

func _get_gold_drop_amount(enemy_type_name: String) -> int:
    var entry: Dictionary = GOLD_DROP_VALUES.get(enemy_type_name, {"min": 3, "max": 5})
    var base := randi_range(int(entry.get("min", 3)), int(entry.get("max", 5)))
    return maxi(1, int(round(float(base) * _room_gold_multiplier)))
```

Initialize `_room_gold_multiplier` in `_start_room()`:

```gdscript
_room_gold_multiplier = 1.0  # Default. Set based on modifier severity when modifiers are reintroduced.
```

When the modifier system is reintroduced, set this based on modifier severity:

- No modifier: 1.0
- Minor modifier: 1.15
- Major modifier: 1.3
- Stacked modifiers: multiply both

Modify `_on_enemy_died(enemy)`:

After the existing screen shake logic, add:

```gdscript
var gold_amount := _get_gold_drop_amount(enemy.get_type_name())
if gold_amount > 0:
    _spawn_gold_pickup(enemy.global_position, gold_amount)
```

Add spawn function:

```gdscript
func _spawn_gold_pickup(position: Vector2, amount: int) -> void:
    var pickup = GoldPickupSceneData.instantiate()
    pickup.amount = amount
    pickup.global_position = position
    pickups.add_child(pickup)
```

**`scripts/enemies/Enemy.gd`**

Add a function to return the enemy type as a string (needed for gold lookup):

```gdscript
func get_type_name() -> String:
    match enemy_type:
        EnemyType.CHASER:
            return "chaser"
        EnemyType.CHARGER:
            return "charger"
        EnemyType.BOSS:
            return "boss"
    return "chaser"
```

Check if `get_type_name()` or equivalent already exists. If so, reuse it.

Also add a function to return visual feedback weight if not present:

```gdscript
func get_feedback_weight() -> float:
    match enemy_type:
        EnemyType.BOSS:
            return 3.0
        EnemyType.CHARGER:
            return 1.5
    return 1.0
```

Check if `get_feedback_weight()` already exists. If so, skip.

Modify `_clear_runtime_nodes()` to also clear pickups:

```gdscript
for group in [projectiles, enemies, effects, pickups]:
```

### Verification
- Headless parse check passes.
- Enemies drop gold pickups on death (visible gold circles on the arena floor).
- Gold pickups persist on the ground.

---

## Phase 4 — Gold Collection (Magnet + Auto-Collect)

**Goal:** Players collect gold by walking near pickups (magnet pull). All remaining gold auto-collects when room clears.

### Files to change

**`scripts/game/CoopManager.gd`**

Add room-level gold tracking:

```gdscript
var _room_gold_earned: int = 0  # total gold earned this room (shared across all players)
const SURVIVAL_BONUS_GOLD := 20  # flat gold bonus on room clear (placeholder)
```

Initialize in `_start_room()`:

```gdscript
_room_gold_earned = 0
```

Add gold collection logic in `_physics_process()`, called every frame:

```gdscript
func _update_gold_pickups(_delta: float) -> void:
    var active_players := get_active_players()
    if active_players.is_empty():
        return
    var to_remove: Array = []
    for pickup in pickups.get_children():
        if not is_instance_valid(pickup):
            continue
        # Find nearest player
        var nearest_player = null
        var nearest_distance := INF
        for player in active_players:
            var dist := player.global_position.distance_to(pickup.global_position)
            if dist < nearest_distance:
                nearest_distance = dist
                nearest_player = player
        if nearest_player == null:
            continue
        # Magnet pull: if within magnet radius, move toward nearest player
        if nearest_distance < GoldPickup.MAGNET_RADIUS:
            var direction: Vector2 = (nearest_player.global_position - pickup.global_position).normalized()
            pickup._magnet_speed = minf(pickup._magnet_speed + GoldPickup.MAGNET_ACCELERATION * _delta, GoldPickup.MAGNET_MAX_SPEED)
            pickup.global_position += direction * pickup._magnet_speed * _delta
            nearest_distance = nearest_player.global_position.distance_to(pickup.global_position)
        # Collect: if within collect radius, add to ALL players' wallets
        if nearest_distance < GoldPickup.COLLECT_RADIUS:
            RunState.add_gold_to_all_players(pickup.amount)
            _room_gold_earned += pickup.amount
            to_remove.append(pickup)
    for pickup in to_remove:
        pickup.queue_free()
```

**Important: `RunState.add_gold_to_all_players()` adds the full pickup amount to every player's wallet.** This is the co-op model: shared pickups, personal wallets. No stealing, no routing arguments.

Call `_update_gold_pickups(delta)` from `_physics_process()` after `_update_room(delta)`.

Add auto-collect function for room clear:

```gdscript
func _auto_collect_all_gold() -> void:
    for pickup in pickups.get_children():
        if not is_instance_valid(pickup):
            continue
        RunState.add_gold_to_all_players(pickup.amount)
        _room_gold_earned += pickup.amount
        pickup.queue_free()
```

Add survival bonus function:

```gdscript
func _award_survival_bonus() -> void:
    RunState.add_gold_to_all_players(SURVIVAL_BONUS_GOLD)
    _room_gold_earned += SURVIVAL_BONUS_GOLD
```

Call both `_auto_collect_all_gold()` and `_award_survival_bonus()` at the start of `_handle_room_clear()`, before `_end_active_encounter()`.

### Verification
- Headless parse check passes.
- Gold pickups are pulled toward nearest player when within 80px.
- Gold pickups are collected when within 24px.
- When collected, ALL players receive the full gold amount.
- All remaining gold is auto-collected when room clears.
- 20g survival bonus is awarded on room clear.
- `RunState.get_player_gold(0)` and `RunState.get_player_gold(1)` both increase equally after any gold collection.

---

## Phase 5 — Gold HUD Display

**Goal:** Show each player's gold total on the combat HUD during play.

### Files to change

**`scripts/game/CoopManager.gd`**

In `_build_hud()`, add a gold display per player. Add a label reference:

```gdscript
var _gold_labels: Array = []
```

After building the player inventory HUDs, add a gold label per player near their HUD panel:

```gdscript
_gold_labels.clear()
for index in range(_player_configs.size()):
    var gold_label := Label.new()
    gold_label.text = "0g"
    gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    gold_label.add_theme_font_size_override("font_size", 16)
    gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.95))
    # Position near the player's inventory HUD
    gold_label.position = Vector2(24.0, 840.0 + index * 140.0 - 24.0) if index == 0 else Vector2(1676.0, 840.0 - 24.0)
    _hud_root.add_child(gold_label)
    _gold_labels.append(gold_label)
```

In `_refresh_hud()`, update gold labels:

```gdscript
for index in range(min(_gold_labels.size(), _player_configs.size())):
    (_gold_labels[index] as Label).text = "%dg" % RunState.get_player_gold(index)
```

### Verification
- Headless parse check passes.
- Gold count is visible on the HUD during combat.
- Gold count updates in real-time as gold is collected.

---

## Phase 6 — Mutation Pick Screen: Gold-Gated

**Goal:** Replace the free mutation pick with a gold-gated mutation shop. Players spend gold to buy mutation picks.

### Mutation cost constants

Add to `CoopManager.gd` or a shared constants location:

```gdscript
const MUTATION_PICK_COSTS := [15, 50, 100]
```

### Files to change

**`scripts/ui/MutationPickUI.gd`**

This is the biggest change. The current UI shows 3 options per player and the player picks 1. The new UI must:

1. Show 3 mutation options (same as before)
2. Show the player's current gold
3. Show the cost of picking each mutation (1st = 15g, 2nd = 50g, 3rd = 100g)
4. Allow the player to pick 0, 1, 2, or 3 mutations (as many as they can afford)
5. Allow the player to confirm / skip when done

**Rework `configure_for_players()`:**

Add new parameters:

```gdscript
func configure_for_players(configs: Array, options_by_player: Array, gold_per_player: Array, pick_costs: Array) -> void:
```

Store `gold_per_player` and `pick_costs` as instance variables.

**Rework the selection model:**

Currently: each player selects exactly 1 mutation and confirms.

New behavior:
- Each player sees 3 mutation cards.
- Each card shows its cost (1st selected = 15g, 2nd = 50g, 3rd = 100g).
- Player toggles cards on/off with left/right + confirm (A button / Space).
- A "Done" option appears after the cards. Selecting "Done" and pressing confirm finalizes.
- OR: player presses a separate "skip/done" button (B button / Escape) to finalize with current selections.
- When finalizing: selected mutations are purchased, gold is deducted, unselected mutations are skipped.

Simplest implementation for Codex:
- Keep the current left/right card navigation.
- Change confirm behavior: pressing confirm on a card **toggles** it (selected/unselected) instead of finalizing.
- Add a 4th "Done" element after the 3 cards. Pressing confirm on "Done" finalizes.
- Cards that cost more gold than the player has are greyed out and unselectable.
- Show cost on each card and remaining gold at the top.

**Rework the signal:**

Change `selections_confirmed` to emit an array of arrays (one per player), where each inner array contains the IDs of all purchased mutations (0 to 3):

```gdscript
signal selections_confirmed(selections_per_player: Array)
```

Each entry in `selections_per_player` is an Array of mutation ID strings (can be empty if player bought nothing).

**`scripts/game/CoopManager.gd`**

Modify `_show_mutation_pick()`:

```gdscript
func _show_mutation_pick() -> void:
    _awaiting_mutation_pick = true
    _mutation_pick_ui = MutationPickUIScene.instantiate()
    _mutation_pick_ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    var options_by_player: Array = []
    var gold_per_player: Array = []
    for player_index in range(_player_nodes.size()):
        options_by_player.append(_mutation_system.roll_mutation_options(player_index, 3))
        gold_per_player.append(RunState.get_player_gold(player_index))
    _mutation_pick_ui.configure_for_players(_player_configs, options_by_player, gold_per_player, MUTATION_PICK_COSTS)
    _mutation_pick_ui.selections_confirmed.connect(_on_mutation_selections_confirmed)
    ui_layer.add_child(_mutation_pick_ui)
    get_tree().paused = true
```

Modify `_on_mutation_selections_confirmed()`:

```gdscript
func _on_mutation_selections_confirmed(selections_per_player: Array) -> void:
    get_tree().paused = false
    for player_index in range(min(selections_per_player.size(), _player_nodes.size())):
        var selected_ids: Array = selections_per_player[player_index]
        for pick_index in range(selected_ids.size()):
            var mutation_id: String = str(selected_ids[pick_index])
            if mutation_id.is_empty():
                continue
            var cost: int = MUTATION_PICK_COSTS[mini(pick_index, MUTATION_PICK_COSTS.size() - 1)]
            if RunState.spend_player_gold(player_index, cost):
                _mutation_system.apply_mutation(player_index, mutation_id)
    _rebuild_player_loadouts()
    if _mutation_pick_ui != null and is_instance_valid(_mutation_pick_ui):
        _mutation_pick_ui.queue_free()
    _mutation_pick_ui = null
    _awaiting_mutation_pick = false
    _finish_room_progression(_pending_clear_summary)
```

### Verification
- Headless parse check passes.
- Mutation pick screen shows gold and costs.
- Player can buy 0, 1, 2, or 3 mutations depending on gold.
- Gold is deducted after purchase.
- Player can skip (buy 0) if they want to save gold.
- Selecting mutations that cost more than available gold is not possible.

---

## Phase 7 — Gold Display on Map Screen

**Goal:** Show each player's gold total on the map/route selection screen so players can make informed route decisions.

### Files to change

**`scripts/ui/RunFlow.gd`**

In `_show_map()`, add gold display to the map status:

```gdscript
var gold_text := ""
for player_index in range(RunState.player_configs.size()):
    gold_text += "  P%d: %dg" % [player_index + 1, RunState.get_player_gold(player_index)]
map_status_label.text = "Floor %d of %d.%s" % [current_floor, map_rows.size(), gold_text]
```

### Verification
- Headless parse check passes.
- Map screen shows gold per player.

---

## Phase 8 — Room-End Summary Shows Gold Earned

**Goal:** After a room clears, show how much gold was earned before the mutation pick screen.

### Files to change

**`scripts/game/CoopManager.gd`**

Modify `_handle_room_clear()` to include gold in the clear context:

```gdscript
func _handle_room_clear(summary: String) -> void:
    if _room_clear_started:
        return
    _room_clear_started = true
    _auto_collect_all_gold()
    _award_survival_bonus()
    var gold_summary := "\nGold earned: %dg (includes %dg survival bonus)" % [_room_gold_earned, SURVIVAL_BONUS_GOLD]
    _pending_clear_summary = summary + gold_summary
    _lock_player_input(true)
    _end_active_encounter()
    if _room_type == "boss":
        _finish_room_progression(_pending_clear_summary)
        return
    _show_mutation_pick()
```

### Verification
- Headless parse check passes.
- Room clear summary shows gold earned per player.

---

## Phase Summary

| Phase | Scope | Dependencies |
|-------|-------|-------------|
| 1. Gold State | `RunState.gd`, `PlayerInventory.gd` | None |
| 2. Gold Pickup Scene | New `GoldPickup.gd`, new `GoldPickup.tscn` | None |
| 3. Enemy Death Drops | `CoopManager.gd`, `Enemy.gd`, `GameWorld.tscn` | Phase 1, 2 |
| 4. Gold Collection | `CoopManager.gd` | Phase 3 |
| 5. Gold HUD | `CoopManager.gd` | Phase 4 |
| 6. Mutation Pick Rework | `MutationPickUI.gd`, `CoopManager.gd` | Phase 4 |
| 7. Map Gold Display | `RunFlow.gd` | Phase 1 |
| 8. Room-End Summary | `CoopManager.gd` | Phase 4 |

Phases 1-2 can run in parallel (no dependencies on each other).
Phases 5, 6, 7, 8 can run in any order after Phase 4.

---

## Files Changed Summary

| File | Phases | Change Type |
|------|--------|-------------|
| `scripts/game/PlayerInventory.gd` | 1 | Add `gold` property |
| `scripts/game/RunState.gd` | 1 | Add gold get/add-to-all/spend functions, update summary |
| `scripts/pickups/GoldPickup.gd` | 2 | **New file** |
| `scenes/pickups/GoldPickup.tscn` | 2 | **New file** |
| `scripts/enemies/Enemy.gd` | 3 | Add `get_type_name()` if missing |
| `scripts/game/CoopManager.gd` | 3, 4, 5, 6, 8 | Gold drop, collection, HUD, mutation rework, summary |
| `scenes/game/GameWorld.tscn` | 3 | Add `Pickups` Node2D child |
| `scripts/ui/MutationPickUI.gd` | 6 | Full rework: gold-gated multi-select |
| `scripts/ui/RunFlow.gd` | 7 | Add gold display to map status |

---

## What This Does NOT Include

These are future work items, not part of this implementation:

- Shop nodes (separate implementation after gold economy validates)
- Encounter type restructuring (Combat / Elite node types on map)
- Modifier system reintroduction
- Mini-boss / elite enemy archetypes
- Side challenges
- Meta progression / ability unlocks
- Gold balance tuning (all values are placeholders)

---

## Important Notes for Codex

1. **GDScript only.** No C#, no C++, no plugins.
2. **Godot 4.6.2 stable.** Use only stable 4.6.2 API.
3. **Run the headless parse check after every phase.** If it fails, fix the error before moving on.
4. **Do not modify files not listed in each phase.** Keep changes minimal and focused.
5. **Do not remove the capture_the_hill objective.** It stays in the codebase but is secondary to survive. Do not break it.
6. **Preserve all existing signals and connections.** The mutation pick signal changes signature in Phase 6 — update all callers.
7. **Test with 1-player and 2-player configurations.** Gold collection and HUD must work for both.
8. **The `Pickups` Node2D must be added to `GameWorld.tscn` in the scene tree.** It sits alongside `Players`, `Projectiles`, `Enemies`, `Effects`.
9. **Gold pickup visual is a simple Polygon2D circle.** No sprites, no textures. Matches the neon geometric style.
10. **All gold/cost values are placeholders.** Do not spend time balancing. Use the exact values in this plan.
11. **Co-op gold model: shared pickups, personal wallets.** When any player collects a gold pickup, ALL players receive the full amount. Use `RunState.add_gold_to_all_players()`, not a per-player add. Each player spends from their own wallet independently.
12. **Survival bonus: 20g flat on every room clear.** Added via `_award_survival_bonus()` in `_handle_room_clear()`. This prevents zero-progression death spirals.
13. **Mutation pick costs are 15 / 50 / 100.** First pick is intentionally cheap so even a struggling player can afford one mutation per room.
