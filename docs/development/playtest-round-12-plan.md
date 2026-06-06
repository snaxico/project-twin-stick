# Playtest Round 12 — Plan & Implementation (for Codex)

Single self-contained build doc for Round 12. Built collaboratively, point by point. Work on
`v3/main` in `D:\GameDev\Project_Twin_stick` (main checkout, no new worktrees). Do not commit unless
asked. **Round 11 (`05e9dbc`) is the implemented + tool-validated baseline.**

> STATUS: **IMPLEMENTED + TOOL-VALIDATED; MANUAL PLAYTEST STILL REQUIRED.**
> Theme: **tune & fix the existing game** (no new weapons/abilities content, no art-style change —
> those are explicitly the *next* and *last* steps, respectively). This round makes the current 5
> weapons / 9 abilities feel good, fixes the hard defects, and improves readability + 1P/2P balance.

## Codex implementation rules (read first)

Per `docs/process/solo-dev-rules.md`:

- **Stick to this plan. Do not invent assumptions. Do not silently deviate.** If a value or behavior
  is unclear, **flag it before implementing**.
- After implementation, **summarize anything unclear, skipped, or deviated**.
- Two items in this plan intentionally describe behavior without a full line-by-line spec and
  **require you to report your approach before/with the implementation**:
  1. **Mid-boss stutter** — investigate first, then fix (see "Mid-boss stutter").
  2. **Pulsar "teleport toward player" targeting** — the targeting change is described by intent +
     exact numbers, but the exact target-selection function is yours to propose; report it.
- "Upgrade" (Weapon + Effect + Attribute + Ability) is the player/doc word; "mutation" is code-only.
- Keep all output on `D:`. Validate headless after each cluster (see "Validation").

---

## Findings (from the Round-11 playtest)

- Arena still feels a little too small; not enough room to move; camera should zoom out more.
- Mid-boss has a stutter/slowdown. The perf harness shows **no** bad result — suspicion is that a
  boss *attack/moveset* (not raw entity count) causes the hitch.
- Reward-screen upgrade text isn't fully visible (Round-11 one-line ellipsize hides info). Wants more
  icons + an encyclopedia.
- Encounter Builder **setup menu**: starting-primary picker is useless (loadout already covers it);
  menu should expand to fit with **no scroll bars**; remove room-step, XP, and cheats.
- Rares still sometimes too few.
- Weapons need balancing: rename Scattergun → Shotgun (feels weak); Overcharge needs a buff; confirm
  Decoy HP; Cannon vs Rifle vs Railgun need differentiating.
- Scanline modifier still shows as "Minefield" on the map/arena choice screen.
- Scanline should be one vertical + one horizontal.
- Game is hard because of low space to move.
- Abilities need buffs (walked each).
- HP pickup needs tweaking.
- Charger elite is good. Pulsar is still very weak — easy to kite.
- Boss marker needs better visibility.
- Revive mechanic needs a HUD element.
- 1P/2P balance: enemies should **not** be weaker in 1P; instead **more enemies** in 2P (same HP/
  damage, so weapon interactions are identical regardless of player count).
- Player character needs better visibility.

Strategy agreed: **tune & fix this patch → new content next → art style last.**

---

## Decisions (locked, exact)

### Weapons — `data/weapons.json`

Roles (for context; the numbers below implement them):
- **Rifle** — all-rounder baseline; not best at anything, not worst; for players who don't specialize.
- **Rocket** — AoE crowd-clearer; dumb-fire; serviceable vs single targets so bosses don't feel bad.
- **Shotgun** — short-range brawler; closeness rewarded by more pellets landing.
- **Cannon** — anti-elite/boss heavy hitter; biggest per-hit damage; knockback visibly shoves
  survivors (elites/non-boss); bosses are push-immune but take the big damage.
- **Railgun** — line-clearer / reference weapon (others tuned toward it).

| Weapon | Field | Current | New |
|---|---|---|---|
| **Rifle** | — | — | **No change** |
| **Rocket** | `blast_damage_percent` | `0.7` | **`0.9`** |
| **Rocket** | `blast_radius` (per level) | `[90,102,114,126,138]` | **`[120,135,150,165,180]`** |
| **Rocket** | damage / fire_rate / speed / range | — | unchanged |
| **Shotgun** | `name` | `"Scattergun"` | **`"Shotgun"`** (keep `id` = `scattergun`) |
| **Shotgun** | `damage` (per pellet) | `8.0` | **`12.0`** |
| **Shotgun** | `knockback` | (none) | **add `150`** |
| **Shotgun** | range / pellet_count / spread / fire_rate / speed | — | unchanged |
| **Cannon** | `damage` (per level) | `[30,42,54,66,78]` | **`[40,55,70,85,100]`** |
| **Cannon** | `knockback` | `220.0` | **`320.0`** |
| **Cannon** | pierce / fire_rate / speed / range / area | — | unchanged |
| **Railgun** | — | — | **No change** |

- **Shotgun rename is display-only.** Change only the `name` field. The `id` stays `scattergun`
  everywhere (code refs, run state, sprite path `player_scattergun.png`). Players only ever see
  "Shotgun".
- **Cannon knockback** must be visible on **elites / non-boss survivors** (shove them). **Bosses are
  push-immune** — do not attempt to move stationary bosses; they just take the big per-hit damage. If
  current knockback application already exempts bosses, no extra work; if not, exempt boss types.

### Abilities — `data/abilities.json`

> **Decoy HP question (answered):** Decoy currently has `decoy_health: 120`. We are **removing** it
> (invincible for its duration) — see below.

Weakest-enemy reference for the "kills weakest" abilities: **Spitter 15, Chaser 20** (Chaser is the
most common trash), Splitter 25. `22` clears Chaser/Spitter with headroom for per-act HP scaling.

| Ability | Field | Current | New |
|---|---|---|---|
| **Shockwave** | `damage` | `15.0` | **`22.0`** (radius/knockback/cooldown unchanged) |
| **Dash** | — | — | **No change** |
| **Overcharge** | `fire_rate_multiplier` | `1.3` | **`1.5`** |
| **Overcharge** | `duration` | `4.0` | **`6.0`** (cooldown stays `22.0`) |
| **Blink** | `detonation_damage` | `12` | **`22`** (distance/iframes/radius/cooldown unchanged) |
| **Shield** | `cooldown` | `12.0` | **`9.0`** (duration `3.0` unchanged) |
| **Decoy** | `decoy_health` | `120` | **remove (invincible while active)** |
| **Decoy** | `duration` | `5.0` | **`3.0`** |
| **Decoy** | taunt | (none explicit) | **add taunt: enemies within ~`700px` retarget to the decoy while it is active** |
| **Decoy** | `invisibility_duration` / `cooldown` | `1.2` / `10.0` | unchanged |
| **Turret** | `damage` | `10` | **`18`** (45→81 DPS at 4.5/s; rest unchanged) |
| **Minefield** | — | — | **No change** |
| **Orbit** | `orbit_radius` | `84.0` | **`150.0`** (further from player) |
| **Orbit** | orb visual size | — | **×1.5 (bigger orbs)** |
| **Orbit** | projectile block | (none) | **add: an orb destroys an enemy projectile on contact** (partial rotating shield; gaps between orbs are intentional) |
| **Orbit** | orb_count / damage / rotation_speed / duration / cooldown | `3` / `9` / `2.6` / `5` / `12` | unchanged |

- **Decoy invincibility** (`DecoyNode.gd`): the decoy currently takes damage via `apply_damage` and
  `_expire()`s at 0 HP. Make it **invincible**: `apply_damage` becomes a no-op while `_alive` (or gate
  it behind an `invincible` flag set true when no `decoy_health` is configured). Expiry is driven
  **only by `lifetime`** (now `3.0`). Do **not** delete the death-blast path — see Volatile note.
- **Decoy taunt — explicit priority override** (`Enemy.gd` `_find_target`, ~589): today enemies pick
  the nearest node in the `player_target` group, and the decoy already joins that group, so it only
  distracts when it happens to be nearest. Add a **priority rule**: if a taunting decoy is within
  `taunt_radius` (`700px`) of the enemy, target that decoy **even if a player is closer** (override).
  Beyond `700px`, fall back to normal nearest-`player_target` selection (decoy still eligible as
  today). Implement by exposing the decoy as a taunt source (e.g. a `decoy_taunt` group or an
  `is_taunting()`/`taunt_radius` accessor on `DecoyNode`) and checking it first in `_find_target`. If
  multiple taunting decoys are in range, pick the nearest taunting decoy.
- **Decoy deals no damage (base) — Volatile rare unchanged:** base Decoy already deals no damage
  (`death_blast_damage = 0` → `_trigger_death_blast()` no-ops). The **Volatile Decoy** rare
  (`decoy_volatile`, `mutations.json`) sets `death_blast_damage`/`death_blast_radius` via `stats` and
  must keep exploding. Because the decoy is now invincible, the rare's explosion fires on the **3s
  timeout** (via `_expire`) rather than on death — keep `_expire` calling `_trigger_death_blast()` so
  this still works. Do **not** change the rare's numbers.
- **Orbit block:** reuse the existing nearby-projectile / enemy-projectile handling; an orb body
  touching an enemy projectile despawns that projectile. Do **not** make it a full ring barrier — the
  gaps between the 3 orbs are part of the balance.

### Economy / Difficulty

- **Rares** (`RunState` / `MutationSystem` rare odds + pity):
  - Act 1 `15%` → **`20%`**
  - Act 2 `25%` → **`30%`**
  - Endless `35%` → **`40%`**
  - Per-player pity: forced rare after `4` dry pick rounds → **`3`**.
- **HP pickup:** heal `5` → **`10`** per pickup; drop chance stays `10%`; magnet behavior unchanged.
- **2P enemy COUNT scaling (×1.5):** in 2-player runs only, multiply enemy **count** by **1.5**.
  Enemy **HP and damage are identical to 1P** (so all weapon breakpoints / one-shots are unchanged
  regardless of player count). 1P is the baseline and is unchanged.
  - **Define one multiplier:** `var p2_count_mult := 1.5 if active_player_count >= 2 else 1.0`
    (derive from the real active-player count, not the lobby max).
  - **Exact mechanism (avoid the rounding/cadence double-count trap):**
    - **Cadence is NOT scaled.** Do **not** touch `_spawn_interval`, `_next_spawn_at`, `_burst_interval`,
      or any ramp. Scaling both count and cadence would compound to ~2.25× — only **count** scales.
    - **Stream pulse** (`_continuous_spawn`, the `batch` loop ~1143, normally `batch = 1`): use a
      **fractional spawn accumulator** so the average is exactly ×1.5 without per-pulse rounding to 2
      (which would be 2×). Each pulse: `_spawn_accum += base_batch * p2_count_mult`;
      `spawn_n = int(floor(_spawn_accum))`; `_spawn_accum -= spawn_n`; spawn `spawn_n` this pulse.
      With `base_batch = 1`, `mult = 1.5` this yields the 1,2,1,2… pattern = 1.5 avg. (Reset the
      accumulator at room start. Swarm's `batch = 2` multiplies the same way.)
    - **Opening burst + periodic burst** (`_spawn_opening_burst` ~1162, burst block ~1150): these are
      already large integers, so apply `burst_size = int(round(burst_size * p2_count_mult))` —
      rounding error is negligible at these sizes. Opening 6–8 → **9–12**.
  - **Scope = base room spawns + boss/elite add-waves** (your decision):
    - Scale: opening burst, stream pulses, periodic bursts, **elite add-waves**, and the **generic
      boss add-wave budget** for normal boss rooms. Raise that boss-room non-boss cap `25` → **`38`**
      in 2P (keep `25` in 1P).
    - **Do NOT scale boss-attack-driven minion spawns** (e.g. Hive target-position pressure adds and
      Pulsar phase minions emitted from `Enemy.gd`). Those stay at 1P counts.
    - **Codex:** confirm whether the generic boss add-wave path and the boss-specific minion calls
      share a function; if entangled, **flag it** before scaling so we don't accidentally scale the
      boss-specific minions. Report which paths you scaled.
  - **Only count scales.** Do not touch enemy HP, contact/projectile damage, or per-act
    `health_multiplier` for player count.

### Systems / Feel

- **Arena bigger:** `CoopManager.ARENA_SIZE` `(3000,1700)` → **`(3600,2100)`**. As in Round 11, change
  **only `ARENA_SIZE`** first; most logic cascades from `ARENA_RECT`/`ARENA_SIZE`. Do **not** pre-scale
  gameplay-distance constants — measure in play and change specific ones **only with approval**. Also
  update the hardcoded fallback `Rect2(... 4800, 2700)` literals in `Enemy.gd`
  (`_find_pulsar_teleport_position` ~1015 and the other ~911) so the fallback matches the real arena
  (they're only used if `_combat_owner` is missing, but keep them consistent).
- **Camera zoom out** (`ZoomCamera.gd`): `zoom_min` `0.60` → **`0.45`**, `zoom_max` `0.80` → **`0.65`**.
  Leave `padding` at `(160,140)` unchanged. (Lower zoom = more zoomed out / more visible space. This
  pairs with the bigger player chevron below so the player stays readable.)
- **Pulsar (aggressive anti-kite buff)** — `Enemy.gd` `_update_pulsar_behavior` / helpers:
  - **Teleport toward the player to cut off escape** instead of a random arena spot. Replace the
    random pick in `_find_pulsar_teleport_position` with a position **near the player** (e.g. within
    ~`350–500px` of a player, biased to reposition onto/ahead of them). **Codex: propose the exact
    target-selection and report it** (no-assumptions rule). Keep it inside arena margins; keep a
    minimum hop so it doesn't teleport on top of the player.
  - Teleport interval: `_get_pulsar_teleport_interval` `lerp(8.0, 6.0, phase)` →
    **`lerp(5.0, 3.5, phase)`**.
  - Teleport telegraph: `_start_pulsar_telegraph` window `0.8s` → **`0.5s`**.
  - Minion spawn interval (`_next_spawn_at`): `9.0 / 6.0` → **`7.0 / 4.5`**.
  - Leading attacks: the player-position hazard/lead currently only triggers at `phase >= 0.75`.
    **Apply leading attacks at all phases** (so it pressures the player's position throughout the
    fight, not just phase 3). Keep telegraph/tell timings intact.
  - EMP cadence and beam helpers otherwise unchanged unless the above isn't enough (playtest).
- **Mid-boss stutter (investigate, then fix):**
  - The perf harness reuses the same effects every frame, so first-use cold-loads never show up. The
    leading hypothesis is **first-time instantiation / shader compile / resource load** the first time
    each boss attack type fires (matches "any moveset stutters, perf test clean"); hit-stop
    (`HitStopManager`, the sole `Engine.time_scale` owner) is a secondary suspect.
  - **Required instrumentation FIRST (before any fix).** `PerfRunner.gd`'s `_Profiler` currently only
    sums `avg_fps` / `min_fps` over the window (`PerfRunner.gd:111`), which cannot see a one-frame
    hitch. Add:
    - **Per-frame max frame time (ms):** track `_frame_ms_max = max(_frame_ms_max, delta * 1000.0)`
      (and/or `TIME_PROCESS + TIME_PHYSICS_PROCESS`); emit it in the CSV row.
    - **Worst-frame log:** print the worst N (~10) frame times with their timestamp so spikes are
      visible, not averaged away.
    - **Attack markers:** have the boss print/emit a marker when each attack type **first** fires
      (attack name + that frame's ms), so a spike can be attributed to a specific moveset's first use.
    - **Boss profiles to run:** profile **each boss type** the mid-boss can be — run `boss:warden`,
      `boss:hydra`, `boss:hive`, `boss:pulsar` (mid-boss is randomly assigned, so don't assume one).
      Run non-headless (headless reports 0 draw calls).
  - **Pass/fail criteria:** no single frame should exceed **~33 ms** (≈ a 2-frame hitch at 60 FPS)
    attributable to a boss attack's **first** activation; after the fix, the max frame time during the
    first cycle of each attack should be within normal per-frame variance (no outlier tied to an
    attack marker).
  - **Then fix.** Most likely: **pre-warm boss VFX/telegraph/projectile scenes at room start** so first
    use isn't a cold load. **Report the measured root cause and the fix before/with implementation.**
    Do not guess-patch a fix that doesn't match a measured spike.

### Modifiers

- **Scanline name bug:** the display name is derived from the `mine_field` id (split on `_` +
  capitalize → "Mine Field"). Fix both call sites to read the real `name` ("Scanline") from
  `data/modifiers.json` by id, falling back to the capitalized id only if missing:
  - `RunFlow._format_modifier_name` (route/map choice cards, ~280)
  - `CoopManager._format_modifier_display_name` (in-arena modifier chip, ~2187)
  - Check `RunState` (~849) for the same id-derived pattern and fix if it feeds any displayed name.
- **Scanline pattern (one vertical + one horizontal):** `MineFieldModifier.gd` — keep the current
  cadence (`_spawn_at` 8.0–9.5s) and `MAX_ACTIVE_SWEEPS = 2`, but **guarantee the two active sweeps
  are always one vertical (`left`/`right`) + one horizontal (`top`/`bottom`)** — never two on the same
  axis. Replace the 4-direction round-robin (`_direction_index`) with: when spawning, pick a direction
  on whichever axis is **not** currently active.

### UI / HUD

- **Reward cards + selected-card detail panel** (`MutationPickUI.gd`, ~269): cards show **icon + short
  label** (clean, scannable), but the reward screen **is the decision surface**, so it must show full
  context for the card being chosen. Add a **selected-card detail panel** on the reward screen: the
  currently focused/highlighted card's **full description** (and rarity/level/group) renders in a
  dedicated detail area. Cards stay compact; the highlighted one is always fully explained, with no
  need to leave the pick flow. (This replaces relying on the Round-11 one-line ellipsize for context.)
  Per-player: each player's detail panel reflects their own focused card.
- **Encyclopedia / codex (new):** a browsable reference covering **weapons, abilities, mutations, and
  enemies**, opened from the **main menu** and the **in-run pause screen**. Source entries from the
  existing data (`weapons.json`, `abilities.json`, `mutations.json`) and the enemy catalog. This is
  the largest new build in the round — implement as its own slice. (The encyclopedia is for browsing
  anytime; the in-pick context need is met by the selected-card detail panel above, so the
  encyclopedia does **not** need to open from the reward screen.)
- **Boss off-screen marker:** replace/upgrade the Round-11 edge indicator with a **large pulsing edge
  arrow**, boss-colored, shown only while the boss is off-screen. Bigger + animated for visibility at
  the new zoom-out (bosses go off-screen more often at `0.45–0.65`).
- **Player visibility:** increase the player chevron base scale by **×1.3** (`Player.gd`
  `_base_visual_scale` / `_apply_visual_state`). Keep colors/bloom as-is.
- **Revive HUD:** surface the existing revive system (`Player._is_downed`, `CoopManager._update_revives`,
  `REVIVE_HOLD_DURATION = 1.2`). Add a **"DOWNED" marker** on the downed player and a **radial
  hold-progress ring** that fills `0→1` over the 1.2s revive hold (drive it from
  `_revive_progress_by_player_id`). Note: revive is 2P-only by design; in 1P there is no reviver, so
  this HUD is primarily a 2P element.

### Encounter Builder (setup menu — `Bootstrap.gd`)

Remove from the encounter-builder setup menu (all under
`$MenuPanel/MarginContainer/MenuScroll/MenuLayout`):
- `DebugPrimaryRow` (starting-primary weapon picker) — redundant with the loadout.
- `DebugStepRow` / `DebugStepSpinBox` (room-step spinbox).
- Starting **level** + starting **XP** cheat spinboxes (`_debug_start_level_spinbox`,
  `_debug_start_xp_spinbox`).
- `LaunchCheatRow` (launch cheats).

**Keep** (the builder's purpose): player count, room type, boss type (when room = boss), objective
(when room = combat), modifiers, layout, and the perf launcher.

**Layout:** rebuild so all remaining rows fit **without `MenuScroll`** (no scrollbar) — size the panel
to its content / drop the scroll dependency.

> This is the **setup menu** only. The **in-room debug overlay** tools (spawn roster, live P1 weapon
> selector, clear-enemies, god mode, weapon-level) are **not** in scope here and stay as-is.

---

## Out of scope (deferred by decision)

- **New content** (new weapons / abilities / projectiles / effects) — the "big design session" is the
  **next** round, on top of this tuned foundation.
- **Art-style change** — explicitly **last**, after mechanics + content are stable.
- **MultiMesh enemies** — still deferred (Round-11 real-room perf was fine; only the synthetic
  200+200 ramp dips, and that's the known per-node ceiling).
- **1P self-revive / extra lives** — not added; 1P stays baseline difficulty with going-down = game
  over solo.

---

## Suggested build order (clusters)

1. **Data tuning** (lowest risk): `weapons.json` (Rocket, Shotgun, Cannon, rename), `abilities.json`
   (Shockwave, Overcharge, Blink, Shield, Turret, Decoy, Orbit), rare odds/pity, HP-pickup heal.
2. **Decoy + Orbit behavior** (taunt; invincible decoy; orb projectile-block).
3. **Arena + camera** (`ARENA_SIZE`, `ZoomCamera` zoom; player chevron ×1.3).
4. **2P enemy-count ×1.5** (accumulator for stream pulses, round() for bursts; cadence unchanged;
   scope = room spawns + boss/elite add-waves; boss-cap 25→38).
5. **Scanline** (name-bug fix + vertical/horizontal pattern).
6. **Pulsar aggressive buff** (report teleport-target approach).
7. **Mid-boss stutter** (investigate → fix; report findings).
8. **HUD/UI:** boss marker, revive HUD, reward-card icons + selected-card detail panel.
9. **Encyclopedia** (own slice).
10. **Encounter Builder setup-menu cleanup** (remove rows + no-scrollbar layout).

Each cluster: implement → headless-validate → continue. Do not treat a broken intermediate state as
done.

---

## Validation

- `git diff --check`
- Headless parse:
  `& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit`
- Headless boot: same exe with `--quit-after 1`
- Perf (non-headless, for the stutter cluster): use the **Perf Runner** / `entity_ramp` and a real
  `boss:` profile; remember headless reports `0` draw calls (don't use it for render/stutter profiling).
- **Manual playtest is required before this round is treated as approved/stable.**

---

## Open items Codex must report after implementation

- The exact **Pulsar teleport-target** selection it implemented.
- The **mid-boss stutter** root cause it measured (per-frame max + attack markers) and the fix applied
  (and whether the cold-load hypothesis held).
- The **2P spawn paths** it scaled, and confirmation that boss-attack-driven minion spawns were left
  unscaled (flag if the generic boss add-wave and boss-specific minion calls share a function).
- Anything **unclear, skipped, or deviated** from this plan, with the reason.
- Any gameplay-distance constant it believes needs scaling for the bigger arena (list only — do **not**
  change without sign-off).

---

## Implementation Report

### Pulsar teleport-target selection

Implemented target selection picks the farthest living player from Pulsar as the kite target. If that
target is a `CharacterBody2D` moving faster than `40 px/s`, Pulsar projects ahead along the target
velocity; otherwise it projects from Pulsar toward the target. The candidate position is:

- `target.global_position + ahead_direction * randf_range(350, 500)`
- plus perpendicular jitter in `[-120, 120]`
- clamped to the arena margin
- accepted only if it satisfies the existing `PULSAR_TELEPORT_MIN_DISTANCE`; otherwise Pulsar falls
  back to the existing random arena-position search.

### Mid-boss stutter measurement and fix

Instrumentation was added before fixing: `PerfRunner` now reports `max_frame_ms` plus the top ten
worst frames, and boss attacks print first-use `attack_marker` rows while debug profiling is enabled.

Follow-up review found the original prewarm was incomplete: it instantiated samples off-screen with
`visible = false`, which can warm scene/resource allocation but does not force CanvasItem draw/shader
paths. Fresh profiling with that old prewarm still showed first-use/stale-monitor spikes:

- `boss:warden --players=2 --build=heavy`: worst sampled frame `88.110 ms`; Warden minion/charge
  monitor estimate `37.739 ms`
- `boss:hydra --players=2 --build=heavy`: max frame `38.749 ms`; aimed/sweep/minion monitor
  estimate `38.749 ms`
- `boss:hive --players=2 --build=heavy`: sampled max `14.423 ms`, but first deflector monitor
  estimate `38.719 ms`
- `boss:pulsar --players=2 --build=heavy`: sampled max `22.111 ms`, but shockwave/minion monitor
  estimate `36.435 ms`

Fix applied: room start now prewarms representative combat VFX, larger boss telegraph/shockwave
rings, hazard/poison hazard visuals, screen flash, one projectile, projectile trail, and common
boss-minion enemy visuals as visible low-alpha samples on-screen for a rendered frame before freeing
them. `PerfRunner` worst-frame ranking now uses actual frame delta (`delta * 1000`) while keeping
process/physics monitor values as separate averages; the previous `max(delta, process+physics)` mixed
in stale monitor values at the warmup/sample boundary.

Final non-headless heavy 2P profiles after the fix:

- `boss:warden --players=2 --build=heavy`: max frame `23.144 ms`; Warden attack markers at or below
  `17.240 ms`
- `boss:hydra --players=2 --build=heavy`: max frame `13.507 ms`
- `boss:hive --players=2 --build=heavy`: max frame `5.643 ms`
- `boss:pulsar --players=2 --build=heavy`: max frame `12.925 ms`

Note: boss attack-marker rows still print process+physics monitor estimates, which can overstate the
attack frame because Godot's monitor value may lag the actual frame delta. The authoritative stutter
metric for this round is `max_frame_ms`.

### 2P enemy-count scaling scope

Scaled in 2P:

- opening burst
- periodic burst
- continuous stream pulses, using an accumulator so cadence remains unchanged
- generic elite add-waves
- generic boss add-waves
- generic boss add cap from `25` to `38`
- multiplier is keyed off configured player count, not currently alive players, so it does not drop
  to 1P pacing while a teammate is downed

Left unscaled as requested:

- boss-attack-driven minion calls in `Enemy.gd`, including Hive pressure/minion mixes and Pulsar
  minions.

### Unclear, skipped, or deviated

- No intended gameplay deviation. Encounter Builder still uses the existing `MenuScroll` node path,
  but scrollbars are disabled and removed controls are no longer constructed/used; this avoids a
  larger scene-path rewrite while satisfying the no-scrollbar requirement.
- Bosses are intentionally immune to all knockback, including Shockwave, so boss attack tells and
  arena positioning cannot be displaced by player control effects. They still take damage.
- Manual playtest remains required before the round is approved/stable.

### Bigger-arena constants to watch, not changed

- revive radius
- pickup/orb collection radius
- player ability radii
- boss/player projectile ranges
- enemy leash/targeting distances
- side-objective spawn and hold-zone distances
