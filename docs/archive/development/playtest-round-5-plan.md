# Playtest Round 5 Patch Plan

## Context

Playtest round 4 surfaced 7 issues across balance, UX, and performance. This plan
addresses all of them. Boss/elite reworks are the largest scope and were designed
collaboratively with the user.

**This plan targeted the main workspace** `D:\GameDev\Project_Twin_stick` on `v3/main`
(starting from commit `c9e9eb8`) plus the round-4 patch stack. All values below were
verified against that live code before implementation.

Findings recap (round 4):
1. Settings menu unclear — what do Screen Effect / Aim Mode do?
2. Warden too weak, can't reach player; mid-bosses need big rework
3. Performance still bad with many projectiles + enemies; fire trail especially
4. Fire trail overtuned — area too big, too strong, kills performance
5. Elites too weak in midgame; Act 2 needs balance
6. Overcharge too strong, needs higher CD
7. Bosses still weak

---

## 1. Remove In-Run Settings Panel (Pause Menu)

**Why:** The pause Settings panel exposes Screen Effect (Off/Minimal/Full) and per-player
Aim (Auto/Movement), but the labels are unclear and the user wants the panel gone. The
underlying features stay in code at their defaults (aim = `auto`, screen effect = `full`).

**Correct location (NOT Bootstrap):** The in-run pause settings live in
`scripts/game/CoopManager.gd` + `scenes/game/GameWorld.tscn`. `Bootstrap.gd`/`Bootstrap.tscn`
own the **main-menu** settings and key-binding editor — leave those untouched.

**Changes to `scripts/game/CoopManager.gd`:**
- Remove the `pause_settings_button` from the pause menu (the button stays as a node only if
  needed for layout; otherwise remove its `@onready` + wiring). Remove its `.pressed.connect`
  at `_bind_ui` (~line 208).
- Remove settings wiring at `_bind_ui` (~lines 211-216): `settings_back_button`,
  `settings_screen_effect_option`, `settings_player_1..4_option` connects.
- Remove handlers: `_configure_settings_panel` (~235), `_on_pause_settings_pressed` (~278),
  `_on_settings_back_pressed` (~283), `_on_screen_effect_option_selected` (~287),
  `_on_player_aim_option_selected` (~297).
- Remove the pause-flow references to `settings_panel` at ~2047, ~2101-2102, ~2110-2111.
- Remove the related `@onready` vars (`settings_panel` @95, `settings_screen_effect_option`,
  `settings_player_N_option`, `settings_back_button`, `pause_settings_button`).
- **Update `_configure_pause_focus()` (~line 226):** its focus-cycle array currently includes
  `pause_settings_button`. Removing the button node/`@onready` while leaving this array intact
  causes a null/parse error and breaks gamepad pause navigation. Change the array to
  `[resume_button, pause_retry_button, pause_main_menu_button]`.

**Changes to `scenes/game/GameWorld.tscn`:**
- Remove the `SettingsPanel` node subtree (~line 358) and the pause-menu Settings button node.

**Leave intact:** `aim_mode` logic in `Player.gd` (used at ~326 and ~344) and
`_screen_effect_level` in CoopManager — they keep working at defaults; we only remove the UI.

> Note: with the UI gone, aim mode is fixed at `auto` (the default) and screen effect at
> `full`. Acceptable per user; revisit if a real settings surface is wanted later.

---

## 2. Fire Bullets Rework — Impact-Only Pools

**Why:** The old Fire Trail behavior spawned a trail zone along each projectile's flight path AND an
impact pool on death. The along-path zones are the performance killer (many `FireTrailZone`
nodes alive at once) and the area was overtuned. User wants "fire on hit only."

**Live values (verified, `data/mutations.json` line 129):**
`trail_lifetime: 3.0, tick_interval: 0.35, damage_percent: 0.4, impact_pool_radius: 90.0,
impact_pool_lifetime: 3.0, impact_pool_damage_percent: 0.5`

**Changes to `scripts/weapons/Projectile.gd`:**
- Remove the along-flight trail-zone spawning entirely (the `TRAIL_SPAWN_INTERVAL` path).
  Confirm exact lines at implementation — do NOT trust prior stale line numbers.
- Keep only the impact pool spawned on projectile death/hit.
- Tune impact pool down: radius 90→50, lifetime 3.0→2.0, damage_percent 0.5→0.4.

**Changes to `data/mutations.json` (`fire_trail`):**
- Drop trail fields (`trail_lifetime`, `tick_interval`, `damage_percent`).
- Set `impact_pool_radius: 50.0, impact_pool_lifetime: 2.0, impact_pool_damage_percent: 0.4`.
- **Update user-facing copy** (line 123-125) — implemented user-facing name is **Fire
  Bullets** and the description is **"Projectiles ignite a burning pool where they hit."**
  The mutation id remains `fire_trail` to avoid save/data churn.

**`scripts/weapons/FireTrailZone.gd`:** no structural change — already used for impact pools;
trail zones simply stop being created. No active-pool cap (per user) — impact-only volume is
low enough that natural lifetime keeps counts bounded.

---

## 3. Overcharge Nerf — Higher CD + Weaker Burst

**Why:** Current 15s CD with 1.5x fire rate + 2x projectiles ≈ 3x DPS burst is too strong,
especially stacked with split shot / Fire Bullets.

**Live values (verified, `data/abilities.json` lines 35-39):**
`cooldown: 15.0, duration: 4.0, fire_rate_multiplier: 1.5, projectile_multiplier: 2`

**Changes to `data/abilities.json` (`overcharge`):**
- `cooldown`: 15.0 → 22.0
- `fire_rate_multiplier`: 1.5 → 1.3
- `projectile_multiplier`: 2 → 1 (remove extra projectiles)
- `description`: match the actual effect: **"Weapon fires 30% faster for a short burst."**

Net: 1.3x fire-rate burst every 22s. Noticeable, not dominant.

---

## 4. Boss Rework — All Four Bosses

> **HP decision (corrected):** Real baseline is **1100/1400/1200/1300** (NOT the 600-800 I
> originally claimed). User chose a **×1.5 bump** off the real baseline. Behavior reworks are
> the primary fix; HP is secondary.

### Base HP (×1.5 from live values):
| Boss | Live HP | New HP |
|------|---------|--------|
| Warden | 1100 | 1650 |
| Hydra  | 1400 | 2100 |
| Hive   | 1200 | 1800 |
| Pulsar | 1300 | 1950 |

Update **both** the `_configure_type` base values (`Enemy.gd` ~221/231/241/251) **and** the
duplicated values in `apply_boss_scale` (`Enemy.gd` ~290+). Co-op scaling (×1.6 at 2P) and
Act 2 scaling (×2.0) remain on top.

### Warden — Aggressive Melee Bruiser
Live: speed 178, single charge at ≤150px + shockwave rings when close, contact 22. Can't reach
a kiting player. New kit (in `_update_warden_behavior`):
- **Leap (gap closer):** target player position, telegraph ground ring (~0.6s), leap there
  with AOE slam on landing (~140px, ~20 dmg). CD 5-6s, tightens with phase. Fixes "can't reach".
- **Faster multi-charge combo:** 2-3 rapid charges in sequence (phase 2: 2, phase 3: 3), each
  ending with a smaller slam (~80px). `_charge_chain_remaining` already exists.
- **Ground pound wave:** every 4-5s, expanding shockwave ring (any range). Uses
  `schedule_enemy_shockwave`.
- **Enrage speed ramp:** base speed scales with phase: `178 * (1.0 + phase * 0.8)` → ~320 at
  phase 3. Note: player base `move_speed` is **488** (`Player.gd:30`), so Warden never
  out-walks a player — the ramp adds late-fight urgency, but reachability is solved by the
  **leap + multi-charge combo**, not walk speed. Do not balance around Warden catching a
  kiter on foot.

### Hydra — Bullet Hell Fortress
Live: stationary, rotating arm fans + periodic 12-shot radial burst. New additions
(in `_update_hydra_behavior`):
- **Aimed snipe shots:** 1-2 fast aimed projectiles at each player between patterns. CD 3-4s.
- **Arm sweep:** dense arc rotating ~120° over ~1.5s. CD 8-10s.
- **Phase-transition minions:** spawn 4-6 chasers/splitters on each transition (67%, 33%) via
  `spawn_enemy_minions`.
- **Slow homing orbs:** every 7-8s, 2-3 large slow projectiles (~120 spd) tracking nearest
  player for 4s. Needs steer logic (see homing note in §4a).

### Hive — Swarm Overlord
Live: speed 145, spawns minions, flees when close. New additions (in `_update_hive_behavior`):
- **Elite minion escalation:** P1 chasers/splitters; P2 occasional chargers; P3 a bomber.
- **Protective swarm shield:** 4 orbiting minis (~30 HP) block projectiles; regen on phase
  transition only if the old shield has already been cleared.
- **Poison cloud AOE:** every 5-6s drop a large poison zone (~160px, 4s DOT) at position.
- **Burrow + relocate:** every 10-12s burrow (brief invuln ~1s), teleport far from players,
  spawn a minion burst on emergence.

### Pulsar — Arena Controller
Live: stationary, shockwaves + hazard zones + aimed fans; P3 targeted hazard zones. New
additions (in `_update_pulsar_behavior`):
- **Teleport repositioning:** every 6-8s fade out/in to a new arena spot (~0.5s invuln).
- **EMP pulse (ability lockout):** every 12-15s, telegraphed expanding ring that delays all
  player ability cooldowns. **Requires explicit Player API — see §4a.**
- **Beam attack:** 1s charge (line telegraph), then sweep ~90° over 1.5s, high contact dmg
  (~25). CD 8-10s.
- **Faster escalation:** P3 fire interval 0.24→0.18, bigger bursts/hazard zones.

### 4a. Player API additions (required by EMP + homing)
- **EMP:** Player cooldown state is internal and **Dash uses a separate dash-state object**
  — class `Dash` (`scripts/player/Dash.gd`), aliased as `DashData` via `const DashData =
  preload(...)` in `Player.gd:5`, stored in `_dash_states`. Its cooldown lives in
  `_cooldown_until` and the class only exposes `get_cooldown_remaining()` — there is **no**
  public way to extend it. So two additions are needed:
  - **Semantic (decided): EMP is an _additive_ delay**, matching the "delays all player
    ability cooldowns" intent. A ready ability becomes unusable for `seconds`; an ability
    already on cooldown is pushed `seconds` further. The rule is the same for both paths:
    `new_cooldown = max(current_cooldown, now) + seconds`.
  - **`Dash.gd`:** add a public `extend_cooldown(seconds: float, now: float)` that sets
    `_cooldown_until = max(_cooldown_until, now) + seconds`. Avoids reaching into underscore
    state from Player.
  - **`Player.gd`:** add `apply_ability_lockout(seconds: float)` that, for each slot, sets
    `cooldown_until = max(cooldown_until, now) + seconds` for normal abilities AND calls
    `Dash.extend_cooldown(seconds, now)` when the slot is Dash. CoopManager iterates
    `get_player_target_nodes()` and calls it on the EMP pulse.
- **Homing orbs:** either a small steer-toward-target update on the enemy projectile, or a
  dedicated slow homing projectile path in CoopManager. Decide at implementation; keep it off
  the pooled fast-projectile path to avoid coupling.

---

## 5. Elite Rework — Act 2 Scaling + Add Waves

**Live elite stats (verified):** Charger 900 HP / 250 spd / 18 dmg; Spitter 650 / 320 / 14
(0.8s fire); Support 760 / 220.

**Act 2 stat multiplier:** new `Enemy.gd` method `apply_elite_act_scale(act: int)`, called
from CoopManager when spawning an elite:
- Act 1: no change.
- Act 2: `max_health *= 1.5; current_health = max_health; contact_damage = int(contact_damage
  * 1.3); projectile_damage = int(projectile_damage * 1.3)`.

**Faster cooldowns in Act 2:** elite ability/fire/charge cooldowns ×0.75. Implement via an
Act-2 flag on the elite that scales the relevant `_next_*_at` increments (or a stored
`_elite_cd_mult`).

**Add waves:** elite rooms periodically spawn 2-3 regular enemies from the room enemy pool
every 6-8s during the fight; stop when the elite dies. Implement alongside the existing elite
spawn path: `_spawn_elite_miniboss()` (`CoopManager.gd:1005`), which builds the elite pool and
calls `_spawn_enemy_instance`. The `apply_elite_act_scale(act)` call also goes here, right
after the elite instance is spawned.

---

## 6. Performance

**Correction:** projectile pooling already exists and is live — `_projectile_pool` /
`_active_projectiles` (`CoopManager.gd:185-186`) with `_acquire_projectile()` (~1359). Do NOT
re-add pooling.

Focus instead on:
- **`FireTrailZone` node churn** — the §2 impact-only rework is the main win (drops active zone
  count by ~90%+). This is the single biggest lever for the round-4 perf complaint.
- **Active zone / hazard counts** under deep endless — watch `FireTrailZone`, enemy hazard
  zones, and shockwave nodes.
- **Verify pooling actually holds** under deep endless load (no leak of `_active_projectiles`,
  no ghost bullets). If frames still drop after the fire-trail fix, escalate to MultiMesh
  rendering (deferred from round-4 Phase 5) and note entity count + symptom.

---

## File Change Summary

| File | Changes |
|------|---------|
| `scripts/enemies/Enemy.gd` | Boss HP ×1.5 (both `_configure_type` + `apply_boss_scale`); Warden/Hydra/Hive/Pulsar behavior reworks; Hive shield safeguard; `apply_elite_act_scale()`; elite Act-2 cooldown scaling |
| `scripts/game/CoopManager.gd` | Remove pause settings panel + handlers; elite add-wave spawning; elite act-scale call; boss minion/homing/beam/EMP helpers |
| `scripts/player/Player.gd` | New `apply_ability_lockout(seconds)` (handles `cooldown_until` slots + Dash) |
| `scripts/player/Dash.gd` | New public `extend_cooldown(seconds, now)` so lockout can push Dash cooldown without touching underscore state |
| `scripts/weapons/Projectile.gd` | Remove along-flight trail zones; keep impact-only pool |
| `data/mutations.json` | `fire_trail` id displayed as Fire Bullets; impact-only params (50px / 2.0s / 0.4); effect-matched description |
| `data/abilities.json` | Overcharge: CD 22, fire_rate 1.3, projectile_multiplier 1; effect-matched description |
| `scenes/game/GameWorld.tscn` | Remove `SettingsPanel` subtree + pause Settings button |
| `Bootstrap.gd` / `Bootstrap.tscn` | **No change** (main-menu settings — out of scope) |

---

## Verification

1. Headless parse: `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick --quit` — **passing** after implementation.
2. Manual playtest: use `docs/development/playtest-round-5-validation.md` for the current stable combined round-4 + round-5 build.
3. Manual playtest focus:
   - Warden reaches and pressures a kiting player; leap/pound/charge all read clearly.
   - Hydra patterns require active movement; sweep + snipes punish standing still.
   - Hive shield/poison/burrow force repositioning; minion quality escalates by phase.
   - Pulsar teleport/beam/EMP create varied dodges; **EMP delays Dash too** (not just other abilities).
   - Boss fights last long enough to see all phases but don't feel spongy at ×1.5 HP.
   - Act 2 elites clearly harder than Act 1; add waves create multi-target pressure.
   - Fire Bullets impact pools are useful, visible, and no longer tank frames.
   - Overcharge feels like a boost, not mandatory.
   - Pause menu has no Settings button; main-menu settings/binding editor still work.
   - Deep-endless perf holds; pooling shows no leaks/ghost bullets.
