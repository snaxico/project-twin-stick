# V4 — Room Model: WHO + WHERE + TWIST

> **Rooms have three ingredients** (LOCKED via MC 2026-07-07). Small, curated shape; big variety from rolls.
> Extends the existing `data/room_archetypes.json`. Selection/UI in [[v4-curated-rooms-plan]].
>
> - **WHO** — 1 of **6 curated archetypes** (the enemies).
> - **WHERE** — **1 arena mechanic** (the stage: a grid / moving columns / hazard / cover). *Exactly one per
>   room* so mechanics never fight over the floor. **Most rooms get one; plain Open is the occasional breather.**
> - **TWIST** — **0–1 stat modifier** (light spice on top).

## WHO — 6 base archetypes (the enemies, curated)

Enemy identity from [[v4-enemy-tiers-plan]]; exact `melee_density`/`melee_bias`/`shooters`/`elites` in
[[v4-curated-rooms-plan]] §Composition profiles.

| Archetype | Identity | Depth gate |
|---|---|---|
| **Horde** | chaser swarm, high density | 1+ |
| **Mixed** | balanced bit-of-everything | 1+ |
| **Splitters** | splitter-heavy, multiplies | 4+ |
| **Pressure** | charger + bomber, space-denial | 4+ |
| **Gauntlet** | capped ranged specials + light melee | 4+ |
| **Elites** | 1–2 elites, priority targets | 7+ |

## WHERE — arena mechanics (the stage, **1 per room**)

Each is a full mechanic (not a flag). One rolls per room, from the archetype's themed pool below.

- **Batch A — ship now** (hazard system): Fire Grid · Frost Grid · Mine Grid · Islands · Pinwheel ·
  Tesla Arcs · Drifting Clouds · **Open** (no mechanic — the breather).
- **Batch B — need [[v4-flowfield-perf-plan]]** (physical cover): Central Bastion · Drifting Cover ·
  Pop-up Pillars (moving columns) · Sliding Gates · Shifting Maze · Bulwark.

*(Mechanics defined in [[v4-curated-rooms-plan]] §Arena layouts. Until the flow-field fix lands, Batch-B
mechanics are benched and those archetypes roll from their Batch-A / Open options only.)*

### Themed WHERE pool per archetype (roll 1)

| Archetype | Arena mechanics it can roll |
|---|---|
| **Horde** | Fire Grid, Islands, Pinwheel, Tesla Arcs, Drifting Clouds, Sliding Gates, Open |
| **Mixed** | Fire Grid, Frost Grid, Islands, Pinwheel, Tesla Arcs, Drifting Clouds, Open |
| **Splitters** | Fire Grid, Mine Grid, Tesla Arcs, Shifting Maze, Open |
| **Pressure** | Mine Grid, Bulwark, Sliding Gates, Pop-up Pillars, Shrinking* , Open |
| **Gauntlet** | Central Bastion, Drifting Cover, Pop-up Pillars, Frost Grid, Islands, Tesla Arcs, Fire Grid |
| **Elites** | Drifting Clouds, Central Bastion, Pinwheel, Open |

*Open is weighted **low** (occasional breather), not zero — most rooms get a real mechanic.

## TWIST — stat modifiers (0–1, light spice)

Shared small pool, rolled 0–1 on top of the stage: **Enemy Speed · Shielded · Explosive Death ·
Shrinking Arena · Accelerating Waves.** Light theming (e.g. Pressure favors Shrinking, Splitters favors
Explosive Death). These are the classic stat modifiers that already exist.

## Rules
- A room = **archetype + exactly 1 WHERE (incl. Open) + 0–1 TWIST.** Never two arena mechanics.
- **Depth gating:** archetype availability per its gate; density + shooter budget scale with depth on top.
- **Selection:** 2 combat archetype-choices per step (champion = 1 forced), no-repeat — [[v4-curated-rooms-plan]] Slice C.
- **Card:** archetype name + icon · danger (derived) · ≤2 tags (**the WHERE mechanic + any TWIST**) · reward.
- **Data:** extend `data/room_archetypes.json` — split its modifier list into a **`where_pool`** (arena
  mechanics, roll exactly 1, Open weighted low) and a **`twist_pool`** (stat modifiers, roll 0–1).
