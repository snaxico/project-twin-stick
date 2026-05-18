# V2 Implementation Plan — Refactor to New Direction

## Branch Strategy

- Current version stays untouched on `codex/patch-15-followup`
- All v2 work happens on a new branch: `v2/core-refactor`
- Branch from current HEAD so all existing work is preserved
- No merging back to main until v2 is playable

## Project Info

- Engine: Godot 4.6.2 (GDScript only)
- Project path: `D:\GameDev\Project_Twin_stick`
- Validation command after every phase:
  ```powershell
  & 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit
  ```
- Must pass headless parse with zero errors after each phase

## Design Reference

Read `docs/design/game-direction-v2.md` for full context. Key decisions:

- 1 primary weapon + 1 secondary ability per player (both can mutate)
- Bigger open arena with Brotato-style zoom camera
- Each player independently picks 1 of 3 mutations after each room
- Enemies: Chaser + Charger + Boss only (Spitter/Bruiser disabled)
- No layouts, no modifiers, no recipes for now
- No meta progression for now
- Minimal HUD: health + weapon + secondary + mutation icons
- Run map (RunFlow) stays but is not touched in this refactor
- Encounter builder stays and gets adapted

---

## Phase 1 — Zoom Camera + Bigger Arena

**Goal:** Replace the fixed fullscreen camera with a Brotato-style zoom camera and expand the arena to ~2-3x current size.

### 1A — Expand Arena Size

**File:** `scripts/game/CoopManager.gd`

Find the arena/floor size constants and the `_rebuild_floor_grid()` function (line ~3724) and `_apply_collision_bounds_from_floor()` (line ~3755). Also look at `_start_room()` (line ~669) and `_apply_layout_preset()` (line ~2821).

- Find the current arena dimensions (the floor polygon size or the default layout bounds)
- Multiply both X and Y by 2.5 to create a larger play area
- Update the collision bounds to match the new size
- Update `_rebuild_floor_grid()` to tile across the larger area
- In `_apply_layout_preset()`, make the `default` layout use the new larger size
- Do NOT touch any other layout presets yet — they will be disabled in Phase 3

**File:** `scenes/game/GameWorld.tscn`

- If the arena size is defined in the scene file, update it there as well
- Ensure the floor polygon and collision walls match the new dimensions

### 1B — Zoom Camera

**New file:** `scripts/game/ZoomCamera.gd`

Create a Camera2D script that:

1. Tracks all living players by computing the center point of all active player positions
2. Calculates the bounding box of all players plus a padding margin (~200-300px)
3. Sets the camera zoom level to fit all players on screen:
   - When players are close together: zoom IN (closer view, more detail)
   - When players spread apart: zoom OUT (wider view)
4. Clamps zoom to a defined range:
   - `zoom_min` (~0.4): maximum zoom-out, this IS the effective arena leash — players cannot spread further than this allows
   - `zoom_max` (~1.2): maximum zoom-in when players are very close
5. Smoothly interpolates both position and zoom (lerp, ~8.0 * delta)
6. Single player: camera follows them with a comfortable zoom level (~0.8-1.0)

**File:** `scripts/game/CoopManager.gd`

- In `_ready()` or `_start_room()`: instantiate or configure the ZoomCamera instead of the current fixed camera setup
- Find where the current camera is set up (look for Camera2D references in `_ready()` or `_start_room()`)
- Replace with the new ZoomCamera, parent it to the game world
- Pass the player node list to ZoomCamera each frame or on player spawn/death

**File:** `scenes/game/GameWorld.tscn`

- If a Camera2D node exists in the scene, remove it (it will be created by script)
- OR replace it with the ZoomCamera script

### 1C — Update Spawn Positions

**File:** `scripts/game/CoopManager.gd`

The spawn position system (functions around lines 2705-2821) currently uses fixed markers or arena-relative positions based on the old arena size.

- Update `_get_enemy_spawn_positions()` and `_find_enemy_spawn_position()` to use the new larger arena bounds
- Update `_build_wave_spawn_positions()` (line ~817) to sample across the full new arena
- Update player spawn positions in `_spawn_players()` (line ~413) to spawn near the center of the new arena, not at old fixed positions
- Ensure the minimum-distance-from-player constraint in `_is_enemy_spawn_position_valid()` (line ~2731) still works at the new scale

### 1D — Update Capture Hill Position

**File:** `scripts/game/CoopManager.gd`

- `_spawn_capture_hill_zone()` (line ~2559) and `_roll_capture_hill_position()` (line ~2568) need to account for the larger arena
- The hill should spawn somewhere within the arena, not always at center

**Verification:** Headless parse passes. Game launches. Arena is larger. Camera zooms in/out as players move apart/together. Enemies spawn across the full arena. Can play a basic room.

**Commit after this phase.**

---

## Phase 2 — Strip to 1 Primary + 1 Secondary

**Goal:** Simplify each player from 2 primary + 2 secondary weapon slots to 1 primary + 1 secondary.

### 2A — Simplify RunState

**File:** `scripts/game/RunState.gd` (1938 lines)

Find the player inventory/loadout data structures. Currently each player has 2 primary slots and 2 secondary slots with weapon data, levels, passive compilation, and tag filtering.

- Reduce to 1 primary slot + 1 secondary slot per player
- Remove: duplicate weapon leveling logic (weapons no longer level up from duplicates)
- Remove: `requires_tags` filtering and per-slot passive application
- Remove: shop offer generation
- Keep: basic weapon stat reading (damage, fire_rate, projectile_speed, etc.)
- Keep: run-mode health persistence (Normal vs Easy)
- Add: `mutations: Array` per player — an ordered list of mutation IDs applied to this player

### 2B — Simplify PlayerInventory

**File:** `scripts/game/PlayerInventory.gd` (121 lines)

- Reduce from 2+2 slots to 1+1
- Remove slot selection cycling (no need to switch between weapons)
- Keep: reference to current primary and secondary

### 2C — Simplify Weapon Data

**File:** `data/weapons.json`

- Keep only the starting weapons needed for now. Minimum: one primary (Rifle) and one secondary (Grenade)
- Remove level-up tiers (Lv1-Lv5 progression)
- Remove weapon families that are not starting weapons for now (Scatter, Slug, Incinerator, Beam Lance, Arc Caster, Cluster Grenade, Siege Grenade, Shrapnel Mine, Heavy Mine)
- Keep the base stats for Rifle and Grenade as simple flat values

### 2D — Simplify CoopManager Weapon Execution

**File:** `scripts/game/CoopManager.gd`

- `_on_player_fire_requested()` (line ~904): simplify to always use the one primary weapon
- `_on_player_secondary_requested()` (line ~910): simplify to always use the one secondary
- Remove: `_execute_primary_cone()`, `_execute_primary_beam()`, `_execute_primary_chain()`, and all chain-target helper functions (lines ~954-1069) — these were for Incinerator/Beam Lance/Arc Caster which are removed
- Keep: `_execute_primary_behavior()` but simplify to only handle `projectile` type
- Keep: `_spawn_grenade()` for the secondary
- Remove: `_spawn_mine()` and `_is_mine_secondary_kind()` (mine system removed)
- Remove: all passive trigger processing — `_process_primary_trigger_event()`, `_execute_primary_trigger_action()`, `_execute_trigger_explosion()`, `_execute_trigger_behavior()` (lines ~1449-1543)

### 2E — Simplify Player

**File:** `scripts/player/Player.gd` (1117 lines)

- Remove weapon slot switching input handling
- Primary fire always uses the one weapon
- Secondary always uses the one ability
- Keep: movement, dash, health, revive, damage, aim direction

### 2F — Remove Loot/Vote/Replacement Flow

**File:** `scripts/game/CoopManager.gd`

Remove or gut the following functions (they will be replaced by the mutation pick screen in Phase 4):

- `_begin_loot_drop()` (line ~1832)
- `_on_loot_drop_interacted()` (line ~1849)
- `_begin_loot_vote()` (line ~1854)
- `_update_loot_resolution()` (line ~1880)
- `_poll_loot_interaction_inputs()` (line ~1890)
- `_update_loot_vote()` (line ~1903)
- `_begin_weapon_replacement()` (line ~1936)
- `_begin_shop_weapon_replacement()` (line ~1944)
- `_show_weapon_replacement_ui()` (line ~1960)
- `_update_weapon_replacement()` (line ~1985)
- `_commit_weapon_replacement()` (line ~2020)
- `_complete_loot_resolution()` (line ~2057)
- `_reset_loot_resolution_state()` (line ~2091)

In `_handle_room_clear()` (line ~1800), after showing the result, skip directly to opening the exit zone instead of starting loot flow. The mutation pick will be added in Phase 4.

**Verification:** Headless parse passes. Game launches. Each player has 1 primary (Rifle) + 1 secondary (Grenade). No weapon switching. No loot drops. No shop. Rooms end and exit opens directly.

**Commit after this phase.**

---

## Phase 3 — Strip Obsolete Systems

**Goal:** Remove layout, modifier, recipe, generator, hazard, shop, and meta systems.

### 3A — Remove Layout/Obstacle System

**File:** `scripts/game/CoopManager.gd`

- Gut `_apply_layout_preset()` (line ~2821, ~170 lines) — replace with a single open arena setup using the default enlarged floor. Keep just the floor polygon and collision bounds, remove all obstacle placement logic.
- Remove: `_spawn_obstacles()`, `_spawn_obstacle_segments()`, `_spawn_rect_obstacle()` (lines ~2994-3082)
- Remove: `_sanitize_generator_positions()`, `_resolve_generator_position()`, `_is_generator_position_clear()` (lines ~3082-3129)
- Remove: `_clear_obstacles()` (line ~3129)
- Remove: all layout palette functions — `_get_layout_palette()`, `_apply_layout_palette()` (lines ~3622-3632)

### 3B — Remove Recipe Engine

**File:** `scripts/game/RecipeEngine.gd` — archive or delete entirely
**File:** `data/recipes.json` — archive or delete

**File:** `scripts/game/CoopManager.gd`

- Remove all references to RecipeEngine
- In `_start_room()` and `configure_room()`, remove recipe selection and weight-hint lookup
- Room configuration should now just need: objective type + depth

### 3C — Remove Modifier System

**File:** `scripts/game/ModifierEngine.gd` — archive or delete
**File:** `data/modifiers.json` — archive or delete
**File:** `scripts/game/HotFloorZone.gd` — archive or delete
**File:** `scripts/game/DeathPuddle.gd` — archive or delete

**File:** `scripts/game/CoopManager.gd`

- Remove: `_update_modifier_hazards()`, `_update_hot_floor_zones()`, `_spawn_hot_floor_batch()`, `_roll_hot_floor_zone_position()`, `_is_hot_floor_position_clear()` (lines ~2500-2560)
- Remove: `_spawn_death_puddle()`, `_update_death_puddles()`, `_clear_modifier_hazards()` (lines ~2601-2637)
- Remove: `_apply_modifier_visuals()` (line ~2490)
- Remove: `_build_modifier_status_text()` (line ~478)
- Remove: `_refresh_modifier_chip()` (line ~3603)
- Remove: `_update_darkness_overlay()` (line ~3632)
- Remove: modifier intro panel logic in `_show_room_intro()` (line ~2469)
- Remove: modifier references in `_start_room()`

### 3D — Remove Generator System

**File:** `scripts/game/GeneratorObjective.gd` — archive or delete
**File:** `scenes/game/GeneratorObjective.tscn` — archive or delete

**File:** `scripts/game/CoopManager.gd`

- Remove: `_spawn_generators()`, `_on_generator_destroyed()`, `_on_generator_hit_received()`, `_on_generator_spawn_requested()`, `_spawn_generator_enemy()` (lines ~1169-1243)
- Remove: `_drop_pickups_for_generator()` (line ~1258)
- Remove: `_update_generator_room()`, `_evaluate_generator_room_clear()` (lines ~1666-1704)
- Remove: `_is_generator_room()` (line ~2686)
- Remove: `_get_alive_generators()` (line ~2698)

### 3E — Remove Shop System

**File:** `scripts/game/ShopStation.gd` — archive or delete
**File:** `scenes/game/ShopStation.tscn` — archive or delete
**File:** `scripts/ui/ShopUI.gd` — archive or delete
**File:** `scenes/ui/ShopUI.tscn` — archive or delete

**File:** `scripts/game/CoopManager.gd`

- Remove: `_start_shop_room()` through `_reset_shop_room_state()` (lines ~2186-2382)
- Remove: all shop input polling functions

### 3F — Remove Obsolete UI

**File:** `scripts/ui/LootVoteUI.gd` — archive or delete
**File:** `scenes/ui/LootVoteUI.tscn` — archive or delete
**File:** `scripts/ui/WeaponReplaceUI.gd` — archive or delete
**File:** `scenes/ui/WeaponReplaceUI.tscn` — archive or delete
**File:** `scripts/game/LootDrop.gd` — archive or delete
**File:** `scenes/game/LootDrop.tscn` — archive or delete

### 3G — Remove Obsolete Data

**File:** `data/passives.json` — archive or delete
**File:** `data/items.json` — archive or delete
**File:** `data/modifiers.json` — already handled in 3C
**File:** `data/recipes.json` — already handled in 3B

**File:** `scripts/game/PassiveTriggerSystem.gd` — archive or delete

### 3H — Disable Spitter + Bruiser

**File:** `scripts/enemies/Enemy.gd` and/or `data/enemies.json`

- Do NOT delete Spitter/Bruiser code — just remove them from spawn pools
- In the wave composition logic in CoopManager (`_roll_wave_composition()` line ~779), only allow `chaser` and `charger` enemy types
- Boss spawning stays as-is

### 3I — Disable Meta Progression

**File:** `scripts/meta/ProfileState.gd`

- Keep the file and the save/load shell
- Disable meta gold accumulation and unlock purchasing
- The profile can still store settings (aim mode, screen effects)

**File:** `scripts/ui/Bootstrap.gd`

- Hide or remove the `Meta` button from the home menu
- Keep `Play`, `Settings`, `Encounter Builder`

### 3J — Remove Obsolete Data/Scene References

After removing the above files, grep the entire project for any remaining references to deleted files/classes:

- `RecipeEngine`
- `ModifierEngine`
- `HotFloorZone`
- `DeathPuddle`
- `GeneratorObjective`
- `ShopStation`
- `ShopUI`
- `LootVoteUI`
- `LootDrop`
- `WeaponReplaceUI`
- `PassiveTriggerSystem`
- `MineProjectile`

Fix any remaining references so the project compiles cleanly.

**Verification:** Headless parse passes. Game launches. Rooms are open arenas with no obstacles. No modifiers. No recipes. No generators. No shop. No loot drops. No mines. Only Chasers + Chargers + Boss spawn. Meta button is hidden. Rooms clear and exit opens directly.

**Commit after this phase.**

---

## Phase 4 — Minimal HUD

**Goal:** Replace the current multi-slot HUD with a minimal display.

### 4A — Simplify Player HUD

**File:** `scripts/ui/PlayerInventoryHUD.gd` (199 lines)
**File:** `scripts/ui/WeaponSlotHUD.gd` (174 lines)

Rewrite the player HUD to show only:

1. Health bar (keep existing)
2. One primary weapon icon
3. One secondary ability icon + cooldown indicator
4. A row of small mutation icons (empty for now — mutations added in Phase 5)

Remove:
- 4-slot weapon display
- Passive chip display
- Selected-slot highlight
- Slot switching indicators

**File:** `scripts/game/CoopManager.gd`

- Simplify `_build_hud()` (line ~3256, ~130 lines) to build the minimal HUD
- Simplify `_refresh_player_inventory_huds()` (line ~3410) for the new simpler data
- Remove: modifier chip from the top-center HUD
- Keep: timer bar, result/pause panels, room intro panel (without modifier text)

**Verification:** Headless parse passes. HUD shows health + weapon + secondary per player. Clean and minimal.

**Commit after this phase.**

---

## Phase 5 — Mutation System

**Goal:** Build the core mutation system — definitions, application, and between-room pick screen.

### 5A — Mutation Data

**New file:** `data/mutations.json`

Define an initial set of ~8-10 mutations. Each mutation has:

```json
{
  "id": "ricochet",
  "name": "Ricochet",
  "description": "Projectiles bounce to a nearby enemy on hit",
  "icon": "ricochet",
  "target": "primary",
  "effect_type": "ricochet",
  "params": { "bounce_count": 1, "bounce_range": 200 }
}
```

Starting mutation roster (visible, always-positive, no stat math):

| ID | Name | Effect |
|----|------|--------|
| `ricochet` | Ricochet | Projectiles bounce to a nearby enemy on hit |
| `pierce` | Pierce | Projectiles pass through 1 extra enemy |
| `split_shot` | Split Shot | Fire 2 extra projectiles in a spread |
| `big_shot` | Big Shot | Projectile size doubled, damage +50% |
| `fire_trail` | Fire Trail | Projectiles leave a short burning trail |
| `rapid_fire` | Rapid Fire | Fire rate doubled |
| `explosion_secondary` | Blast Radius | Secondary explosion radius +50% |
| `secondary_charges` | Extra Charge | Secondary gets +1 use before cooldown |
| `dash_damage` | Impact Dash | Dash damages enemies you pass through |
| `knockback` | Knockback | All hits push enemies away from you |

These are starting examples. The exact mutations can be adjusted. The key is: every one is always positive and visibly changes something.

### 5B — Mutation System Runtime

**New file:** `scripts/game/MutationSystem.gd`

A system that:

1. Loads mutation definitions from `data/mutations.json`
2. Tracks applied mutations per player (ordered list)
3. Provides `get_compiled_weapon_stats(player_index)` that takes base weapon stats and returns modified stats after applying all mutations
4. Provides `get_active_mutations(player_index)` for HUD display
5. Provides `roll_mutation_options(count: int)` → returns N random mutations from the pool (no duplicates of what the player already has)

For mutations that change behavior (ricochet, pierce, fire_trail) rather than stats, the system should expose flags:
- `has_mutation(player_index, mutation_id) -> bool`

The projectile and weapon execution code in CoopManager checks these flags to apply visual/gameplay changes.

### 5C — Apply Mutations to Combat

**File:** `scripts/game/CoopManager.gd`

In the primary fire path (`_execute_primary_behavior()` → `_spawn_projectile()`):

- Check MutationSystem for the firing player
- If `split_shot`: spawn extra projectiles with spread
- If `big_shot`: scale up projectile size and damage
- If `rapid_fire`: reduce fire interval
- If `ricochet`: mark projectile so it bounces on hit
- If `pierce`: mark projectile so it passes through enemies

**File:** `scripts/weapons/Projectile.gd`

- Add `pierce_remaining: int` — if > 0, don't destroy on hit, decrement instead
- Add `ricochet_remaining: int` — if > 0, on hit find nearest other enemy within range, redirect projectile toward it
- Add `leaves_fire_trail: bool` — if true, spawn a small damage area behind the projectile every N frames

For secondary mutations:
- `explosion_secondary`: scale up grenade explosion radius
- `secondary_charges`: allow multiple uses before cooldown kicks in

For dash mutations:
- `dash_damage`: in Dash.gd or Player.gd, if flag is set, deal damage to enemies overlapping the dash path

For general mutations:
- `knockback`: in the hit handling code, apply a push force to enemies when hit

### 5D — Mutation Pick Screen

**New file:** `scripts/ui/MutationPickUI.gd`
**New file:** `scenes/ui/MutationPickUI.tscn`

A simple UI that:

1. Shows 3 mutation cards side by side
2. Each card shows: icon + name + short description
3. Each player picks independently (split screen layout or sequential picks)
4. For co-op: either show both players' picks simultaneously (P1 left side, P2 right side) or have P1 pick first then P2
5. Confirm with gamepad A / keyboard enter
6. After both players pick, return to the game flow

**File:** `scripts/game/CoopManager.gd`

- In `_handle_room_clear()`: after showing result, instead of opening exit zone immediately, show MutationPickUI
- After both players have picked, then open the exit zone
- Wire up: `MutationSystem.roll_mutation_options(3)` for each player, pass to UI, receive selection back, apply via `MutationSystem.apply_mutation(player_index, mutation_id)`

### 5E — Update HUD with Mutations

**File:** `scripts/ui/PlayerInventoryHUD.gd`

- Add a row of small icons below the weapon display
- Each icon represents one active mutation
- Use `IconFactory` to generate procedural placeholder icons for each mutation (use the mutation name as a seed)
- Update the icon row when mutations change

**Verification:** Headless parse passes. After clearing a room, each player sees 3 mutation options and picks one. The mutation visibly affects combat (e.g., split shot fires more projectiles). HUD shows active mutations. Multiple mutations stack.

**Commit after this phase.**

---

## Phase 6 — Objective Variety

**Goal:** Add hold-zone objective alongside survive. Make rooms feel different.

### 6A — Objective Assignment

**File:** `scripts/game/CoopManager.gd`

- In `_start_room()` or `configure_room()`: assign an objective type per room
- For now: alternate between `survive` and `capture_the_hill`, or weight by depth
- The objective type determines win condition and any extra scene elements (hill zone)
- `capture_the_hill` already exists via `CaptureHillZone.gd`

### 6B — Adapt Capture Hill to Bigger Arena

**File:** `scripts/game/CaptureHillZone.gd`
**File:** `scripts/game/CoopManager.gd`

- Hill position should use the larger arena space — spawn it in a random quadrant, not always center
- Ensure the hill zone scales appropriately for the larger arena
- Verify hill progress fill/drain rates still feel right at the new arena scale

### 6C — Encounter Builder Adaptation

**File:** `scripts/ui/Bootstrap.gd`

Update the encounter builder to work with new systems:

- Remove layout dropdown (no layouts)
- Remove modifier dropdown (no modifiers)
- Keep objective dropdown: `Survive`, `Hold Zone`
- Remove recipe dropdown
- Add: starting mutation selection (for testing specific mutations)
- Keep: enemy composition options (but limited to Chaser + Charger)
- Keep: depth/wave selection
- Auto-launch into the configured room and return to builder on complete (existing behavior)

**Verification:** Headless parse passes. Rooms alternate between survive and hold-zone objectives. Hold zone works in the bigger arena. Encounter builder can test both objective types.

**Commit after this phase.**

---

## Phase 7 — Tuning Pass

**Goal:** Make the core loop feel good. This is not code-heavy — it's playtesting and number adjustment.

### Tuning Targets

**Enemy pacing:**
- Chaser HP, speed, damage — should die fast, feel like fodder
- Charger charge speed, recovery time, windup — must force dodge, punish recovery
- Wave size and spawn intervals per depth — should escalate clearly
- Boss HP and attack patterns — should feel like a climax

**Weapon feel:**
- Rifle damage vs Chaser HP — Chasers should die in 2-3 hits max
- Rifle fire rate — should feel active, not sluggish
- Grenade cooldown, radius, damage — should feel like a panic button
- Projectile speed and size — must read clearly in the bigger arena

**Mutation balance:**
- Each mutation should be visibly impactful immediately
- Stacking 3+ mutations should feel noticeably powerful
- Late-run with 6+ mutations should feel ridiculous

**Camera feel:**
- Zoom speed — smooth but responsive
- Zoom range — close enough to see detail, far enough for co-op spread
- Player padding — enough breathing room at all zoom levels

**Arena scale:**
- Too big = running simulator. Too small = old problem
- Find the sweet spot where objectives in corners feel like a decision but not a trek

### Tuning Method

Use the encounter builder for focused tests:
- Test A: Survive, Chasers only — is shooting satisfying?
- Test B: Survive, Chasers + Chargers — does Charger force dodge?
- Test C: Hold Zone, mixed enemies — does the objective create interesting positioning?
- Test D: Multiple rooms in sequence — does the mutation pickup feel rewarding?

**Commit after meaningful tuning changes.**

---

## Phase Summary

| Phase | What | Estimated Scope |
|-------|------|----------------|
| 1 | Zoom camera + bigger arena | Medium — new system + arena resize |
| 2 | Strip to 1 primary + 1 secondary | Medium — simplify many files |
| 3 | Remove obsolete systems | Large — delete/archive many files, clean references |
| 4 | Minimal HUD | Small — rewrite HUD display |
| 5 | Mutation system | Large — new system, data, UI, combat integration |
| 6 | Objective variety + builder adaptation | Small-Medium — adapt existing systems |
| 7 | Tuning pass | Ongoing — playtesting and number tweaks |

## Constraints

- Every phase must pass headless parse before moving to the next
- Do NOT touch RunFlow — the map system is preserved as-is for now
- Do NOT create new enemy types
- Do NOT build meta progression
- Do NOT design the shop — shop nodes on the map can exist but are non-functional for now
- Do NOT add arena layouts or obstacles
- Prefer deleting/archiving obsolete code over commenting it out
- When archiving: move files to a new `archive/v1/` folder rather than deleting, so they can be referenced if needed

## File Deletion / Archive Plan

Move these to `archive/v1/scripts/` and `archive/v1/scenes/` and `archive/v1/data/`:

**Scripts:**
- `scripts/game/RecipeEngine.gd`
- `scripts/game/ModifierEngine.gd`
- `scripts/game/HotFloorZone.gd`
- `scripts/game/DeathPuddle.gd`
- `scripts/game/GeneratorObjective.gd`
- `scripts/game/LootDrop.gd`
- `scripts/game/ShopStation.gd`
- `scripts/game/PassiveTriggerSystem.gd`
- `scripts/game/RoomPickup.gd`
- `scripts/ui/LootVoteUI.gd`
- `scripts/ui/ShopUI.gd`
- `scripts/ui/WeaponReplaceUI.gd`
- `scripts/weapons/MineProjectile.gd`

**Scenes:**
- `scenes/game/GeneratorObjective.tscn`
- `scenes/game/LootDrop.tscn`
- `scenes/game/ShopStation.tscn`
- `scenes/game/RoomPickup.tscn`
- `scenes/ui/LootVoteUI.tscn`
- `scenes/ui/ShopUI.tscn`
- `scenes/ui/WeaponReplaceUI.tscn`
- `scenes/weapons/MineProjectile.tscn`
- `scenes/weapons/GrenadeProjectile.tscn` (archive, rebuild grenade as simpler secondary)

**Data:**
- `data/recipes.json`
- `data/modifiers.json`
- `data/passives.json`
- `data/items.json`
