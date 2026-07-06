# Project Twin-Stick

Same-screen local co-op neon auto-attack roguelite prototype built in Godot 4.6.2.

## Current Direction

A **neon auto-attack co-op survivor roguelite** built around four class kits: Mobile, Tank, Controller, and
Risk. Your weapon auto-fires at nearby enemies; skill expression comes from movement, positioning, ability
timing, ultimate cadence, class passives, reward choices, and room routing.

## Stack

- Engine: Godot 4.6.2 stable · GDScript · JSON content · Windows desktop.

## Run Loop

1. Open in Godot 4.6.2 and run the main scene. Front menu: `Play`, `Meta`, `Settings`, or debug
   `Encounter Builder`.
2. Setup: 1-2 players, per-player control source, class, class weapon, and three class abilities.
3. Each class ultimate is inserted into slot 4 automatically.
4. Auto-fire handles the weapon; you focus on movement, ability timing, class passive management, and room
   rewards.
5. Kills feed one shared XP bar; level-ups bank room-end reward picks.

## Classes And Weapons

- **Mobile / Stormrunner:** Rifle or Beam; momentum-focused mobility and Slipstream ultimate.
- **Tank:** Shotgun or Whirlwind; overshield, close-range sustain, and Blood Frenzy ultimate.
- **Controller:** Beam or Arc Wand; summons, constructs, space control, and Overload Grid ultimate.
- **Risk:** Flamethrower or Rocket Launcher; Heat pressure, fire tools, and Firestorm ultimate.

## Abilities & Upgrades

- Every player has four ability slots on controller face buttons `A`, `X`, `B`, `Y`; `Y` is the class ultimate.
- Keyboard ability defaults use number-row `1`, `2`, `3`, `4`.
- Upgrades use common, rare, and Signature tiers with V4 tag-gated offer rules.

## Run Structure

- One continuable room sequence.
- Normal steps offer two next-room cards.
- Champion steps force one champion room.
- Room `10` is the current milestone champion room; clearing it banks a win and offers `Continue` or `End Run`.

## Enemies & Bosses

- Enemies: Chaser, Charger, Spitter, Splitter, Splitter Mini, Bomber.
- Champions: Warden, Hydra, Hive, Pulsar.

## Co-Op

- 1-2 players, same-screen, dynamic zoom camera, no split-screen.

## Branch

- `v4/class-system` is the canonical active branch.
- Older `v2/*` and `v3/*` branches are historical baselines. Do not merge them into V4 wholesale; only port
  reviewed changes that still fit the class-system direction.

## What's Deferred

- Split-screen · real audio assets · `3-4` players · large art pass.
- Current follow-up plan: V4 round 2 performance, bug fixes, balance, class clarity, room variety, and drops.

## Documentation

- Design direction: `docs/design/game-direction.md`
- Current runtime state: `docs/development/current-state.md` · session refresher: `docs/development/start-of-day.md`
- Process / rules / architecture: `docs/process/`
- Active patch plan: `docs/development/v4-round-2-plan.md`
- Shipped round plans + superseded docs: `docs/archive/`
