# V4 — Room & Enemy Redesign: Master Patch (sequenced)

> **One coordinated patch**, built in phase order (LOCKED 2026-07-07). Branch `v4/class-system`, active
> checkout `D:\GameDev\Project_Twin_stick`. Detailed Codex-ready specs live in the referenced sub-plans; this
> doc is the **orchestration** — order, dependencies, and the ship seam. Validate + commit **per phase**
> (one patch, but not one giant commit).
>
> **Validation gate (per phase):**
> ```powershell
> $GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' --quit                        # parse
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=entity_ramp       # perf (avg_fps>=60)
> ```

## The room model (target)

Each room = **WHO** (1 of 6 archetypes) + **WHERE** (exactly 1 arena mechanic; Open is the low-weight
breather) + **TWIST** (0–1 stat modifier). Full spec: [[v4-room-pool.md]]. Selection/card/schema:
[[v4-curated-rooms-plan]].

## Sequence

| Phase | What | Spec | Ships on | Risk |
|---|---|---|---|---|
| **1** | Enemy tiers (telegraphed spitter + shooter cap) **+** card streamline | [[v4-enemy-tiers-plan]] (Codex-ready) · [[v4-curated-rooms-plan]] Slice A | existing tech | none — **fixes the bullet-hell now** |
| **2** | Room foundation: WHO + selection + TWIST (existing modifiers only; WHERE = Open) | [[v4-curated-rooms-plan]] Slices B–D + [[v4-room-pool.md]] | existing modifiers | low |
| **3** | First WHERE mechanic: **pulsing hazard grid** (Fire/Frost/Mine) | this doc §Phase 3 | existing fire/ice/mine hazards | low |
| **4** | **Flow-field perf fix** → unblocks cover | [[v4-flowfield-perf-plan]] (Codex-ready) | — | **⚠ uncertain (9× undiagnosed)** |
| **5** | Remaining Batch-A WHERE: Islands · Pinwheel · Tesla Arcs · Drifting Clouds | this doc §Phase 5 | hazard system | med (new mechanics) |
| **6** | Batch-B WHERE (cover): Bastion · Pop-up Pillars · Sliding Gates · Bulwark · Drifting Cover · Shifting Maze | this doc §Phase 6 | **needs Phase 4** | gated on Phase 4 |

**Ship seam:** Phases **1–3 + 5** = the **shippable core** (complete new room system on the hazard system, no
perf risk). Phases **4 + 6** = the **gated tail** — build only if the flow-field fix hits ≥60fps; if it
doesn't, the core still ships as a complete game and cover becomes a later effort.

## Phase 3 — Pulsing hazard grid (first WHERE)

The cheapest new mechanic (reuses existing hazards) and the one that proves the WHERE slot.
- **Grid overlay:** divide the arena into a coarse grid (~6×4 cells). Cells alternate **safe ↔ hazard** on a
  **slow pulse (~2.5s)** with a **~0.5s telegraph** (cells glow before igniting). Checkerboard phase A/B.
- **Hazard fill:** the active cells spawn the chosen hazard — **Fire** (fire_floor), **Frost** (ice_zone,
  slows), or **Mine** (mines arm on the hazard phase). One system, three WHERE options.
- **Fits the WHERE slot:** a room with WHERE = Fire/Frost/Mine Grid activates this over the (otherwise open)
  arena; damages the swarm too. Touchpoints: reuse the existing hazard spawn (`CoopManager` hazard modifiers)
  + a new grid/pulse driver; drive via the room's `where` field.
- **Acceptance:** grid pulses readably (telegraph → swap), player weaves safe cells while fighting, enemies
  caught in hazard cells; parse + `entity_ramp` ≥60fps.

## Phase 5 — Remaining Batch-A WHERE mechanics

Each is a self-contained hazard mechanic keyed off the room's `where` field, built one at a time (validate +
commit each): **Islands** (safe pads in a hazard sea, reshuffle on pulse) · **Pinwheel** (rotating hazard arms
from center) · **Tesla Arcs** (arcs snap between fixed nodes on a rhythm) · **Drifting Clouds** (toxic gas
blobs drift across). All damage the swarm; all readable/telegraphed. Design notes: [[v4-curated-rooms-plan]]
§Arena layouts. Acceptance per mechanic: readable, hits enemies, no perf regression.

## Phase 6 — Batch-B WHERE mechanics (cover; gated on Phase 4)

Physical dynamic cover (StaticBody2D on layer 1; route via the flow field, block shots per the verified
mechanic). Built one at a time: **Central Bastion** (static, the LOS keeper) · **Pop-up Pillars** (raise/lower
on rhythm) · **Sliding Gates** (passage slides) · **Bulwark** (patrolling wall) · **Drifting Cover** (wander) ·
**Shifting Maze** (lanes reconfigure). Moving cover rebuilds the flow field on state change (gated, infrequent).
Acceptance: routes at ≥60fps @ 200 (Phase 4 must hold), cover blocks shots, no clipping.

## Notes
- Canonical tree `D:\GameDev\Project_Twin_stick` on `v4/class-system`; **parallel Codex may edit — re-read
  before each edit** ([[feedback-parallel-codex]]).
- Validate + commit **per phase**; **don't push unless asked.**
- Phases 3/5/6 introduce new mechanics not yet spec'd to Codex-ready line level — spec each just-in-time before
  building it (Phases 1, 2-schema, 4 already are).
