# V4 — Enemy Tiers: Ranged "Specials" + Shooter Cap (Codex-ready)

> **Phase 0** of the room/enemy redesign — the immediate `ranged_gauntlet` bullet-hell fix. Independently
> shippable (no dependency on the flow-field / curated-room work). Branch `v4/class-system`, active checkout
> `D:\GameDev\Project_Twin_stick`.
>
> **Validation gate (per slice):**
> ```powershell
> $GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' --quit                                   # parse
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=entity_ramp                 # perf (avg_fps >= 60)
> ```
>
> **Root cause:** the swarm/density model is a **melee** mechanic; multiplying **ranged** enemies just
> multiplies bullet *sources* into noise. `ranged_gauntlet` biases `["spitter","spitter","elite_spitter"]` at
> `normal` density, and `elite_spitter` fires a **5-shot fan every 0.8s** — the wall.
>
> **Model = "trash + specials"** (NOT a full pivot — keeps the crowds that Bloodthirst/Bloodfrenzy/Momentum
> feed on): melee = the density-scaled swarm; **ranged = capped, telegraphed, priority threats.**
>
> **Decisions (LOCKED via MC 2026-07-07):**
> - **Spitter → telegraphed 3-shot fan.** ~0.45s wind-up, aim locked at wind-up START (so moving dodges),
>   **scale-pulse** tell (body swells), then a 3-shot fan. HP **14 → 30**. Slows while winding up.
> - **elite_spitter → telegraphed heavy 5-shot fan**, drop the 0.8s machine-gun (cadence → ~2.2s), same
>   wind-up + scale-pulse. HP unchanged (360).
> - **Global concurrent-shooter budget:** base **6**, **+2 for 2P** (`6 + 2*(player_count-1)`). Cost:
>   **spitter = 1, elite_spitter = 2.**
> - **Overflow → melee** from the **room's own melee pool** (fallback `chaser`) when the budget is full — same
>   enemy count, threat moves from bullets to bodies.
> - **No new ranged enemy types.**

---

## Tier reference

| Tier | Members | Behavior |
|---|---|---|
| Trash — melee | chaser, charger, splitter, splitter_mini, bomber | Swarm; **density-scaled** (unchanged). |
| Ranged / specials | **spitter, elite_spitter** (+ elite_charger/elite_support are melee elites) | **Capped** by the shooter budget; telegraphed; priority. |
| Champions | boss_warden/hydra/hive/pulsar | One per boss room; **excluded** from the swarm cap. |

---

## Slice 1 — Spitter & elite_spitter → telegraphed fans (`scripts/enemies/Enemy.gd`)

The fan mechanism already exists: `_emit_projectiles_at(dir, count, spread_radians, scale)` →
`_build_spread_directions` (spread = **per-shot step**; elite already fires count 5 @ 0.16). We add a
**wind-up phase** and adjust counts/cadence/HP.

**① New state + wind-up in `_update_spitter_behavior`** (currently L834; fires inline at L840-843):
- Add fields (near the other windup timers ~L214): `var _spitter_windup_until := 0.0`,
  `var _spitter_aim_dir := Vector2.ZERO`, `var _spitter_windup_active := false`. Reset them in the type
  reset block (~L269) and on `_configure_type`.
- Replace the inline fire (L840-843) with a **two-step wind-up**:
  - **Enter wind-up** when `now >= _next_fire_at and distance > 120.0 and not _spitter_windup_active`:
    - `_spitter_windup_active = true`
    - `_spitter_windup_until = now + (0.45 if SPITTER else 0.50)`
    - capture aim **now**: `_spitter_aim_dir = (_get_lead_direction(raw_direction, projectile_speed, 0.35) if ELITE_SPITTER else raw_direction)` *(elite keeps its lead; basic locks straight)*
    - `_next_fire_at = now + _get_effective_fire_interval()` *(cadence measured from wind-up start)*
  - **Fire** when `_spitter_windup_active and now >= _spitter_windup_until`:
    - `_emit_projectiles_at(_spitter_aim_dir, 3, 0.22, 0.7)` for **SPITTER** (3-shot fan, ~13°/step ≈ 25° arc)
    - `_emit_projectiles_at(_spitter_aim_dir, 5, 0.18, 0.9)` for **ELITE_SPITTER** (heavy 5-shot fan)
    - `_spitter_windup_active = false`
- **Slow while winding up:** if `_spitter_windup_active`, scale the returned `desired_velocity` by **~0.35**
  (commit + readable + killable). Keep the existing approach/retreat split otherwise.
- elite_spitter's separate shockwave ability (L844-847) unchanged.

**② Scale-pulse tell** (`_update_visual_state`, L1264; sets `visual.scale`):
- Add a transient wind-up scale factor. While `_spitter_windup_active`, lerp a factor
  `1.0 → ~1.30` over the wind-up window (`(now - windup_start)/windup_len`) and multiply it into the
  `visual.scale` expression at L1274; snap back to 1.0 on fire. (Store `_spitter_windup_started_at` or derive
  from `_spitter_windup_until - len`.) This is the whole telegraph — no line drawn.

**③ Stats** (`_configure_type`, L305 / L355):
- `spitter`: `max_health 14 → 30`; `fire_interval 1.8 → 2.0`. (speed 350, dmg 4, proj_speed 380 unchanged.)
- `elite_spitter`: `fire_interval 0.8 → 2.2`. (HP 360, speed 320, dmg 8, proj_speed 470 unchanged.)

**Acceptance:** one spitter is dodgeable by reading the swell + sidestepping the fan; the elite reads as a
heavier telegraphed burst you close on, **not** a 0.8s stream; overlapping shooters stay readable; movement
split (approach flow / retreat raw) unchanged. Parse clean.

---

## Slice 2 — Global concurrent-shooter budget (`scripts/game/WaveDirector.gd`)

Bounds simultaneous bullet **sources** regardless of room/density. (`ARENA_*` etc. already in this file.)

- **Classify + cost:** `const SHOOTER_COST := { "spitter": 1, "elite_spitter": 2 }`; helper
  `func _shooter_cost(type: String) -> int: return int(SHOOTER_COST.get(type, 0))` (0 = not a shooter).
- **Budget:** `const SHOOTER_BUDGET_BASE := 6`; `func _shooter_budget() -> int: return SHOOTER_BUDGET_BASE + 2 * maxi(int(_coop.call("get_player_count")) - 1, 0)`.
- **Live counter:** `var _active_shooter_budget := 0`. Increment by `_shooter_cost(type)` in
  `spawn_enemy_instance` (L86) after a shooter spawns; **reset to 0 in `start_room`** (L37).
- **Decrement on death:** `CoopManager._on_enemy_died` (already the death hub) must tell WaveDirector to
  subtract the dead enemy's shooter cost. Add `WaveDirector.notify_enemy_removed(type)` and call it from the
  enemy-died path (the enemy exposes `get_type_name()`), decrementing `_active_shooter_budget` (clamp ≥ 0).
- **Enforce (overflow → melee):** wrap type selection so **every** spawn path (opening burst L79-82,
  continuous L152-155, burst L164-167) substitutes. Add:
  ```
  func _pick_spawn_type(pool) -> String:
      var t := _roll_wave_enemy_type(pool)
      var cost := _shooter_cost(t)
      if cost > 0 and _active_shooter_budget + cost > _shooter_budget():
          return _roll_melee_type(pool)   # pool filtered to non-shooters; fallback "chaser"
      return t
  ```
  `_roll_melee_type(pool)` = pick a random entry with `_shooter_cost == 0`; if none, return `"chaser"`.
  Route all three spawn loops + the opening burst through `_pick_spawn_type`.

**Acceptance:** with a spitter-heavy pool, on-screen shooters never exceed the budget (6 solo / 8 in 2P,
elites counting double); surplus arrives as room-appropriate melee; **total enemy count unchanged** vs before
the cap; counter returns to 0 across rooms (no leak). Parse clean; `entity_ramp` still ≥ 60 avg_fps (should
improve — fewer live projectiles).

---

## Slice 3 — `ranged_gauntlet` immediate data tweak (`data/room_archetypes.json`)

So the room plays as the intended positioning puzzle *now* (its bias has **no melee**, so overflow would fall
back to plain chaser). Small data-only change; the full curated redesign is later ([[v4-curated-rooms-plan]]).

- `ranged_gauntlet.enemy_bias`: `["spitter","spitter","elite_spitter"]` →
  `["spitter","spitter","elite_spitter","charger","chaser"]` (add on-theme melee harassment for the
  close-the-gap puzzle + gives overflow a themed melee pool).
- `ranged_gauntlet.density_profile`: `"normal"` → `"low"` (the shooters carry the threat, not raw count).

**Acceptance:** `ranged_gauntlet` reads as "close on a capped set of telegraphed shooters while melee harasses
you," not a bullet wall.

---

## Notes

- Canonical tree `D:\GameDev\Project_Twin_stick` on `v4/class-system`; **parallel Codex may edit — re-read
  before each edit.** See [[feedback-parallel-codex]].
- Order: **Slice 1 → 2 → 3.** Validate + commit per slice; **don't push unless asked.**
- All numbers are first-pass (locked via MC) and meant to be tuned in a playtest.
- Deferred (see [[v4-curated-rooms-plan]] / [[v4-enemy-tiers-plan]] out-of-scope): new ranged types
  (lobber/sniper), boss/swarm separation, LOS/cover.
