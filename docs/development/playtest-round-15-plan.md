# Playtest Round 15 — "Core feel" patch — Plan & Implementation (for Codex)

Self-contained Codex build doc for **Patch 1** of the Round-14 content vision: **tuning + manual aim +
the weapon roster + the Momentum/Flow system.** Work on `v3/main` in `D:\GameDev\Project_Twin_stick`
(main checkout, no new worktrees). Do not commit unless asked. **Baseline = Round 13 (commit
`3c37ec7`).** Design rationale + the wider vision live in `playtest-round-14-plan.md`.

> STATUS: **PLAN — ready to implement.** Scope = make the core feel good. **No new abilities, bosses,
> biomes, or enemy re-tuning** (those are later patches / post-playtest).

## Codex implementation rules (read first)
- **Stick to this plan. Do not invent assumptions. Do not silently deviate.** Flag unclear values
  before implementing.
- After implementation, **summarize anything unclear, skipped, or deviated.**
- Report your approach **before/with** implementation for the items marked **[REPORT]**.
- "Upgrade" is the player/doc word; "mutation" is code-only.
- Validate headless after each cluster (see Validation). Keep all output on `D:`.

---

## Cluster A — Data tuning (`data/*.json`)

**`data/weapons.json`:**
- **Cannon:** `fire_rate` `2.0` → **`1.5`**; `per_level.damage` `[40,55,70,85,100]` →
  **`[55,75,95,115,135]`**; **remove `pierce`** and **remove `knockback`**.
- **Shotgun:** `per_level.spread_degrees` `[18,17,16,15,14]` → **`[12,11,10,9,8]`**; **remove
  `knockback`** (the `150` from R13).
- **Railgun:** no change.
- **Add Beam** and **Add Boomerang** — new entries (see Cluster D for behavior; data fields below):
  - **Beam:** `projectile_kind` `"beam"`; stats `range 750`; `per_level.max_damage_per_second
    [120,140,160,180,200]`; `ramp_seconds 1.5`; `ramp_start_fraction 0.30`. (Continuous; ramp resets
    instantly on target change — see D.)
  - **Boomerang:** `projectile_kind` `"boomerang"`; stats `fire_rate 3.0`, `travel_distance 480`,
    `projectile_speed` (pick to match feel, ~700); `per_level.damage [16,20,24,29,34]`. Double-hits
    out + back; full stream.

**`data/abilities.json`:**
- **Overcharge:** `cooldown` `16` → **`12`**.
- **Dash:** `cooldown` `3.0` → **`1.5`**; **remove the dash-through damage** (see Player dash hit
  logic); i-frames/dash_speed/duration unchanged.

**`data/mutations.json`:**
- **Remove the `knockback` mutation** entirely.
- **Ricochet → Split:** repurpose `ricochet` — on projectile hit, **spawn 1 new projectile aimed at
  the nearest *other* enemy**; splits do **not** re-split. Update description; param e.g.
  `split_count: 1`. (R13 wall-bounce is removed — it failed against auto-aim.) See Cluster D for the
  `Projectile.gd` change.

---

## Cluster B — Manual aim (auto default + seamless override)

Today aiming is auto-only (`Player.gd` `_find_auto_target` / `_auto_attack_direction`; `aim_mode`
`auto`/`movement` in `PlayerConfig.gd`). Add a real manual override.

- **Input:** bind the already-defined-but-unbound `pX_aim_*` actions to the right stick
  (`JOY_AXIS_RIGHT_X/Y`) in the controller-default setup (mirror `Bootstrap.gd` ~753 where move/secondary/
  dash defaults are added). Compute an **`_aim_facing`** from the aim-stick vector when its magnitude
  **> 0.35** (deadzone).
- **Fire logic** (`Player.gd` `_physics_process`, ~364–372): if aim magnitude > deadzone →
  **manual**: `fire_direction = _aim_facing`, fire toward it (deflect-to-fire, continuous at weapon
  cadence, **no aim-assist**); else → **auto** (current nearest-target behavior).
- **KB+M:** auto + override, consistent with gamepad — auto by default; mouse movement / firing engages
  manual aim at the cursor and reverts to auto when idle.
- **Reticle:** when manual-aiming, draw a neon **directional line/arc** from the player toward
  `_aim_facing`, out to weapon range.
- **Abilities are NOT aimed by the stick:** Dash/Blink keep using the **movement** direction
  (`_move_facing`); only the "no movement input while aiming" edge case falls back to `_aim_facing`,
  else last facing. Placed/centered abilities unchanged.
- **Settings:** add a **"Manual only"** `aim_mode` (weapon fires *only* while aiming; no auto-fallback).
  Default = auto + override.
- **[REPORT]** how you wired the per-device aim input and the manual/auto fire branch.

---

## Cluster C — Momentum / Flow system (new)

A per-player flow meter that rewards aggressive, flawless play. Builds on the existing
`_kill_streak_progress` (`CoopManager.gd`).

- **Meter:** 4 tiers, **per-player**, **resets at room start.**
- **Build — kills per tier, cumulative (placeholder, to balance):** T1 = **10** kills, T2 = **+15**
  (25 total), T3 = **+20** (45 total), T4 = **+25** (70 total).
- **Tier buffs (ADDITIVE, UNCAPPED — stack with Overcharge/Root/mutations/levels):**
  | Tier | Move speed | Fire rate |
  |---|---|---|
  | T1 | +10% | +15% |
  | T2 | +20% | +30% |
  | T3 | +35% | +50% |
  | T4 | +50% | +75% |
- **Loss:** a **damaging** hit drops **2 tiers.** Hits **prevented** by dash i-frames / Shield /
  Barrier dome cost **nothing** (gate the drop on actual HP loss, not on hit attempts). **No idle
  decay.**
- **Feedback:** **4 tier pips** near each player's HUD card (`CoopManager` HUD build, near the
  combat indicator) + an **escalating player aura** (intensifies per tier; neon placeholder).
- **Do not cap** the resulting fire rate / move speed anywhere — additive, uncapped is intended.
- **[REPORT]** where you hooked momentum gain (kills) and loss (damage) and how the buffs feed into
  the existing move-speed / fire-rate calculations.

---

## Cluster D — New weapon behavior (`scripts/weapons/…`)

- **Beam (continuous, dwell-ramp):** a continuous beam along `_aim_facing` (manual) or toward the
  nearest target (auto), out to `range 750`. **Damage ramps per *held target*:** starts at
  `ramp_start_fraction` (0.30) of `max_damage_per_second`, ramps to max over `ramp_seconds` (1.5s)
  while on the **same** target; **resets instantly** when the beam leaves/swaps target. Apply damage as
  ticks (choose a tick rate; document it). Auto melts single targets; manual can sweep (sacrificing
  ramp). **[REPORT]** the tick model + how "same target" / reset is tracked.
- **Boomerang (returning, double-hit):** travels `travel_distance` (480) outward then **returns to the
  player**, dealing `damage` on enemies hit on **both** legs (don't double-hit the *same* enemy on the
  same leg). Full stream (no in-flight cap), `fire_rate 3.0`. Auto throws at nearest; manual aims the
  path.
- **Ricochet → Split** (`Projectile.gd`): on hit, if split charges remain, **spawn 1 projectile toward
  the nearest enemy that isn't the current target**; the spawned projectile does **not** split again.
  Remove the R13 wall-reflection path.
- Add icons for Beam/Boomerang (`IconFactory.gd`) so HUD/encyclopedia render them.

---

## Cluster E — Other tuning (`scripts/…`)

- `Player.move_speed` **488 → 560** (base; momentum adds on top).
- `ZoomCamera.zoom_max` **0.52 → 0.56** (zoom_min `0.45`, padding `(440,380)` unchanged).
- `Player.gd` player visual scale **`*1.5` → `*1.35`** (`_base_visual_scale`); **collision unchanged.**
- `Enemy.gd` `READABILITY_VISUAL_SCALE` **1.3 → 1.2** (collision already decoupled — leave it).
- `CoopManager._rebuild_floor_grid` (~771): set grid `Line2D` **`antialiased = true`** (flicker fix);
  small width bump optional.
- **Remove the boss off-screen indicator** (`CoopManager._update_boss_offscreen_indicator` +
  `_boss_offscreen_indicator` build/refs): at this zoom the arena is ~always on-screen, so it's noise.

---

## Out of scope (later patches / post-playtest)
- **Enemy re-tune** — ship current enemy values; hand-tune trash/elites (and bosses) **after playtest**
  against the stronger player. No enemy changes here.
- New abilities (Stance/Root, combat drone, Barrier dome), bosses/enemies, biomes — later patches.
- The arcade/score/heat layer and rubberhose art — parked.

---

## Suggested build order
1. **Cluster A** data tuning (lowest risk).
2. **Cluster E** other tuning.
3. **Cluster B** manual aim.
4. **Cluster D** Beam / Boomerang / split.
5. **Cluster C** momentum + pips.

Each cluster: implement → headless-validate → continue.

## Validation
- `git diff --check`
- Headless parse:
  `& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit`
- Headless boot: same exe with `--quit-after 1`
- **Manual playtest required** before this patch is treated as approved — especially to feel the
  manual aim, momentum flow, and the new weapons, and to drive the post-playtest enemy re-tune.

## Open items Codex must report
- Manual-aim per-device input wiring + the manual/auto fire branch.
- Momentum gain/loss hooks + how buffs feed the move-speed/fire-rate math (and that nothing caps it).
- Beam tick model + ramp/reset tracking; Boomerang double-hit handling.
- Anything unclear, skipped, or deviated, with the reason.
