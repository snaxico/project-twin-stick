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
- **Controller ult "shielded minions on the right"** (`CoopManager._activate_overload_grid`) — investigate:
  likely the Aegis/reinforce shield VFX on the overload constructs rendering oddly/offset. Clarify or fix the
  visual so it reads as "overcharged constructs," not a stray shielded blob.
- **Element tag gating (decision: gate by delivery + dedupe)** (`MutationSystem.gd` + `data/mutations.json`) —
  `fire_trail` / `freeze_shot` / `poison` currently `requires:[]` (any weapon), so "Fire Bullets" shows on the
  flamethrower. **Change:** these on-hit "where the shot lands" effects **require a `projectile`-style delivery**
  (not cone/beam/melee where a landing-pool is nonsensical), **and are not offered if the weapon already carries
  that element** (no fire on flamethrower, etc.). Add the delivery requirement + a same-element exclusion in the
  offer filter. Audit all elements against all weapons for logical fit.
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
- **HP pickups — FEWER DROPS, keep heal value** (`HealthPickup.gd` + drop logic) — cut the **drop chance**
  (~⅓–½ as often); **heal amount unchanged** (a found pickup still matters; no steady stream). Locate the drop
  knob in impl.

**Acceptance:** arc is a strong pick, not the auto-best; summons are useful but not carry-alone; a boss survives
a meaningful engagement; Tank can't facetank-and-win (must play); no class trivially dominant; heat feels
maintainable; ults are a moment, not a rotation.

---

## Slice 4 — Rooms: hybrid curated archetypes + variation (LOCKED design 2026-07-06)

**Goal:** replace the random per-room modifier roll (`RunState._roll_modifiers_for_depth`) with **curated room
archetypes** the player **chooses between**, each with intra-theme variation. Kills the "random stack = samey"
feel and makes the roguelite room-choice a real decision.

**How it works:**
- **Archetype table** (new `data/room_archetypes.json` or a const): each = `{ id, name, icon, short_desc,
  enemy_bias, themed_modifier_pool, density_profile, arena_size_hint, reward_hint, depth_gate? }`.
- **Map gen** (`RunState._build_run_node` + map builder): assign each node an **archetype** (respect depth gates
  + **anti-repeat** so consecutive nodes differ), then roll intra-archetype variation. Replaces the random
  modifier roll.
- **Player picks between 2–3 archetypes per node** at the next-room screen — readable cards (name / icon /
  short_desc / reward hint), reusing the existing map + card UI style [[feedback-card-ui-style]]. "Swarm for XP
  vs Elite Ambush for the rare."
- **Modifiers per room: up to 2, both drawn from the archetype's themed pool** — never random cross-theme.
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

**Files:** new `data/room_archetypes.json` (or const); `RunState.gd` (`_build_run_node`, replace
`_roll_modifiers_for_depth` with archetype assignment + themed-modifier draw + anti-repeat); the next-room map /
choice UI (`Bootstrap.gd` / map UI — present 2–3 archetype cards); `WaveDirector.gd` (consume archetype
enemy-bias + density); `CoopManager.configure_room` (extend `room_config` with archetype fields).
**Acceptance:** each map node offers a choice of 2–3 readable archetypes; a run visibly mixes room types (no two
consecutive identical); every room carries ≤2 on-theme modifiers (no random cross-theme stacks); the 6
archetypes each play distinctly. *(Biggest slice — new data + map-gen + choice UI; do last.)*

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
