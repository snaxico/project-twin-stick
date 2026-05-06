# Architecture

## Folder Ownership

- `scenes/`: scene composition for world, player, enemies, weapons, UI, and run/menu flows
- `scripts/`: gameplay and runtime logic
- `data/`: editable JSON definitions
- `assets/`: sprites, audio, fonts, and imported content only
- `docs/process/`: source of truth for scope, roadmap, and architecture
- `docs/development/`: current state and session memory

## Runtime Boundaries

- Simulation owns movement, aim rules, combat, revive logic, room rules, loot rules, and run progression.
- Presentation owns visuals, HUD, modifier tinting, hit feedback, particles, and camera feel.
- Scene files compose nodes but do not become the place where rules are hidden.
- Placeholder visuals should stay Godot-native through the current prototype slices. The current paused build uses simple placeholder geometry, a faux 3/4 view, and minimal player/enemy color identity for readability rather than any custom art pipeline.
- Pre-run configuration flows should pass state through scene ownership, not early autoloads. The current menu uses a bootstrap scene that hands off explicit player configs into the run flow.

## Singleton Policy

- No autoloads in Patches 0-4.
- Introduce exactly one autoload in Patch 5: `RunState.gd`.
- `RunState.gd` owns cross-room run state only: active players, health persistence, run-mode recovery rules, node progression, current node selection, acquired upgrades, shared gold, and run outcome.
- Patch 9 introduces `ProfileState.gd` for persistent save data, meta currency, and unlock ownership outside individual runs.

## Input And Bootstrap Note

- Movement remains action-map driven for `p1_*` through `p4_*`.
- Aim and some control routing are resolved through a code-side control layer so the prototype can stay clean and playable without premature editor-side input plumbing.
- Keyboard control currently uses mouse aim, left mouse primary fire, and right mouse secondary fire.
- Gamepad control currently uses `R2` for primary fire, `L2` for secondary, and a movement-first dash direction with aim fallback.
- Aim mode and screen-effect settings now live in shared bootstrap and pause-menu UI instead of a debug HUD.
- Player count, control source, and run-mode selection happen in a bootstrap menu before the run-flow scene starts.

## Run Flow Note

- The bootstrap menu hands off to a run-flow scene instead of opening the room directly.
- `RunFlow` owns connected-map rendering, node inspection, node selection, and room transitions.
- `GameWorld` remains the combat-room runtime and receives per-room configuration from the selected node.
- `RunState` persists health, run-mode recovery behavior, gold, acquired items, connected-map progression, reachable node state, and final run outcome across those transitions.
- `ProfileState` persists unlocks and meta currency across application launches and gates which run upgrades may appear in reward/shop pools.
- Mainline run flow now uses a row-based connected graph:
  - start row exposes three nodes
  - non-boss rows expose `2–4` nodes across fixed columns
  - edges only connect to the next row and only stay in the same column or move by one column
  - debug single-room flow remains a separate simplified path

## Core Data Contracts

- `PlayerConfig`: `player_id`, `control_source`, `tint`, `aim_mode`
- `weapons.json`: weapon definitions and later balance data
- `enemies.json`: enemy archetypes and tuning values
- `modifiers.json`: room modifier definitions
- `items.json`: item definitions and descriptive text
- `unlocks.json`: persistent unlock definitions and costs

## Planned Runtime Signals

- `room_cleared`
- `player_downed`
- `player_revived`
- `all_players_dead`
- `loot_choice_resolved`
- `run_completed`

Signals stay local to the systems that own them until cross-room state exists.

## Current State Note

- The current build includes early Patch 8 work:
  - `1–4` player support
  - extra room layouts
  - extra modifiers
  - light placeholder-only juice
- The current build also includes an early Patch 9 baseline:
  - persistent meta profile save data
  - menu-side unlock purchasing
  - run-end return-to-menu flow for spending unlock currency
- Those systems are present in code but still need broader tuning and readability passes before they should be treated as stable.
