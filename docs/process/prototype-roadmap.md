# Prototype Roadmap

## Delivery Rule

One patch equals one validated subsystem. Do not start the next patch until the current slice runs, is readable enough to judge, and is documented.

## Patch Order

| Patch | Goal | Current Status |
| --- | --- | --- |
| Phase 0 | Project structure, docs, standards alignment, Git, readiness artifacts | Completed |
| Patch 0 | Bounded room and Player 1 movement baseline | Implemented and interactively validated during development |
| Patch 1 | Two players, aim, dash, aim assist, hot-plug tolerance | Implemented and interactively validated during development |
| Patch 2 | Primary combat loop and first enemies | Implemented and interactively validated during development |
| Patch 3 | Secondary slot and cooldown feedback | Implemented and interactively validated during development |
| Patch 4 | Modifier engine and room telegraphing | Implemented and interactively validated during development |
| Patch 5 | Node map, room flow, reward preview, `RunState` | Implemented and interactively validated during development |
| Patch 6 | Shared loot and build differentiation | Implemented and interactively validated during development |
| Patch 7 | Boss, revive flow, full run, first-playable validation | Implemented and interactively validated during development |
| Patch 8 | Juice, audio, 3-4 player tuning, broader content | Implemented as an early baseline, broader validation and tuning still pending |
| Patch 9 | Meta-progression and distribution | Meta-progression baseline implemented, export/distribution work still pending |
| Patch 10 | Number scale, combat feel, loot presentation, and flow validation | Implemented in code; headless validation passes; follow-up remains live tuning and run-level readability checks |
| Patch 11 | Melee-first enemy balance and survivability | Implemented in code; headless validation passes; follow-up remains live `Normal` run validation and sustain tuning |
| Patch 12 | Icon-first UI pass | Implemented and interactively validated during development |

## Validation Gate Per Patch

- The project launches.
- The changed behavior can be exercised directly.
- Readability is good enough to judge.
- Godot output is clean or any remaining noise is written down.
- `docs/development/current-state.md` and the session history are updated.
- Commit only after the slice passes its done-when condition.

## Current Validation Note

- The project was exercised interactively through these slices while development was in progress.
- Headless Godot validation passes when launched through `Godot_v4.6.2-stable_win64_console.exe` inside the extracted Godot folder.
- The strongest remaining runtime risk at pause is tuning and readability rather than basic flow breakage:
  - meta-progression usability and unlock pacing
  - `3–4` player pressure and HUD readability
  - grenade readability and general combat clarity under stress
  - boss pacing and revive fairness
  - full-run duration tuning toward the intended `10–15` minute target
- Patch 9 now has a persistence baseline, but export and distribution flow are still not implemented.
- Patch 10 landed the base-10 combat scale, stronger hit/kill feedback, and loot presentation polish without widening system scope.
- Patch 11 shifted wave composition and sustain toward melee-first pressure with rarer `Spitter` presence and combat food drops.
- Patch 12 replaced text-heavy combat/reward UI surfaces with icon-first presentation using procedural placeholder icons plus real-sprite fallback.
