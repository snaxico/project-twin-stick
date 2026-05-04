# Prototype Roadmap

## Delivery Rule

One patch equals one validated subsystem. Do not start the next patch until the current slice runs, is readable enough to judge, and is documented.

## Patch Order

| Patch | Goal | Current Status |
| --- | --- | --- |
| Phase 0 | Project structure, docs, standards alignment, Git, readiness artifacts | Completed |
| Patch 0 | Bounded room and Player 1 movement baseline | Implemented, manual control check pending |
| Patch 1 | Two players, aim, dash, aim assist, hot-plug tolerance | Implemented, interactive validation pending |
| Patch 2 | Primary combat loop and first enemies | Implemented, gameplay validation pending |
| Patch 3 | Secondary slot and cooldown feedback | Implemented, gameplay validation pending |
| Patch 4 | Modifier engine and room telegraphing | Implemented, gameplay validation pending |
| Patch 5 | Node map, room flow, reward preview, `RunState` | Implemented, gameplay validation pending |
| Patch 6 | Shared loot and build differentiation | Planned |
| Patch 7 | Boss, revive flow, full run, first-playable validation | Planned |
| Patch 8 | Juice, audio, 3-4 player tuning, broader content | Deferred until Patch 7 passes |
| Patch 9 | Meta-progression and distribution | Deferred until Patch 8 passes |

## Validation Gate Per Patch

- The project launches.
- The changed behavior can be exercised directly.
- Readability is good enough to judge.
- Godot output is clean or any remaining noise is written down.
- `docs/development/current-state.md` and the session history are updated.
- Commit only after the slice passes its done-when condition.

## Current Validation Note

- Headless Godot launch is clean on 2026-05-04.
- Patch 0 still needs an interactive manual check for movement feel, wall collision, and runtime readability before it should be treated as complete and committed as a finished patch.
- Patch 1 now loads cleanly and spawns two placeholder players with a shared fixed camera and runtime aim-mode cycling.
- A bootstrap menu now loads before the game scene and configures player count plus per-player control source for the current `1–2` player scope.
- Patch 1 still needs interactive checks for dual-keyboard controls, mixed aim modes, dash timing, and controller disconnect/reconnect behavior.
- Patch 2 now loads cleanly with placeholder projectiles, a small enemy wave, HP/damage, and room-clear or full-party-loss state.
- Patch 2 still needs the real gameplay test: do the controls, combat readability, and enemy pressure feel like the first actual fun slice?
- Patch 3 now loads cleanly with one grenade-style secondary and HUD cooldown feedback.
- Patch 4 now loads cleanly with JSON-backed room modifiers, visual telegraphing, and active room-rule effects.
- Patch 3 and Patch 4 still need gameplay validation for grenade readability, modifier clarity, and whether the different room rules feel distinct enough to justify staying.
- Patch 5 now loads cleanly with `RunState`, a simple node map, room/reward preview, and transitions between room selection and configured encounters.
- Patch 5 still needs gameplay validation for room-flow clarity, health persistence between nodes, and whether the current rest/shop placeholders are sufficient until the loot/map systems expand.
