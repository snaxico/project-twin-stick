# Project Placeholder

Personal couch co-op twin-stick roguelite prototype built in Godot 4.6.2.

## Current Position

- Development is now in a cleanup, encounter-identity, HUD, menu, and validation phase after the Patch 13 runtime pass and Patch 14 data cleanup.
- The prototype remains locked to a same-screen, room-based, local co-op structure.
- The first-playable milestone is still defined by the Patch 7 target: one complete 10-15 minute run that is readable, stable, and usable without explanation.
- The current build includes connected map flow, persistent meta progression, per-player inventories, personal gold wallets, and in-room loot/shop handling.
- The current build also includes expanded primary behavior families, split grenade-vs-mine secondary behavior, a compact icon-first HUD, and the first sprite-backed player/weapon pass.
- The current build now also includes encounter recipes, five active combat layout identities, `capture_the_hill`, telegraphed hazard modifiers, and an Encounter Builder flow for single-room validation.
- The current build now also includes a combat spectacle pass, a short post-dash shield, faster melee-first enemy pressure, and arena-wide valid spawn sampling instead of fixed spawn markers.

## Stack

- Engine: Godot 4.6.2 stable
- Language: GDScript
- Data: JSON-first content definitions
- Platform target: Windows desktop first

## Current Runtime

1. Open the project in Godot 4.6.2 stable and run the main scene.
2. A front menu opens with `Play`, `Meta`, `Settings`, and `Encounter Builder`.
3. `Play` opens run setup with `1–4` players, per-player control source selection, and `Normal` / `Easy` run modes.
4. `Encounter Builder` opens the single-room validation flow with room, objective, modifier, layout, and depth overrides, then returns to the builder after the encounter ends.
5. Starting a run opens a connected node-map flow with room, modifier, and reward preview.
6. Combat and elite nodes launch recipe-driven rooms with `survive`, `capture_the_hill`, or `destroy_generators` objectives, recurring enemy pressure, and room modifiers.
7. Cleared combat and elite rooms now drop physical loot, then wait for players to exit through an opened exit zone.
8. Shop nodes launch a real shop room with personal offers, personal gold wallets, replacement support, and a shared ready-up flow.
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
- expanded primary behavior families: `Incinerator`, `Beam Lance`, `Arc Caster`
- data-driven secondary weapons: `Grenade`, `Cluster Grenade`, `Siege Grenade`, `Mine`, `Shrapnel Mine`, `Heavy Mine`
- weapon duplicate leveling through `Lv1–Lv5`
- physical loot drops with Take/Scrap resolution
- contested loot rolls and replacement flow when weapon slots are full
- real shop rooms with personal offers and personal purchases
- manual room exit after loot/shop resolution
- Encounter Builder single-room launches with explicit room/objective/modifier/layout/depth selection
- normal/easy run modes
- pause menu with resume and room restart
- gamepad menu confirm/back support
- mouse aim and mouse buttons for keyboard/mouse play
- `L2` secondary for gamepad play
- movement-first dash direction with aim fallback
- downed and proximity-revive flow
- room modifiers with pre-fight telegraphing
- multiple room layout presets with five active normal-run identities: `default`, `lane`, `pillars`, `ring`, `pockets`
- enemy archetypes: `Chaser`, `Spitter`, `Charger`, `Bruiser`, and placeholder boss
- placeholder boss encounter
- clean rectangular grid arena with placeholder walls
- arena framing pushed closer so the room fills most of the screen
- projectile, impact, and grenade burst colors now inherit from the firing actor
- mine secondaries now use instant placement plus proximity detonation
- arena-wide valid spawn sampling and feeler-based enemy obstacle steering
- return-to-menu flow after a run so meta unlocks can be spent
- connected map with linked route selection before each room
- first sprite-backed presentation pass for player 1, the rifle, and player bullets
- player-facing HUD with compact per-player wallets, icon-based weapon slots, passive chips, cooldowns, timer/objective header, and boss bar

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
- The current HUD uses real rifle / scatter / slug sprites as primary-slot icons; secondaries and passives still use placeholder badges.

## Documentation

- Process docs: `docs/process/`
- Development memory: `docs/development/`
