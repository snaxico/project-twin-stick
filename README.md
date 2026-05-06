# Project Placeholder

Personal couch co-op twin-stick roguelite prototype built in Godot 4.6.2.

## Current Position

- Development is now in a cleanup, HUD, menu, and validation phase after a larger Patch 9 progression rework.
- The prototype remains locked to a same-screen, room-based, local co-op structure.
- The first-playable milestone is still defined by the Patch 7 target: one complete 10-15 minute run that is readable, stable, and usable without explanation.
- The current build includes connected map flow, persistent meta progression, per-player inventories, and in-room loot/shop handling.
- The current build also includes a full juice pass, an enemy behavior pass, a secondary identity pass, and a debug start-gear mode.
- The current build now also includes a working pause flow, gamepad-driven menu confirm/back navigation, and shooter-colored projectiles.
- The current build now also includes a readability-and-balance follow-up: lower ranged pressure, clearer aiming/projectile contrast, and separate grenade and mine secondary families.
- The current build now also includes a connected route map, run-mode selection, personal loot/shop flow, manual room exits, and the first sprite-backed player/weapon pass.

## Stack

- Engine: Godot 4.6.2 stable
- Language: GDScript
- Data: JSON-first content definitions
- Platform target: Windows desktop first

## Current Runtime

1. Open the project in Godot 4.6.2 stable and run the main scene.
2. A front menu opens with `Play`, `Meta`, `Settings`, and `Debug`.
3. `Play` opens run setup with `1–4` players, per-player control source selection, and `Normal` / `Easy` run modes.
4. `Debug` opens the separate debug launcher for full-run overrides or single-room starts.
5. Starting a run opens a connected node-map flow with room, modifier, and reward preview.
6. Combat and elite nodes launch survival rooms or generator-objective rooms with recurring enemy pressure and room modifiers.
7. Cleared combat and elite rooms now drop physical loot, then wait for players to exit through an opened exit zone.
8. Shop nodes launch a real shop room with personal offers, personal gold wallets, and a shared ready-up flow.
9. Clearing the final boss room resolves into a run-victory screen and meta-gold summary. Losing all active players resolves into a defeat screen with the same return path.

## Current Feature Baseline

- `1–4` local players
- persistent profile save data
- meta-gold rewards after each completed run
- persistent unlock purchases that gate future reward/shop pools
- dedicated run-end summary panel with direct meta-menu handoff
- per-player gold wallets
- per-player inventories with:
  - `2` primary slots
  - `2` secondary slots
  - selected-slot switching
  - passive ownership
- data-driven primary weapons: `Rifle`, `Scatter`, `Slug`
- data-driven secondary weapons: `Grenade`, `Cluster Grenade`, `Siege Grenade`, `Mine`, `Shrapnel Mine`, `Heavy Mine`
- weapon duplicate leveling through `Lv1–Lv5`
- physical loot drops with Take/Scrap resolution
- contested loot rolls and replacement flow when weapon slots are full
- real shop rooms with personal offers and personal purchases
- manual room exit after loot/shop resolution
- debug mode for selecting starting primary and secondary gear
- normal/easy run modes
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
- connected map with linked route selection before each room
- first sprite-backed presentation pass for player 1, the rifle, and player bullets
- player-facing HUD with per-player wallets, weapon slots, cooldowns, timer/objective header, and boss bar

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
  - dash: `B / O`
  - pause: `Start`
  - menu confirm: `A / X`
  - menu back: `B / O`

## Placeholder Policy

- Use Godot-native placeholder visuals only during the current prototype stage.
- The art pipeline is still provisional, but sprite integration has started.
- Current readability is mixed:
  - `P1`: custom standing/running sprite, attached rifle sprite, and sprite bullet
  - `P2`: blue
  - `P3`: yellow
  - `P4`: orange
  - enemies: colored placeholder silhouettes
- Players `2–4` still use procedural bodies.

## Documentation

- Process docs: `docs/process/`
- Development memory: `docs/development/`
