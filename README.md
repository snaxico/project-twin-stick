# Project Placeholder

Personal couch co-op twin-stick roguelite prototype built in Godot 4.6.2.

## Current Position

- Development resumed for a Patch 9 baseline pass.
- The prototype remains locked to a same-screen, room-based, local co-op structure.
- The first-playable milestone is still defined by the Patch 7 target: one complete 10-15 minute run that is readable, stable, and usable without explanation.
- The current build includes early Patch 8 work plus a Patch 9 baseline for persistent meta progression and unlocks.
- The current build also includes a full juice pass, an enemy behavior pass, a secondary identity pass, and a debug start-gear mode.
- The current build now also includes a working pause flow, gamepad-driven menu confirm/back navigation, and shooter-colored projectiles.
- The current build now also includes a readability-and-balance follow-up: lower ranged pressure, clearer aiming/projectile contrast, and separate grenade and mine secondary families.

## Stack

- Engine: Godot 4.6.2 stable
- Language: GDScript
- Data: JSON-first content definitions
- Platform target: Windows desktop first

## Current Runtime

1. Open the project in Godot 4.6.2 stable and run the main scene.
2. A bootstrap menu opens first and currently defaults to `1 Player` plus `Gamepad`.
3. The menu supports `1–4` players and per-player control source selection.
4. Starting a run opens a simple node-map flow with room, modifier, and reward preview.
5. Combat and elite nodes launch survival rooms with recurring enemy spawns and room modifiers.
6. Rest and shop nodes resolve through lightweight placeholder progression flows.
7. Clearing the final boss room resolves into a run-victory screen. Losing all active players resolves into a defeat screen.

## Current Feature Baseline

- `1–4` local players
- persistent profile save data
- meta-gold rewards after each completed run
- persistent unlock purchases that gate future reward/shop pools
- dedicated run-end summary panel with direct meta-menu handoff
- shared gold economy and shared upgrade selection
- shared primary loadout variants: `Rifle`, `Scatter`, `Slug`
- shared secondary loadout variants: `Grenade`, `Cluster Grenade`, `Siege Grenade`, `Mine`, `Shrapnel Mine`, `Heavy Mine`
- debug mode for selecting starting primary and secondary gear
- pause menu with resume and room restart
- gamepad menu confirm/back support
- mouse aim and mouse buttons for keyboard/mouse play
- `L2` secondary for gamepad play
- movement-first dash direction with aim fallback
- downed and proximity-revive flow
- room modifiers with pre-fight telegraphing
- multiple room layout presets
- enemy archetypes: `Chaser`, `Spitter`, `Charger`, and placeholder boss
- placeholder boss encounter
- clean rectangular grid arena with placeholder walls
- arena framing pushed closer so the room fills most of the screen
- projectile, impact, and grenade burst colors now inherit from the firing actor
- mine secondaries now use instant placement plus proximity detonation
- return-to-menu flow after a run so meta unlocks can be spent

## Controls

- Keyboard/mouse:
  - move: `WASD`
  - aim: mouse
  - primary fire: left mouse button
  - secondary: right mouse button
  - dash: `Space`
- Gamepad:
  - move: left stick
  - aim: right stick
  - primary fire: `R2`
  - secondary: `L2`
  - dash: `A`
  - pause: `Start`
  - menu confirm: `A / X`
  - menu back: `B / O`

## Placeholder Policy

- Use Godot-native placeholder visuals only during the current prototype stage.
- No custom sprite production or final art pipeline has been started.
- Current player/enemy readability relies on simple colored placeholder forms:
  - `P1`: green
  - `P2`: blue
  - `P3`: yellow
  - `P4`: orange
  - enemies: red

## Documentation

- Process docs: `docs/process/`
- Development memory: `docs/development/`
