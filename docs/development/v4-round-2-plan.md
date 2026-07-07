# V4 Round 2 — Playtest Fixes & Rebalance (plan)

> Follows the polish round (`038dcc1`). From playtest feedback on that build. Branch `v4/class-system`, active
> checkout `D:\GameDev\Project_Twin_stick`. Validation gate (per slice):
> ```powershell
> $GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' --quit                                                 # parse
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=champion:hive --players=2 --build=heavy   # perf
> ```
> **Decisions (2026-07-06):** rooms = **hybrid curated templates + variation**; element mutations = **gate by
> delivery + dedupe element**; balance thrust = **rein in the player, harden threats** (coordinated pass).
> **Slice 3 balance numbers are LOCKED with the user (2026-07-06).**

---

## Slice 1 — Performance (the lag reports)

**① `_apply_separation()` O(n²) blowup** (`scripts/enemies/Enemy.gd`) — **✅ DONE** (shipped `3202b81` "bound
enemy separation in clustered swarms"). Clustered check went from **100 enemies @ 3.5 fps → 144 fps** (150 @
144, 200 @ 119). *Residual (current-state Known Risks): a fully-overlapped 200-enemy cluster still shows a low
instantaneous monitor reading — watch dense real rooms for residual physics-overlap cost.*

**② Projectiles** (`ProjectileSystem.gd` / `Projectile.gd`) — many spitters + shots still lag. Confirm enemy
projectiles are **pooled** and honor `MAX_ACTIVE_PROJECTILES`; the projectile-persistence change (Slice 2) must
**not** let count grow unbounded — arena-bound despawn is the backstop.

**③ Summon cap** (`CoopManager.gd`) — summon spam + Controller-ult lag. Add a **hard cap on total active
summons** (~5) regardless of recast/Legion/Overload; drop the oldest when exceeded. Cheapen construct
per-frame work if profiling points at it.

**Acceptance:** PerfRunner `--build=heavy --players=2` holds ~60fps in a packed cluster + summon-spam + firestorm
of spitters; no single-digit-FPS cluster case.

---

## Slice 2 — Bug fixes

- **Ultimates constantly available** (`UltimateCharge.gd`) — density made kills cheap. Cut rates to **~1/room**:
  `KILL_CHARGE 0.05 → 0.02`, `DAMAGE_CHARGE_RATE 0.0018 → 0.0012`, `CHAMPION_KILL_CHARGE 0.30 → 0.20`. (Tune to
  ~40–50 basic kills = full.)
- **Enemy projectiles despawn by distance** (`Projectile.gd`) — enemy projectiles already skip lifetime but die
  at `max_distance` (L246). **Enemy projectiles should persist until they hit a wall / player / summon**, not a
  range. Ignore `max_distance` for `team == "enemy"`; **ensure an arena-bounds despawn** (so off-screen shots
  don't accumulate — required for perf). Verify wall + player + deployable collision all despawn.
- **Momentum HUD on every class** (`GameHud.gd`) — momentum pips are built ungated for all cards. **Make the
  bottom-card indicator class-specific:** Mobile = Momentum pips; Risk = **Heat bar**; Tank = **Overshield bar**;
  Controller = **Radiance indicator** (aura active / deployable count). Drop the momentum pips for non-Mobile.
- **Controller ult "shielded minions on the right"** — **cause NOT yet identified; repro needed** (my earlier
  root-cause was wrong). Verified what it is **not**: `_reinforce_deployables` (`CoopManager.gd`) only **heals**
  existing deployables (no shield) and runs **before** the constructs spawn; and **`aegis` / `shield_amount` has
  no implementation** — it's a **dead, data-only mutation** (grep finds it only in `data/mutations.json`). So
  the "shield blob" is a mis-read visual; likely candidates: the reinforce shockwave-ring / glint VFX, an Orbit
  deployable's ring, or the overload constructs' own look. **Do:** repro (Controller → cast Overload Grid → note
  what the blob actually is), then give Overload constructs a clear **overcharged** read. **Separate item:**
  `aegis` is dead data — implement its deployable-shield or drop it (cleanup).
- **Element tag gating — CONCRETE** (`data/mutations.json` + `MutationSystem.gd` offer filter). Two changes:
  1. **Delivery gate:** set `fire_trail` / `freeze_shot` / `poison` `requires: [] → ["projectile"]` (mirrors
     `ricochet` / `piercing_rounds`, which already gate on `projectile`). This alone excludes the flamethrower
     (`cone`) + beam / whirlwind (`melee`) / arc_wand (`chain`) — fixes "Fire Bullets on flamethrower."
  2. **Same-element dedupe** in the offer filter: skip an element mutation if the equipped weapon already carries
     that element tag.
  ⚠ **Tradeoff (playtest watch-item):** non-projectile weapons (beam/whirlwind/arc_wand/flamethrower) then get
  **no** elemental on-hit mutations — narrows their build pool. If that feels too thin, revisit (e.g. allow
  slow/DoT on beam but keep landing-pool fire projectile-only).
- **Ignite is unclear** — clarify its description (burn DoT + burst-on-death spread) in the ability text /
  encyclopedia, and **verify it actually fires** (burn applied, spread-on-death triggers).
- **Flamethrower feels "like a beam"** (`ProjectileSystem._process_cone_fire` + its VFX) — smoother, flame-y
  feel: continuous flame-stream particles instead of the beam-like cadence; verify tick cadence / VFX read as
  fire, not a solid beam.

**Acceptance:** ult fills ~1/room; enemy shots travel until wall/player/summon (no mid-air pop, no runaway
count); each class's card shows its own passive indicator (no momentum on Tank/Risk/Controller); no element
mutation is offered on a weapon it makes no sense for; Ignite reads clearly and works; flamethrower reads as fire.

---

## Slice 3 — Balance rebalance (rein in player, harden threats)

**LOCKED with the user (2026-07-06).**

- **Arc Wand** (best-by-far) `data/weapons.json` — `damage [18,21,24,28,33] → [16,19,22,25,29]`, `chain_count
  [3,3,4,4,5] → [2,2,3,3,4]`, `chain_falloff 0.82 → 0.65` (later jumps hurt far less), `fire_rate 3.4 → 2.9`.
- **Summons** (too strong + lag) `data/abilities.json` — `summon.damage 14 → 10`, `attack_interval 0.55 → 0.70`;
  `overload_grid.construct_count 3 → 2`, `damage 22 → 16`; + the **Slice 1 hard cap (~5 active)**.
- **Bosses** (`Enemy.gd`) — **~2× HP**: warden 800→**1600**, hydra 1000→**2000**, hive 900→**1800**, pulsar
  950→**1900** (champion scale unchanged). *(Deeper boss-in-swarm rework parked.)*
- **Tank sustain — HARDER (must play, no facetank):** `Player.gd` `BLOODTHIRST_MAX_OVERSHIELD_RATIO 0.65 →
  **0.25**` (caps ~37 on 150 HP), `BLOODTHIRST_OVERSHIELD_DECAY_PER_SECOND 5 → **9**`; heal-per-kill
  (`CoopManager._apply_bloodthirst_on_kill`) `5 → **2**`; Blood Frenzy ult heal `35 → **25**`. Audit for any
  double-dip (weapon lifesteal + on-kill).
- **Cooldowns — BROADER +25% across the board** (`data/abilities.json`) — raise **all** ability base cooldowns
  ~+25% so abilities are commitments, not constant (e.g. dash 1.5→1.9, shockwave 5→6.25, overcharge 12→15,
  shield 9→11, turret/orbit/summon 12→15, minefield 7→9, ground_slam 6→7.5, quake 9→11, blood_lance 5.5→7,
  fireball 4→5, ignite 5→6.25, sonic_boom 5→6.25, momentum_burst 7→9). Also trim `quick_reflexes`
  (`[0.2,0.35,0.5] → [0.15,0.25,0.35]`). **Risk unaffected** (Overheat overrides CDs with its 0.5s).
- **Heat — STICKIER** (`Player.gd`) — `OVERHEAT_DECAY_PER_SECOND 14 → **6**`, `OVERHEAT_DECAY_DELAY 0.75 →
  **1.5**` so Risk ramps to high heat and holds it (more reward + more danger).
- **HP pickups — FEWER DROPS, keep heal value** — `CoopManager.HEALTH_DROP_CHANCE **0.06 → 0.03**` (halve the
  per-non-champion-kill drop chance); **`HealthPickup.heal_amount` stays 8** (a found pickup still matters; no
  steady stream).

**Acceptance:** arc is a strong pick, not the auto-best; summons are useful but not carry-alone; a boss survives
a meaningful engagement; Tank can't facetank-and-win (must play); no class trivially dominant; heat feels
maintainable; ults are a moment, not a rotation.

---

## Slice 4 — Rooms: hybrid curated archetypes + variation (LOCKED design 2026-07-06)

**Goal:** replace the random per-room modifier roll (`RunState._roll_modifiers_for_depth`) with **curated room
archetypes** the player **chooses between**, each with intra-theme variation. Kills the "random stack = samey"
feel and makes the roguelite room-choice a real decision.

**How it works:**
- **Archetype table — `data/room_archetypes.json`** (LOCKED: a JSON data file, not a const, for easy tuning):
  each = `{ id, name, icon, short_desc, enemy_bias, themed_modifier_pool, density_profile, arena_size_hint,
  reward_hint, depth_gate? }`.
- **Map gen** (`RunState._build_choice_step` / `_build_run_node`): assign each node an **archetype** (respect
  depth gates + **anti-repeat** so consecutive nodes differ), then roll intra-archetype variation. Replaces the
  random modifier roll.
- **Choice count — LOCKED: 2 combat archetype choices per normal step; champion steps stay 1 forced card**
  (matches the current `_build_choice_step`, 2/1 — don't change the step shape). Readable archetype cards (name /
  icon / short_desc / reward hint), reusing the existing choice + card UI [[feedback-card-ui-style]].
- **Modifiers per room: up to 2, both from the archetype's themed pool** — never random cross-theme.
- **⚠ Replace the modifier-dedupe helpers** so they can't reintroduce off-theme / >2 stacks:
  `RunState._ensure_route_traits_differ` currently rerolls via `_roll_modifiers_for_depth`, and
  `_build_distinct_modifier_load` **appends any** major/minor modifier. Rework both to be **archetype-aware**:
  differentiate the 2 choices by **archetype** (not random modifier reroll), and only ever draw modifiers from
  the chosen archetype's themed pool, capped at 2.
- **Variation within an archetype:** exact enemy sub-mix, arena-size roll, modifier count (0–2) + intensity,
  density — so two Swarm rooms differ but both read as Swarm.

**The 6 archetypes** (all map to existing enemies + modifiers — no new layout engine; arena size via the
existing shrink/size lever):

| Archetype | Enemy bias | Themed modifier pool | Arena / density | Tests |
|---|---|---|---|---|
| **Standard** | balanced depth mix | any 1 (mild) | normal | baseline |
| **Swarm** | chaser / splitter / mini | `swarm`, `accelerating_waves` | normal, +density | AOE / crowd |
| **Elite Ambush** | few trash + 1–2 elites | `shielded`, `enemy_speed` | normal, −density | priority targets |
| **Ranged Gauntlet** | spitter / elite_spitter | `accelerating_waves`, `enemy_speed` | larger arena | dodging projectiles |
| **Hazard Field** | moderate mix | `fire_floor`, `ice_zone`, `mine_field` | normal | positioning |
| **Pressure Cooker** | charger / bomber | `shrinking_arena`, `explosive_death` | shrinking | space denial |

**Files:** new **`data/room_archetypes.json`**; `RunState.gd` (`_build_choice_step` / `_build_run_node`, replace
`_roll_modifiers_for_depth` with archetype assignment + themed-modifier draw; **rework `_ensure_route_traits_differ`
+ `_build_distinct_modifier_load` to archetype-aware dedupe**); the next-room choice UI (`RunFlow.gd` / choice
cards — show the **2** archetype cards); `WaveDirector.gd` (consume archetype enemy-bias + density);
`CoopManager.configure_room` (extend `room_config` with archetype fields).
**Acceptance:** each **normal** step offers **2** readable archetype choices (champion steps stay 1 forced card);
a run visibly mixes room types (no two consecutive identical); every room carries ≤2 **on-theme** modifiers (no
random cross-theme stacks, verified via the reworked dedupe helpers); the 6 archetypes each play distinctly.
*(Biggest slice — new data + map-gen + choice UI; do last.)*

**Physical structure — DEFERRED (decision 2026-07-06).** Round 2 rooms are **open arenas**; archetype variety
comes from enemy mix + themed modifiers + **arena size** only — **no internal obstacles / cover / chokepoints**.
Reason: enemies today have `collision_layer/mask = 0` and **no pathfinding** (straight-line move-to-target + the
soft separation push), so any wall/obstacle that should block enemies first needs **enemy collision + avoidance
(steering or a nav mesh)** — a real AI feature, its own project. Prereq captured for a future "room geometry"
feature: give enemies avoidance (extend the separation pass to repel from an `obstacle` group, or add nav);
player + projectiles already collide with `StaticBody2D`, so obstacles slot into that side cheaply once enemies
can route around them.

---

## Notes
- **Canonical tree = `D:\GameDev\Project_Twin_stick` on `v4/class-system`** (the `_v4` worktree was promoted +
  removed, `8e5c30b`; local == origin). Parallel Codex may be editing — **re-read before each edit.** See
  [[feedback-parallel-codex]], [[feedback-worktree-branch]].
- Order: **Perf → Bugs → Balance → Rooms** (perf + bugs unblock a clean balance playtest; rooms is the biggest
  new work, last).
- Keep art abstract-geometric; validate + commit per slice.
