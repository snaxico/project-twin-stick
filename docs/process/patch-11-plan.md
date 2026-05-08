# Patch 11 — Melee-First Enemy Balance and Survivability

Hard scope lock: no new enemies, no new weapons, no new systems. Rebalance existing enemy roster so combat is primarily melee-dodge, with ranged as rare flavoring. Smooth the Normal mode difficulty curve by improving healing economy and reducing spike damage.

---

## Goal

Make the game pass the "girlfriend test":

- The main threat should be things running at you that you dodge by moving, not projectile patterns you need to weave through.
- Spitters become a support role, not the main pressure source.
- Normal mode should feel challenging but survivable — chip damage should not silently end runs before the boss.

---

## Patch 11A — Wave Composition Rebalance

### Changes

#### Wave weights — `scripts/game/CoopManager.gd`

`_roll_wave_composition()` starting at line 714. Weights are `[chaser, spitter, charger]`.

| Step range | Current weights | New weights | Rationale |
|------------|----------------|-------------|-----------|
| Early (0–1) | `[5, 2, 0]` | `[6, 1, 0]` | Almost all Chasers, rare single Spitter |
| Mid (2–3) | `[3, 3, 2]` | `[4, 1, 3]` | Chargers arrive, Spitter stays rare |
| Late (4+) | `[1, 3, 4]` | `[2, 1, 5]` | Charger-heavy with Chaser support, Spitter minimal |

```gdscript
# Old
var weights := [5, 2, 0]
if step_index >= 4:
    weights = [1, 3, 4]
elif step_index >= 2:
    weights = [3, 3, 2]

# New
var weights := [6, 1, 0]
if step_index >= 4:
    weights = [2, 1, 5]
elif step_index >= 2:
    weights = [4, 1, 3]
```

#### Elite modifier — `scripts/game/CoopManager.gd`

Lines 721–724. Currently elite rooms boost both Spitter and Charger weight. Change to only boost Charger — elite rooms should feel more aggressive melee pressure, not more projectiles.

```gdscript
# Old
if is_elite:
    weights[0] = max(weights[0] - 1, 0)
    weights[1] += 1
    weights[2] += 1

# New
if is_elite:
    weights[0] = max(weights[0] - 1, 0)
    weights[2] += 2
```

#### Boss support waves — `scripts/game/CoopManager.gd`

`_build_boss_support_wave_plan()` at line 746. Current support rotation is `["spitter", "charger", "chaser"]`. Reorder so Spitter appears last and least often.

```gdscript
# Old
var support_types := ["spitter", "charger", "chaser"]

# New
var support_types := ["chaser", "charger", "chaser"]
```

This removes Spitter from boss support entirely. Boss adds are now melee-only.

### Do NOT change

- Wave size formula (`_compute_wave_size`).
- Spawn interval or timing.
- Generator room spawn logic (uses its own `spitter_chance` parameter).

### Validation

1. Run headless parse.
2. Play rooms 1–3 on a normal run. Confirm:
   - Early rooms are almost all Chasers.
   - Mid rooms introduce Chargers heavily, with rare Spitters.
   - Late rooms feel like a melee swarm, not a bullet hell.
3. Play a boss room. Confirm support waves are melee-only.

---

## Patch 11B — Spitter Stat Nerf

### Goal

Reduce Spitter from burst-fire pressure to a single slow shot. Even when a Spitter appears, it should be a punctuation mark, not sustained fire.

### Changes

#### Spitter stats — `scripts/enemies/Enemy.gd`

Inside `setup()`, the `"spitter"` match arm starting at line 76:

| Stat | Current | New | Rationale |
|------|---------|-----|-----------|
| `fire_interval` | `1.85` | `2.6` | Much slower shot cadence |
| `_projectile_burst_count` | `3` | `1` | Single shot instead of 3-burst |
| `projectile_speed` | `340.0` | `280.0` | Slower projectile, easier to dodge |

```gdscript
# Old
fire_interval = 1.85
projectile_speed = 340.0
...
_projectile_burst_count = 3

# New
fire_interval = 2.6
projectile_speed = 280.0
...
_projectile_burst_count = 1
```

### Do NOT change

- Spitter HP, move speed, preferred distance, or visual identity.
- Spitter projectile damage (stays at 10).
- Any other enemy type stats.
- Boss projectile behavior (boss is meant to be the ranged threat).

### Validation

1. Run headless parse.
2. Play a mid-run room where Spitters appear. Confirm:
   - Spitter fires one slow projectile at a time.
   - Projectile is readable and dodgeable.
   - Spitter no longer floods the screen with burst volleys.
   - Spitter still feels like a distinct threat from Chaser/Charger (ranged identity preserved).

---

## Patch 11C — Survivability Tuning

### Goal

Smooth the Normal mode difficulty curve so runs don't silently die to accumulated chip damage. Good play (killing enemies) should be rewarded with sustain. Spike damage from Chargers should be punishing but not run-ending in one mistake.

### Changes

#### Enemy food drops — `scripts/game/CoopManager.gd`

`_drop_pickups_for_enemy()` starting at line 1129. Currently enemies can only drop gold (20% chance). Add a separate food drop chance so players can heal through combat skill.

After the existing gold drop logic, add a 15% chance to also drop food:

```gdscript
# Old — only drops gold
func _drop_pickups_for_enemy(enemy) -> void:
    ...
    if _room_random.randf() > 0.2:
        return
    _spawn_pickup("gold", enemy.global_position + pickup_offset, 1)

# New — gold stays at 20%, food added at 15%
func _drop_pickups_for_enemy(enemy) -> void:
    ...
    var drop_pos: Vector2 = enemy.global_position + pickup_offset
    if _room_random.randf() <= 0.2:
        _spawn_pickup("gold", drop_pos, 1)
    if _room_random.randf() <= 0.15:
        _spawn_pickup("food", drop_pos + Vector2(12.0, 0.0), 1)
```

Gold drop chance stays at 20%. Food drop chance is a separate 15% roll. Both can proc on the same kill. Food heals 10 HP (one Chaser hit). More kills = more sustain. Rewards aggressive play.

#### Charger contact damage — `scripts/enemies/Enemy.gd`

Inside `setup()`, the `"charger"` match arm at line 93:

| Stat | Current | New | Rationale |
|------|---------|-----|-----------|
| `contact_damage` | `20` | `15` | 3-hit kill instead of near 2-hit. Still punishing, not run-ending. |

```gdscript
# Old
contact_damage = 20

# New
contact_damage = 15
```

### Do NOT change

- Chaser contact damage (stays at 10 — the baseline threat).
- Boss contact or projectile damage.
- Spitter projectile damage.
- Food healing amount (stays at 10 per food).
- Rest room heal amount (stays at 20).
- Easy mode behavior (already full-heals after each room).
- Generator food drops (those are guaranteed and separate).

### Validation

1. Run headless parse.
2. Play a full Normal mode run. Confirm:
   - Food drops appear noticeably more often during combat.
   - Players recover some HP through combat before the next room.
   - Charger hits still hurt but surviving a single hit at mid-HP feels possible.
   - The run doesn't feel like Easy mode — damage still accumulates, choices still matter.
3. Compare: does a Normal run now reach the boss more often than before?

---

## Implementation Order

Execute 11A first. Validate. Then 11B. Validate. Then 11C. Validate.

- 11A changes how often Spitters appear (wave composition).
- 11B changes how threatening each Spitter is (stat nerf).
- 11C changes the healing economy and Charger spike damage (survivability).

All three are independent value changes that validate separately, but together they shift the game from "hard and projectile-heavy" to "melee-first and challenging but fair."

## After Patch 11

Update:
- `docs/development/current-state.md` — note the melee-first rebalance and survivability tuning
- `docs/development/history/` entry for the session
- `docs/process/prototype-roadmap.md` — add Patch 11 row
- `docs/development/start-of-day.md` — update wave composition and healing/damage descriptions
