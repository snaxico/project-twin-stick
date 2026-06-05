# Playtest Round 9 — Plan & Implementation (for Codex)

Single self-contained build doc for the round-9 Mutation → Weapon System rework: design summary +
exact build spec (Slices 0–7). Work on `v3/main` in `D:\GameDev\Project_Twin_stick` (main checkout,
no new worktrees). Do not commit unless asked. Round-8 is the stable baseline being built on.

## Design Summary (what we're building & why)

Round 9 turns the old "mutation" pool into a **weapon system** plus categorized upgrades. Locked decisions:
- **5 peer weapons** — Rifle, Rocket Launcher, Scattergun, Cannon, Railgun. Each levels **1→5**;
  one active at a time; a **single global `weapon_level`** (no per-weapon memory). Player starts Rifle Lv1.
- **Weapon cards** roll in the normal loot pool: **Level Up Weapon** (Common, +1 level) and
  **Change Weapon → X** (Rare, swap active weapon, keeps level). Switching is cost-free; weapon
  cards compete in the pools by rarity (no per-screen cap — multiple may appear).
- **4 Upgrade categories:** **Weapon** · **Effect** (burn/frost/venom/bounce on-hit riders;
  one-time Rares) · **Attribute** (Common stat boosts) · **Ability** (Common ability mods + a
  per-ability Rare **Signature**).
- **Number model:** player HP **100**; base damage halved (rifle base **10**); **weapon level is
  the primary power axis** (~2.5× L1→L5); **additive** damage/knockback stacking (no compounding);
  **crit dropped**; enemy HP/damage rescaled with role differentiation.
- **Terminology:** **"Upgrade"** is the umbrella the player sees; **"mutation"** is **code-only**
  (storage for the Effect/Attribute/Ability categories). See Glossary.

## Glossary (agreed terminology — use in docs + player-facing UI)

**Model:** `Upgrade = Weapon + (Effect + Attribute + Ability)`. "Upgrade" is the umbrella for
everything the player picks. **"Mutation" is a code-only word** for the three non-weapon
categories' storage — it is NOT a design/player term and does NOT include Weapon. So
**Upgrade ≠ Mutation** (mutation is a subset).
```
UPGRADE  ← everything you pick
├── Weapon      → weapon state (weapons.json, weapon_id + weapon_level)
├── Effect   ┐
├── Attribute├──→ code calls these "mutations" (mutations.json, inventory.mutations[])
└── Ability  ┘
```
- **Upgrade** — umbrella; anything chosen on the Reward screen.
- **Card** — the on-screen tile for one Upgrade.
- **Reward screen** — the level-up / elite pick moment.
- **Categories** (= the visual `group` field values `weapon | effect | attribute | ability`):
  - **Weapon** — the 5 guns. Cards: **Level Up Weapon** (Common), **Change Weapon → [type]** (Rare).
  - **Effect** — on-hit riders: burn / frost / venom / bounce (Rare, one-time).
  - **Attribute** — stat boosts (Common, stack to Lv3): damage, fire rate, move speed, HP, etc.
  - **Ability** — modifies an equipped ability (Common: cooldown/area/duration; Rare = a **Signature**).
- **Signature** — an Ability-category Rare bound to one specific ability (e.g. Shockdash = Dash's signature).
- **Common / Rare** — the two rarity tiers.
- **Code naming:** "mutation" stays in code (`MutationSystem`, `mutations.json`, `apply_mutation`,
  `roll_mutation_options`) — **no rename**. Those flow functions also carry synthetic Weapon cards;
  that's expected. Docs + player-facing strings use "Upgrade" + the four category names only.

## Conventions
- Per-level stats are 5-element arrays; **index = level − 1** (Lv1..Lv5).
- After every slice, run the headless parse check:
  `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick --quit`
- Line numbers in this doc are **indicative** — re-confirm against live code before editing.

## Slice order
0. **Number model** — rescale Player HP + Enemy HP/damage; lock the damage philosophy.
1. **Data layer** — `weapons.json`, `abilities.json` (minefield + ability-damage rescale), `mutations.json`.
2. Weapon state + pick-flow (Level Up / Change Weapon cards, compile by active weapon).
3. Per-weapon fire patterns (rocket AOE, scatter pellets, cannon slug, railgun lance).
4. Secondary effects (burn/frost/venom/bounce) as weapon-agnostic riders.
5. New commons + light retunes.
6. Ability signature rares (7 new bespoke behaviors).
7. Visuals — 4-group icon colors + pick-card tags.

---

# SLICE 0 — Number Model (foundational; do first)

## Philosophy (apply across all slices)
- **Damage anchor halved:** rifle base 20 → **10**. **Weapon LEVEL is the primary power axis**
  — weapon damage grows ~**2.5×** from Lv1→Lv5 (with crit dropped and few damage mutations,
  leveling carries offense). Enemy HP is anchored so every ~2 weapon levels **removes a hit** on
  common enemies.
- **Player HP 50 → 100** (reads as a clean %).
- **Stacking is additive into one pool** (no compounding): `hit = weapon_damage[level] ×
  (1 + Σ damage%)`. Only damage% source for now is High Caliber (0.20×lvl, cap 0.60). **Crit is
  dropped.** Fire rate / speed / range follow the same `base × (1 + Σ bonus)` pattern.
- **Power budget:** fully-invested offense (Lv5 weapon ×2.5 × High Caliber ×1.6) ≈ **×4** of a
  fresh rifle. Enemy HP scaling (×act, ×1.6 @2P) keeps late game honest.

## 0A. Player (`scripts/player/Player.gd`)
- `max_health` 50 → **100**; `_base_max_health` 50 → **100**.
- `projectile_damage` default 16 → **10** (fallback only; live value comes from `weapons.json`).
- Runtime HP is also owned by `RunState.gd`: update `get_player_runtime_loadout_for()` so
  `"max_health"` returns **100**, and initialize `player_health_states` with
  `{ "current": 100, "max": 100 }`. Otherwise the loadout/state path can keep HUD/player HP at 50
  despite the `Player.gd` defaults.

## 0B. Enemy HP & damage (`scripts/enemies/Enemy.gd` `_configure_type`) — before → after
| Enemy | HP | contact | projectile |
|---|---|---|---|
| chaser | 21 → **20** | 6 → **8** | — |
| charger | 40 → **45** | 8 → **18** | — |
| spitter | 30 → **15** | 5 → **6** | 10 → **12** |
| splitter | 25 → **25** | 5 → **8** | — |
| splitter_mini | 8 → **8** | 5 → **6** | — |
| bomber | 35 → **30** | 5 → **5** | death-explosion → **25** |
| elite_charger | 900 → **500** | 18 → **28** | — |
| elite_spitter | 650 → **380** | 8 → **12** | 14 → **20** |
| elite_support | 760 → **440** | 5 → **10** | — |

**Bosses** — set base HP to **Warden 800 / Hydra 1000 / Hive 900 / Pulsar 950**, contact
**Warden 35 / Hydra 35 / Hive 35 / Pulsar 35**, projectiles **16**. Update BOTH the
`_configure_type` boss entries AND the duplicated base values in `apply_boss_scale` (re-confirm
exact current values/line numbers at edit time — live boss HP is inconsistent with older docs).
Co-op (×1.6 @2P) and act (×2.0) multipliers remain on top.

> All weapon damage values live in Slice 1A (already written at the new scale). All ability/DoT
> flat damage is rescaled in Slices 1B/1C. Slice 0 owns Player.gd + Enemy.gd + the RunState.gd HP
> loadout/state defaults.

## Slice 0 acceptance
- Headless parse passes; game boots; HUD shows player HP 100.
- Spot-check TTK: fresh rifle (10 dmg) kills a chaser (20) in 2 hits; a charger (45) in ~5.

---

# SLICE 1 — Data Layer

## 1A. `data/weapons.json` — define all 5 weapons

Replace the weapon entries with the five below. Keep any existing non-weapon entries
(e.g. the legacy `shockwave` `primary_skill` entry) untouched. Each weapon has fixed scalar
`stats` plus a `per_level` block of arrays (index = level−1). The compiler reads `per_level[lvl-1]`
for those keys and `stats` for the rest.

Damage arrays are at the **new scale** (Slice 0): rifle base 10, ~2.5× growth to Lv5, all ≈65→160 DPS.
```json
{
  "id": "rifle", "name": "Rifle", "type": "weapon", "projectile_kind": "bullet",
  "stats": { "projectile_speed": 850.0, "range": 950.0, "area": 4.0 },
  "per_level": { "damage": [10,13,17,21,25], "fire_rate": [6.5,6.8,7.1,7.4,7.7] }
}
{
  "id": "rocket", "name": "Rocket Launcher", "type": "weapon", "projectile_kind": "rocket",
  "stats": { "fire_rate": 1.6, "projectile_speed": 600.0, "range": 900.0, "area": 6.0, "blast_damage_percent": 0.7 },
  "per_level": { "damage": [40,55,70,85,100], "blast_radius": [90,102,114,126,138] }
}
{
  "id": "scattergun", "name": "Scattergun", "type": "weapon", "projectile_kind": "pellet",
  "stats": { "damage": 8.0, "fire_rate": 2.2, "projectile_speed": 800.0, "range": 550.0 },
  "per_level": { "pellet_count": [4,5,6,7,8], "spread_degrees": [18,17,16,15,14] }
}
{
  "id": "cannon", "name": "Cannon", "type": "weapon", "projectile_kind": "slug",
  "stats": { "fire_rate": 2.0, "projectile_speed": 700.0, "range": 900.0, "area": 8.0, "knockback": 220.0 },
  "per_level": { "damage": [30,42,54,66,78], "pierce": [1,1,2,2,3] }
}
{
  "id": "railgun", "name": "Railgun", "type": "weapon", "projectile_kind": "lance",
  "stats": { "fire_rate": 4.0, "projectile_speed": 1400.0, "range": 950.0, "area": 3.0 },
  "per_level": { "damage": [16,22,28,34,40], "pierce": [3,3,4,4,5] }
}
```
(Scattergun scales mainly via pellet count 4→8 = ×2 plus close-range coverage; the others ~2.5× via the damage arrays.)

## 1B. `data/abilities.json` — Minefield rework

In the `minefield` entry, replace `stats` with (cooldown 10 / duration 14 unchanged):
```json
"stats": { "mine_count": 4, "spread_radius": 150.0, "radius": 170.0, "trigger_radius": 110.0, "damage": 40 }
```
- `spread_radius` is NEW (Slice 2/3 makes `_spawn_ability_mines` use it instead of the hardcoded
  `60 + (i%2)*24`).
- `radius` is the blast/explosion radius (was 130). `trigger_radius` was 80 and was being ignored
  (see Slice 3 — pass it into `AbilityMine.configure`).
- `damage` is **40** (new half-scale per Slice 0).

### Ability-damage rescale (Slice 0 half-scale) — `data/abilities.json`
Halve the flat damage on damage-dealing abilities (knockback/radius/cooldown/duration unchanged):
- `shockwave` damage 30 → **15**
- `blink` `detonation_damage` 24 → **12**
- `turret` damage 20 → **10**
- `orbit` damage 18 → **9**
- (`dash` deals no damage by default — the Shockdash rare adds it; see 1C.)

## 1C. `data/mutations.json` — restructure

### Remove (these 4 become weapons in `weapons.json`):
`split_shot`, `big_shot`, `pierce`, `explosive_rounds`. Their stat-compile blocks in
`MutationSystem.get_compiled_weapon_stats()` are removed in Slice 2.

### Add `group` to every remaining/added mutation (values: `effect` | `attribute` | `ability`):

**Secondaries — `group: "effect"`, `rarity: "rare"`, one-time (no `max_level`):**
- `fire_trail` (Burn) — keep impact-pool params; **no change** beyond `group`.
- `freeze_shot` (Frost) — `group`; params change to deep-slow stacking:
  `{ "slow_step": 0.8, "slow_floor": 0.15, "slow_duration": 1.5 }` (see Slice 4C).
- `poison` (Venom) — **new-scale rebalance:** `poison_dps 8.0 → 5.0`, `poison_duration 2.5 → 3.0`; add `group`.
- `ricochet` (Bounce) — `group`; keep `bounce_count 1`, `bounce_range 220`.

**Attribute commons — `group: "attribute"`, `rarity: "common"`, `max_level: 3`:**
- Keep `move_speed`, `tough` as-is (+`group`).
- Light retunes: `rapid_fire` `0.333 → 0.30`/lvl; `velocity` keep `0.333`.
- `knockback` — **change to additive flat bonus**: replace `force_bonus_per_level: 0.333` with
  `force_per_level: 120`. `get_knockback_multiplier` becomes additive `get_knockback_bonus`
  (= `knockback_level × 120`); compile uses `knockback_force = weapon_base + bonus` (see Slice 3C).
- **New** `high_caliber`: `{ "damage_bonus_per_level": 0.20 }` — +20% weapon damage/level (the
  only damage% source; feeds the additive pool, cap +0.60 at Lv3).
- **New** `range`: `{ "range_bonus_per_level": 0.20 }` — +20% projectile range/level.
- ~~Crit Chance~~ — **dropped** (per the additive-only damage model; no crit common).

**Ability commons — `group: "ability"`, `rarity: "common"`, `max_level: 3`:**
- `quick_reflexes` keep (20/35/50%); `wide_pulse` light retune `0.333 → 0.25`/lvl; `duration` keep `0.333`.

**Ability rares — `group: "ability"`, `rarity: "rare"`, `requires_ability` set (one-time):**
- Existing: `oc_piercing_overdrive` (Overcharge), `sw_resonance` (Shockwave) — +`group` only.
- **New (params are first-pass; behavior in Slice 6):**
  - `dash_shockdash` → `requires_ability: "dash"`, `{ "passthrough_damage": 20, "knockback_force": 600 }`
  - `blink_twin_charge` → `requires_ability: "blink"`, `{ "extra_charges": 1 }`
  - `shield_aegis_burst` → `requires_ability: "shield"`, `{ "burst_radius": 200, "burst_damage": 40 }`
  - `decoy_volatile` → `requires_ability: "decoy"`, `{ "death_blast_damage": 30, "death_blast_radius": 160 }` (death blast only, no pulse)
  - `turret_twin` → `requires_ability: "turret"`, `{ "gun_count": 2 }` (one turret, twin barrels)
  - `orbit_expanding` → `requires_ability: "orbit"`, `{ "expand_interval": 2.0, "expand_bonus_radius": 120, "extra_orbs": 2 }`
  - `mf_extra_mines` → `requires_ability: "minefield"`, `{ "mine_count_bonus": 3 }`

> Note: `category` field stays untouched on all entries (only `category == "ability"` is read, by
> `MutationSystem.get_ability_rare_effects()`). The new `group` field is additive/visual + lets the
> roll/UI classify the 4 roles. Confirm new ability rares carry `category: "ability"` so the
> existing routing picks up their params.

## Slice 1 acceptance
- Headless parse passes.
- JSON validates (no trailing commas). `MutationSystem._load_definitions()` loads without error.
- Game still boots on round-8 behavior paths that don't yet reference the removed 4 mutations
  (those references are cleaned in Slice 2 — expect Slice 1 alone to leave dangling compile blocks
  that still parse; full removal is Slice 2).

---

# SLICE 2 — Weapon State + Pick Flow

Goal: a single rising `weapon_level` + an `active_weapon_id`; "Level Up Weapon" (common) and
"Change Weapon → [type]" (rare) cards that roll in the **same pool** with rarities and apply to
weapon state; and level-aware weapon stat resolution feeding the existing fire pipeline.

## 2A. `scripts/game/PlayerInventory.gd` — add weapon level
- Add `var weapon_level: int = 1`. Keep `weapon_id: String = "rifle"` as the **active** weapon.
- (Optional helper) `get_selected_weapon()` may include `"weapon_level": weapon_level`.

## 2B. `scripts/game/RunState.gd` — level-aware weapon resolution + accessors
- **Resolve stats by level.** `get_player_runtime_loadout_for()` (line ~215) currently does
  `"weapon_stats": weapon.get("stats", {})`. Replace with a resolver that merges fixed `stats`
  with `per_level[level-1]` and carries `projectile_kind`:
  ```
  func _resolve_weapon_stats(weapon_def: Dictionary, level: int) -> Dictionary:
      var out := (weapon_def.get("stats", {}) as Dictionary).duplicate(true)
      var per_level := weapon_def.get("per_level", {}) as Dictionary
      var idx := clampi(level - 1, 0, 4)
      for key in per_level.keys():
          var arr := per_level[key] as Array
          if arr.size() > 0:
              out[str(key)] = arr[min(idx, arr.size() - 1)]
      out["projectile_kind"] = str(weapon_def.get("projectile_kind", "bullet"))
      return out
  ```
  Use `_resolve_weapon_stats(get_weapon(idx_def), get_weapon_level(idx))` for `weapon_stats`.
  (`get_weapon()` at ~197 returns the `_weapons_by_id` entry for `inventory.weapon_id`.)
- **Add accessors** (per-player, reading `PlayerInventory`):
  - `get_weapon_level(player_index) -> int` (default 1)
  - `get_active_weapon_id(player_index) -> String` (default "rifle")
  - `func level_up_weapon(player_index)`: `inventory.weapon_level = mini(weapon_level + 1, 5)`
  - `func set_active_weapon(player_index, weapon_id)`: **validate first** — only set if `weapon_id`
    exists in `_weapons_by_id` with `type == "weapon"`; otherwise **no-op** (guards against
    malformed/stale synthetic ids). Level unchanged. (Optional `is_valid_weapon_id(id) -> bool` helper.)
  - `get_weapon_catalog() -> Array`: ids from `_weapons_by_id` where `type == "weapon"`
    (excludes the legacy `shockwave` `primary_skill` entry), with name for labels.

## 2C. Weapon cards in the roll — `scripts/game/MutationSystem.gd`
Weapon cards are synthetic, state-dependent option dicts. Factor generation into a private helper
`_build_weapon_cards(player_index) -> {common:[], rare:[]}` (reads the `RunState` autoload — this
is a cold path, only runs on Reward screens, so optimise for clarity not speed). In
`roll_mutation_options()` (line ~176) inject them into the pools so they compete by rarity:
- **No per-screen cap (design choice):** weapon cards sit in the real pools and roll by rarity like
  any option — a Level Up and a Switch (or multiple Switches) may appear on the same Reward screen.
  No purge/suppression step.
- Before the shuffle, append:
- **Level Up Weapon** (common pool) — only if `RunState.get_weapon_level(player_index) < 5`:
  ```
  { "id": "__weapon_levelup", "name": "Level Up Weapon", "rarity": "common", "group": "weapon",
    "icon": <active_weapon_id>,
    "description": "Upgrade %s to Lv %d." % [active_name, level + 1] }
  ```
- **Change Weapon → X** (rare pool) — one per catalog weapon `!= active`:
  ```
  { "id": "__weapon_change__<id>", "name": "Switch: <Name>", "rarity": "rare", "group": "weapon",
    "icon": "<id>", "description": "Equip the <Name> (keeps Lv %d)." % level }
  ```
These dicts carry the same fields the pick UI reads (`id/name/description/rarity/group/icon`).
`_can_still_pick` is not consulted for them (they're generated already-valid).
- **Same-screen multi-card semantics:** card text is snapshot-based for the current Reward screen.
  If `Level Up Weapon` and `Switch` appear together, choosing Level Up first may leave the visible
  Switch description saying the old level, but applying the Switch still keeps the current
  `RunState.weapon_level`. Do not rebuild remaining cards mid-screen.

## 2D. Apply weapon cards — `scripts/game/MutationSystem.gd` `apply_mutation()`
At the top of `apply_mutation(player_index, mutation_id)` (line ~38), route synthetic ids BEFORE
the normal `_definition_map` path (so they never touch `inventory.mutations`):
```
if mutation_id == "__weapon_levelup":
    RunState.level_up_weapon(player_index); return
if mutation_id.begins_with("__weapon_change__"):
    RunState.set_active_weapon(player_index, mutation_id.trim_prefix("__weapon_change__")); return
    # set_active_weapon validates the id (in _weapons_by_id, type=="weapon") — invalid → no-op
```
No change needed in `CoopManager._on_mutation_selections_confirmed` (it already calls
`apply_mutation` then `_rebuild_player_loadouts`, which re-resolves the now-updated weapon).

## 2E. Reward-screen rendering — `scripts/ui/MutationPickUI.gd`
- `_build_card()` (line ~189): for weapon cards (`group == "weapon"`), **use the weapon icon**
  (`IconFactoryData.get_weapon_icon(str(option.get("icon", "")))`) instead of `get_mutation_icon`;
  do **not** pass the synthetic card id (`__weapon_levelup` / `__weapon_change__...`) to
  `get_weapon_icon`. Also **skip the
  `"Lv X -> Lv Y"` label** (line ~247-254) — that reads a mutation stack count, meaningless here;
  the card's description already states the weapon level. Other card chrome unchanged.
- **Active-weapon chip in "Current Build":** in `_populate_inventory_flow` / `_build_inventory_entries`
  (line ~279-305), prepend a chip for the active weapon, e.g. `"<Weapon Name> Lv<N>"` from
  `RunState.get_active_weapon_id` + `get_weapon_level` (+ catalog name), so the player sees their
  gun alongside Effects/Attributes/Abilities. (Tint with the weapon group color in Slice 7.)
- **Chip metadata lookup:** add `MutationSystem.get_definition(id) -> Dictionary` returning the
  mutation's `name` / `rarity` / `group`. `_build_inventory_entries` should use it instead of local
  `_format_name` + the hardcoded rare-id list in `_is_current_pick_rare`, so chips show real name,
  rarity, and group. (The active-weapon chip's group is `weapon`.)
- **Player-facing terminology sweep:** update visible reward/build UI strings from "mutation" to
  "Upgrade" / "upgrade" while keeping code names unchanged. Examples: "Choose one mutation" →
  "Choose one upgrade"; "No mutations yet" → "No upgrades yet". Do not rename scripts, methods,
  variables, JSON file names, or code-only concepts.

## 2F. Remove the 4 promoted upgrades' compile blocks
In `MutationSystem.get_compiled_weapon_stats()`: remove the `split_shot`, `big_shot`, `pierce`,
and `explosive_rounds` blocks — their behavior now lives in weapon definitions (Scattergun
`pellet_count`, Cannon `area`, Cannon/Railgun `pierce`, Rocket `blast_radius`/`blast_damage_percent`)
+ the Slice 3 fire patterns. **Keep** the Effect blocks (`fire_trail`, `freeze_shot`, `poison`,
`ricochet`) and the Attribute multipliers (`rapid_fire`→fire_rate, `velocity`→speed, `knockback`).
Weapon-resolved stats pass through untouched.
- **High Caliber (+dmg%) and Range (+range%) compile handling is in Slice 5** (with the other new
  commons), not here.
- Note for Slice 3: reconcile stat key names — weapon defs use `pierce`, the old projectile path
  used `pierce_count`; pick one key and make the fire path read it.

## Slice 2 acceptance
- Headless parse passes.
- Start a run: player has Rifle Lv1; leveling-up offers a "Level Up Weapon" common and (sometimes)
  "Switch: …" rares; taking Level Up raises `weapon_level` and damage rises next room; taking a
  Switch changes the active weapon while keeping the level.
- `get_player_runtime_loadout_for` returns level-correct `damage`/`fire_rate`/etc.; the rifle at
  Lv5 deals 25 (vs 10 at Lv1).

---

# SLICE 3 — Per-weapon Fire Patterns (via stat mapping)

**Approach (locked):** reuse the existing projectile mechanics (multi-projectile spread, pierce,
impact explosion) — **no new per-weapon fire code.** The weapons differ purely by their stats,
mapped once onto the keys the fire path already reads.

## 3A. Mapping helper — `MutationSystem.get_compiled_weapon_stats()`
Add `_map_weapon_stats_to_projectile_keys(compiled)`, called at the **end** of
`get_compiled_weapon_stats` (cold path: once per room). Translations:
- `pellet_count` → `split_extra_count` = `max(0, pellet_count - 1)`; `spread_degrees` → `split_spread_degrees`
- `pierce` → `pierce_count`
- `blast_radius` → `explosion_radius`; `blast_damage_percent` → `explosion_damage_percent`
- `knockback` → base `knockback_force` (then ×Knockback attribute — see 3C)
- `projectile_kind` → set the projectile visual fields (`projectile_shape`, `trail_style`,
  `impact_sfx`) from the kind→visual table in **3D**, because `Projectile.gd` consumes those fields,
  NOT `projectile_kind`. Accent stays the player tint (round-7 core-readability rule).

`Player._fire_weapon` + `CoopManager._on_player_fire_requested` already consume
`split_extra_count` / `pierce_count` / `explosion_radius` → **no changes there**.

## 3B. Per-weapon results (all emergent from the mapping)
- **Rifle** — no special keys → single projectile (area 4 collision, range 950).
- **Scattergun** — `pellet_count` 4→8 ⇒ `split_extra_count` 3→7 in a `spread_degrees` cone;
  range 550; each pellet deals full 8 dmg.
- **Cannon** — `pierce` 1→3 ⇒ `pierce_count`; area 8 ⇒ large `collision_half_width`; base knockback 220.
- **Railgun** — `pierce` 3→5 ⇒ `pierce_count`; speed 1400; area 3 ⇒ thin.
- **Rocket** — `blast_radius` 90→138 ⇒ `explosion_radius`; `blast_damage_percent` 0.7 ⇒
  `explosion_damage_percent`; speed 600 (slow). **Direct target: full damage; others in blast: 70%**
  (existing impact handler, CoopManager ~883-902, skips the direct target).

## 3C. Knockback — additive model (`get_compiled_weapon_stats` knockback block)
Knockback follows the same **additive** rule as damage (no compounding):
```
knockback_force = weapon_base_knockback + (knockback_level × flat_bonus)
```
- `flat_bonus` ≈ **120/level** (first-pass). Weapon base `knockback`: **Cannon 220, all others 0**
  — the attribute adds a flat amount on top of any weapon, so it works on guns with 0 base too
  (no zero-multiply dead zone).
- **Attribute change:** `knockback` mutation param flips from a percent (`force_bonus_per_level:
  0.333`) to a flat value (`force_per_level: 120`); `get_knockback_multiplier` becomes an additive
  `get_knockback_bonus` returning `knockback_level × 120`. (See Slice 1C update.)

## 3D. `projectile_kind` → projectile visual fields (explicit mapping)
`Projectile.gd` consumes `projectile_shape`, `trail_style`, `impact_sfx` — **not** `projectile_kind`.
So the stat mapper translates `projectile_kind` into those fields via this table (accent = player
tint, unchanged):
| `projectile_kind` | `projectile_shape` | `trail_style` | `impact_sfx` |
|---|---|---|---|
| `bullet` | `small_orb` | `thin` | `hit` |
| `pellet` | `small_orb` | `short` | `spread` |
| `slug` | `large_orb` | `heavy_slow` | `thump` |
| `lance` | `lance` | `sharp` | `zip` |
| `rocket` | `ember_orb` | `embers` | `boom` |
No behavior in Slice 3; this is the visual wiring (the look targets are in 7-pre). If a listed
`trail_style`/`impact_sfx` value isn't yet handled by `Projectile.gd`, add the case there.

## Slice 3 acceptance
- Headless parse passes.
- Each weapon fires its pattern: Scattergun sprays a pellet cone, Cannon/Railgun pierce, Rocket
  explodes on impact with splash, Rifle single shot.
- No regression vs the old split/pierce/explosion (now driven by weapon stats, not the removed upgrades).

---

# SLICE 4 — Effects (weapon-agnostic riders)

Effects already apply on hit for **any** projectile (`Projectile._attempt_hit_target` /
`_spawn_impact_fire_pool`); the compile sets their flags on the active weapon's config, so they
ride whatever weapon is equipped — **no architecture change.** Effects are **one-time Rares**
(no leveling) → compile uses binary `has_mutation`, not level scaling.

## 4A. Burn (`fire_trail`) — AOE pool
Existing impact pool; rides any weapon. Values from Slice 1 (radius 50, lifetime 2.0, dmg% 0.4).
No new behavior. (compile already uses `has_mutation`.)

## 4B. Venom (`poison`) — single-target stacking DoT
`apply_poison` already **stacks** (`_poison_dps += dps`), per-enemy, ticks every 0.5s. Just the
Slice 1 rescale to **5 dps / 3.0s**. No new behavior.

## 4C. Frost (`freeze_shot`) — deep stacking slow (NO hard freeze; no boss special-casing)
Locked: a **deep slow only** — sustained fire deepens the slow toward a near-stop; no frozen/
stunned state; works on bosses normally (they still act, just slowly).
- Today `apply_slow` takes the *strongest single* slow (`min(...)`), so repeat hits of equal
  strength don't deepen. Make Frost **deepen per hit** toward a floor (~85% slow = multiplier
  **0.15**), refreshing duration (~1.5s).
- **freeze_shot params** become: `{ "slow_step": 0.8, "slow_floor": 0.15, "slow_duration": 1.5 }`
  (each hit multiplies current slow ×0.8 down to the floor).
- **Implementation caution:** `apply_slow` is also called by the **Ice Zone modifier**. Don't
  silently flip its semantics to multiplicative — either add a stacking variant/param for weapon
  Frost or guard the change so Ice Zone still behaves. Confirm callers at edit time.

## 4D. Bounce (`ricochet`) — one-time fixed bounces
Works via `ricochet_remaining`. Since Effects don't level, compile sets a **fixed**
`ricochet_count` (1–2) via `has_mutation` — not `level × bounce_count`. Keep `bounce_range 220`.

## 4E. Compile (`get_compiled_weapon_stats`)
Keep the `fire_trail` / `freeze_shot` / `poison` blocks (already binary). Change the `ricochet`
block from `get_mutation_level × bounce_count` to binary `has_mutation` → fixed count. Effects ride
the active weapon automatically (flags on the compiled weapon config).

## Slice 4 acceptance
- Headless parse.
- Equip each Effect with different weapons — burning rockets, poison railgun, frost scattergun,
  bouncing cannon — each applies regardless of weapon.
- Frost: sustained fire on one enemy visibly deepens its slow toward a near-stop; no hard freeze;
  bosses still act. Venom stacks. Burn pool drops on impact. Bounce hits 1–2 extra targets.

---

# SLICE 5 — New Commons + Light Retunes

## 5A. High Caliber compile — `get_compiled_weapon_stats`
`compiled["damage"] = weapon_damage × (1 + 0.20 × high_caliber_level)` (cap +0.60 at Lv3). The
**only** damage% source = the additive pool. Bake into `compiled["damage"]` (flows to
`projectile_damage`), matching the existing fire_rate/speed handling. Ceiling: Lv5 weapon (×2.5)
× maxed High Caliber (×1.6) ≈ **×4** of a fresh rifle (power budget).

## 5B. Range compile — `get_compiled_weapon_stats`
`compiled["range"] = weapon_range × (1 + 0.20 × range_level)`. `range` flows to `max_distance`.

## 5C. Light retunes (data, `mutations.json`)
- `rapid_fire` `0.333 → 0.30`/lvl
- `wide_pulse` `0.333 → 0.25`/lvl
- `knockback` → **additive** `force_per_level: 120` (the Slice 3C flip; `get_knockback_bonus`)
- `velocity` / `move_speed` / `tough` / `quick_reflexes` / `duration` — **unchanged**

## 5D. New common data (defined in Slice 1C)
`high_caliber` `{damage_bonus_per_level: 0.20}` · `range` `{range_bonus_per_level: 0.20}` ·
group `attribute`, max_level 3. **Common pool = 7** (rapid_fire, velocity, knockback, move_speed,
tough, high_caliber, range) + the Level Up Weapon card.

> Transient **room buffs** (objective Damage buff) and **zone modifiers** remain their own
> multiplier layered on top — the additive rule governs *permanent Upgrades* only. Unchanged.

## Slice 5 acceptance
- Headless parse.
- High Caliber Lv3 raises damage ~+60%; Lv5 weapon + maxed High Caliber ≈ ×4 a fresh rifle.
- Range Lv3 extends projectile travel; rapid_fire/wide_pulse feel slightly tamer; knockback works
  additively on every weapon (incl. 0-base guns).

---

# SLICE 6 — Ability Signatures (7 bespoke behaviors)

**Foundation (no new plumbing):** `_build_runtime_ability()` (CoopManager ~585) already merges each
Signature's params into its ability's `stats` via `get_ability_rare_effects(player_index,
ability_id)` — for both player-side and world-side abilities. Signatures are loadout-gated Rares,
only offered when the ability is equipped (enforced by `_required_ability_is_equipped` /
`_can_still_pick`). Data entries are in Slice 1C. **So each Signature below = behavior-only: read
its param from the ability's `stats` and act.** Build/parse-check one at a time.

## 6.1 Shockdash (Dash) — `passthrough_damage: 20`, `knockback_force: 600`
Dash is player-side (`DashData` + movement in `Player.gd`). Hook in `Player._physics_process`:
while a dash slot `is_active(now)`, query nearby enemies (combat owner `get_nearby_enemy_target_nodes`,
as `AbilityMine` does) and for each enemy overlapping the player apply `passthrough_damage` +
`apply_knockback(dir, knockback_force)` **once per enemy per dash** — track a per-dash hit set,
cleared in `_on_dash_started`. Guard: only runs when the dash slot's `passthrough_damage > 0`.

## 6.2 Twin Charge (Blink) — `extra_charges: 1`
Add a small **charge system** to the blink slot: track `charges` + `next_recharge_at`,
`max_charges = 1 + extra_charges` (default 1). In the "blink" activation (Player ~497), gate on
`charges > 0` (consume one) instead of `_is_slot_ready`; **regen one charge per `cooldown` (4s)**
up to max. Seed `charges = max_charges` on loadout build. Without the Signature, `max_charges = 1`
→ identical to today's single-cooldown blink.
- **Cooldown/HUD semantics:** `get_ability_cooldown_remaining(blink_slot)` returns **0** while
  `charges > 0`; when `charges == 0`, returns `next_recharge_at − now` (time to the next charge),
  so the cooldown arc only shows while fully empty.
- **HUD:** for any slot with `max_charges > 1`, display the **charge count** (e.g. small pips or a
  number badge) next to the slot; the recharge arc fills toward the next charge when below max.

## 6.3 Aegis Burst (Shield) — `burst_radius: 200`, `burst_damage: 40`
Shield is player-side (`_shield_until`). **No absorb tracking** — when the shield **expires**
(active→inactive transition), if the shield slot owns the Signature (`burst_damage > 0`), emit a
**fixed-damage AOE** only after the shield itself is over and the player is vulnerable again:
`now >= _shield_until` and the previous frame was shield-active. Implement with a dedicated
`shield_burst_requested(origin, radius, damage, color)` signal on `Player.gd`, connected in
`CoopManager.gd`. CoopManager deals `burst_damage` (40) to enemies within `burst_radius` (200),
reusing the in-radius damage loop (~886-902) + a ring VFX. Do not fire the burst on shield cast,
dash i-frames, contact i-frames, or while the shield remains active.

## 6.4 Volatile Decoy (Decoy) — `death_blast_damage: 30`, `death_blast_radius: 160`
**Death blast only — no pulse.** In `DecoyNode._expire()` (death OR timeout), if it owns the
Signature (`death_blast_damage > 0`), deal `death_blast_damage` (30) to enemies within
`death_blast_radius` (160) via the combat-owner grid + `apply_damage`, plus a ring VFX (same
pattern as `AbilityMine._explode`). The decoy spawn (CoopManager ~1191) passes the params into
`DecoyNode.configure`. Plain Decoy (no Signature) is unchanged.

## 6.5 Twin Turret (Turret) — `gun_count: 2`
**One turret, twin gun** (not two turrets). In `TurretNode`: `configure` reads `gun_count`
(default 1). On each fire cycle, emit `fire_requested` **`gun_count` times** from barrels offset
perpendicular to the aim direction (±8px), same target/direction → doubled DPS. `_draw` renders
`gun_count` parallel barrel lines (twin-barrel look). Plain Turret (`gun_count` 1) = unchanged.

## 6.6 Expanding Orbit (Orbit) — `expand_interval: 2.0`, `expand_bonus_radius: 120`, `extra_orbs: 2`
**Expand + add orbs.** In `OrbitNode`: `configure` reads all three (defaults 0). `orb_count =
base + extra_orbs` (3 → 5). Add `_current_orbit_radius(now) = orbit_radius + expand_bonus_radius ×
pulse`, where `pulse` is a smooth 0→1→0 sine over `expand_interval` (84 → ~204 → 84 every 2s). Use
the effective radius in `_get_orb_positions` / `_draw` and the damage query (`orbit_radius + 32` →
`effective + 32`). Plain Orbit (all 0) = unchanged.

## 6.7 Extra Mines (Minefield) — `mine_count_bonus: 3`
In `_spawn_ability_mines` (~838): `mine_count = stats.mine_count (4) + stats.mine_count_bonus (0)`
→ **7 mines** at `spread_radius` 150 with the Signature. Rest of the minefield rework (Slice 1B)
unchanged. Plain Minefield = 4.

## Slice 6 acceptance
- Headless parse after each Signature (build one at a time).
- Each behaves only when its ability is equipped AND the Signature is picked:
  Shockdash damages dashed-through enemies · Twin Charge = 2 blink charges · Aegis Burst = 40 AOE
  in 200px on shield expiry · Volatile Decoy = 30 blast in 160px on death · Twin Turret = twin
  barrels (~2× DPS) · Expanding Orbit = 5 orbs sweeping 84→~204 · Extra Mines = 7 mines.
- Existing pilots (Overcharge Piercing Overdrive, Shockwave Resonance) still work.

---

# SLICE 7 — Visuals (4-group language + weapon projectiles)

## 7-pre. Weapon projectile visuals (LOCKED) — keyed by `projectile_kind`
Each kind gets a distinct projectile look; **keep a player-tint core** for team readability
(round-7 rule). Implemented in `Projectile.gd` visual path + `IconFactory`/feedback as needed.
| `projectile_kind` | weapon | look |
|---|---|---|
| `bullet` | Rifle | small fast round, thin streak |
| `pellet` | Scattergun | small stubby cluster, short trail |
| `slug` | Cannon | big heavy orb, slow weighty trail |
| `lance` | Railgun | thin elongated lance, sharp bright streak |
| `rocket` | Rocket | warhead shape + smoke/flame trail |

## 7A. Group colors (LOCKED — max separation)
Define once as `MUTATION_GROUP_COLORS` (in `IconFactory` or a shared const); used by icons, card
tags, and chips:
- **Weapon** = orange `Color(1.0, 0.55, 0.2)`
- **Effect** = green `Color(0.4, 0.9, 0.4)`
- **Attribute** = cyan `Color(0.35, 0.75, 1.0)`
- **Ability** = violet `Color(0.72, 0.46, 1.0)`

## 7B. Group-colored icons — `IconFactory._build_mutation_icon`
Replace the random hue (`hash(id) % 360`) with the **group color** background; keep the per-id
glyph. Change `get_mutation_icon(id)` → `get_mutation_icon(id, group)`; `MutationPickUI` passes the
option's `group`. Include `group` in the cache key. Weapon cards use `get_weapon_icon` (Slice 2E),
tagged Weapon/orange.

## 7C. Card group tag — `MutationPickUI._build_card`
Add a small text tag (`WEAPON` / `EFFECT` / `ATTRIBUTE` / `ABILITY`) tinted by the group color,
alongside the existing `COMMON`/`RARE` label; rarity stays on the **border**. Both signals coexist.

## 7D. Build-panel chips
Tint inventory chips (`_build_inventory_chip`) and the active-weapon chip (Slice 2E) by group color,
read from `MutationSystem.get_definition(id).group` (active-weapon chip = `weapon`). See the 2E
chip-metadata note.

## Slice 7 acceptance
- Headless parse.
- Pick cards show category at a glance via color + text tag; rarity still readable on the border.
- Each weapon fires a visually distinct projectile (bullet/pellet/slug/lance/rocket) with a
  player-tint core; Effect riders (burn/frost/venom/bounce) overlay on top.
