# V4 Playtest Findings — 2026-07-14

Branch: `v4/class-system`. This is a **plan / triage doc only** — nothing here is implemented yet.
Baseline commit: `b7bf0e5` (cover-only enemy cap, Phase 6).

Source: live playtest batch (raw findings quoted verbatim in each item). Each finding is triaged into a
category, tagged **BUG** (broken / dead behavior, code-confirmed), **BALANCE** (works but mis-tuned), or
**DESIGN** (feel/layout, needs a design pass), and given a code-grounded diagnosis where one exists.

> Terminology: "Upgrade" = player/doc word; "mutation" = code word. Same thing.

---

## How to implement this plan (Codex rules)

**Baseline:** commit `b7bf0e5` on `v4/class-system` (main checkout, no worktrees). Each slice builds on the
previous; treat the latest committed slice as the baseline for the next. If the baseline is unclear, stop and say so.

**Rules:**
- Stick to this plan. **Do not invent assumptions; do not silently deviate** — flag unclear values first.
- **One patch = one subsystem.** Do not mix gating, balance, UI, and content in a single commit.
- All design/gating/lever decisions are approved and A–E are fully specced with concrete values — there are no
  remaining approval seams. Implement A→E in order per the specs. If a value or spec reads ambiguous, flag it
  rather than guessing.
- Remove dead systems rather than half-reviving them (e.g. Twin Charge, the cut WHERE mechanics).
- First-pass tuning values may be set during implementation and flagged for a live feel-check; **design and
  gating decisions may not** — those come from this doc.
- After each cluster, run the validation checklist below and **report anything unclear, skipped, or deviated.**
- Keep all output on `D:`. Do not push unless asked. Check `git status` for parallel edits before committing
  (`Enemy.gd` / `FlowField.gd` / `WaveDirector.gd` currently carry unrelated concurrent edits — do not fold them in).

**Validation checklist (run per slice / touched subsystem):**
- `git diff --check`
- JSON parse for any edited `data/*.json`.
- Headless parse: `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick --quit`
- Bootstrap smoke boot: `… res://scenes/ui/Bootstrap.tscn --quit`
- The subsystem-specific check named in that slice's spec.
- Core-loop regression when runtime changes: boot → primary input → combat loop → reward pick → room clear/fail.

**Slice status:** A0 ✅ approved (see [`v4-slice-a0-mutation-audit.md`](v4-slice-a0-mutation-audit.md)) ·
A1–E all specced below with concrete values · **nothing deferred**.

---

## Category 1 — Build-fit / mutation gating **(BUG, systemic, code-confirmed)**

**Player findings:**
- "twin charge doesnt seem to work with dash"
- "why tank gets extra mines"
- "why tak has piercing overdrive and twin turrets, all these upgrades need check if they fit the builds"

**Root cause (confirmed in `data/mutations.json` + `data/abilities.json`):** V4 replaced the old
per-ability gating (`requires_ability: "<id>"`, still visible in `docs/archive/.../playtest-round-9-plan.md`)
with **generic mechanic-tag gating** (`requires: ["summon"]`, `["buff"]`, `["mobility"]`, ...). Multiple
abilities share one mechanic tag, so an ability-*specific* mutation is now offered on any build carrying that
tag — including builds where its param is never read, producing **dead upgrade cards**.

Tag map that causes the collisions:
- `summon` tag is shared by `turret`, `minefield`, `orbit`, `summon` (abilities.json:65,83,101,242).
- `mobility` tag is shared by `dash` and `slipstream` (ult).
- `buff` tag is shared by `overcharge`, `reinforce`, `blood_frenzy`, `overload_grid`.

Confirmed dead / mismatched offers (expanded after review — the effect-targeting leaks below are confirmed, not
merely "worth auditing"; A0 re-verifies each effect-consumer in code):

| Mutation (id) | current `requires` | offer leaks in via | effect consumed only by | failure |
|---|---|---|---|---|
| Twin Charge (`blink_twin_charge`) | `mobility` | dash, slipstream | Blink (removed) — `extra_charges` read nowhere | fully dead → **remove** |
| Twin Turret (`turret_twin`) | `summon` | turret, minefield, orbit, summon | Turret (`gun_count`, TurretNode) | dead on non-turret summons |
| Extra Mines (`mf_extra_mines`) | `summon` | turret, minefield, orbit, summon | Minefield (`mine_count_bonus`, CoopManager) | dead on non-minefield summons |
| Expanding Orbit (`orbit_expanding`) | `summon` | turret, minefield, orbit, summon | Orbit (`extra_orbs`, OrbitNode) | dead on non-orbit summons |
| Shockdash (`dash_shockdash`) | `mobility` | dash, slipstream | Dash (`passthrough_damage`) | offered via Slipstream w/o Dash → dead |
| Shockwave Resonance (`sw_resonance`) | `blast` | shockwave, momentum_burst, ground_slam, fireball | Shockwave (resonance scheduler) | offered via other blasts → dead |
| Aegis Burst (`shield_aegis_burst`) | `defense` | shield, deflect | Shield (expire-burst; Deflect is instant, no expiry) | offered via Deflect → dead |
| Piercing Overdrive (`oc_piercing_overdrive`) | `buff` | overcharge, reinforce, blood_frenzy, overload_grid | Overcharge + a projectile weapon | offered via other buffs / on melee → dead |

**Two failure modes — both must be fixed (this is runtime work, not just a data change):**
- **Offer leak** — `_mutation_requirements_met` (`MutationSystem.gd:324`) checks `requires` against the
  *whole-kit* tag set, so any equipped item sharing the tag unlocks the card.
- **Effect leak** — `get_ability_rare_effects` (`MutationSystem.gd:180`) injects a mutation's params into every
  equipped ability whose tags satisfy `_mutation_targets_item` (`MutationSystem.gd:395`). So even a correctly
  *gated* card still leaks its params into other same-tag abilities. **Gating alone is insufficient; effect
  targeting must also honor `requires_ability`.**

**DECISION (2026-07-14, revised after review): re-tighten via new runtime gating support (offer + effect).**
Add two requirement keys to the mutation system, honored in BOTH offer-eligibility and effect-targeting:
- `requires_ability: "<id>"` — offer only when that exact ability is equipped (new check in
  `_mutation_requirements_met`) AND inject params only into that ability (new check in `_mutation_targets_item` /
  `get_ability_rare_effects`).
- `requires_weapon_tags: ["<tag>", ...]` — offer only when the active weapon carries all listed tags.

Assignments:
- Twin Turret → `requires_ability: "turret"`; Extra Mines → `"minefield"`; Expanding Orbit → `"orbit"`;
  Shockdash → `"dash"`; Aegis Burst → `"shield"`.
- Shockwave Resonance → `requires_ability: "shockwave"` (default; only generalize if we deliberately extend the
  resonance scheduler to all blasts — flagged, not chosen).
- Piercing Overdrive → `requires_ability: "overcharge"` + `requires_weapon_tags: ["projectile"]`.
- Twin Charge → **removed** (Blink is gone; not rebuilt as a Dash charge system — recorded default).
- Generalize-the-effects (adaptive families) is **out of scope** — rejected in favor of tighten-gating, not a
  pending item.

**A0 audit table (review seam).** Produced: **[`v4-slice-a0-mutation-audit.md`](v4-slice-a0-mutation-audit.md)** —
full mutation × class/weapon/ability matrix with verified effect-consumers, recommended gates, the required
runtime support, and A1 acceptance criteria. **Approved 2026-07-14 — Tier 1–3 gates are A1 scope.** See Slice A.

---

## Category 2 — Balance / OP **(BALANCE, needs investigation + tuning)**

**Player findings:**
- "tank healin is op"
- "orbit stacks endlessly and is op"

- **Tank healing OP. DECISION (2026-07-14, updated): lever = overshield cap + decay** (validated live, not
  profile-gated). The full-HP→overshield conversion is the likeliest sustain engine in dense rooms (near-full HP
  + every kill banks shield), so tighten cap `0.25 → 0.16` and decay `9 → 13` (first-pass); leave Bloodthirst
  heal/kill, Gorge/Overflow, and Blood Frenzy heal unchanged. Measure the effective HP/s drop after implementing
  as validation. Implemented in Slice B.
- **Orbit stacks endlessly. DECISION (2026-07-14, updated): decouple orbit-node lifetime from slot-active
  duration so Orbit mildly overlaps (overlap is wanted).** Add a **separate `orbit_lifetime` stat (first-pass `20s`)** for
  the orbit node, and keep the **slot-active `duration` below the cooldown**. This is required because Orbit calls
  `_set_slot_active()` and `_is_slot_ready()` needs *both* cooldown finished *and* the ability no longer active —
  so if we simply bumped the ability `duration` to 18–22s, the recast interval would grow to 18–22s and the old
  orbit would expire exactly as the next spawns → overlap of **1, not 2**. With the decoupled model (slot-active
  < ~15s cooldown; node lifetime `20s`) you recast each cooldown while the previous orbit is still alive →
  **~2 concurrent (the wanted overlap)** at base values. A *finite* `orbit_lifetime` is what fixes the original
  bug — orbits now expire instead of persisting forever. Concurrent count ≈ `ceil(orbit_lifetime /
  effective_cooldown)`, so a build that invests in cooldown reduction (Quick Reflexes) + Duration can stack more.
  **DECISION (2026-07-14): NO hard cap** — that scaling is an intended build payoff, not a bug (the bug was
  infinite persistence, already resolved by the finite lifetime). The `duration` upgrade extends `orbit_lifetime`,
  not slot-active. Orbit-only. **Follow-ons to resolve in Slice B:**
  - **Scope — DECISION (2026-07-14): Orbit-only.** Turret/Summon/mines keep persist-until-destroyed; only Orbit
    ticks down and expires. Minimal reversal, targets just the OP outlier.
  - **No hard cap (DECISION, 2026-07-14).** Concurrent orbits scale with build investment (cooldown reduction +
    `orbit_lifetime`), and the player explicitly accepts a cooldown-reduction/Duration build stacking more orbits
    as a fair payoff. No per-owner cap, no replace-on-recast. The finite `orbit_lifetime` alone fixes the
    endless-persistence bug; concurrent count is intentionally build-dependent.
  - **`duration` upgrade re-diagnosed + eligibility (review correction).** `duration` is *not* "never offered to
    an Orbit build." Its `requires: ["projectile"]` checks the *whole kit*, so Orbit + a projectile-tagged weapon
    **does** receive it, while Orbit + a melee weapon does not. Meanwhile `get_ability_duration_multiplier`
    (`MutationSystem.gd:215`) applies **globally**. The real bug: availability keys off an unrelated weapon tag,
    effect is kit-wide. **DECISION: Duration is a global common upgrade offered whenever the kit has a
    `duration_scalable` ability — an explicit flag / reviewed list, NOT every `type: "sustained"` ability.**
    Rationale: `type: sustained` over-includes — Turret's node persists independently of ability duration (so
    scaling it changes nothing but slot-active gating), and Slipstream / Blood Frenzy / Firestorm are ults we
    don't want a common card to scale. **Candidate `duration_scalable`:** Afterburn, Quake, Shield, Overcharge,
    and Orbit (via `orbit_lifetime`); Turret **only if** we wire its node lifetime to duration. **Ownership:**
    Afterburn/Quake/Shield/Overcharge are flagged in A1; **Orbit is flagged in Slice B**, atomically with its
    `orbit_lifetime` stat + node expiry (so Duration never lands on Orbit before the runtime that uses it).
    **A0 must verify Duration changes real behavior for each flagged ability.** Both offer AND effect must gate on
    `duration_scalable`: this is a change to `_build_runtime_ability()` (`CoopManager.gd:466`), where the current
    `scales_duration = type != instant/movement` predicate applies the multiplier to *every* sustained ability
    (Turret + ults included). Replace that predicate with a `duration_scalable` check, and for Orbit multiply
    `orbit_lifetime` — not the slot-active `duration` (`CoopManager.gd:472`). Offer-filtering alone is
    insufficient; the effect path changes too.
- **(original note) Orbit stacks endlessly.** Orbit is a persistent deployable (`orbit_health 140`, no lifetime
  despawn in V4). If a player can recast Orbit while the previous instance is still alive, orbs accumulate —
  unlike Summons (`MAX_ACTIVE_SUMMONS=5`) and homing (`MAX_ACTIVE_HOMING=40`), Orbit appears to have **no
  per-owner cap**. Likely fix: add a per-owner active-orbit/orb cap and/or replace-on-recast. **Confirm in
  `CoopManager.gd` / `OrbitNode.gd` before implementing.**

---

## Category 3 — Ability feel **(DESIGN + tuning)**

**Player findings:**
- "shockwave resonance not fun, shockdash also weak"
- "afterburn boring and clunky"

- **Shockwave Resonance** (`sw_resonance`). **DECISION: one big delayed slam.** Replace the 2 staggered pulses
  with a single larger second impact ~0.5s after the first (wider radius, more damage) — "boom… BOOM" instead
  of filler. Rework `extra_pulses`/`pulse_interval` params into a single delayed-slam definition.
- **Shockdash** (`dash_shockdash`). **DECISION: just raise the number.** Bump `passthrough_damage` `20 → 45`
  (locked in Slice D); no new mechanic, no knockback re-add.
- **Afterburn** (`afterburn`). **DECISION: burning wake that follows the player.** Convert the static field drop
  into a burning trail dragged behind movement over its duration (fits Mobile / kiting), with clearer feedback.
  This is the biggest of the three (runtime change from a placed field to a moving wake).

---

## Category 4 — Arena WHERE mechanics **(DESIGN, biggest bucket)**

**Player findings:**
- "fire grid transition too fast and rigid, hard to do wihtout damage, not that fun, needs layout adjustment"
- "pin wheel layout needs some extras"
- "minegrid same static problems as other grids, pop up pillards needs more placements and coloro code"
- "sliding gates boring, bulwark boring"
- "shifting maze boring"

Common thread: the **grid / cover mechanics feel static and under-telegraphed**, and several cover mechanics
(Sliding Gates, Bulwark, Shifting Maze) don't create interesting decisions.

**Correction to earlier note:** `IslandsMechanic` and `PulsingGridMechanic` both extend `ArenaMechanic`
(damage floors, **not** physical cover). The physical-cover mechanics (`CoverMechanicBase`) are Bastion,
Pop-up Pillars, Sliding Gates, Bulwark, Drifting Cover, Shifting Maze. An earlier draft wrongly listed Islands
in the cover roster.

**DECISION (2026-07-14) — MERGE Islands + Fire/Frost/Mine Grid into one "Hazard Floor" mechanic.** They were
already the same family (positional floor hazard; survive by being in the telegraphed safe zone that moves on a
cycle), and the agreed grid rework ("moving safe lanes") converged them further. Unify on the **Islands model**
— the floor is hazardous except organic safe zones that drift/reshuffle with a telegraph — and drop the rigid
checkerboard. Damage flavor stays as **fire / frost / mine skins** (kept as distinct route options so card
variety survives). Both are damage floors, so **no flow-field/obstacle cost** to the merge.
- New unified mechanic (e.g. `HazardFloorMechanic`), skin param `fire | frost | mine`, absorbing
  `PulsingGridMechanic` + `IslandsMechanic`.
- Frost skin keeps the slow zone modifier; mine skin keeps proximity blasts; fire skin deals direct periodic
  damage with no lingering burn status.
- Safe zones are **organic** (drifting pads / soft shapes), not a checkerboard — matches the "less structured"
  direction below.

**DECISION (2026-07-14) — weak cover: cut Sliding Gates, Bulwark, Shifting Maze.** All three removed rather than
redesigned (aligns with the "quality over quantity" north star).

| Mechanic | Finding | Direction | Status |
|---|---|---|---|
| Fire/Frost/Mine Grid + Islands | grids static/unavoidable; grid ≈ islands (redundant) | **MERGE → one "Hazard Floor" mechanic**, Islands model + organic moving safe zones + telegraph; fire/frost/mine skins | merge approved (spec set) |
| Pinwheel (`PinwheelMechanic`) | central spokes weak — easy to evade | **rework → ROAMING SAWBLADES**: `3` blades drift/bounce the whole arena; no fixed safe spot. Speed `130`, damage `8` (Spec 2) | direction approved (spec set) |
| Pop-up Pillars (`PopupPillarsMechanic`) | needs more placements + color code; too structured | **more pillars + 3-state color (down=safe / rising=warning / up=solid) + damage-on-rise + HAND-AUTHORED ORGANIC CLUSTERS** (irregular designed sets per room, not a lattice) | direction approved (spec set) |
| Sliding Gates (`SlidingGatesMechanic`) | boring | **CUT** | cut approved |
| Bulwark (`BulwarkMechanic`) | boring | **CUT** | cut approved |
| Shifting Maze (`ShiftingMazeMechanic`) | boring | **CUT** | cut approved |

**Catalog impact (corrected):**
- **Hazard floors / arena mechanics:** Hazard Floor (fire/frost/mine skins, merged), Roaming Sawblades (was
  Pinwheel), Tesla Arcs, Drifting Clouds. Net: 4 previous grid+islands options collapse into one skinned mechanic.
- **Physical cover (`CoverMechanicBase`):** after cuts → **Bastion, Pop-up Pillars, Drifting Cover** (Sliding
  Gates / Bulwark / Shifting Maze removed). None of the survivors were flagged boring.
- **To resolve on each cut/merge:** scrub the removed scripts + `.uid`s and merge Islands into the Hazard Floor
  mechanic; update every reference in `room_archetypes.json`, CoopManager WHERE activation, the
  Encyclopedia/where-name formatters, and PerfRunner `where:<id>` smoke lists.

Standing constraint: physical-cover rooms (now just Bastion / Pop-up Pillars / Drifting Cover) are capped at
`MAX_OBSTACLE_ENEMIES=160` and flow-field perf gates heavy obstacle authoring — the organic-cluster pillar
layout must respect reachability + that cap. Hazard-floor rooms are uncapped (no obstacles).

### WHERE mechanical specs — AUTHORED + APPROVED 2026-07-14

All three specced with concrete first-pass values (tunable, flagged for live feel-check). **All damage is
players-only** (decided) — enemies ignore these hazards; this is a deliberate change from today's both-targets
grids/pinwheel. Untouched survivors (Tesla Arcs, Drifting Clouds) keep their current both-targets behavior and
are out of this rework's scope. Reference base values are the pre-rework constants.

**Spec 1 — Hazard Floor** (new `HazardFloorMechanic`, merges `IslandsMechanic` + `PulsingGridMechanic`; extends
`ArenaMechanic`, no obstacles → uncapped). Structure = Islands model: the floor is hazardous except circular
safe zones you stand in; zones **reshuffle with a telegraph**.
- **Safe zones:** 4 per set, radius `170`. Author 3 position sets. Always ≥2 zones live.
- **Cycle:** hold `2.8s` → telegraph next set `0.8s` (amber rings on the incoming zones) → zones jump. `START_GRACE 1.5s` before first damage.
- **Skins (off-zone effect, players-only):**
  - `fire`: direct `5` dmg / `0.5s`; no lingering burn DoT.
  - `frost`: `3` dmg / `0.5s` + move slow `×0.5` while off-zone.
  - `mine`: `10` proximity mines seeded in the hazard between zones each reshuffle; `22` dmg blast, trigger radius
    `110`, blast radius `150`. **Placement rules:** each mine ≥ `340px` from any current safe-zone centre
    (zone radius `170` + trigger radius `110` + `60` margin, so standing in a zone never triggers a mine);
    ≥ `300px` between mines (trigger and blast circles do not overlap; no simultaneous double-trigger/clumping).
    Triggered mines are **consumed until the next reshuffle** (like the old mine_grid
    `_spent_mines`). Incoming mine positions are **telegraphed during the `0.8s` window** (dim markers) and only
    arm when the new set goes live.
- **Fairness rule (acceptance):** telegraph ≥ `0.8s`; author position sets so the max gap from any current zone
  to the nearest next-set zone ≤ `player_speed × telegraph` — i.e. both players can always reach a safe zone
  before the current set expires. No arena state where a player is unavoidably off-zone.

**Spec 2 — Roaming Sawblades** (rework `PinwheelMechanic`; extends `ArenaMechanic`, no obstacles). 3 spinning
blades translate around the whole arena and bounce off walls; no fixed safe spot.
- **Blades:** count `3` in all rooms (arena size is fixed — no "smaller arena" branch), radius `30` (spokes are
  visual). Speed `~130 px/s`, straight-line travel, reflect off arena bounds; random initial headings. Spin is cosmetic.
- **Damage (players-only):** `8` on contact, with a per-blade re-hit cooldown `0.5s` (no multi-hit per frame).
  Blades ignore enemies and don't collide with each other physically.
- **No-unavoidable-overlap guarantee (acceptance):** clamp blade motion so no two blade **centres** come within
  `2×radius + 120px` — i.e. a dodge lane ≥ `120px` (> player diameter) always exists between any two blades.
  Blade speed ≤ `1.2× player speed` so a player can always outrun/juke. Never let blades collectively wall off a
  region. **Room-gen constraint:** do not pair this WHERE with an arena-shrinking TWIST, so the `120px` lane
  guarantee always holds at fixed arena size.

**Spec 3 — Pop-up Pillars** (rework `PopupPillarsMechanic`; extends `CoverMechanicBase`, physical cover →
obstacle cap + reachability apply). Denser, irregular, telegraphed, with a rise hazard.
- **Layout:** exactly `9` pillars at hand-authored **irregular** positions; author `3` layout sets, pick one per
  room. Varied sizes `200–260`. Physical cover through `CoopManager.rebuild_obstacles` (connectivity + relocation as today).
- **Cycle per pillar:** down (safe) → rising/telegraph `0.4s` → up (solid cover) `1.8s` → down `1.2s`. Stagger
  per-pillar phase offsets so they don't pop in unison (readable rhythm).
- **3-state color:** down = dim low-alpha; rising = amber dashed pulsing (warning); up = solid blue + top highlight.
- **Rise-damage (players-only):** a player standing on a pillar footprint as it rises takes `10` dmg, once per
  rise. Enemies unaffected.
- **Fairness rule (acceptance):** rising telegraphed ≥ `0.4s`; footprint-only damage, escapable within the
  telegraph at base speed; connectivity check guarantees a traversable path at every phase; respect
  `MAX_OBSTACLE_ENEMIES=160`.

---

## Category 5 — Next-room card UI **(DESIGN / UX)**

**Player findings:**
- "what top left sign on cards mean?"
- "also needs better visibility on what is chosen right now in next room screen"

- **Top-left marker identified + DECISION.** It's the **trait/archetype icon** from `_trait_icon_text()`
  ([RunFlow.gd:214](../../scripts/ui/RunFlow.gd)), a cryptic ASCII fallback glyph (`O` open, `S` swarm, `F`
  flame, `!` used for BOTH bolt and bomb, `[]`, `^`, `<>`, `#`, `*`). A trait name already renders right beside
  it (RunFlow.gd:118), so the glyph is redundant and confusing. **DECISION: drop the glyph, emphasize the
  name.** Remove the ASCII symbol; keep/strengthen the trait/archetype name; **no dot** — name only (decided).
  (Same fix family as the objective-panel `H/K/C` fallback glyphs — could be batched.)
- **Current selection not visible + DECISION.** Cards are Buttons with a subtle focus cue (border lightened 0.22
  / width 1→2, `RunFlow.gd:179`) and a subtle hover bg tint (`RunFlow.gd:176`). Hover is **not absent** (review
  correction) — both cues are just too weak to read at a glance. **DECISION: exactly one active card at a time —
  mouse hover transfers focus to the hovered card**, so focus is the single source of truth for the strong style.
  (Otherwise a pad-focused card + a mouse-hovered *other* card would both light up, breaking the "other dims"
  rule.) The focused card gets a glowing border + background tint + ~1.03 scale (centered `pivot_offset`; verify
  the scale-up doesn't clip or overlap the sibling card inside its container); the other card dims. No text/arrow
  marker.

---

## Category 6 — Encyclopedia gamepad navigation **(BUG, code-confirmed)**

**Player finding:**
- "cant reach encyclopedia inpuase menu with gamepad, alwas skps"

**Confirmed in `scripts/game/PauseDebugUi.gd`:** `_configure_pause_focus()` (line ~294) builds the
focus-neighbor loop over only `[_resume_button, _pause_retry_button, _pause_main_menu_button]`. The
Encyclopedia button is inserted afterward by `_ensure_pause_encyclopedia_button()` (line ~305) and is **never
added to the focus chain**, so D-pad navigation skips over it entirely. Fix: include the Encyclopedia button in
the focus-neighbor wiring (rebuild the chain after inserting it, or add it to the button list before wiring).
Small, isolated fix.

---

## Implementation slices (Codex-ready)

Order: A → B → C → D → E. Each is a bounded patch; follow the Codex rules + validation checklist above. D
depends on A1 (gating). Slice E specs are approved (Spec 1/2/3 in "WHERE mechanical specs").

### Slice A — Build-fit + gating + encyclopedia focus

- **Baseline:** `b7bf0e5`.
- **A0 — audit (DONE ✅, approved):** [`v4-slice-a0-mutation-audit.md`](v4-slice-a0-mutation-audit.md). Tier 1 +
  Tier 1–3 gates approved as A1 scope.
- **A1 — implement (two separate commits):**
  - **Commit A1a — mutation gating (subsystem: mutations):**
    - **In scope:** add runtime support for `requires_ability` (offer in `_mutation_requirements_met`
      `MutationSystem.gd:324` **and** effect targeting in `_mutation_targets_item` `:395` /
      `get_ability_rare_effects` `:180`) and `requires_weapon_tags` (offer, checks `RunState.get_weapon` tags);
      apply the Tier 1 gates (`turret_twin`→turret, `mf_extra_mines`→minefield, `orbit_expanding`→orbit,
      `dash_shockdash`→dash, `sw_resonance`→shockwave, `shield_aegis_burst`→shield, `oc_piercing_overdrive`→
      overcharge + `requires_weapon_tags:["projectile"]`); **remove** `blink_twin_charge`; fix Tier 2 commons
      (`move_speed` → `requires: []` universal; `wide_pulse` → **`area_scalable` treatment** parallel to
      `duration_scalable` (flag area abilities, offer iff the kit has one, and expand the `_build_runtime_ability`
      area-scaling key set beyond `radius`/`orbit_radius`/`distance` — see A0 §2 for the full key set); `duration`
      → `duration_scalable`: swap the `_build_runtime_ability` predicate `CoopManager.gd:466` from
      `type != instant/movement` to a `duration_scalable` flag, and flag **Afterburn / Quake / Shield /
      Overcharge** in `data/abilities.json`.
      **Orbit is NOT flagged here** — Orbit's `duration_scalable` + `orbit_lifetime` land atomically in Slice B,
      so A1 never ships a Duration card whose Orbit effect is a no-op). **Tier 3 (approved):** add
      `requires_ability` to `implosion`→momentum_burst, `legion`→summon, `aegis`→reinforce.
    - **Files:** `data/mutations.json`, `data/abilities.json`, `scripts/game/MutationSystem.gd`,
      `scripts/game/CoopManager.gd`.
    - **Out of scope:** any damage/number balance; ability-feel reworks (Slice D); the **entire Orbit lifetime
      feature** (Slice B, atomic: Orbit `duration_scalable` flag + `orbit_lifetime` + routing + node expiry).
      Duration's A1 behavior check therefore covers Afterburn/Quake/Shield/Overcharge only — not Orbit.
    - **Acceptance:** the A0 "Acceptance criteria (A1)" behavior checks (temp headless roll script or manual).
  - **Commit A1b — encyclopedia focus (subsystem: pause UI):**
    - **In scope:** include the Encyclopedia button in `_configure_pause_focus` (`PauseDebugUi.gd:294`) — rebuild
      the focus-neighbor chain after `_ensure_pause_encyclopedia_button` (`:305`) inserts it.
    - **Out of scope:** any other pause-menu behavior.
    - **Acceptance:** with a gamepad, D-pad reaches Resume ↔ Encyclopedia ↔ Retry ↔ Main Menu in a loop.
- **Regression:** parse + Bootstrap smoke boot; roll upgrade cards in a run without error.

### Slice B — OP balance (Tank sustain + Orbit)

- **Baseline:** post-A1. Lever decided — no profiling seam; measure the HP/s drop after implementing as
  validation (not a gate).
- **In scope:**
  - **Tank sustain — overshield cap + decay (DECIDED):** tighten the full-HP→overshield conversion; leave
    Bloodthirst heal-per-kill, Gorge/Overflow, and Blood Frenzy heal untouched. First-pass: overshield cap
    `0.25 → 0.16` (of max HP), decay `9 → 13`. (Tunable; validate the effective HP/s drop live.)
  - **Orbit lifetime (atomic — the whole feature lands here):** flag Orbit `duration_scalable` in
    `data/abilities.json`; add an `orbit_lifetime` stat (first-pass `20s`); keep slot-active `duration` below the
    `15s` cooldown (keep `5s`); make `OrbitNode` expire at `orbit_lifetime`; route the Duration multiplier onto
    `orbit_lifetime` (Orbit special-case in `_build_runtime_ability`, `CoopManager.gd:466` — not slot-active
    `duration`). **No cap** (overlap scales with cooldown-reduction/Duration investment). Orbit-only.
- **Files:** `data/abilities.json` (orbit `duration_scalable` + `orbit_lifetime` + `duration`); the Tank
  overshield-conversion site in the Bloodthirst passive (locate in CoopManager/Player — search overshield
  cap/decay); `scripts/game/OrbitNode.gd` (lifetime despawn); the orbit spawn / `_set_slot_active` path;
  `scripts/game/CoopManager.gd` `_build_runtime_ability` (route Duration → `orbit_lifetime` for Orbit).
  (`MutationSystem.get_ability_duration_multiplier` already supplies the global multiplier — no change there.)
- **Out of scope:** other classes; other deployables' persistence; the other Tank levers (heal/kill,
  Gorge/Overflow, Blood Frenzy) — untouched this pass.
- **Acceptance:** overshield caps at ~16% max HP and decays faster (Tank no longer effectively immortal in a
  dense room — spot-check live); Orbit despawns after `orbit_lifetime`; **Duration is offered for an Orbit build
  and raises `orbit_lifetime` (uptime rises)**; base ~2 concurrent, more with investment.
- **Regression:** parse + smoke boot; a Tank run and an Orbit run play without error.

### Slice C — Next-room card readability (subsystem: RunFlow card UI)

- **Baseline:** post-B.
- **In scope:** in `scripts/ui/RunFlow.gd` — drop the ASCII trait glyph (remove `_trait_icon_text` usage
  `:214`/`:118`, keep/strengthen the trait name; **no category dot** — name only); strong active-card
  highlight in `_apply_route_card_style` (`:168`) — glow border + bg tint + ~1.03 scale via centered
  `pivot_offset`, other card dims; **hover transfers focus** so exactly one card is active (focus = source of
  truth). Verify the scale doesn't clip/overlap the sibling in its container.
- **Out of scope:** card data/logic; the objective-panel `H/K/C` glyphs (same fix family — batchable later, not now).
- **Acceptance:** no ASCII glyph on cards; exactly one card highlighted at a time under both mouse and pad;
  active card visibly scaled + glowing without clipping; the other dims; selecting a card still launches the room.
- **Regression:** parse + smoke boot; next-room screen navigable by pad and mouse.

### Slice D — Ability feel (subsystem: 3 abilities) — after A1

- **Baseline:** post-C. (Depends on A1: resonance is now Shockwave-only, shockdash Dash-only.)
- **In scope (concrete first-pass values, tunable):**
  - **Shockwave Resonance** → one big delayed slam: replace `sw_resonance` params `{extra_pulses, pulse_interval}`
    with `{slam_delay: 0.5, slam_radius_mult: 1.5, slam_damage_mult: 1.3}`, and rework
    `schedule_player_shockwave_resonance` (`CombatEffects.gd:142`) to schedule ONE larger slam at `slam_delay`
    (radius × `slam_radius_mult`, damage × `slam_damage_mult`) instead of N staggered equal pulses.
  - **Shockdash** → `dash_shockdash` `passthrough_damage` `20 → 45`.
  - **Afterburn** → burning wake following the player: during the `3s` duration, emit a burning segment at the
    player's position every `~0.15s`; each segment lives `1.5s` and applies the existing Afterburn tick
    (`10` dmg / `0.35s`). **Segment radius = the compiled `trail_radius`** — set data base `trail_radius: 70` and
    read the scaled value per segment; do **not** hardcode `70`, or Wide Pulse's `area_scalable` scaling of
    `trail_radius` is lost. Replaces the single placed field. (Locate the Afterburn field-spawn runtime in D.)
- **Out of scope:** other abilities; gating (done in A1); numbers beyond these three.
- **Acceptance:** Resonance produces one larger delayed slam (not 2 small pulses); Shockdash noticeably harder;
  Afterburn trails behind movement. First-pass values flagged for live feel-check.
- **Regression:** parse + smoke boot; the three abilities fire without error.

### Slice E — WHERE catalog (subsystem: arena mechanics)

- **Baseline:** post-D. Specs authored + approved — implement per Spec 1/2/3 in "WHERE mechanical specs"
  (concrete values, players-only damage, fairness rules). Consider splitting into 3 commits (Hazard Floor merge;
  sawblades + pillars; cuts) since it's the largest slice.
- **In scope:**
  - **Merge** `IslandsMechanic` + `PulsingGridMechanic` → one `HazardFloorMechanic` (Islands model, organic
    drifting safe zones + telegraph; `fire | frost | mine` skins as distinct route options).
  - **`PinwheelMechanic` → roaming sawblades** per spec.
  - **`PopupPillarsMechanic`** → more pillars + 3-state color + damage-on-rise + hand-authored organic clusters;
    respect `MAX_OBSTACLE_ENEMIES=160` + reachability.
  - **Cut** `SlidingGatesMechanic`, `BulwarkMechanic`, `ShiftingMazeMechanic` — delete scripts + `.uid`s and
    scrub every reference in `data/room_archetypes.json`, CoopManager WHERE activation, the where-name/
    Encyclopedia formatters, and the PerfRunner `where:<id>` smoke lists.
- **Out of scope:** untouched survivors (Tesla Arcs, Drifting Clouds, Bastion, Drifting Cover); non-WHERE systems.
- **Acceptance:** per-spec fairness rules met; WHERE `--smoke` passes for Hazard Floor (each skin), roaming
  sawblades, pop-up pillars; cut mechanics leave no dangling references; `flowfield_stress` / `entity_ramp` hold.
- **Regression:** parse + smoke boot + WHERE smokes + a perf probe; a room with each new mechanic plays.

## Decision status

**Nothing is open.** All design, gating, and lever decisions are made; the Slice E WHERE specs are authored with
concrete values; Tier 3 is in A1 scope. The remaining numbers are **first-pass tuning validated live** (listed
below) — not open decisions. Codex can implement Slices A→E end-to-end following the specs.

Decided (no longer open) — A0 gate assignments approved 2026-07-14 (see the audit file):
- **Twin Charge → removed** (Blink is gone; not rebuilt).
- **Tier 1 gates** → `requires_ability`: turret / minefield / orbit / dash / shockwave / shield respectively;
  **Piercing Overdrive → `requires_ability: overcharge` + `requires_weapon_tags: [projectile]`**.
- **Tier 2 commons** → `move_speed` → universal (`requires: []`); **`wide_pulse` → `area_scalable` treatment**
  (offer iff the kit has an area ability; scale that ability's full area-key set — parallel to Duration, not a
  blind "universal"); **Duration** → offered if the kit has a `duration_scalable` ability; multiplier applies
  only to `duration_scalable` abilities (offer + effect; Orbit scales `orbit_lifetime`, flagged in Slice B).
- **Tier 3 precision tightens** → **in A1** (approved): `implosion`→momentum_burst, `legion`→summon,
  `aegis`→reinforce.
- **Tank sustain lever** → overshield cap `0.25→0.16` + decay `9→13` (Slice B).
- **WHERE specs** → authored with concrete values (Spec 1/2/3), all hazards players-only.

First-pass values are set in the specs above; these get a **live feel-check** after implementation (validation,
not open decisions): Shockdash `45`, Afterburn wake segments, sawblade count `3`/speed `130`/damage `8`,
Hazard-Floor telegraph `0.8s`/cycle `3.6s`/skin damage, Pop-up Pillars `9`/rise `10`, Orbit `orbit_lifetime`
`20s` + slot-active `5s`, Tank overshield `0.16`/decay `13`.

Out of scope (rejected, not pending): generalize-the-effects adaptive mutation families (Option B) — we chose
tighten-gating instead.
