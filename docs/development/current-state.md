# Current State

## Project Role

Godot 4.6.2 prototype for a same-screen local co-op twin-stick roguelite, currently paused after an early Patch 8 baseline while the first-playable target remains defined by Patch 7.

## What Currently Runs

- A bootstrap main scene that opens a setup menu before the game
- A selectable `1–4` player pre-run setup flow
- A simple node-map flow with two choices per step
- Shared gold, post-combat upgrade picks, and a shop choice flow
- A downed-and-revive combat loop for co-op recovery
- A bounded room with solid collision walls
- A 2D faux 3/4-view placeholder presentation layer
- Light camera/tint juice for intros, damage, revives, and clears
- Placeholder players spawned by `CoopManager.gd`
- Primary fire with placeholder projectiles
- Shared primary loadout variants
- Shared secondary loadout variants
- Keyboard control with mouse aim, left-click primary fire, and right-click secondary fire
- Gamepad secondary on `L2`
- A timed survival room with recurring chaser and spitter spawns
- A placeholder boss room that ends the run
- A JSON-backed room modifier system with pre-fight telegraphing
- Expanded room layout presets for combat and elite rooms
- HP/damage flow for players and enemies
- Room-end state for `Victory` after 30 seconds or `All players down`
- A shared fixed room camera
- Runtime aim-mode cycling through a small debug HUD
- The project has been exercised interactively through the current feature slices

## Active Systems

- project structure and documentation baseline
- bootstrap menu for player count and per-player control source
- `RunState` autoload for cross-room progression and health persistence
- shared gold economy and shared item inventory
- shared build-state/loadout application across the active team
- `RunFlow` scene for node selection and room transitions
- pooled reward-choice and shop-choice UI
- run win/lose resolution through the node-map flow
- faux 3/4-view room presentation with fixed camera
- input action namespace for `p1` through `p4`
- one-to-four player spawning
- per-player aim assist modes with enemyless fallback behavior
- movement-first dash with aim fallback
- primary fire requests from players
- secondary requests from players
- placeholder projectile spawning and hit resolution
- grenade projectile and cooldown state
- three shared primary profiles: rifle, scatter, and slug
- three shared secondary profiles: grenade, cluster, and siege
- downed players, proximity revive progress, and revive recovery
- one chaser enemy behavior
- one spitter enemy behavior
- one placeholder boss behavior with support spawns
- JSON-backed modifier definitions
- modifier intro panel and active room tinting
- frenzy, armoured, inferno, explosive death, stampede, and crossfire room rules
- survival timer, recurring enemy spawns, and retry flow
- room clear and room fail state signaling
- real shop node resolution with shared gold spending
- reward preview, health carry-over, and shared upgrade rewards across rooms
- layout presets: default, crossfire, pinch, offset, and boss gate
- placeholder-only Godot-native runtime visuals
- player color identity: P1 green, P2 blue, P3 yellow, P4 orange, enemies red
- room boundary collision
- JSON data stubs for weapons, enemies, modifiers, and items

## Constraints And Known Gaps

- `3–4` player support is implemented but still needs deeper runtime validation and tuning
- full run-length tuning and broader solo-vs-3/4-player balancing are not implemented yet
- grenade readability is still weaker than the primary-fire loop
- the current aim-mode switcher is a debug HUD, not the final pause-menu flow
- headless validation from this Codex environment is currently blocked by local Godot execution access outside the workspace
- no custom art, audio, export flow, or meta-progression pipeline has been started
- development is paused at this state rather than continuing into Patch 9

## Next Step

If development resumes, the next work should be tuning and validation rather than new feature scope:

- verify `3–4` player joins, HUD readability, and encounter pressure scaling
- tune grenade readability and secondary usefulness
- tune revive timing, boss pressure, and failure fairness
- tune full-run duration toward the intended `10–15` minute target
- decide whether Patch 8 should be stabilized as part of the first-playable track or held as extra scope beyond it
