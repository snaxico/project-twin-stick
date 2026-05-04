# Project Placeholder

Personal couch co-op twin-stick roguelite prototype built in Godot 4.6.2.

## Current Position

- Phase 0 foundation and Patch 0 baseline are the active implementation target.
- The prototype is locked to a same-screen, room-based, local co-op structure.
- The first playable target is Patch 7: one complete 10-15 minute run that passes the girlfriend test.

## Stack

- Engine: Godot 4.6.2 stable
- Language: GDScript
- Data: JSON-first content definitions
- Platform target: Windows desktop first

## Run

1. Open the project in Godot 4.6.2 stable.
2. Run the main scene.
3. Current runtime baseline:
    - A bootstrap menu opens first.
    - The menu selects `1–2` players and one control source per player.
    - The selected setup launches a simple node-map flow.
    - The node map previews room type, modifier, and reward before entry.
    - Combat and elite selections launch configured survival rooms.
    - Rest and shop nodes resolve as lightweight placeholder progression nodes.
    - Two placeholder players can spawn in the active room.
    - Players can fire placeholder projectiles.
    - One grenade-style secondary is available with cooldown feedback.
    - A small placeholder enemy wave can be defeated or can defeat the players.
    - Each room rolls one active modifier with a visible pre-fight telegraph.
    - The room reports either `Victory` after 30 seconds or `All players down`.
    - Shared fixed camera stays centered on the room.
    - Debug HUD buttons cycle P1 and P2 aim modes at runtime.
4. Current keyboard fallback:
   - P1 move: `WASD`
   - P1 aim: arrow keys
   - P1 dash: `Space`
   - P2 move: `IJKL`
   - P2 aim: numpad `8/4/5/6`
   - P2 dash: `Enter`

## Placeholder Policy

- Use Godot-native placeholder visuals with default styling during the current prototype slices.
- Do not add custom sprite production work, custom placeholder palettes, or custom art assets before the gameplay slices demand it.

## Current Menu Scope

- Player count selection currently supports `1` or `2`.
- Per-player control source currently supports `Keyboard`, `Gamepad`, or `Hybrid`.
- The menu is a pre-run bootstrap flow, not the final front-end or pause-menu implementation.

## Documentation

- Process docs: `docs/process/`
- Development memory: `docs/development/`
