# Playtest Round 14 + Content Vision — Plan & Design Notes

Captured from a long collaborative design session. **Baseline = Round 13 (commit `3c37ec7`).**
Work on `v3/main` in `D:\GameDev\Project_Twin_stick`. Do not commit unless asked.

> STATUS: **DESIGN / PLANNING — NOT all implementation-ready.**
> This doc has three parts:
> - **Part 1 — Round 14 tuning:** near-term, implementable patch (concrete values).
> - **Part 2 — Content vision:** the bigger "quality over quantity" redesign (manual aim + new
>   weapons/abilities/bosses/biomes). Concepts + identities are locked; **most stats are NOT yet
>   designed**, so this is a multi-round vision, not a single Codex hand-off.
> - **Part 3 — Open items:** things we explicitly deferred to keep discussing.

> **Design north star (from this session):** *quality over quantity.* We can't out-quantity big
> studios, so every new thing must feel **genuinely different**, not marginally different. Cut anything
> redundant. Every weapon must **work in auto-aim AND be better (not required) in manual.**

> **Art direction:** the current neon-geometric look (Geometry-Wars-ish) is an **explicit
> placeholder.** The intended final style is **rubberhose** (1930s cartoon, Cuphead lineage) — a full
> restyle, deferred because **gameplay is the priority.** Consequences: build on the neon placeholder;
> do rubberhose later as a **re-skin of stable mechanics** (consistent with "art last"); keep visuals
> **parameterized / data-driven** (shape/color/particle params per weapon) so the rubberhose pass
> swaps the skin, not the logic; and **don't over-polish neon** — it's scaffolding.

---

# Part 1 — Round 14 tuning (implementable now)

From the Round-13 playtest. Concrete values; safe to build.

### Scale / speed / camera (R13 zoom-out overshot + felt slow)
- **`Player.move_speed`** `488` → **`560`**.
- **`ZoomCamera.zoom_max`** `0.52` → **`0.56`** (keep `zoom_min 0.45`, `padding (440,380)`).
- **Player visual scale** `1.5` → **`1.35`** (`Player.gd` `_base_visual_scale`). Collision unchanged
  (already decoupled).
- **Enemy `READABILITY_VISUAL_SCALE`** `1.3` → **`1.2`** (`Enemy.gd`). Collision unchanged (already
  decoupled — confirmed `_refresh_static_visuals` excludes it).
- **Hitbox note:** confirmed visual ≠ hitbox for both player and enemies; the "too big" feel is purely
  visual, addressed by the scale trims above.

### Grid flicker
- Arena grid `Line2D`s are not antialiased (`CoopManager._rebuild_floor_grid` ~779; only walls are).
  **Set `antialiased = true`** on the grid lines (and consider a small width bump) to stop the shimmer
  at the zoomed-out scale.

### Boss off-screen indicator
- **Remove it entirely.** At this zoom the arena is nearly always fully on-screen, so the edge marker
  is noise (and it was showing on-screen anyway). Revisit only if we ever zoom in significantly.

### Dash (differentiate from Blink)
- Blink is the better tool (moves through enemies) and stays as-is. **Dash → high-frequency dodge:**
  lower cooldown (`3.0` → **`~1.5s`**), **drop the marginal dash-through damage**, keep i-frames.
  Identity = "always have a dodge."

### Ricochet mutation → Split (R13 wall-bounce failed)
- Wall-bounce never triggers because auto-aim sends shots straight at enemies, not walls. **Replace
  with split:** on hit, spawn **1** new projectile aimed at the **nearest *other* enemy**; splits do
  **not** re-split (no infinite chain). (`mutations.json` `ricochet` + `Projectile.gd`.)

### Shotgun
- **Tighter spread:** `spread_degrees` `[18,17,16,15,14]` → **`[12,11,10,9,8]`**.

### Knockback — dropped entirely (weapons + mutation)
- **Remove `knockback` from Cannon (`320`→none) and Shotgun (`150`→none).** "Knockback feels useless"
  (trash one-shots, bosses immune, elites barely react). Shotgun loses its self-defense push — accepted
  as brawler risk.
- **Remove the Knockback mutation entirely** (`mutations.json` `knockback`). No forced replacement —
  the hit-effect category is crowded and every proposed swap felt redundant; a tighter pool beats
  filler (quality over quantity).

### Overcharge cooldown
- **`cooldown` `16` → `12`** (`data/abilities.json` overcharge). Duration 6s / 1.5× fire rate
  unchanged — ~50% uptime so the burst comes around often.

### Strategic direction
- **Structured (acts + map) is the MAIN mode**; endless is a secondary/score mode. New content is
  designed around the structured arc.

---

# Part 2 — Content vision (design locked, stats TBD)

The "need more content" answer, built to the quality north star. **Identities/mechanics are decided;
numbers are not** (a future design+build effort, sequenced over multiple rounds — manual aim first
since it's foundational).

## Aiming model — auto default + seamless manual override
- **Default behaviour:** **auto-aim with a seamless manual override** — NOT a hard mode toggle.
  - **No aim input** (right stick centered) → **auto-targets nearest** (today's game). Pure
    accessibility floor; a left-stick-only player gets full auto forever.
  - **Push the right stick** → **manual takes over that instant** (deflect-to-fire in the aimed
    direction). **Release → snaps back to auto.** Manual is always one flick away, never a commitment.
- **Deflect-to-fire:** the aim stick **aims AND fires** (no separate fire button — you fire near-
  constantly anyway). **KB+M:** moving the mouse / firing engages manual aim at the cursor; otherwise
  auto. (KB+M override details → implementation.)
- **Settings:** a **"Manual only"** option for purists (auto never engages). Default = auto + override.
- Bind the already-defined-but-unbound **`pX_aim_*`** actions to the right stick; produce an
  `_aim_facing` separate from `_move_facing`; fire toward `_aim_facing` when aim input is present, else
  auto-target.
- **Every weapon works in both, moment-to-moment.** **Manual upside = a MODERATE edge** (reach, target
  selection, sweeping) — **not a damage gap** — so auto never becomes a trap. **No manual-only
  weapons.** Auto remains the best/default option ongoing; manual layers on as skill expression.
- **Manual aim is WEAPON-ONLY.** Abilities are not aimed by the right stick:
  - **Movement abilities (Dash, Blink) follow the MOVEMENT direction (left stick)** — "left stick =
    where I go." Edge case (no movement input while aiming): fall back to aim direction, else last
    facing.
  - **Placed/centered abilities** (turret, minefield, decoy, shockwave, shield, dome, orbit) are
    **unaffected** — drop at/around the player as today.

## Core — Momentum / Flow system (new core-feel feature)
Pulled from the parked combo idea, but **only the moment-to-moment flow part** — NOT the score / heat-
escalation / endless arcade layers (those stay parked). Goal: reward aggressive, flawless play with an
"in the zone" feel.
- **Build:** killing builds momentum (rapid kills faster). Builds on the existing
  `_kill_streak_progress`.
- **Grants:** escalating **move speed + fire rate** as momentum climbs — literally feeling snappier/in
  the zone. **Distinct from Overcharge** (Overcharge = active burst ability; momentum = passive,
  *earned* by play).
- **Loss:** **drops hard on hit** (Returnal-style) — rewards flawless aggression. **No idle decay** →
  "kill to build it, don't get hit to keep it."
- **Defense preserves it:** only hits that actually **deal damage** drop momentum. A hit **prevented**
  by dodge i-frames / Shield / Barrier dome does **NOT** cost momentum — defensive skill protects your
  flow.
- **Co-op:** **per-player meter** (your own hits drop your own momentum) — fair, individual.
- **Feedback:** visible escalating aura (neon placeholder now; reads as "fired up," re-skins to
  rubberhose later).
- **Stats TBD:** tier thresholds, speed/fire-rate per tier, build rate, on-hit loss amount.

## Balance & difficulty principles
- **Fire-rate (and power) sources ADD, and are UNCAPPED.** Momentum + Overcharge + Root stance +
  fire-rate mutations + weapon levels all **stack additively with no cap.** The player is *meant* to be
  able to become OP — that's the power fantasy. **Balance via the individual values, not via caps.**
- **Difficulty is re-tuned by HAND, AFTER playtest.** The player gets much stronger (momentum +
  uncapped stacking + new kit), but we **don't pre-tune enemies blind.** Patch 1 ships with **current
  enemy values unchanged**; then a **manual re-tune pass** (trash + elites, and bosses) is done based on
  how the stronger player actually feels in playtest. No formula/auto-scaling. The likely direction
  (given momentum makes the game about *not getting hit*) is **threat over HP** — but that's confirmed
  in playtest, not pre-committed.

## Weapon roster (7 — each a distinct delivery)
| Weapon | Delivery | Auto | Manual upside | Change from today |
|---|---|---|---|---|
| **Rifle** | Sustained single-target | Fires at nearest | Choose which target to focus | Keep |
| **Shotgun** | Short cone burst | Cone at nearest | Aim the cone at the pack/fleer | Tighter spread (Part 1) |
| **Rocket** | Direct AoE | Blast at nearest | Aim blast at densest spot | Keep |
| **Cannon** | Biggest single hit (boss-killer) | Big shot at nearest | Place the big shot on an elite/boss | **Remove pierce + knockback; keep simple** |
| **Railgun** | Unlimited pierce line | Line at nearest | **Line up max enemies** (showcase manual payoff) | Keep; **Lance folded in** |
| **Beam** ✨ | Continuous, per-target dwell-ramp | Locks nearest, ramps | Sweep to spread, or hold on a boss | **New.** Ramp ~8→40 dmg/s over ~1.5s, **resets instantly** on leaving target |
| **Boomerang** ✨ | Returning double-hit | Throws at nearest | Aim path so out + back both rake | **New.** Full-stream (fires freely); hits on both legs |

**Cut:** Lance (merged into Railgun), Arc, Flamethrower, Pilot, Gravity Well.

## Abilities (3 new)
- **Stance toggle — "Root for Power":** toggle on → you can't move (or move very slowly) but fire
  rate + damage + range spike hugely. Commit-to-a-spot turret mode; pairs with Barrier/positioning. An
  ongoing trade-off, not a timed burst.
- **Persistent companion — combat drone:** an always-on auto-firing drone that follows you the **whole
  run** (not a timed turret, no cooldown, no command input). Picking it dedicates an ability slot to a
  permanent second gun.
- **Barrier — dome:** a timed bubble around you that **blocks incoming projectiles only** (not bodies);
  **you can still shoot out**; lasts longer than Shield. Distinct from **Shield** (which is total
  invuln, short, *can't* attack). Roles: dome = bullet-cover you fight from; Shield = panic invuln.

## Bosses / enemies (4 concepts — mechanics TBD)
- **Arena-altering boss** — reshapes the battlefield mid-fight (raises walls, floods zones, shrinks the
  space). The arena becomes part of the fight.
- **Weakpoint / puzzle boss** — must be beaten a specific way (expose/hit cores, or reflect its own
  attack). Directly targets the recurring "bosses too easy/samey."
- **Conditional enemies** — demand tactics, not more HP: directional shield (must flank),
  movement-mirror, and an "anchor" that buffs others (kill-priority).
- **Combiner enemies** — small enemies that **merge into a big threat** if not cleared fast (urgency +
  target priority).

## Modifiers / map — physical biomes (rule-modifiers parked)
Clear signal: change the **space**, not the **rules**.
- **Destructible cover** — breakable cover you *and* enemies use; turns the open arena tactical (pairs
  with manual aim).
- **Pits / gaps** — fall hazards; deadly to step in, but you can knock enemies in and dash/blink
  across.
- **Pinball bumpers** — physics bumpers that bounce enemies (and you) around.
- *Parked (no strong interest):* rule modifiers (vampirism, overheat, bullet-time dodge, no-auto-aim,
  glass cannon, bouncing projectiles, darkness), and other biomes (ice/low-friction, wind currents).

---

# Patch 1 — Implementation spec (in progress)

Concrete, Codex-bound values, locked chunk by chunk. This becomes the Round-15 Codex plan.

## Chunk 1 — Weapons (`data/weapons.json`)
- **Cannon:** `fire_rate` 2.0 → **1.5**; `damage` per_level `[40,55,70,85,100]` → **`[55,75,95,115,135]`**;
  **remove `pierce` and `knockback`.** (Slow, heavy, biggest single hit — boss-killer.)
- **Railgun:** **no change** (`damage [16,22,28,34,40]`, `fire_rate 4.0`, unlimited pierce from R13).
- **Beam (new):** continuous beam, **range 750**. Per-target **dwell ramp**: starts at **30% of max**,
  ramps to max over **1.5s** on the same target, **resets instantly** on leaving. Max dmg/s per_level
  **`[120,140,160,180,200]`**. Auto: locks nearest; Manual: aim/sweep. (Damage applied as ticks; tick
  rate set in impl.)
- **Boomerang (new):** `damage` **`[16,20,24,29,34]`**, `fire_rate` **3.0**, travel **~480** out then
  returns to player; **double-hits** (out + back); full stream (no in-flight cap). Auto: throws
  nearest; Manual: aim the path.

## Chunk 2 — Manual aim
- **Gamepad input:** bind `pX_aim_*` to the right stick (`JOY_AXIS_RIGHT_X/Y`); compute `_aim_facing`
  from the stick vector when magnitude **> 0.35** (deadzone).
- **Fire logic:** aim magnitude > deadzone → **manual** (fire toward `_aim_facing`, deflect-to-fire,
  continuous at weapon cadence, **no aim-assist** — pure direction); else → **auto** (nearest, current).
  Movement abilities still use the left stick; placed abilities still drop at the player.
- **KB+M:** **auto + override** (consistent with gamepad) — auto by default; moving the mouse / firing
  engages manual aim at the cursor, reverts to auto when idle.
- **Reticle:** a neon **directional line/arc** from the player toward the aim direction, out to weapon
  range, shown while manual-aiming.
- **Settings:** `aim_mode` adds **"Manual only"** (weapon fires *only* while aiming; no auto-fallback).
  Default = auto + override.

## Chunk 3 — Momentum / Flow
- 4-tier meter; **per-player**; **resets at room start**; aura intensifies per tier. Builds on existing
  `_kill_streak_progress`.
- **Tier buffs (additive, uncapped, stack with Overcharge/Root/mutations):**
  - T1 **+10% move / +15% fire**
  - T2 **+20% move / +30% fire**
  - T3 **+35% move / +50% fire**
  - T4 **+50% move / +75% fire**
- **Build — kills per tier, escalating & cumulative (placeholder, to balance):** T1 = **10** kills,
  T2 = **+15** (25 total), T3 = **+20** (45 total), T4 = **+25** (70 total).
- **Loss:** a **damaging** hit drops **2 tiers**. Hits **prevented** by i-frames / Shield / Barrier dome
  cost nothing. **No idle decay.**

## Chunk 4 — Part 1 tuning (exact values)
- `Player.move_speed` **488 → 560** (base; momentum adds on top).
- `ZoomCamera.zoom_max` **0.52 → 0.56** (zoom_min 0.45, padding (440,380) unchanged).
- Player visual scale **1.5 → 1.35**; enemy `READABILITY_VISUAL_SCALE` **1.3 → 1.2** (collision
  unchanged for both).
- Grid `Line2D`s **`antialiased = true`** (flicker fix).
- **Remove** the boss off-screen indicator.
- **Dash:** `cooldown` **3.0 → 1.5**; **remove the dash-through damage**; i-frames/speed/duration
  unchanged.
- **Ricochet mutation → split** (on hit, spawn 1 bolt at nearest *other* enemy; no re-split).
- Shotgun `spread_degrees` **[18..14] → [12,11,10,9,8]**.
- **Remove `knockback`** from Cannon + Shotgun; **remove the Knockback mutation**.
- Overcharge `cooldown` **16 → 12**.

## Chunk 5 — Enemy re-tune
- **No enemy changes in Patch 1.** Ship the stronger player against **current enemy values**, then
  **hand-tune trash/elites (and bosses) after playtest.** (See difficulty principle above.)

# Parked ideas / future development (not now)

Captured so they're not lost; explicitly deferred, not part of the current plan.

- **Arcade high-score layer (Returnal/MANIAC-inspired).** NOTE: the *flow* half of this idea was
  **pulled into core** as the Momentum/Flow system (see Part 2). What remains parked is the **arcade
  layer on top:** a **score multiplier** driven by momentum, and **"heat" — aggression-driven dynamic
  difficulty** (the more you push, the harder the response, MANIAC-style), with **endless mode** as the
  score-chase home (potentially shaped as a single persistent **open arena**). Parked because core
  gameplay comes first; revisit once core is solid.
- **Returnal-style readable bullet-hell boss patterns.** A boss-design note for the future boss work —
  dense, weave-through geometric patterns; helps "bosses too easy" and plays to the neon strength.
- **Risk/reward "parasite" items** — upgrades with a real downside. Adds depth to the mutation pool;
  more scope/complexity. Optional.
- **Open-world / GTA2-style roaming** — considered and **set aside**: a genre pivot that fights our
  bounded couch-co-op identity, unbounded run length, and scope. Not pursuing.
- **Interconnected arenas** — **rejected as filler**: corridors between the same fights add travel time
  and break the upgrade beat without adding decisions, unless something *flows* through them (roaming/
  pursuing enemies, persistent state, real routing). Not worth it for connection's sake.

# Part 3 — Open items (continue next session)

**Cross-system gaps logged for later (raised, not yet designed):**
- **Mutation × new-weapon interactions** — define how existing effect mutations behave on **Beam**
  (continuous — "split" is odd) and **Boomerang** (does pierce apply on both legs?). Some auto-work,
  some need exclusion. Reconcile during the weapon stats pass.
- **New HUD / UI** — a **momentum meter / aura**, a **manual-aim reticle** (so you see where you're
  pointing), and **encyclopedia entries** for the new weapons/abilities/momentum.
- **Onboarding** — rising complexity (manual aim, momentum, 7 weapons, more abilities) with no tutorial;
  couch co-op needs lightweight teaching (control hints / first-run tips).

- **Stats/numbers** for everything in Part 2: Beam ramp/range, Boomerang fire rate/return, Cannon
  damage/cadence post-rework, Railgun confirm, the 3 abilities (root multipliers, drone DPS, dome
  duration/radius), the 4 boss/enemy concepts, the 3 biomes.
- **Manual aim implementation details:** right-stick/mouse input wiring, `_aim_facing`, settings UI,
  per-weapon auto-vs-manual behavior tuning.
- **Cannon** — confirmed "keep simple = boss-killer," but it's mechanically plain; watch in playtest /
  revisit if it feels flat.
## Build sequencing (decided)

One big patch instead of many small rounds, scoped so it stays shippable:

- **Patch 1 (next):** **Part 1 tuning + Manual aim system + full Weapon roster** (Cannon de-pierce,
  Railgun pierce line, **Beam**, **Boomerang**) **+ the Momentum/Flow system** (core-feel, self-
  contained). All "make the core feel good" work in one playtestable chunk. **Needs a stats pass +
  manual-aim implementation detail before it's Codex-ready.**
- **Patch 2:** Abilities (Stance/Root, combat drone, Barrier dome).
- **Patch 3:** Bosses/enemies (arena-altering, weakpoint, conditional, combiner).
- **Patch 4:** Physical biomes (cover, pits, bumpers).

Remaining before Patch 1 is Codex-ready:
- **Weapon stats:** Beam ramp/range/DPS, Boomerang fire rate/travel/return, Cannon damage/cadence
  post-rework, Railgun confirm.
- **Manual-aim implementation:** right-stick/mouse input wiring + `_aim_facing`, settings-menu toggle,
  per-weapon auto-vs-manual behavior.
