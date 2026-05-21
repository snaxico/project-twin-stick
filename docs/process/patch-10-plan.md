# Patch 10 — Number Scale, Combat Feel, and Flow Validation

Hard scope lock: no new weapons, enemies, progression systems, map systems, or major UI systems.

---

## Patch 10A — x10 Number Scale — IMPLEMENTED (uncommitted)

## Status Note

- This file is a historical implementation record for an earlier slice.
- It is not the current runtime source of truth.

**Status:** All code changes applied in the main working tree. Not yet committed. Needs headless parse and live validation before commit.

### Goal

Convert all combat numbers to base-10 while preserving balance. Every hit, health bar, and healing value should display 10x the current number. Time-to-kill, relative balance, and game flow must remain identical.

### Rules

- Scale flat combat damage, HP, healing, generator HP, passive flat combat bonuses, and modifier flat combat bonuses by x10.
- Gold and economy values stay unchanged.
- Percent multipliers, cooldowns, ranges, radii, spawn timing, movement speeds, and fire rate values stay unchanged.
- Do not tune balance during this pass. The only goal is bigger numbers with identical feel.

### Changes

#### Player base stats — `scripts/player/Player.gd`

| Line | Field | Old | New |
|------|-------|-----|-----|
| 39 | `max_health` | `5` | `50` |
| 42 | `projectile_damage` | `1` | `10` |
| 45 | `secondary_damage` | `3` | `30` |

These exports are fallback defaults. The runtime compiler in `RunState.gd` overrides them, but they must stay consistent.

#### Enemy stats — `scripts/enemies/Enemy.gd`

All values inside `setup()` (lines 73–117) and the export defaults (lines 27–30):

| Enemy | Field | Old | New | Line(s) |
|-------|-------|-----|-----|---------|
| Chaser (default) | `max_health` | `3` | `30` | 27, 110 |
| Chaser (default) | `contact_damage` | `1` | `10` | 28 |
| Chaser (default) | `projectile_damage` | `1` | `10` | 30, 114 |
| Spitter | `max_health` | `2` | `20` | 78 |
| Spitter | `projectile_damage` | `1` | `10` | 82 |
| Charger | `max_health` | `4` | `40` | 88 |
| Charger | `contact_damage` | `2` | `20` | 93 |
| Boss | `max_health` | `18` | `180` | 99 |
| Boss | `projectile_damage` | `1` | `10` | 103 |
| Boss | `contact_damage` | `1` | `10` | 104 |

#### Boss per-player scaling — `scripts/enemies/Enemy.gd`

Line 140: the additive damage bonus per extra player must scale.

```
# Old
projectile_damage += maxi(player_count - 1, 0)

# New
projectile_damage += maxi(player_count - 1, 0) * 10
```

The health scaling formula on line 137 (`1.0 + (player_count - 1) * 0.6`) stays unchanged — it is a multiplier on the already-scaled base HP.

#### Generator HP — `scripts/game/GeneratorObjective.gd`

| Line | Field | Old | New |
|------|-------|-----|-----|
| 7 | `normal_max_health` | `10` | `100` |
| 8 | `elite_max_health` | `14` | `140` |
| 11 | `max_health` (default) | `10` | `100` |
| 12 | `current_health` (default) | `10` | `100` |

#### Primary weapon base damage — `data/weapons.json`

Scale every `base_stats.damage` value in the `weapons` array. Level `damage_mult` values stay unchanged — they are multipliers on the base.

| Weapon | Old `base_stats.damage` | New |
|--------|-------------------------|-----|
| Rifle | `1.0` | `10.0` |
| Scatter | `1.0` | `10.0` |
| Slug | `2.0` | `20.0` |
| Incinerator | `1.0` | `10.0` |
| Beam Lance | `1.0` | `10.0` |
| Arc Caster | `1.0` | `10.0` |

#### Secondary base damage — `scripts/game/RunState.gd`

Line 1062: the hardcoded secondary base damage must scale.

```
# Old
"secondary_damage": max(1, int(round((3.0 + ...

# New
"secondary_damage": max(1, int(round((30.0 + ...
```

#### Rest room heal amount — `scripts/game/RunState.gd`

Line 540:

```
# Old
"reward": {"type": "heal_all", "amount": 2, "label": "Recover 2 HP"},

# New
"reward": {"type": "heal_all", "amount": 20, "label": "Recover 20 HP"},
```

Line 800:

```
# Old
node["reward_label"] = "Recover 2 HP"

# New
node["reward_label"] = "Recover 20 HP"
```

#### Rest room heal fallback max — `scripts/game/RunState.gd`

Line 826: the fallback max health cap must scale.

```
# Old
state["current"] = min(int(state.get("current", 0)) + amount, int(state.get("max", 5)))

# New
state["current"] = min(int(state.get("current", 0)) + amount, int(state.get("max", 50)))
```

#### Revive health — `scripts/game/CoopManager.gd`

| Line | Field | Old | New |
|------|-------|-----|-----|
| 109 | `revive_health` | `2` | `20` |

#### Inferno stationary damage — `scripts/game/CoopManager.gd`

Line 2319:

```
# Old
player.apply_damage(1)

# New
player.apply_damage(10)
```

#### Passive flat bonuses — `data/passives.json`

| Passive | Field | Old | New | Approximate line |
|---------|-------|-----|-----|------------------|
| Tungsten Cores | `effects.damage_add` | `2` | `20` | 35 |
| Charged Payload | `passive_effects.secondary_damage_bonus` | `2` | `20` | 78 |
| Chain Reaction | `effects.damage_add` | `1` | `10` | 115 |
| High Velocity Rounds | `effects.damage_add` | `1` | `10` | 133 |
| Ember Bloom trigger | `triggers[0].action.damage` | `1` | `10` | 171 |
| Feedback Arc trigger | `triggers[0].action.damage` | `1` | `10` | 202 |
| Culling Burst trigger | `triggers[0].action.damage` | `1` | `10` | 231 |
| Detonation Web trigger | `triggers[0].action.damage` | `1` | `10` | 259 |
| Ablative Coating | `passive_effects.max_health_bonus` | `2` | `20` | 281 |
| Reinforced Plating | `passive_effects.max_health_bonus` | `1` | `10` | 294 |

#### Passive descriptions — `data/passives.json`

Update display text to match new numbers:

| Passive | Old description | New description |
|---------|-----------------|-----------------|
| Tungsten Cores | "Add 2 primary damage to every shot." | "Add 20 primary damage to every shot." |
| Charged Payload | "Add 2 damage to every secondary detonation." | "Add 20 damage to every secondary detonation." |
| Chain Reaction | "Give explosions more reach and add 1 primary damage." | "Give explosions more reach and add 10 primary damage." |
| High Velocity Rounds | "Increase projectile speed and add 1 primary damage." | "Increase projectile speed and add 10 primary damage." |
| Ablative Coating | "Give every player +2 max HP and restore that amount immediately." | "Give every player +20 max HP and restore that amount immediately." |
| Reinforced Plating | "Give every player +1 max HP and heal that amount immediately." | "Give every player +10 max HP and heal that amount immediately." |

#### Modifier flat bonuses — `data/modifiers.json`

| Modifier | Field | Old | New | Line |
|----------|-------|-----|-----|------|
| Armoured | `enemy_bonus_health` | `2` | `20` | 17 |
| Explosive Death | `death_explosion_damage` | `1` | `10` | 32 |
| Stampede | `enemy_contact_damage_bonus` | `1` | `10` | 40 |

#### Modifier descriptions — `data/modifiers.json`

No modifier descriptions reference specific numbers, so no text changes are needed.

### Do NOT change

- Gold reward values (`BASE_GOLD_COMBAT`, `BASE_GOLD_ELITE`, `GOLD_PER_STEP` in `RunState.gd`).
- Shop costs and scrap values in `weapons.json` and `passives.json`.
- All `_mult` values (fire_rate_mult, damage_mult in weapon levels, cooldown_mult, etc.).
- Cooldowns, fire intervals, spawn timing, movement speeds, radii, ranges.
- Boss health scaling multiplier formula (the `0.6` per extra player stays).
- Pierce counts (`pierce_count_add` stays at `1`).
- Projectile amounts (`amount_add` stays at `1`).
- Pickup gold and food `value` parameters in `_spawn_pickup()` calls — these are gold economy values, not combat values.
- `GLOBAL_PRIMARY_FIRE_INTERVAL_MULT` and `GLOBAL_SECONDARY_COOLDOWN_MULT` (these are rate multipliers).

### Validation

1. Run headless parse:
   ```powershell
   & 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit
   ```
2. Start a normal run. Confirm:
   - Player HP bar shows 50.
   - Floating damage text shows values like `-10`, `-20`.
   - Rest room heals 20 HP.
   - Enemy kills take the same number of shots as before.
   - Boss HP scales visibly higher.
   - Generator HP is 100/140.
   - Passive descriptions show updated numbers.

---

## Patch 10B — Combat Feel and Readability — IMPLEMENTED (uncommitted)

**Status:** All code changes applied in the main working tree. Not yet committed. Needs live validation before commit.

### Goal

Make combat hits, kills, and weapon identity feel satisfying without hurting readability. All changes are value tuning on existing systems.

### Rules

- Tune only existing feedback systems. Do not add new particle types, new shaders, or new sound categories.
- Keep effects readable with 2–4 players. If spectacle obscures enemies, projectiles, aim lines, loot, or HUD, pull it back.
- Do not change balance or damage values.

### Changes

#### Kill feedback — `scripts/game/CoopManager.gd`

`_on_enemy_died()` starting at line 1202:

| Parameter | Old | New |
|-----------|-----|-----|
| Hitstop duration | `0.03 + enemy_weight * 0.014` | `0.05 + enemy_weight * 0.025` |
| Camera trauma | `0.18 + enemy_weight * 0.16` | `0.25 + enemy_weight * 0.20` |
| Death ring radius | `36.0 + enemy_weight * 20.0` | `44.0 + enemy_weight * 28.0` |
| Death ring thickness | `2.5 + enemy_weight` | `3.0 + enemy_weight * 1.5` |

#### Non-lethal hit hitstop — `scripts/game/CoopManager.gd`

`_on_enemy_hit_received()` at line 1281:

| Parameter | Old | New |
|-----------|-----|-----|
| Hitstop duration | `0.01 + enemy_weight * 0.006` | `0.018 + enemy_weight * 0.01` |

#### Muzzle flash camera trauma — `scripts/game/CoopManager.gd`

`_on_player_muzzle_flash_requested()` at lines 1259–1264:

| Profile | Old | New |
|---------|-----|-----|
| `slug` | `0.08` | `0.16` |
| `scatter` | `0.04` | `0.10` |
| default (rifle) | `0.02` | `0.05` |

#### Aim recoil — `scripts/player/Player.gd`

`_play_fire_recoil()` at line 943–945:

| Parameter | Old | New |
|-----------|-----|-----|
| Aim line recoil | `9.0 + 5.0 * intensity` | `14.0 + 8.0 * intensity` |
| Turn squash | `0.24 + 0.12 * intensity` | `0.28 + 0.16 * intensity` |

#### Weapon targets

After applying the above values, validate in live play that:

- **Rifle** feels reliable and snappy — steady rhythm, light but consistent kick.
- **Scatter** feels wide and punchy — noticeable spread feedback, stronger camera push.
- **Slug** feels heavy and impactful — visible recoil, strong hitstop on hit, camera shove.

### Do NOT change

- Particle counts, particle lifetimes, particle colors.
- Sound generation parameters in `SfxEngine.gd`.
- Explosion feedback values (those are already tuned separately).
- Dash feedback values.
- Any damage, HP, or balance values.

### Validation

1. Run headless parse.
2. Play rooms 1–3 with Rifle, then Scatter, then Slug.
3. Confirm:
   - Kills feel punchier than before.
   - Enemies, projectiles, aim lines, and loot stay readable.
   - Slug feels noticeably heavier than Rifle.
   - Scatter feels wider and punchier than Rifle.
   - With 2 players, effects do not obscure the arena.

---

## Patch 10C — Loot, HUD, and Flow Validation — PARTIALLY IMPLEMENTED (uncommitted)

**Status:** Loot animation and gold burst offset are applied in the main working tree. HUD and flow validation still need live play.

### Goal

Make the reward flow feel like a reward, reduce debug-like HUD presentation, and validate the full gameplay loop with gamepad input.

### Rules

- Loot presentation changes should be small tweens, not new systems.
- HUD changes should reduce clutter, not add new elements.
- Flow fixes should only address confusing friction points found during validation.

### Changes

#### Loot spawn animation — `scripts/game/LootDrop.gd` — IMPLEMENTED

Scale tween on `_ready()` so loot items pop in instead of appearing instantly:

- Start at `scale = Vector2(0.0, 0.0)`.
- Tween to `Vector2(1.0, 1.0)` over `0.18` seconds with `TRANS_BACK` and `EASE_OUT`.

#### Enemy gold pickup burst — `scripts/game/CoopManager.gd` — IMPLEMENTED

In `_drop_pickups_for_enemy()`, gold spawns with a small random offset from the death position:

- Offset: `Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))`.

#### HUD readability — validation-driven

These are not pre-planned code changes. Play several rooms and identify:

- Any element that reads as debug UI rather than player UI.
- Secondary/passive chip readability during active fights.
- Floating text readability with the new x10 numbers (do the numbers overlap, are they too large, do they need font size adjustment?).
- Fix only what is found during validation.

#### Loot/shop flow — validation-driven

Run several rooms with gamepad-first input and check:

- Take / Scrap resolution.
- Weapon replacement flow.
- Shop ready-up.
- Exit zone behavior.
- Fix only confusing friction points found during validation.

### Final Validation

1. One full Easy mode run.
2. One full Normal mode run.
3. Record pacing issues: too slow, too hard, unclear rewards, weak power curve, confusing UI moments.
4. Document findings in `docs/development/history/` for the session date.

---

## Implementation Status

| Sub-patch | Code | Committed | Validated |
|-----------|------|-----------|-----------|
| 10A — x10 Number Scale | Done | No | Needs headless parse + live run |
| 10B — Combat Feel | Done | No | Needs live play rooms 1–3 |
| 10C — Loot animation | Done | No | Needs live play |
| 10C — Gold burst offset | Done | No | Needs live play |
| 10C — HUD readability | Not started | — | Needs live play |
| 10C — Loot/shop flow | Not started | — | Needs live play |
| 10C — Full-run pacing | Not started | — | Needs live play |

## Remaining Work

1. Run headless parse to confirm no errors.
2. Commit all 10A + 10B + 10C code changes as one patch commit.
3. Play-validate 10A (numbers display correctly, TTK unchanged).
4. Play-validate 10B (weapon feel, kill feedback, readability).
5. Play-validate 10C (loot pop, HUD, flow friction, full-run pacing).
6. Record findings and fix issues found during validation.

## After Patch 10

Update:
- `docs/development/current-state.md`
- `docs/development/history/` entry for the session
- `docs/process/prototype-roadmap.md` (add Patch 10 row)
