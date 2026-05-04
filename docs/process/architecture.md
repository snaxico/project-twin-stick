# Architecture

## Folder Ownership

- `scenes/`: scene composition for world, player, enemies, weapons, UI, and later boss/menu flows
- `scripts/`: gameplay and runtime logic
- `data/`: editable JSON definitions
- `assets/`: sprites, audio, fonts, and imported content only
- `docs/process/`: source of truth for scope, roadmap, and architecture
- `docs/development/`: current state and session memory

## Runtime Boundaries

- Simulation owns movement, aim rules, combat, revive logic, room rules, loot rules, and run progression.
- Presentation owns visuals, HUD, modifier tinting, hit feedback, particles, and camera feel.
- Scene files compose nodes but do not become the place where rules are hidden.
- Placeholder visuals should stay Godot-native through the current prototype slices, using default styling rather than a custom palette. No custom sprite work is needed before combat readability or feel requires it.
- Pre-run configuration flows should pass state through scene ownership, not early autoloads. The current menu uses a bootstrap scene that instantiates `GameWorld` with explicit player configs.

## Singleton Policy

- No autoloads in Patches 0-4.
- Introduce exactly one autoload in Patch 5: `RunState.gd`.
- `RunState.gd` owns cross-room run state only: active players, health persistence, node progression, current node selection, and run outcome.

## Input Contract

Reserve per-player action namespaces now:

- `p1_*`
- `p2_*`
- `p3_*`
- `p4_*`

Each namespace will own:

- `move_left`, `move_right`, `move_up`, `move_down`
- `aim_left`, `aim_right`, `aim_up`, `aim_down`
- `fire`, `secondary`, `dash`, `pause`

Patch 0 validates only Player 1 movement. Patch 1 fills in the active co-op bindings and aim behavior.

## Patch 1 Note

- Movement remains action-map driven for `p1_*` and `p2_*`.
- Aim and dash are currently resolved through a code-side control layer so the prototype can stay clean and playable without premature editor-side input plumbing.
- Runtime aim-mode switching currently uses a small debug HUD. A proper pause-menu flow is still deferred.
- Player count and control source selection now happen in a bootstrap menu before `GameWorld` starts.

## Patch 5 Note

- The bootstrap menu now hands off to a run-flow scene instead of opening the room directly.
- `RunFlow` owns node selection and room transitions.
- `GameWorld` remains the combat room runtime and receives per-room configuration from the selected node.

## Core Data Contracts

- `PlayerConfig`: `player_id`, `control_source`, `tint`, `aim_mode`
- `weapons.json`: weapon definitions and later balance data
- `enemies.json`: enemy archetypes and tuning values
- `modifiers.json`: room modifier definitions
- `items.json`: item definitions and descriptive text

## Planned Runtime Signals

- `room_cleared`
- `player_downed`
- `player_revived`
- `all_players_dead`
- `loot_choice_resolved`
- `run_completed`

Signals stay local to the systems that own them until cross-room state exists.
