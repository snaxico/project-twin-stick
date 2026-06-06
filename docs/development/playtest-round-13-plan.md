# Playtest Round 13 — Plan & Implementation (for Codex)

Single self-contained build doc for Round 13. Built collaboratively, point by point. Work on
`v3/main` in `D:\GameDev\Project_Twin_stick` (main checkout, no new worktrees). Do not commit unless
asked.

> STATUS: **PLAN ONLY — NOT YET IMPLEMENTED.**
> **Baseline = the Round 12 implementation currently in the working tree** (weapon/ability rebalance,
> 2P count scaling, arena 3600×2100, zoom 0.45–0.65, Scanline/Decoy/Orbit/Pulsar changes, prewarm,
> PerfRunner worst-frame instrumentation, encyclopedia, revive HUD, Encounter Builder cleanup). Round
> 13 builds on top of that.
> Theme: **tune & fix from the Round-12 playtest** (camera/scale, ability tuning, two weapon-mutation
> reworks, the recurring boss-room problem, revive/reward UX, perf). Still no new-content design pass,
> no art-style change.

## Codex implementation rules (read first)

Per `docs/process/solo-dev-rules.md`:
- **Stick to this plan. Do not invent assumptions. Do not silently deviate.** Flag unclear values
  before implementing.
- After implementation, **summarize anything unclear, skipped, or deviated.**
- Items that intentionally need you to **report your approach before/with implementation**:
  1. **Boss-in-normal-room** restructure (room-flow change — reconcile with existing boss-add-waves).
  2. **Boss screen-shake FPS** — investigate first, then fix the measured cause.
  3. **Railgun unlimited pierce** + **Ricochet wall-bounce** — report how you represented each given the
     current `Projectile.gd` pierce/ricochet handling.
- "Upgrade" is the player/doc word; "mutation" is code-only.
- Validate headless after each cluster (see "Validation"). Keep all output on `D:`.

---

## Findings (Round-12 playtest)

- Zoom out more + increase player/enemy scale.
- Camera zooms out too late — players are on the screen edge when the zoom-out starts.
- Reduce Overcharge cooldown.
- Ricochet makes Railgun redundant — needs rework.
- Ice zone shouldn't stack the slow effect.
- Shockwave Resonance pulses are too close together — needs rework.
- 2P reward: can't go back after a wrong choice; while any player hasn't confirmed, all should still
  be able to switch.
- Boss arena too easy (recurring) — consider putting the boss in a normal fight, spawned later.
- Encyclopedia: add how long an ability stays active.
- Revive should have a bigger trigger radius.
- Boss screen shake appears to lower FPS — check performance specifically there.
- Boss marker should only appear when the boss is off-screen.

---

## Decisions (locked, exact)

### A. Camera & scale

> Note: at `zoom_min 0.45` the camera already shows the entire 3600×2100 arena (full-fit ≈ 0.51), so
> "zoom out more" is **not** a lower `zoom_min` (that only reveals void outside the walls). The fix is
> to widen **earlier** (bigger padding), use a **wider baseline** when players are close (lower
> `zoom_max`), and make **sprites bigger** so the wider view stays readable.

- **`ZoomCamera.gd`:** `padding` `(160,140)` → **`(440,380)`**; `zoom_max` `0.65` → **`0.52`**;
  `zoom_min` stays **`0.45`**.
- **Player sprite scale** (`Player.gd` `_base_visual_scale` / shadow, currently `* 1.3`): → **`* 1.5`**
  (visual + shadow).
- **Enemy sprite scale:** apply **`× 1.3`** to the enemy visual/body scale at init (mirror the Player
  chevron approach in `Enemy.gd`; scale the visual + shadow, not collision). Apply to all enemy types
  including elites/bosses unless a boss already sets its own scale — if so, leave boss scale and only
  flag it.

### B. Tuning & reworks

- **Overcharge cooldown** (`data/abilities.json`): `22.0` → **`16.0`** (fire-rate 1.5× / 6s duration
  unchanged from R12).
- **Shockwave Resonance** (`data/mutations.json` `sw_resonance`): keep "2 extra pulses," widen the
  per-pulse stagger **`0.15s` → `0.4s`** (update the stagger param and the description text to match).
- **Ice zone — no stacking** (`IceZoneModifier.gd`): today each patch calls
  `apply_zone_modifier(patch_id, 0.5, 1.0)` with a unique `patch_id`, so overlapping patches stack the
  slow. Fix: apply a **single shared slow per player** (one fixed key, e.g. `"ice_zone"`, factor
  `0.5`) whenever the player is inside **any** patch; clear it when in none. Standing in 1 or N patches
  = the same single 0.5 slow. Do not multiply.
- **Railgun — unlimited pierce** (`data/weapons.json` + `Projectile.gd`): pierce should hit **every
  enemy in the straight line** (remove the `[3,3,4,4,5]` cap). Represent unlimited pierce cleanly given
  current pierce handling — e.g. an `infinite_pierce`/never-decrement flag, or a sentinel large value.
  **Keep damage `[16,22,28,34,40]` unchanged.** Railgun's identity = the aimed line (positioning).
  **Report which representation you used.**
- **Ricochet — bounce off WALLS, not enemies** (`data/mutations.json` `ricochet` + `Projectile.gd`):
  - Redefine: projectiles **reflect off the arena walls** and keep traveling, **2 bounces**, instead
    of seeking a nearby enemy.
  - `mutations.json`: update description to wall-bounce; set bounce count to **2**; the
    enemy-seek `bounce_range` param is no longer used (remove or leave unused).
  - `Projectile.gd`: replace the enemy-seeking `_redirect_to_ricochet_target` path with
    **wall reflection** — when the projectile reaches the arena bounds (from
    `combat_owner.get_arena_rect()`), reflect its velocity across the hit wall normal, decrement the
    bounce counter; expire normally when bounces are used up. Pierce is unaffected (pierce continues
    after a bounce).
  - **Interaction:** Railgun (unlimited pierce) + Ricochet = pierce the aimed line, **bank off a wall,
    keep piercing** a new line. Orthogonal axes — pierce = enemies-per-line, ricochet = bounces off
    geometry. No enemy-targeting/end-of-life logic. **Report how you handled the reflect + pierce
    composition.**

### C. Boss encounter — boss in a normal fight, spawned later (recurring "too easy" fix)

Replace the dedicated empty boss arena with a **normal combat room that spawns the boss partway
through**, so the boss is fought amid continuous adds.

- **Trigger:** boss spawns once at **`_room_elapsed >= 25.0s`** (add `const BOSS_SPAWN_DELAY := 25.0`).
- **During the room:** run the **normal continuous spawn** (stream + bursts) for the whole room so adds
  keep coming before and after the boss appears.
- **Room clear:** the room ends **only when the boss is dead** (not when `_enemy_nodes` is empty). Adds
  keep spawning until the boss dies.
- **Reconcile with existing boss systems (report):** the current separate boss flow uses
  `_spawn_boss`, boss-add-waves (`_update_boss_add_waves`, `BOSS_ADD_CAP`), and the `"boss"` room type.
  With continuous spawn now providing adds, the **boss-add-wave system is likely redundant** — Codex
  should decide whether to disable boss-add-waves (preferred, to avoid double-spawning) or keep them,
  and **report the choice**. Keep boss intro/telegraph, boss HUD, and the off-screen marker working.
- Keep the **2P count scaling** behavior intact in these rooms (it already applies to room spawns).
- This is the biggest structural change — implement it as its own cluster and validate carefully.

### D. Revive

- **`CoopManager.REVIVE_RADIUS`** `96.0` → **`150.0`** (`REVIVE_HOLD_DURATION 1.2` unchanged).

### E. 2P reward screen — switchable until all confirm

- **Rule:** the pick round **finalizes only when ALL players have confirmed.** While any player is
  unconfirmed, every player (including ones who already confirmed) can still change their selection.
- **Un-confirm interaction:** a confirmed player presses **back/cancel (`ui_cancel`)** to un-confirm
  and re-pick.
- **`MutationPickUI.gd`:** do not apply/close on a single player's confirm; gate finalize on
  `all(_confirmed)`. Allow `ui_cancel` to clear that player's `_confirmed`/`_locked_selection_ids` and
  re-enable navigation. The selected-card detail panel (R12) should reflect the re-opened state.

### F. UI / Encyclopedia

- **Encyclopedia ability duration** (`EncyclopediaUI.gd`): for ability entries, show **how long the
  ability is active** (the `duration` field) alongside cooldown — e.g. "Active: 6s · Cooldown: 16s".
  For instant/0-duration abilities show "Instant".
- **Boss marker only when fully off-screen** (`CoopManager._update_boss_offscreen_indicator`): today it
  hides when the boss **center** is on-screen, so a large boss whose body is visible at the edge (center
  just off-screen) still shows the marker. Fix: treat the boss as on-screen (hide the marker) when it
  is within the viewport **inflated by a margin** (~the boss visual radius, e.g. `140px`), so the marker
  only appears once the boss is genuinely off-screen.

### G. Performance — boss screen-shake FPS

- **Investigate first, then fix** (like the R12 stutter): profile a boss fight **specifically during
  screen shake** using the R12 worst-frame / attack-marker instrumentation (`PerfRunner.gd`). Determine
  whether the shake itself, or something firing alongside it, causes the drop. Then fix the measured
  cause (e.g. throttle a per-frame allocation, cache the shake offset, or reduce shake cost). **Report
  findings before/with the fix.** Do not blind-reduce shake without measuring.

---

## Out of scope (deferred)

- New content (new weapons/abilities/effects) — still the *next* round.
- Art-style change — still *last*.
- Lower `zoom_min` past arena-fit (would only show void).

---

## Suggested build order (clusters)

1. **Data tuning:** Overcharge CD 16; Railgun pierce; Ricochet params; Shockwave Resonance stagger;
   revive radius. (`abilities.json`, `weapons.json`, `mutations.json`, `CoopManager` const)
2. **Camera & scale:** `ZoomCamera` padding/zoom_max; player ×1.5; enemy ×1.3.
3. **Ricochet wall-bounce + Railgun unlimited pierce** (`Projectile.gd`) — report representations.
4. **Ice zone no-stack** (`IceZoneModifier.gd`).
5. **2P reward switchable-until-all-confirm** (`MutationPickUI.gd`).
6. **Encyclopedia duration + boss-marker margin** (`EncyclopediaUI.gd`, `CoopManager`).
7. **Boss-in-normal-room restructure** (own cluster; report add-wave reconciliation).
8. **Boss screen-shake perf** (investigate → fix; report findings).

Each cluster: implement → headless-validate → continue.

---

## Validation

- `git diff --check`
- Headless parse:
  `& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit`
- Headless boot: same exe with `--quit-after 1`
- Perf (non-headless) for the screen-shake cluster: run a real `boss:` profile and read the worst-frame
  / attack-marker output (headless reports 0 draw calls — don't use it for render profiling).
- **Manual playtest required before this round is treated as approved/stable.**

---

## Open items Codex must report after implementation

- Railgun unlimited-pierce representation and Ricochet wall-reflection/pierce composition.
- Boss-in-normal-room: whether boss-add-waves were disabled or kept, and how room-clear now keys off
  boss death.
- Boss screen-shake measured cause and the fix applied.
- Enemy sprite scaling: whether any boss/elite already sets its own scale (left as-is if so).
- Anything unclear, skipped, or deviated, with the reason.
