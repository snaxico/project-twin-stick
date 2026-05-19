# Project Twin-Stick — v3 Neon Roguelite

Same-screen local co-op neon auto-attack roguelite prototype built in Godot 4.6.2.

## Current Direction

This is a **neon auto-attack co-op survivor roguelite**. The player auto-attacks the nearest enemy — all skill expression is movement, positioning, shockwave timing, and dash usage. Mutations snowball the auto-attack into screen-filling chaos over a run.

Reference mix: Vampire Survivors (auto-attack escalation), Brotato (wave structure, camera zoom), Geometry Wars (neon aesthetic).

## Stack

- Engine: Godot 4.6.2 stable
- Language: GDScript
- Data: JSON content definitions
- Platform target: Windows desktop

## Current Runtime

1. Open the project in Godot 4.6.2 and run the main scene.
2. Front menu: `Play` or `Encounter Builder`.
3. `Play` opens run setup: 1-2 players, per-player control source, Normal/Easy mode.
4. Run flow uses a node map: combat, rest, boss.
5. Combat rooms have objectives: Survive (60s) or Hold Zone (capture area).
6. Auto-attack fires at nearest enemy. Player focuses on movement and abilities.
7. Room clears — game pauses, each player picks 1 of 3 mutations.
8. Auto-advances to map. Repeat until boss.

## Active Loadout

Each player has:
- **Weapon: Rifle** (auto-fire) — 3 shots/sec, glowing orb projectiles, pure nearest targeting
- **Primary Skill: Shockwave** (RT / Space) — expanding ring, 5s cooldown, 950 knockback, centered on player
- **Secondary Skill: Dash** (LT / B / Ctrl) — movement burst in move direction, 5s cooldown, shield on activation
- **Mutations** — picked after each room, modify weapon and skill abilities

## Mutations

10 mutations, all visible effects:
- Weapon: ricochet, pierce, split shot, big shot, fire trail, rapid fire, knockback
- Primary Skill: shockwave radius, shockwave cooldown (Quick Pulse)
- Secondary Skill: dash damage

## Enemies

- **Chaser** (triangle) — fast melee swarmers, HP 21, speed 292.5
- **Charger** (pentagon) — telegraph + dash attack, HP 40, speed 247.5
- **Boss** (star/crown) — projectile bursts, HP 180, speed 157.5

## Visual Style

Neon geometric: dark background, glowing Polygon2D shapes, Line2D grid floor, color shifts per room depth via HSV hue rotation. Player is a chevron (P1 cyan, P2 magenta). Future pivot to rubberhose sprites planned once gameplay validates.

## Controls

Gamepad (P1 default):
- Left stick: move
- LT / B: secondary skill (dash)
- RT: primary skill (shockwave)
- Start: pause

Keyboard (P2 default):
- WASD: move
- Ctrl: secondary skill (dash)
- Space: primary skill (shockwave)

Weapon auto-fires at the nearest enemy — no input needed.

## Branch Structure

- `main` — stable pre-rework build (commit `e71d366`)
- `v2/core-refactor` — active v3 development branch

## What's Deferred

- Shop nodes / gold economy
- Third objective type
- Boss redesign
- 3-4 player support
- Audio pass
- Meta progression
- Rubberhose sprite art pivot

## Documentation

- Design direction: `docs/design/game-direction-v3.md`
- Implementation plan: `docs/design/v3-implementation-plan.md`
- Current state: `docs/development/current-state.md`
- Process docs: `docs/process/`
