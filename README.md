# Project Placeholder

Personal couch co-op twin-stick roguelite prototype built in Godot 4.6.2.

## Current Position

- Development is paused after a Patch 8 baseline pass.
- The prototype remains locked to a same-screen, room-based, local co-op structure.
- The first-playable milestone is still defined by the Patch 7 target: one complete 10-15 minute run that is readable, stable, and usable without explanation.
- The current build already includes early Patch 8 work: `1–4` player support, added layout variety, added modifiers, and light placeholder-only presentation juice.

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
- shared gold economy and shared upgrade selection
- shared primary loadout variants: `Rifle`, `Scatter`, `Slug`
- shared secondary loadout variants: `Grenade`, `Cluster`, `Siege`
- mouse aim and mouse buttons for keyboard/mouse play
- `L2` secondary for gamepad play
- movement-first dash direction with aim fallback
- downed and proximity-revive flow
- room modifiers with pre-fight telegraphing
- multiple room layout presets
- placeholder boss encounter
- faux 3/4-view 2D presentation

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
