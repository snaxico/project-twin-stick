# Project Twin-Stick

Same-screen local co-op neon auto-attack roguelite prototype built in Godot 4.6.2.

## Current Direction

A **neon auto-attack co-op survivor roguelite**. Your weapon auto-fires at the nearest enemy;
skill expression comes from movement, positioning, ability timing (OFF/DEF), **Upgrade** choices at
level-ups, and route choice. Reference mix: Vampire Survivors, Brotato, Geometry Wars.

## Stack

- Engine: Godot 4.6.2 stable · GDScript · JSON content · Windows desktop.

## Run Loop

1. Open in Godot 4.6.2 and run the main scene. Front menu: `Play` or `Encounter Builder`.
2. Setup: 1–2 players, per-player control source, Structured or Endless.
3. Auto-fire handles the basic combat; you focus on movement + your two abilities.
4. Kills feed one **shared XP bar**; level-ups bank room-end **Reward screens** (pick one Upgrade).
5. Health resets each room. Push toward the boss. (No gold/shop economy — that was removed in V3.)

## Weapons (round-9 system)

5 peer weapons — **Rifle, Rocket Launcher, Scattergun, Cannon, Railgun**. One active at a time;
a single shared **weapon level (1–5)** preserved when switching. Chosen at the Reward screen via
**Level Up Weapon** (common) and **Change Weapon** (rare) cards.

## Abilities & Upgrades

- **Abilities:** `1 OFF` (LT) + `1 DEF` (RT) from 9 — Shockwave, Dash, Overcharge, Blink, Shield,
  Decoy, Turret, Minefield, Orbit. Each has a rare **Signature** upgrade.
- **Upgrade categories:** Weapon · Effect (burn/frost/venom/bounce) · Attribute (damage/fire-rate/
  HP/…) · Ability.

## Run Structure

- **Structured:** 2-act branching route (combat + optional elites + mid-boss + final boss).
- **Endless:** sequential rooms, boss every 5, score = rooms cleared.

## Enemies & Bosses

- Enemies: Chaser, Charger, Spitter, Splitter, Splitter Mini, Bomber.
- Elites: Elite Charger, Elite Spitter, Elite Support.
- Bosses: Warden, Hydra, Hive, Pulsar.

## Co-Op

- 1–2 players, same-screen, dynamic zoom camera, no split-screen. P2 is keyboard-only for now.

## Branch

- `v3/main` — active branch and GitHub default.

## What's Deferred

- A dedicated performance round (~200-entity ceiling: MultiMesh + caps) · split-screen · real audio
  assets · meta progression · `3-4` players · large art pass.

## Documentation

- Design direction: `docs/design/game-direction.md`
- Current runtime state: `docs/development/current-state.md` · session refresher: `docs/development/start-of-day.md`
- Process / rules / architecture: `docs/process/`
- Active patch plan: `docs/development/playtest-round-10-plan.md`
- Shipped round plans + superseded docs: `docs/archive/`
