# Project Twin-Stick — Content Vision & Patch 1 Plan

Single source-of-truth doc for the current content effort. **Baseline = Round 13 (commit `3c37ec7`).**
Work on `v3/main` in `D:\GameDev\Project_Twin_stick` (main checkout, no new worktrees). Do not commit
unless asked.

**Structure:**
- **Part A — Patch 1 (build now; Codex-ready):** tuning + manual aim + weapon roster + Momentum/Flow.
  This is the "one big patch."
- **Part B — Content vision (future patches; design locked, most stats TBD):** abilities, bosses/
  enemies, biomes, and build sequencing.
- **Part C — Parked ideas.**
- **Part D — Open items.**

> **Codex rules (apply to Part A):** Stick to this plan. **Do not invent assumptions. Do not silently
> deviate** — flag unclear values first. After implementing, **summarize anything unclear, skipped, or
> deviated.** Report your approach **before/with** the items marked **[REPORT]**. "Upgrade" is the
> player/doc word; "mutation" is code-only. Validate headless after each cluster. Keep output on `D:`.

> **Design north star:** *quality over quantity.* We can't out-quantity big studios, so every new thing
> must feel **genuinely different**, not marginally different. Cut anything redundant.

> **Art direction:** the current neon-geometric look is an **explicit placeholder.** The intended final
> style is **rubberhose** (1930s cartoon, Cuphead lineage) — a full restyle, deferred because
> **gameplay is the priority.** Build on the neon placeholder; do rubberhose later as a **re-skin of
> stable mechanics**; keep visuals **parameterized/data-driven** so the re-skin swaps the look, not the
> logic; **don't over-polish neon** (it's scaffolding).

---

# PART A — PATCH 1 — "core feel" (Codex-ready, build now)

The single big patch: **tuning + manual aim + the full weapon roster + the Momentum/Flow system.**
No new abilities/bosses/biomes; **no enemy re-tune** (that's post-playtest).

**Weapon roster after this patch (7, each a distinct delivery; all work in auto + manual):**

| Weapon | Delivery | Change in Patch 1 |
|---|---|---|
| Rifle | Sustained single-target | none |
| Shotgun | Short cone burst | tighter spread; knockback removed |
| Rocket | Direct AoE | none |
| Cannon | Biggest single hit (boss-killer) | remove pierce + knockback; slower + heavier |
| Railgun | Unlimited pierce line | none (Lance concept folded into it) |
| **Beam** ✨ | Continuous, per-target dwell-ramp | **new** |
| **Boomerang** ✨ | Returning double-hit | **new** |

## A1 — Data tuning (`data/*.json`)

**`data/weapons.json`:**
- **Cannon:** `fire_rate` `2.0` → **`1.5`**; `per_level.damage` `[40,55,70,85,100]` →
  **`[55,75,95,115,135]`**; **remove `pierce`** and **remove `knockback`**.
- **Shotgun:** `per_level.spread_degrees` `[18,17,16,15,14]` → **`[12,11,10,9,8]`**; **remove
  `knockback`** (the `150` from R13).
- **Railgun:** no change.
- **Add Beam / Add Boomerang — but do this LAST, after the A4 firing branches exist** (see build-order
  gate; they must not be selectable before the pipeline can fire them):
  - **Beam:** `projectile_kind "beam"`; stats `range 750`; `per_level.max_damage_per_second
    [120,140,160,180,200]`; `ramp_seconds 1.5`; `ramp_start_fraction 0.30`.
  - **Boomerang:** `projectile_kind "boomerang"`; stats `fire_rate 3.0`, `travel_distance 480`,
    `projectile_speed ~700`; `per_level.damage [16,20,24,29,34]`.

**`data/abilities.json`:**
- **Overcharge:** `cooldown` `16` → **`12`**.
- **Dash:** `cooldown` `3.0` → **`1.5`** only. (Base Dash has **no** damage — the "dash-through
  damage" is the **Shockdash** rare, handled in `mutations.json` below.) i-frames/speed/duration
  unchanged.

**`data/mutations.json`:**
- **Remove the `knockback` mutation** entirely. **Also strip the dead code it leaves** (data removal
  alone isn't enough): the `knockback_level` / `get_knockback_bonus` / `knockback_bonus` computation in
  `MutationSystem.gd` (~117) and the `knockback_level` read in `Player._fire_weapon` (~611), plus any
  stale `current-state.md` references. (Weapon `knockback` removal in `weapons.json` is data-only.)
- **Shockdash (`dash_shockdash` rare):** **remove its knockback** — drop the `knockback_force` param
  and the knockback application in `Player._apply_shockdash_hits` (~517); **keep `passthrough_damage`**.
  Update its description (drop "and knocks back"). (This is the only "dash-through damage" in the game.)
- **Ricochet → Split:** repurpose `ricochet` — on hit, **spawn 1 projectile at the nearest *other*
  enemy**; splits do **not** re-split (param e.g. `split_count: 1`). Update description. (R13
  wall-bounce removed — it failed vs auto-aim.) Code change in A4 — **routed through `CoopManager`**,
  not `Projectile.gd`.

## A2 — Manual aim (auto default + seamless override)

Today aiming is auto-only (`Player.gd` `_find_auto_target`/`_auto_attack_direction`; `aim_mode`
`auto`/`movement` in `PlayerConfig.gd`). Add a real manual override — **purely additive over auto.**

- **Input (via A6's per-device InputMap bindings):** **bind `pX_aim_*` to the right stick**
  (`JOY_AXIS_RIGHT_X/Y`), with each player's aim events **device-stamped to that player's gamepad**
  (per A6) — so aim is **rebindable, per-device, and symmetric P1/P2** with no cross-drive. Read it
  through the action (action strengths / `Input.get_vector`) into **`_aim_facing`** when magnitude
  **> 0.35** (deadzone). The KB+M/mouse player aims with the mouse.
- **Fire logic** (`Player.gd` `_physics_process`, ~364–372): aim magnitude > deadzone → **manual**
  (`fire_direction = _aim_facing`; deflect-to-fire; continuous at weapon cadence; **no aim-assist**);
  else → **auto** (current nearest-target behavior).
- **KB+M:** auto + override, consistent with gamepad — auto by default; moving the mouse / firing
  engages manual aim at the cursor, reverts to auto when idle.
- **Reticle:** while manual-aiming, draw a neon **directional line/arc** from the player toward
  `_aim_facing`, out to weapon range.
- **Abilities are weapon-aim-independent:** Dash/Blink use the **movement** direction (`_move_facing`);
  only "no movement input while aiming" falls back to `_aim_facing`, else last facing. Placed/centered
  abilities (turret/minefield/decoy/shockwave/shield/dome/orbit) unchanged.
- **Settings:** add a **"Manual only"** `aim_mode` (weapon fires *only* while aiming). Default = auto +
  override.
- **[REPORT]** the per-device aim input wiring and the manual/auto fire branch.

## A3 — Momentum / Flow system (new core feel)

Per-player flow meter rewarding aggressive, flawless play. Builds on existing `_kill_streak_progress`
(`CoopManager.gd`). The "in the zone" feel — distinct from Overcharge (active burst) since momentum is
passive/earned.

- **Meter:** 4 tiers, **per-player**, **resets at room start.**
- **Build — kills per tier, cumulative (placeholder, to balance):** T1 = **10**, T2 = **+15** (25),
  T3 = **+20** (45), T4 = **+25** (70).
- **Tier buffs (ADDITIVE, UNCAPPED — stack with Overcharge/mutations/levels):**
  | Tier | Move | Fire rate |
  |---|---|---|
  | T1 | +10% | +15% |
  | T2 | +20% | +30% |
  | T3 | +35% | +50% |
  | T4 | +50% | +75% |
- **Loss:** a **damaging** hit drops **2 tiers.** Hits **prevented** by dash i-frames / Shield / (future
  Barrier dome) cost **nothing** — gate the drop on actual HP loss. **No idle decay.**
- **Kill credit = SHARED gain, per-player loss.** Gain is **shared**: on **any** enemy death
  (`_on_enemy_died`, `CoopManager.gd`), **all players gain** toward their meter — so **no damage-owner
  attribution is needed** (we avoid threading a `source_player` through projectiles / Beam ticks /
  fire & poison pools / Shockwave / Orbit / Turret / mines / splitter-minis). **Loss is per-player:**
  each player drops their own 2 tiers only when **they** take a damaging hit (already attributable —
  the Player takes damage individually). Hook gain into `_on_enemy_died`; per-player meters track tiers
  + loss.
- **Do NOT cap** the resulting fire rate / move speed — additive + uncapped is intended (OP is the
  fantasy; balance via values, and via the post-playtest enemy pass).
- **Implementation — UNIFIED ADDITIVE stat path (changes today's multiplicative stacking):** today
  `Player._recompute_effective_stats` (~934) **multiplies** sources (`_combined_modifier`) and
  `MutationSystem.get_compiled_weapon_stats` (~79) multiplies mutation bonuses. **Rework to ADDITIVE
  accumulation:** sum all percent bonuses (momentum tiers + Overcharge + Root + fire-rate/damage/move
  mutations) and apply once as **`base * (1 + Σ%)`**, **uncapped.** This is a **deliberate balance
  change** (additive stacks weaker than multiplicative at high counts) — re-tune values in playtest.
  **[REPORT]** the new additive formula and which sources feed it.
- **UI:** **4 tier pips** near each player's HUD card + an **escalating player aura** (per tier).
- **[REPORT]** the gain/loss hooks and how buffs feed the move-speed/fire-rate math (and that nothing
  caps it).

## A4 — New weapon behavior (`scripts/weapons/…`)

- **Beam (continuous, dwell-ramp):** continuous beam along `_aim_facing` (manual) or toward nearest
  (auto), out to `range 750`. Damage ramps **per held target**: starts at `ramp_start_fraction` (0.30)
  of `max_damage_per_second`, ramps to max over `ramp_seconds` (1.5s) on the **same** target; **resets
  instantly** on target change. Apply damage as ticks (document tick rate). **[REPORT]** the tick model
  + "same target"/reset tracking.
- **Boomerang (returning, double-hit):** travels `travel_distance` (480) out, then **returns to the
  player**, dealing `damage` to enemies on **both** legs (don't double-hit the same enemy on the same
  leg). Full stream, `fire_rate 3.0`. Auto throws at nearest; manual aims the path.
- **Ricochet → Split:** on hit, if a split charge remains, spawn 1 projectile toward the nearest enemy
  that isn't the current target; the spawned one does **not** split. **Route the spawn through
  `CoopManager`** — emit a `split_requested` signal from `Projectile.gd` → manager callback (or call a
  manager method) so split shots respect pooling, `MAX_ACTIVE_PROJECTILES`, `impact_requested` /
  `projectile_deactivated`, and active-projectile cleanup. **Do NOT instantiate projectiles inside
  `Projectile.gd`** (that bypasses the pool/caps/signals). Remove the R13 wall-reflection path.
- **Mutation compatibility (Beam is continuous → projectile-spawn/travel mutations don't apply):**
  - **Apply to Beam:** `high_caliber` (damage), `range`, `rapid_fire` (remap → faster ramp / DPS),
    `fire_trail` (ignite a pool at the contact point — **one active pool per beam, repositioned to the
    current contact point and refreshed on a ~0.5s cooldown; do NOT spawn a pool per damage tick**, to
    avoid balance/perf spam), `freeze_shot` (slow stacks on the hit target), `poison` (DoT on the hit
    target); plus survival/player stats (`move_speed`, `tough`).
  - **Do NOT apply to Beam:** `velocity` (no projectile travel), `ricochet`/split (no projectile to
    spawn), `oc_piercing_overdrive` (pierce/travel N/A — beam already hits the whole line). (Ability-
    group mutations are ability-scoped and never touch weapons.)
  - **Boomerang is projectile-based** → all weapon mutations apply normally; damage is applied per leg
    per the double-hit rule.
  - **Compiler branch (required):** add an explicit `if projectile_kind == "beam"` branch in
    `MutationSystem.get_compiled_weapon_stats` (~79) — the generic projectile path targets the wrong
    keys for a beam. In the branch: **remap** `high_caliber` → `max_damage_per_second`, `rapid_fire` →
    ramp speed; **skip** `velocity` / `ricochet`(split) / pierce. The generic projectile mutation pass
    must NOT run for beams.
- Add Beam/Boomerang icons (`IconFactory.gd`). The encyclopedia auto-picks them up from
  `weapons.json`.

## A5 — Other tuning (`scripts/…`)

- `Player.move_speed` **488 → 560** (base; momentum adds on top).
- `ZoomCamera.zoom_max` **0.52 → 0.56** (zoom_min `0.45`, padding `(440,380)` unchanged).
- `Player.gd` player visual scale **`*1.5` → `*1.35`** (`_base_visual_scale`); **collision unchanged.**
- `Enemy.gd` `READABILITY_VISUAL_SCALE` **1.3 → 1.2** (collision already decoupled).
- `CoopManager._rebuild_floor_grid` (~771): grid `Line2D` **`antialiased = true`** (grid-flicker fix).
- **Remove the boss off-screen indicator** (`_update_boss_offscreen_indicator` + build/refs) — at this
  zoom the arena is ~always on-screen, so it's noise.

## A6 — Per-player controller ownership (make P1 = P2)

Today **P2 is forced to `keyboard`** (`Bootstrap._build_player_configs` ~352) because shared pad
bindings can drive *both* players off one controller. Make P1 and P2 **symmetric**, each owning a
**distinct gamepad** — this is the prerequisite for 2P manual aim.

- **Assign each player a distinct `gamepad_device_id`** — extend the assignment loop in `CoopManager`
  (~672) so P2+ get their own connected pad; **remove the forced-keyboard P2 default** (~352).
- **Per-device InputMap bindings (keep rebinding functional):** **stamp each player's gameplay action
  events** (move / aim / abilities / fire) **with that player's assigned device id** — never device
  `-1` (all devices), which is what lets one pad cross-drive both. This keeps the InputMap rebind
  system working **and** per-device. **Rebinding persists per-player, device-targeted events.**
- **UI / settings — also unblock P2 gamepad (else P2 still can't pick it):**
  - `_populate_player_2_control_option` (~264): offer **Gamepad**, not keyboard-only.
  - **Enable the P2 controller-binding buttons** (~596).
  - **Stop stripping saved P2 controller bindings** (~749).
- Result: **P1 and P2 identical** — movement, aim, abilities, **and** rebinding. KB+M stays a
  selectable control source.
- **[REPORT]** the per-device binding + storage approach, the UI changes, and confirm two pads no
  longer cross-drive and that P2 can both **pick** and **rebind** a gamepad.

## Patch 1 — out of scope
- **Enemy re-tune:** ship **current enemy values**; hand-tune trash/elites (and bosses) **after
  playtest** against the stronger player. Likely direction = **threat over HP** (momentum makes the
  game about *not getting hit*), but confirmed in playtest, not pre-committed.
- New abilities, bosses/enemies, biomes — see Part B.

## Patch 1 — build order / validation
- Order: **A1** data tuning **(EXCEPT the Beam/Boomerang weapon entries)** → **A5** other tuning →
  **A6** per-player controller ownership → **A2** manual aim → **A4** new-weapon firing branches
  (continuous Beam + compiler branch, returning Boomerang, split-via-`CoopManager`) **→ then add the
  Beam/Boomerang `weapons.json` entries** → **A3** momentum **(incl. the unified additive stat-path
  rework)**.
- **Gate:** the current pipeline assumes projectile-style firing (`_fire_weapon` →
  `_on_player_fire_requested` → `_activate_projectile`). **Beam/Boomerang must NOT be selectable until
  their A4 firing branches exist** — otherwise selecting them breaks firing.
- Each cluster: implement → headless-validate → continue.
- `git diff --check`
- Parse: `& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit`
- Boot: same exe with `--quit-after 1`
- **Manual playtest required** before approval — feel the manual aim, momentum flow, new weapons; it
  drives the post-playtest enemy re-tune.
- **[REPORT]** list: per-player controller ownership (symmetric P1/P2, no cross-drive); aim wiring +
  fire branch; the unified additive stat-path formula + sources; momentum gain/loss hooks; Beam tick
  model + compiler branch; Boomerang double-hit; split-via-`CoopManager`; anything unclear/skipped/
  deviated.

---

# PART B — Content vision (future patches)

Identities/mechanics locked; **most stats TBD.** Built *around the structured (acts + map) main mode*
(endless is the secondary/score mode). Manual aim, weapons, and momentum from Part A are the
foundation these build on.

## Build sequencing
- **Patch 1 (Part A):** tuning + manual aim + weapons + momentum. ← now
- **Patch 2 — Abilities:** Stance/Root, combat drone, Barrier dome.
- **Patch 3 — Bosses/enemies:** arena-altering, weakpoint/puzzle, conditional, combiner.
- **Patch 4 — Biomes:** destructible cover, pits/gaps, pinball bumpers.
- Each later patch gets its own stats pass + Codex plan, and a hand enemy re-tune as the player power
  changes.

## B1 — Abilities (Patch 2)
- **Stance toggle — "Root for Power":** toggle on → can't move (or very slowly) but fire rate + damage
  + range spike hugely. Commit-to-a-spot turret mode; an ongoing trade-off, not a timed burst.
- **Persistent companion — combat drone:** an always-on auto-firing drone that follows you the **whole
  run** (no cooldown, no command); picking it dedicates an ability slot to a permanent second gun.
- **Barrier — dome:** timed bubble around you that blocks **incoming projectiles only** (not bodies);
  **you can still shoot out**; lasts longer than Shield. Distinct from **Shield** (total invuln, short,
  can't attack).

## B2 — Bosses / enemies (Patch 3)
- **Arena-altering boss** — reshapes the battlefield mid-fight (walls, flood, shrink).
- **Weakpoint / puzzle boss** — beat a specific way (expose cores / reflect its attack); fixes "bosses
  too easy/samey."
- **Conditional enemies** — directional shield (must flank), movement-mirror, anchor-buffer
  (kill-priority).
- **Combiner enemies** — small enemies that merge into a big threat if not cleared fast.
- (Boss readability: lean into Returnal-style dense, weave-through patterns.)

## B3 — Modifiers / biomes (Patch 4)
Physical/spatial biomes (rule-modifiers parked):
- **Destructible cover** — breakable cover you + enemies use; turns the open arena tactical.
- **Pits / gaps** — fall hazards; knock enemies in; dash/blink across.
- **Pinball bumpers** — physics bumpers that bounce enemies (and you) around.

---

# PART C — Parked ideas (not now)

- **Arcade layer (Returnal/MANIAC-inspired)** — the *flow* half is already core (Momentum, Part A).
  Parked on top: a **score multiplier** driven by momentum, and **"heat" — aggression-driven dynamic
  difficulty** (push harder → harder response, MANIAC-style), with **endless** as the score-chase home
  (possibly a single persistent **open arena**). Revisit once core is solid.
- **Returnal-style bullet-hell boss patterns** — a boss-design note for Patch 3.
- **Risk/reward "parasite" items** — upgrades with a downside; adds mutation-pool depth; optional.
- **Open-world / GTA2 roaming** — set aside (genre pivot vs bounded couch-co-op identity, scope).
- **Interconnected arenas** — rejected as filler (corridors add travel time without decisions unless
  something *flows* through them).

---

# PART D — Open items (future sessions)

- **Stats for Part B:** the 3 abilities, the 4 boss/enemy concepts, the 3 biomes.
- **Mutation × new-weapon interactions** — *specified in A4* (Beam mutation-compatibility list;
  Boomerang = projectile-based, mutations apply per-leg). Verify in playtest that the categorization
  feels right.
- **New HUD/UI polish** beyond Patch 1: encyclopedia entries auto-update, but verify new weapons read
  well; aim-reticle feel.
- **Onboarding** — rising complexity (manual aim, momentum, 7 weapons, more abilities) with no
  tutorial; couch co-op needs lightweight teaching (control hints / first-run tips).
- **Cannon** — confirmed "keep simple = boss-killer," but watch it in playtest in case it feels flat.
