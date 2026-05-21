# v3 Implementation Plan — Historical Record

## Status

- This file is a historical implementation record.
- It documents the migration into the auto-fire / shockwave / dash runtime direction.
- Parts of it were implemented, but it is no longer the source of truth for current branch state.
- Use these instead for active work:
  - `docs/development/current-state.md`
  - `docs/development/start-of-day.md`
  - `docs/design/roadmap.md`
  - `docs/process/architecture.md`

## Context

Converting the live v2 branch to the design now summarized in `game-direction-current.md`.
The v2 codebase is already simplified (1 weapon + 1 primary skill + 1 secondary skill, zoom camera, bigger arena, mutation system, hold zone objective). The v3 changes are mechanical (auto-attack, shockwave, dash) and visual (neon geometric), not architectural.

## Resolved Decisions

| Question | Answer |
|----------|--------|
| Branch strategy | Continue on `v2/core-refactor`. No new branch — v3 is an evolution, not a rewrite. |
| AimAssist.gd | Repurpose as AutoTarget. The `_find_target()` logic is exactly what auto-attack needs. |
| Grenade scene | Archive `GrenadeProjectile.tscn` to `archive/v1/`. Primary skill (shockwave) replaces it. |
| Sprite assets | Stop loading P1 sprite textures. Chevron polygon replaces them. Sprites stay on disk for future rubberhose pivot. |
| Existing mutations | All weapon mutations (ricochet, pierce, split_shot, big_shot, fire_trail, rapid_fire, knockback) work unchanged with auto-attack since they modify projectile behavior, not input. |
| Primary skill mutations | `blast_radius` → `shockwave_radius`. `extra_charge` → `shockwave_cooldown` ("Quick Pulse", reduces cooldown by 2s per stack, stackable). |
| Input mapping | Left stick = move. **RT = primary skill / shockwave** (gamepad), **Space = primary skill / shockwave** (keyboard P2). **LT / B = secondary skill / dash** (gamepad), **Ctrl = secondary skill / dash** (keyboard P2). No fire trigger — weapon auto-fires. Right stick reserved for future use. P1 keyboard bindings are empty (P1 defaults to gamepad). |
| Primary skill center | **Centered on player (offset = 0).** Fully radial — no directional aiming. Simplest, most panic-button feel. |
| Primary skill cooldown ownership | **Player.gd owns cooldown + signal.** No separate ShockwaveAbility.gd. Stats come from loadout dictionary (weapons.json → RunState → Player). CoopManager handles the blast effect. Secondary skill (dash) has its own separate cooldown in Player.gd. |
| Direction variables | **Two directions in Player.gd:** `_move_facing` (left stick, used for chevron rotation + secondary skill), `_auto_attack_direction` (toward current auto-target). Skill aim direction removed — primary skill is fully radial. |

---

## Phase 1 — Auto-Attack (the core change)

**Goal:** Player auto-fires at the nearest enemy. No trigger input. Movement only.

### Files to change

**`scripts/player/Player.gd`**

Remove:
- `_is_fire_pressed()` function and all callers
- `_fire_pressed_last_frame`, `_primary_fire_buffered_until`, `_primary_fire_buffered_direction` state vars
- Fire input block in `_physics_process()` (lines 290–301)
- `PRIMARY_FIRE_BUFFER_DURATION` constant

Add:
- `_auto_target: Node2D = null` — current auto-attack target
- `_next_auto_fire_at: float = 0.0`
- **Two direction vars replacing the old single `aim_direction`:**
  - `_move_facing: Vector2 = Vector2.RIGHT` — tracks left stick. Used for chevron rotation, dash direction. Updated every frame from move input. Persists last nonzero value when stick is released.
  - `_auto_attack_direction: Vector2 = Vector2.RIGHT` — direction toward current auto-target. Updated every frame. Only valid when `_auto_target != null`.
- New block in `_physics_process()`:
  ```
  _auto_target = _find_auto_target()
  if _auto_target != null:
      _auto_attack_direction = (_auto_target.global_position - global_position).normalized()
      if now >= _next_auto_fire_at:
          _fire_primary(now, _auto_attack_direction)
          _next_auto_fire_at = now + primary_fire_interval
  ```
- Dash uses `_move_facing` (not auto-attack direction) so dashing always goes where the player is moving.

Modify:
- Remove the old single `aim_direction` var entirely. Update all references:
  - Dash direction → `_move_facing`
  - Primary fire direction → `_auto_attack_direction`
  - `aim_pivot` rotation (if kept) → `_auto_attack_direction`
  - Body tilt → `_move_facing`
- `_fire_primary()` — stays as-is. It already takes a direction and emits `fire_requested`. No changes needed.
- `apply_loadout()` — `primary_fire_interval` is now driven by the 3/sec baseline + rapid_fire mutation. Current formula (`1.0 / fire_rate`) already handles this if we set base fire_rate to 3.0.

**`scripts/player/AimAssist.gd` → rename to `scripts/player/AutoTarget.gd`**

Repurpose. Single mode: **pure nearest** within weapon range.

```
func find_nearest(owner, range) -> Node2D
```

Keep the file, rename the class. Update the preload in Player.gd. Directional targeting can be added later if needed.

**`data/weapons.json`**

Change rifle baseline fire_rate from 5.8 to 3.0:
```json
"fire_rate": 3.0
```

**`scripts/game/CoopManager.gd`**

`_on_player_fire_requested()` — no changes. It already receives origin + direction + config from `fire_requested` signal. Auto-attack fires the same signal, just with auto-aimed direction.

### What stays untouched
- Projectile.gd, Projectile.tscn — projectiles still work the same
- MutationSystem.gd — `get_compiled_weapon_stats()` still compiles primary stats identically
- All primary mutations — they modify projectile behavior, not input
- CoopManager.gd fire handling — signal-driven, doesn't know or care about input

### Verification
- Launch game, enemies should die without pressing fire
- Mutations (pierce, ricochet, split_shot) should still work
- Fire rate should visibly be ~3/sec at baseline
- Rapid fire mutation should speed it up

---

## Phase 2 — Primary Skill: Shockwave (replace grenade)

**Goal:** Shockwave pulse centered on player. 5s cooldown, 250px radius, 950 knockback force, damage + strong knockback.

### No new file — shockwave lives in Player.gd + CoopManager.gd

Same pattern as the current grenade: Player.gd owns the cooldown and emits a signal, CoopManager handles the effect. Stats come from the loadout dictionary (via weapons.json → RunState → Player). No separate ShockwaveAbility.gd. When multiple ability types exist later, extract an AbilityBase class then.

### Files to change

**`scripts/player/Player.gd`**

Remove:
- `_secondary_hold_active` and hold-to-aim grenade logic
- `_update_secondary_preview()` and all trajectory/ring/cross preview code
- `secondary_projectile_speed`, `_secondary_projectile_data` grenade-specific vars
- `_secondary_charges_remaining`, `_secondary_charges_max` charge system
- `_refresh_secondary_charges()` function
- References to `SecondaryPreview`, `SecondaryTrajectory`, `SecondaryTargetRing`, `SecondaryTargetCross` nodes
- `_is_secondary_pressed()` → replaced by `_is_primary_skill_pressed()`

Add:
- `_primary_skill_cooldown_until: float = 0.0` — **sole cooldown owner**
- `_primary_skill_cooldown: float = 5.0` — set from loadout
- `_primary_skill_radius: float = 250.0` — set from loadout
- `_primary_skill_damage: int = 30` — set from loadout
- `_primary_skill_knockback: float = 950.0` — set from loadout
- `_is_primary_skill_pressed()` — **RT** (gamepad) or action `p%d_secondary` (keyboard, maps to Space for P2)
- On press when cooldown ready: emit `primary_skill_requested(global_position, Vector2.ZERO, stats_dict)`
  - **Blast is centered on player (offset = 0).** Knockback is radial (away from player), not directional.
- Set `_primary_skill_cooldown_until = now + _primary_skill_cooldown`
- **Secondary skill (dash)** — separate ability with its own 5s cooldown. Triggered by LT / B (gamepad) or Ctrl (keyboard P2). Uses `_move_facing` direction.

Modify:
- `get_primary_skill_hud_data()` → return primary skill cooldown info (cooldown_remaining, cooldown_duration) instead of charge count.
- `apply_loadout()` → read primary skill stats from `primary_skill_stats` dict: `cooldown`, `radius`, `damage`, `knockback_force`. Apply mutation-adjusted cooldown from MutationSystem.

**`scripts/game/CoopManager.gd`**

Remove:
- `_on_player_secondary_requested()` grenade handler
- `GrenadeProjectileSceneData` preload

Add:
- `_on_player_primary_skill_requested(origin, direction, stats)` handler:
  - `origin` = player's `global_position` (blast centered on player, offset = 0)
  - `direction` = passed but knockback is fully radial (away from player center)
  - Find all enemies within `stats.radius` of `origin`
  - Apply `stats.damage` to each
  - Knockback direction = away from `origin`, force = `stats.knockback_force` (950)
  - Spawn visual: expanding ring (Line2D or Polygon2D circle that scales up over 0.15s then fades)
  - Screen shake
- Connect the new signal when spawning players

**`scripts/game/CoopManager.gd` — visual**

New function `_spawn_shockwave_visual(center, radius, color, duration)`:
- Creates a Line2D circle at center
- Tweens scale from 0 → 1 over `expand_duration`
- Tweens alpha from 1 → 0 over 0.3s
- queue_free after fade

**`data/weapons.json`**

Replace grenade entry:
```json
{
  "id": "shockwave",
  "name": "Shockwave",
  "type": "primary_skill",
  "stats": {
    "kind": "shockwave",
    "damage": 30.0,
    "cooldown": 5.0,
    "radius": 250.0,
    "knockback_force": 950.0,
    "expand_duration": 0.15
  }
}
```

**`scripts/game/RunState.gd`**

- `_build_default_player_inventories()` — change `primary_skill_id` from `"grenade"` to `"shockwave"`
- `get_player_runtime_loadout_for()` — fallback primary skill changes from grenade to shockwave

**`data/mutations.json`**

- `blast_radius` → rename to `shockwave_radius`, update description: "Shockwave radius +50%."
- `extra_charge` → replace with `shockwave_cooldown`, description: "Shockwave cooldown reduced by 2s.", params: `{ "cooldown_reduction": 2.0 }`. Stackable.

**`scripts/game/MutationSystem.gd`**

- `get_secondary_radius_multiplier()` — rename or keep, now applies to shockwave radius
- `get_secondary_charges()` → remove, replace with `get_shockwave_cooldown_reduction()`:
  ```
  func get_shockwave_cooldown_reduction(player_index: int) -> float:
      return float(get_mutation_count(player_index, "shockwave_cooldown")) * 2.0
  ```

**Archive:** Move `GrenadeProjectile.tscn` and `GrenadeProjectile.gd` (if separate) to `archive/v1/`.

### Verification
- RT (gamepad) / Space (keyboard P2) fires shockwave pulse centered on player
- Enemies get pushed away from blast center (950 knockback)
- 5s cooldown visible on HUD
- Shockwave radius mutation makes it bigger
- Dash on LT / B (gamepad) or Ctrl (keyboard) with separate 5s cooldown
- No grenade references remain in live code

---

## Phase 3 — Player Chevron Visual

**Goal:** Player is a neon chevron pointing in move direction. No weapon sprite. P1 cyan, P2 magenta.

### Files to change

**`scripts/player/Player.gd`**

Remove:
- Sprite texture loading (`_standing_sprite_texture`, `_running_sprite_texture`, etc.)
- `_uses_sprite_visual()` and sprite display logic
- `weapon_sprite`, `aim_pivot` references and logic
- Sprite texture constants (`PLAYER_P1_STANDING_TEXTURE_PATH`, etc.)
- `PLAYER_RIFLE_TEXTURE_PATH`

Modify:
- `_apply_visual_state()` — always use Polygon2D visual (chevron). Remove sprite branch.
- Chevron shape polygon:
  ```gdscript
  visual.polygon = PackedVector2Array([
      Vector2(16, 0),     # point (front)
      Vector2(-12, -14),  # top-left wing
      Vector2(-6, 0),     # inner notch
      Vector2(-12, 14),   # bottom-left wing
  ])
  ```
- `visual.color` = player tint (cyan for P1, magenta for P2 — set via player_config.tint)
- `body_root.rotation` — rotate toward move direction instead of subtle tilt. The chevron points where you're going.

**`Player.tscn`** (scene file)

- Remove or hide `SpriteVisual`, `AimPivot`, `WeaponSprite` nodes
- Remove `SecondaryPreview`, `SecondaryTrajectory`, `SecondaryTargetRing`, `SecondaryTargetCross` nodes
- Polygon2D `Visual` stays — shape set in code

**`scripts/player/PlayerConfig.gd`**

- Ensure P1 tint defaults to cyan `Color(0.2, 0.9, 1.0)` and P2 to magenta `Color(1.0, 0.2, 0.8)`
- Or set in Bootstrap.gd where configs are built

### Verification
- Player renders as a glowing chevron
- Chevron points in movement direction
- P1 and P2 have distinct colors
- No weapon sprite visible
- Dash shield ring still works

---

## Phase 4 — Neon Visual Pass

**Goal:** Commit to the neon geometric aesthetic. Orb projectiles, glow, arena color shifts.

### Projectile visual → orb

**`scripts/weapons/Projectile.gd`** or **`Projectile.tscn`**

Current projectile visual is likely a Line2D or small shape. Change to:
- Small circle Polygon2D (8-point polygon, radius ~4px at baseline)
- Bright color matching player tint
- Subtle glow via modulate overbright: `Color(1.2, 1.2, 1.2, 1.0)` or additive blend
- Size scales with `area` stat (big_shot mutation makes visually bigger orbs)

### Arena color shifts per depth

**`scripts/game/CoopManager.gd`**

New function `_apply_arena_color_for_depth(depth: int)`:
- Base grid color = cool neon (cyan/blue at depth 1)
- Shift toward warm (orange/red) as depth increases
- Wall visuals follow the same shift
- Simple HSV hue rotation: `base_hue + depth * 0.08`

Call from `_start_room()` after setting `_room_depth`.

### Bloom / glow shader

**New: `shaders/neon_glow.gdshader`** (post-processing)

Apply as a WorldEnvironment with glow enabled, or as a screen-space shader on the camera:
- Soft bloom on bright pixels
- Low threshold so neon colors glow naturally
- Keep it subtle — readability first

Alternative (simpler): skip full-screen bloom, instead give projectiles and shockwave a `Light2D` or additive-blend duplicate at 2x size with low alpha. Cheaper, more controlled.

### Enemy shape refinement

**`scripts/enemies/Enemy.gd` — `_apply_type_visual()`**

- Chaser (triangle): already a triangle. Make slightly larger for zoomed-out readability. Brighter red.
- Charger (pentagon): already pentagon-ish. Ensure distinct from chaser at distance. Keep orange.
- Boss: already large star. Add pulsing glow ring (Line2D circle that breathes).

### Verification
- Projectiles look like glowing orbs
- Arena grid/walls shift color between rooms
- Enemies read clearly at default zoom
- Screen looks "neon" — dark background, bright everything else
- Performance stays smooth with 30+ enemies + projectiles

---

## Phase 5 — Data & Mutation Cleanup

**Goal:** All data files and mutation logic are consistent with v3. No grenade references in live code.

### `data/weapons.json`

Already updated in Phase 2. Verify rifle fire_rate = 3.0, primary skill = shockwave.

### `data/mutations.json`

Already updated in Phase 2. Verify:
- Weapon mutations unchanged (ricochet, pierce, split_shot, big_shot, fire_trail, rapid_fire, knockback)
- `blast_radius` → `shockwave_radius`
- `extra_charge` → `shockwave_cooldown`
- `dash_damage` stays

### `scripts/game/MutationSystem.gd`

Already updated in Phase 2. Verify:
- `get_compiled_weapon_stats()` works with 3.0 base fire_rate
- `get_primary_skill_radius_multiplier()` applies to shockwave
- `get_primary_skill_cooldown_reduction()` works
- No references to grenade, charges, or grenade-specific params

### `scripts/game/RunState.gd`

- Default primary skill = "shockwave"
- `get_player_runtime_loadout_for()` fallback primary skill = shockwave stats
- Remove any grenade-specific fallback logic

### `scripts/game/CoopManager.gd`

- Remove `GrenadeProjectileSceneData` preload
- No references to grenade in any function

### `scripts/game/PlayerInventory.gd`

- Default `primary_skill_id = "shockwave"`

### Grep verification

After all changes, grep the live `scripts/`, `scenes/`, and `data/` trees for:
- `grenade` (should only appear in archive/) ✅ Clean
- `GrenadeProjectile` (should only appear in archive/) ✅ Clean
- `_is_fire_pressed` (should be gone) ✅ Clean
- `aim_assist` / `AimAssist` (should be replaced by AutoTarget) ✅ Clean
- `charges_remaining` (gone — shockwave is cooldown, not charges) ✅ Clean
- `AimMode` / `aim_mode` (removed — auto-attack has no aim modes) ✅ Clean
- `SPITTER` / `BRUISER` (removed from active roster and code) ✅ Clean
- `_shockwave_aim_direction` (removed — shockwave is fully radial) ✅ Clean
- `find_directional` (removed — pure nearest only) ✅ Clean

---

## Phase 6 — Tuning & Polish

**Goal:** Make it feel good. Numbers pass, then playtest.

### Auto-attack tuning
- Base fire rate: 3.0/sec (confirm this feels "chunky" not "sluggish")
- Projectile speed: 850 (from v2 tuning pass — verify it reads well as an orb)
- Projectile size: baseline 4px radius. Big_shot mutation → 8px, 16px with stacks.
- Auto-target range: use weapon range (950px). Enemies beyond this aren't targeted.

### Shockwave tuning
- Damage: 30 (kills ~1.5 chasers per blast)
- Radius: 250px (roughly player's immediate area)
- Knockback: 950 force (sends enemies flying hard)
- Cooldown: 5s (mutation reduces by 2s per stack — minimum 1s with 2 stacks)
- Expand duration: 0.15s (fast but visible)

### Dash tuning
- Cooldown: 5s (separate from shockwave)
- Direction: follows `_move_facing` (left stick direction)
- Input: LT / B (gamepad), Ctrl (keyboard P2)

### Enemy tuning (live values — +50% speed from original plan)
- Chaser: HP 21, speed 292.5, lunge range 520px
- Charger: HP 40, speed 247.5, charge range 60-720px, preferred_distance 200
- Boss: HP 180, speed 157.5, preferred_distance 110, fire_interval 1.0
- Spawn cooldown: maxf((0.55 - depth * 0.03) * 0.5, 0.09)

### Survive objective
- Duration: flat 60 seconds (all depths)

### Room clear flow
- Auto-advance after objective complete — no exit zone walk
- Mutation pick pauses game (`get_tree().paused = true`)
- Flow: `_handle_room_clear()` → `_end_active_encounter()` → `_show_mutation_pick()` → `_finish_room_progression()` → `room_cleared.emit()`

### Power curve validation
- Room 1: 3 shots/sec, single orb, ~14 enemies. Should feel manageable but pressured.
- Room 3: rapid_fire → 6/sec, maybe pierce. 22 enemies. Feeling strong.
- Room 5+: split_shot + fire_trail + ricochet. 30+ enemies. Screen is chaos, player is winning.
- Boss: full build, huge auto-attack fan, shockwave for emergencies. Power fantasy payoff.

### Feel targets
- Auto-attack should feel like a rhythmic pulse, not a constant stream
- Each orb hit should have a small screen shake + enemy flash
- Shockwave should feel like a bass drop — big shake, enemies ragdoll away
- Mutation pickups should create a visible "before/after" moment

---

## Build Order Summary

| Phase | Scope | Status |
|-------|-------|--------|
| 1. Auto-Attack | Player.gd, AimAssist→AutoTarget, weapons.json | ✅ Done |
| 2. Shockwave + Dash | Player.gd (cooldown + signal), CoopManager.gd (blast handler + visual), weapons.json, mutations.json | ✅ Done |
| 3. Chevron Visual | Player.gd, Player.tscn, PlayerConfig.gd | ✅ Done |
| 4. Neon Pass | Projectile visual, arena colors, enemy shapes, particle effects | ✅ Done |
| 5. Data Cleanup | Grep + fix all stale references | ✅ Done |
| 6. Tuning | Numbers pass, playtest loop | Ongoing |

Phases 1-5 are implemented. Phase 6 is iterative playtesting.

---

## What's NOT in this plan (deferred)

- Shop nodes / gold economy — add after core loop validates
- Third objective type — add after Survive + Hold Zone feel good
- Boss redesign — movement/phase-based instead of projectile spam. Separate task.
- 3-4 player support — deferred until 1-2 player validates
- Audio pass — after visual pass, separate task
- Meta progression — removed for now
