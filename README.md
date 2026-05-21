# Project Twin-Stick

Same-screen local co-op neon auto-attack roguelite prototype built in Godot 4.6.2.

## Current Direction

This is a **neon auto-attack co-op survivor roguelite**. The player auto-attacks the nearest enemy. Skill expression comes from movement, positioning, shockwave timing, dash usage, route choice, and gold spending.

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
4. Run flow uses a node map: combat, elite, rest, shop, boss.
5. Combat and elite rooms use `survive` as the room objective, with hold-zone as a parallel side objective.
6. Auto-attack fires at the nearest enemy. Player focuses on movement, dash, shockwave, and room pressure.
7. Enemies drop gold. Gold buys room-end mutations and shop services.
8. Repeat until boss.

## Active Loadout

Each player has:
- **Weapon: Rifle** (auto-fire) — 3 shots/sec, glowing orb projectiles, pure nearest targeting
- **Primary Skill: Shockwave** (RT / Space) — expanding ring, 5s cooldown, 950 knockback, centered on player
- **Secondary Skill: Dash** (LT / B / Ctrl) — movement burst in move direction, 5s cooldown, shield on activation, `+33%` tuned travel range
- **Mutations** — bought after combat with shared-drop/personal-wallet gold flow

## Mutations

Mutations are now split into:
- **Commons** — upgradable to `Lv3`, shown in normal combat rewards
- **Rares** — one-off effects, shown in elite rewards

Current common effects include:
- pierce
- rapid fire
- big shot
- split shot
- skill range
- skill cooldown
- knockback

Current rare effects include:
- ricochet
- fire trail
- dash damage

## Enemies

- **Chaser** (triangle) — fast melee swarmers, HP 21, speed 292.5
- **Charger** (pentagon) — telegraph + dash attack, HP 40, speed 247.5
- **Spitter** (hex) — ranged kiting enemy, 1 projectile, 1.0s fire interval
- **Boss** (star/crown) — projectile bursts, HP 180, speed 157.5
- **Elite mini-bosses** — elite charger, elite spitter, elite support

## Visual Style

Neon geometric: dark background, glowing Polygon2D shapes, Line2D grid floor, color shifts per room depth via HSV hue rotation. Player is a chevron (P1 cyan, P2 magenta). Procedural placeholder visuals remain acceptable while gameplay tuning stays the priority.

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

## Branch

- `v2/core-refactor` — active branch and GitHub default branch

## What's Deferred

- Boss redesign
- 3-4 player support
- Audio pass
- Meta progression
- Large art-production pass

## Documentation

- Design direction: `docs/design/game-direction.md`
- Roadmap: `docs/design/roadmap.md`
- Implementation plan: `docs/design/implementation-plan.md`
- Current state: `docs/development/current-state.md`
- Process docs: `docs/process/`
