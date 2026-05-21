# V2 Implementation Plan — Historical Record

## Status

- This file is a historical implementation record.
- It describes the earlier refactor plan that created `v2/core-refactor`.
- Do not use this as the source of truth for the current runtime.
- Use these instead for active work:
  - `docs/development/current-state.md`
  - `docs/development/start-of-day.md`
  - `docs/design/roadmap.md`
  - `docs/process/architecture.md`

## Branch Strategy

- Stable current gameplay lives on `main` at commit `e71d366`
- All v2 work happens on branch: `v2/core-refactor`
- The old version is fully preserved — switch back with `git checkout main` at any time
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
- No shop — shop nodes removed from map generation
- Minimal HUD: health + weapon + secondary + mutation icons
- Run map (RunFlow) stays but is not touched in this refactor
- Encounter builder stays and gets adapted

## Resolved Design Decisions

These were flagged during review and are now locked:

| Decision | Answer |
|----------|--------|
| Camera leash when players exceed zoom-out limit | **Hard distance clamp.** Players physically cannot move further apart than the zoom-out limit allows. Invisible wall enforced at the movement level. |
| Shop nodes on the run map | **Skip entirely.** Remove shop nodes from map generation. Only combat, rest, and boss nodes exist during v2. |
| Refactor approach for CoopManager + RunState | **Rewrite core flow from scratch.** Create new slimmed-down versions of CoopManager and RunState. Copy over only what's needed. The old files are too coupled to surgically edit. |
| GrenadeProjectile.tscn | **Stays.** It is the live secondary weapon. Do NOT archive it. Only MineProjectile gets archived. |
| Valid room types between Phase 3 and Phase 6 | **Combat (survive only), rest, boss.** No shop, no generators, no elites (map to regular combat). |
| `ricochet` + `pierce` stacking | **Pierce first, ricochet on final hit.** Projectile passes through enemies (pierce count), then on the last hit bounces to a new target (ricochet). |
| `secondary_charges` cooldown model | **2 uses, then full cooldown.** Fire both whenever you want. One shared cooldown timer recharges both after the second use. |
| `fire_trail` behavior | **Trail lasts 1.5s, ticks damage every 0.5s, deals ~30% of primary damage per tick.** |
| `dash_damage` behavior | **Deals 100% of primary damage, hits each enemy once per dash, no multi-hit.** |

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
- Do NOT touch any other layout presets yet — they will be removed in Phase 3

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
   - `zoom_min` (~0.4): maximum zoom-out — this defines the visual limit
   - `zoom_max` (~1.2): maximum zoom-in when players are very close
5. Smoothly interpolates both position and zoom (lerp, ~8.0 * delta)
6. Single player: camera follows them with a comfortable zoom level (~0.8-1.0)

### 1C — Player Distance Clamp

**File:** `scripts/player/Player.gd` or `scripts/game/ZoomCamera.gd`

Enforce a hard maximum distance between players:

- Define `MAX_PLAYER_SEPARATION` — tied to what the camera can show at `zoom_min`
- Each frame, after player movement, check if any player is further than `MAX_PLAYER_SEPARATION` from the group center
- If so, clamp their position back to the boundary
- This is an invisible wall — the player simply cannot walk further apart
- Single player: no clamp needed

**File:** `scripts/game/CoopManager.gd`

- In `_ready()` or `_start_room()`: instantiate or configure the ZoomCamera instead of the current fixed camera setup
- Find where the current camera is set up (look for Camera2D references in `_ready()` or `_start_room()`)
- Replace with the new ZoomCamera, parent it to the game world
- Pass the player node list to ZoomCamera each frame or on player spawn/death

**File:** `scenes/game/GameWorld.tscn`

- If a Camera2D node exists in the scene, remove it (it will be created by script)
- OR replace it with the ZoomCamera script

### 1D — Update Spawn Positions

**File:** `scripts/game/CoopManager.gd`

The spawn position system (functions around lines 2705-2821) currently uses fixed markers or arena-relative positions based on the old arena size.

- Update `_get_enemy_spawn_positions()` and `_find_enemy_spawn_position()` to use the new larger arena bounds
- Update `_build_wave_spawn_positions()` (line ~817) to sample across the full new arena
- Update player spawn positions in `_spawn_players()` (line ~413) to spawn near the center of the new arena, not at old fixed positions
- Ensure the minimum-distance-from-player constraint in `_is_enemy_spawn_position_valid()` (line ~2731) still works at the new scale

### 1E — Update Capture Hill Position

**File:** `scripts/game/CoopManager.gd`

- `_spawn_capture_hill_zone()` (line ~2559) and `_roll_capture_hill_position()` (line ~2568) need to account for the larger arena
- The hill should spawn somewhere within the arena, not always at center

**Verification:** Headless parse passes. Game launches. Arena is larger. Camera zooms in/out as players move apart/together. Players cannot separate beyond the zoom-out limit. Enemies spawn across the full arena. Can play a basic room.

**Commit after this phase.**

---

## Phase 2+3 — Rewrite Core Systems

**Goal:** Replace CoopManager and RunState with new slimmed-down versions. Archive all obsolete systems.

Because CoopManager (3775 lines, 167 functions) and RunState (1938 lines) are deeply coupled to the systems being removed, this phase rewrites them from scratch rather than trying surgical removal.

### Approach

1. Rename current files to `CoopManager_v1.gd` and `RunState_v1.gd` (keep as reference)
2. Create new `CoopManager.gd` and `RunState.gd` from scratch
3. Copy over only the functions and logic that v2 needs
4. Archive all obsolete files
5. Delete the `_v1` reference files after the new versions work

### 2+3A — Rewrite RunState

**New file:** `scripts/game/RunState.gd` (rewritten from scratch)

The new RunState only needs:

**Keep (copy from v1):**
- Run mode (Normal / Easy)
- Per-player health tracking and room-to-room HP persistence
- Room depth / step counter
- Run outcome tracking (win/loss)
- Basic weapon stat reading for one primary + one secondary per player

**New:**
- `mutations: Array` per player — ordered list of applied mutation IDs
- Simple API: `get_primary_weapon(player_index)`, `get_secondary_weapon(player_index)`, `get_mutations(player_index)`

**Remove (do not copy):**
- 2+2 weapon slot arrays
- Duplicate weapon leveling (Lv1-Lv5)
- Per-slot passive compilation
- `requires_tags` filtering
- Shop offer generation
- Loadout compilation with tag/passive resolution

### 2+3B — Rewrite CoopManager

**New file:** `scripts/game/CoopManager.gd` (rewritten from scratch)

The new CoopManager needs these functional areas only:

**Player management (copy and adapt):**
- `_spawn_players()` — spawn at arena center
- Player health/damage/downed/revived signal handling
- `get_active_players()`, `get_player_target_nodes()`, `get_enemy_target_nodes()`
- Gamepad assignment

**Room lifecycle (copy and simplify):**
- `_start_room()` — set up arena (no layouts, no modifiers, no recipes), start objective, begin spawning
- `_evaluate_room_state()` / `_update_room_progress()` — check win condition based on objective
- `_handle_room_clear()` — show result → open mutation pick → open exit zone
- `_update_exit_zone()` / `_trigger_room_exit()` — exit flow

**Combat — primary fire (copy and simplify):**
- `_on_player_fire_requested()` — fire the one primary weapon
- `_execute_primary_behavior()` — projectile only (no cone/beam/chain)
- `_spawn_projectile()` / `_spawn_projectile_from_config()` — keep
- `_apply_damage_with_context()` — keep

**Combat — secondary (copy and simplify):**
- `_on_player_secondary_requested()` — fire the one secondary
- `_spawn_grenade()` — keep (grenade is the live secondary)
- `_on_explosive_detonated()` — keep

**Enemy spawning (copy and adapt):**
- `_build_survival_wave_plan()` / `_spawn_survival_wave()` — keep, but only chaser + charger
- `_roll_wave_composition()` — simplify to only use chaser + charger weights
- `_build_wave_spawn_positions()` — adapted for new arena size (done in Phase 1)
- `_spawn_enemy_wave()` — keep
- `_on_enemy_died()` — keep
- `_on_enemy_hit_received()` — keep
- Boss spawning functions — keep

**Survive objective (copy):**
- Timer-based survival logic from `_update_room_progress()`

**Capture hill objective (copy):**
- `_spawn_capture_hill_zone()`, `_roll_capture_hill_position()`
- `_update_capture_hill_room()`
- `_is_capture_hill_room()`

**HUD (simplify):**
- `_build_hud()` — rewrite for minimal HUD (health + weapon + secondary + mutation icons)
- `_refresh_player_inventory_huds()` — simplified
- Timer bar, result panel, pause panel — keep
- Remove: modifier chip, 4-slot display, passive chips, debug text

**Juice / effects (copy):**
- All SFX functions (`_play_sfx_fire()`, `_play_sfx_hit()`, etc.)
- All juice functions (`_play_intro_juice()`, `_play_damage_juice()`, etc.)
- Hitstop, camera trauma, zoom punch
- Muzzle flash, dash trail
- Floating text functions

**Pause / input (copy):**
- Pause toggle, pause menu, settings panel
- Input helpers for gamepad/keyboard

**Camera (new):**
- ZoomCamera integration from Phase 1

**Do NOT copy:**
- Layout/obstacle system (~200 lines)
- Modifier/hazard system (~150 lines)
- Recipe engine integration
- Generator system (~100 lines)
- Shop system (~200 lines)
- Loot drop/vote/replacement system (~260 lines)
- Mine spawning
- Cone/beam/chain primary behaviors (~120 lines)
- Passive trigger processing (~100 lines)
- Darkness overlay
- Multi-weapon slot HUD building

### 2+3C — Archive Obsolete Files

Move to `archive/v1/` (preserving folder structure):

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

**Data:**
- `data/recipes.json`
- `data/modifiers.json`
- `data/passives.json`
- `data/items.json`

**Do NOT archive (stays live):**
- `scripts/weapons/Projectile.gd` — live primary projectile
- `scenes/weapons/Projectile.tscn` — live primary projectile scene
- `scenes/weapons/GrenadeProjectile.tscn` — live secondary weapon
- `scripts/game/CaptureHillZone.gd` — live objective type

### 2+3D — Simplify Weapon Data

**File:** `data/weapons.json`

- Keep only: Rifle (primary) and Grenade (secondary) as flat stat entries
- Remove: all other weapon families (Scatter, Slug, Incinerator, Beam Lance, Arc Caster, Cluster Grenade, Siege Grenade, Shrapnel Mine, Heavy Mine)
- Remove: level-up tiers (Lv1-Lv5)

### 2+3E — Simplify PlayerInventory

**File:** `scripts/game/PlayerInventory.gd`

- Reduce from 2+2 slots to 1 primary + 1 secondary
- Remove slot selection cycling
- Keep: reference to current primary and secondary

### 2+3F — Simplify Player

**File:** `scripts/player/Player.gd`

- Remove weapon slot switching input handling
- Primary fire always uses the one weapon
- Secondary always uses the one ability
- Keep: movement, dash, health, revive, damage, aim direction

### 2+3G — Disable Spitter + Bruiser

**File:** `data/enemies.json`

- Do NOT delete Spitter/Bruiser entries — just ensure the new CoopManager wave composition only rolls `chaser` and `charger`
- Boss spawning stays as-is

### 2+3H — Disable Meta Progression

**File:** `scripts/meta/ProfileState.gd`

- Keep the file and save/load shell
- Disable meta gold accumulation and unlock purchasing
- Profile still stores settings (aim mode, screen effects)

**File:** `scripts/ui/Bootstrap.gd`

- Hide or remove the `Meta` button from the home menu
- Keep `Play`, `Settings`, `Encounter Builder`

### 2+3I — Remove Shop Nodes from Map

**File:** `scripts/ui/RunFlow.gd`

- This is a minimal touch — only change the map generator to stop emitting shop nodes
- Find where node types are assigned during map generation
- Remove `shop` from the possible node type pool
- Valid node types: `combat`, `rest`, `boss`
- Elite rooms map to regular combat (no separate elite behavior)
- Do NOT restructure RunFlow beyond this — it stays as-is otherwise

### 2+3J — Clean All References

After the rewrite and archiving, grep the entire project for remaining references to:

- `RecipeEngine`, `ModifierEngine`, `HotFloorZone`, `DeathPuddle`
- `GeneratorObjective`, `ShopStation`, `ShopUI`
- `LootVoteUI`, `LootDrop`, `WeaponReplaceUI`
- `PassiveTriggerSystem`, `MineProjectile`, `RoomPickup`

Fix any remaining references. Remove the `_v1` reference files once the new versions work.

**Verification:** Headless parse passes. Game launches with rewritten CoopManager and RunState. Each player has 1 primary (Rifle) + 1 secondary (Grenade). Rooms are open arenas. Only Chasers + Chargers + Boss spawn. No loot, no shop, no modifiers, no layouts. Map has no shop nodes. Rooms clear and exit opens directly. Meta button is hidden.

**Commit after this phase.**

---

## Phase 4 — Minimal HUD

**Goal:** Replace the current multi-slot HUD with a minimal display.

### 4A — Simplify Player HUD

**File:** `scripts/ui/PlayerInventoryHUD.gd`
**File:** `scripts/ui/WeaponSlotHUD.gd`

Rewrite the player HUD to show only:

1. Health bar (keep existing style)
2. One primary weapon icon
3. One secondary ability icon + cooldown indicator
4. A row of small mutation icons (empty for now — mutations added in Phase 5)

Remove:
- 4-slot weapon display
- Passive chip display
- Selected-slot highlight
- Slot switching indicators

### 4B — Simplify CoopManager HUD Building

**File:** `scripts/game/CoopManager.gd`

The new CoopManager's `_build_hud()` should already be minimal from the Phase 2+3 rewrite. Verify:

- No modifier chip in HUD
- No debug text panels
- Timer bar still works
- Result/pause panels still work
- Room intro panel works (without modifier text)

**Verification:** Headless parse passes. HUD shows health + weapon + secondary per player. Clean and minimal.

**Commit after this phase.**

---

## Phase 5 — Mutation System

**Goal:** Build the core mutation system — definitions, application, and between-room pick screen.

### 5A — Mutation Data

**New file:** `data/mutations.json`

Define the initial mutation set. Each mutation entry:

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

Starting roster:

| ID | Name | Target | Effect | Params |
|----|------|--------|--------|--------|
| `ricochet` | Ricochet | primary | Projectiles bounce to nearest enemy on final hit | `bounce_count: 1, bounce_range: 200` |
| `pierce` | Pierce | primary | Projectiles pass through 1 extra enemy | `pierce_count: 1` |
| `split_shot` | Split Shot | primary | Fire 2 extra projectiles in a spread | `extra_count: 2, spread_degrees: 15` |
| `big_shot` | Big Shot | primary | Projectile size doubled, damage +50% | `size_mult: 2.0, damage_mult: 1.5` |
| `fire_trail` | Fire Trail | primary | Projectiles leave a burning trail | `trail_lifetime: 1.5, tick_interval: 0.5, damage_percent: 0.3` |
| `rapid_fire` | Rapid Fire | primary | Fire rate doubled | `fire_rate_mult: 2.0` |
| `blast_radius` | Blast Radius | secondary | Explosion radius +50% | `radius_mult: 1.5` |
| `extra_charge` | Extra Charge | secondary | 2 uses before cooldown | `charges: 2` — both uses available, one shared cooldown recharges both after second use |
| `dash_damage` | Impact Dash | dash | Dash damages enemies you pass through | `damage_percent: 1.0` — 100% of primary damage, each enemy hit once per dash |
| `knockback` | Knockback | general | All hits push enemies away | `force: 300` |

**Stacking rules:**
- `pierce` + `ricochet`: pierce first (pass through enemies), ricochet on final hit (bounce to new target)
- `split_shot` stacks additively: picking it twice = 4 extra projectiles
- `big_shot` stacks multiplicatively on size, additively on damage
- `rapid_fire` stacks multiplicatively (2x → 4x)
- All other mutations stack naturally or are single-pick

### 5B — Mutation System Runtime

**New file:** `scripts/game/MutationSystem.gd`

A system that:

1. Loads mutation definitions from `data/mutations.json` on startup
2. Tracks applied mutations per player as an ordered list of IDs
3. Provides:
   - `apply_mutation(player_index: int, mutation_id: String)` — add to player's list
   - `has_mutation(player_index: int, mutation_id: String) -> bool` — check flag
   - `get_mutation_count(player_index: int, mutation_id: String) -> int` — for stacking
   - `get_active_mutations(player_index: int) -> Array` — for HUD
   - `get_compiled_weapon_stats(player_index: int, base_stats: Dictionary) -> Dictionary` — apply stat mutations to base
   - `roll_mutation_options(player_index: int, count: int) -> Array` — returns N random mutations (weighted toward ones the player doesn't already have, but allows stacking for stackable mutations)
   - `reset(player_index: int)` — clear all mutations (for new run)

### 5C — Apply Mutations to Combat

**File:** `scripts/game/CoopManager.gd`

In the primary fire path:

- Before spawning projectile, get compiled weapon stats from MutationSystem
- If `split_shot`: spawn extra projectiles with angular spread
- If `big_shot`: scale projectile node size and set boosted damage
- If `rapid_fire`: compiled stats already have faster fire_rate
- If `ricochet`: set `ricochet_remaining` on projectile
- If `pierce`: set `pierce_remaining` on projectile
- If `fire_trail`: set `leaves_fire_trail = true` on projectile
- If `knockback`: set `knockback_force` on projectile

**File:** `scripts/weapons/Projectile.gd`

Add mutation-aware fields:

- `pierce_remaining: int = 0` — if > 0, don't destroy on enemy hit, decrement instead
- `ricochet_remaining: int = 0` — on hit, if > 0 and pierce is exhausted, find nearest other enemy within `ricochet_range`, redirect toward it, decrement
- `ricochet_range: float = 200.0`
- `leaves_fire_trail: bool = false` — if true, spawn a damage area (simple Area2D with timer) every 0.15s along the path. Trail area lasts 1.5s, ticks damage every 0.5s at 30% primary damage.
- `knockback_force: float = 0.0` — if > 0, on hit apply impulse to enemy away from projectile direction

For secondary mutations in `_spawn_grenade()`:
- If `blast_radius`: multiply explosion area by `radius_mult`
- If `extra_charge`: track charges per player — allow 2 uses, then start single shared cooldown

For dash mutation:
- In `Dash.gd` or `Player.gd`: if `dash_damage` mutation active, on dash start query enemies overlapping the dash path, deal 100% primary damage to each once

### 5D — Mutation Pick Screen

**New file:** `scripts/ui/MutationPickUI.gd`
**New file:** `scenes/ui/MutationPickUI.tscn`

UI behavior:

1. Receives a list of mutation options per player from CoopManager
2. Shows cards side by side: icon + name + 1-line description
3. **Co-op layout:** P1's 3 cards on the left half, P2's 3 cards on the right half. Both pick simultaneously.
4. **Solo layout:** 3 cards centered.
5. Navigation: left/right to highlight, A/Enter to confirm
6. After all players confirm, emit a signal back to CoopManager with each player's chosen mutation ID
7. No timer, no pressure — brain-off, take your time

**File:** `scripts/game/CoopManager.gd`

- In `_handle_room_clear()`: after showing result, call `MutationSystem.roll_mutation_options(player_index, 3)` for each player
- Show MutationPickUI with the rolled options
- On selection callback: `MutationSystem.apply_mutation(player_index, chosen_id)`
- Then open exit zone

### 5E — Update HUD with Mutations

**File:** `scripts/ui/PlayerInventoryHUD.gd`

- Add a row of small icons below weapon display
- Each icon = one active mutation
- Use `IconFactory` for procedural placeholder icons (use mutation ID as seed)
- Update when mutations change

**Verification:** Headless parse passes. After clearing a room, each player sees 3 mutation options and picks one. Mutations visibly affect combat (split shot fires more projectiles, pierce goes through enemies, etc.). HUD shows active mutation icons. Multiple mutations stack correctly. Pierce + ricochet interact correctly.

**Commit after this phase.**

---

## Phase 6 — Objective Variety + Builder

**Goal:** Make rooms alternate between survive and hold-zone. Adapt encounter builder.

### 6A — Objective Assignment

**File:** `scripts/game/CoopManager.gd`

- In `_start_room()` or `configure_room()`: assign objective type per room
- Logic: alternate between `survive` and `capture_the_hill` based on room depth, or random weighted selection
- Survive is the default. Hill rooms appear from depth 2+ onward.
- The objective type determines win condition and whether a hill zone spawns

### 6B — Adapt Capture Hill to Bigger Arena

**File:** `scripts/game/CaptureHillZone.gd`
**File:** `scripts/game/CoopManager.gd`

- Hill position should spawn in a random quadrant of the larger arena, not always center
- Scale the hill zone radius if needed for the bigger space
- Verify fill/drain rates feel right — may need tuning for larger arena where enemies take longer to reach the hill

### 6C — Encounter Builder Adaptation

**File:** `scripts/ui/Bootstrap.gd`

Update the encounter builder:

- Remove: layout dropdown (no layouts)
- Remove: modifier dropdown (no modifiers)
- Remove: recipe dropdown (no recipes)
- Keep: objective dropdown — `Survive`, `Hold Zone`
- Keep: depth/wave selection
- Keep: enemy composition (but only Chaser + Charger available)
- Add: starting mutation multi-select or checkboxes (for testing specific mutations)
- Keep: auto-launch into room and return to builder on complete

**Verification:** Headless parse passes. Normal run rooms alternate between survive and hold-zone. Hold zone works in the bigger arena with correct positioning. Encounter builder can test both objectives and pre-apply mutations.

**Commit after this phase.**

---

## Phase 7 — Tuning Pass

**Goal:** Make the core loop feel good through playtesting and number adjustment.

### Tuning Targets

**Enemy pacing:**
- Chaser HP / speed / damage — should die fast (2-3 Rifle hits), feel like fodder
- Charger windup (~0.35s) / charge speed (fast, faster than player walk) / turn rate during charge (near zero) / recovery (~1.2s) — must force sidestep/dash, then punish window
- Wave size and spawn intervals per depth — should escalate clearly
- Boss HP and attack patterns — should feel like a climax

**Weapon feel:**
- Rifle damage vs Chaser HP — Chasers die in 2-3 hits
- Rifle fire rate — active, not sluggish
- Grenade cooldown / radius / damage — panic button that creates breathing room
- Projectile speed and size — must read clearly in the bigger arena (may need to increase both from v1 values)

**Mutation balance:**
- Each mutation should be visibly impactful on first pick
- Stacking 3+ mutations should feel noticeably powerful
- Late-run with 6+ mutations should feel ridiculous and fun
- No mutation should feel like a wasted pick

**Camera feel:**
- Zoom interpolation speed — smooth but responsive
- Zoom range — close enough to see detail solo, far enough for co-op spread
- Player padding — enough breathing room at all zoom levels
- Distance clamp feel — should the player feel the wall or just not notice it?

**Arena scale:**
- Too big = running simulator with dead time between enemies
- Too small = old kiting-in-circles problem
- Sweet spot: objectives in different areas feel like a meaningful trip but enemies are always nearby

### Tuning Method

Use the encounter builder:
- Test A: Survive, Chasers only — is shooting satisfying?
- Test B: Survive, Chasers + Chargers — does Charger force dodge?
- Test C: Hold Zone, mixed enemies — does the objective create positioning decisions?
- Test D: Multiple rooms in sequence via normal run — does mutation pickup feel rewarding?
- Test E: Late-run simulation (pre-apply 5+ mutations in builder) — does the power fantasy land?

**Commit after meaningful tuning changes.**

---

## Phase Summary

| Phase | What | Scope | Key Risk |
|-------|------|-------|----------|
| 1 | Zoom camera + bigger arena + distance clamp | Medium | Camera feel may need iteration |
| 2+3 | Rewrite CoopManager + RunState + archive obsolete | Large | Biggest phase — core systems rewritten |
| 4 | Minimal HUD | Small | Straightforward after rewrite |
| 5 | Mutation system + data + UI + combat hooks | Large | New system, most creative work |
| 6 | Objective variety + builder adaptation | Small-Medium | Mostly adapting existing code |
| 7 | Tuning pass | Ongoing | Requires live playtesting |

## Constraints

- Every phase must pass headless parse before moving to the next
- Do NOT touch RunFlow beyond removing shop nodes from generation — map system is preserved
- Do NOT create new enemy types
- Do NOT build meta progression
- Do NOT add arena layouts or obstacles
- Do NOT design a shop system
- GrenadeProjectile.tscn stays live — do NOT archive
- When archiving: move files to `archive/v1/` preserving folder structure
- Delete `_v1` reference files only after the new versions pass headless parse and gameplay verification
