# Current State

## Project Role

Godot 4.6.2 prototype for a same-screen local co-op twin-stick roguelite, now carrying a Patch 9 baseline for persistent progression while the first-playable target remains defined by Patch 7.

## What Currently Runs

- A bootstrap main scene that opens a setup menu before the game
- A selectable `1–4` player pre-run setup flow
- A persistent meta-progression menu with unlock purchases
- A simple node-map flow with two choices per step
- Shared gold, post-combat upgrade picks, and a shop choice flow
- Meta-gold rewards after each completed run
- A dedicated run-end summary panel with direct meta-menu handoff
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
- Headless Godot validation passes with `Godot_v4.6.2-stable_win64_console.exe`

## Active Systems

- project structure and documentation baseline
- bootstrap menu for player count and per-player control source
- `ProfileState` autoload for save data, meta gold, and unlock ownership
- `RunState` autoload for cross-room progression and health persistence
- shared gold economy and shared item inventory
- shared build-state/loadout application across the active team
- `RunFlow` scene for node selection and room transitions
- pooled reward-choice and shop-choice UI
- reward/shop pool gating based on persistent unlock ownership
- run win/lose resolution through the node-map flow
- run-end return to menu for persistent spending
- run-end summary with newly affordable unlock callouts
- clean rectangular grid arena with fixed same-screen camera
- input action namespace for `p1` through `p4`
- one-to-four player spawning
- per-player aim assist modes with enemyless fallback behavior
- movement-first dash with aim fallback
- primary fire requests from players
- secondary requests from players
- placeholder projectile spawning and hit resolution
- grenade projectile and cooldown state
- enemy hit flash, knockback, delayed death flash, and kill hitstop
- player damage flash
- trauma-based camera shake on kills, downed states, room clear, and grenade explosions
- grenade explosion zoom punch and dedicated camera shake runtime
- three shared primary profiles: rifle, scatter, and slug
- three shared secondary profiles: grenade, cluster, and siege
- downed players, proximity revive progress, and revive recovery
- one chaser enemy behavior with lunge pressure
- one spitter enemy behavior with strafing burst fire
- one charger enemy behavior with windup dash pressure
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
- the new `J1` hit feedback layer still needs an interactive feel pass for flash readability, knockback strength, and hitstop intensity
- the new `J2` camera layer still needs an interactive feel pass for shake strength, clear readability, and grenade punch intensity
- the current aim-mode switcher is a debug HUD, not the final pause-menu flow
- no custom art, audio, or export pipeline has been started
- export flow and distribution polish are still not implemented
- patch 9 currently covers persistence and unlocks, not the distribution part of the roadmap item

## Next Step

If development resumes, the next work should be tuning and validation rather than new feature scope:

- verify `3–4` player joins, HUD readability, and encounter pressure scaling
- verify `J1` hit feedback in live play: enemy flash, player flash, knockback, and kill hitstop
- verify `J2` camera feel in live play: kill shake, damage shake, room-clear shake, and grenade zoom punch
- verify profile save/load, unlock purchase flow, and reward-pool gating across relaunches
- tune grenade readability and secondary usefulness
- tune revive timing, boss pressure, and failure fairness
- tune full-run duration toward the intended `10–15` minute target
- decide whether Patch 8/9 systems should be stabilized as part of the first-playable track or held as extra scope beyond it
## Juice Status

- `J1` is implemented and validated: enemy/player flash, enemy knockback, kill hitstop.
- `J2` is implemented and validated: trauma-based screen shake, grenade shake reduced to zoom punch only.
- `J3` is now implemented: muzzle flash, projectile trail, impact sparks, enemy death burst, grenade explosion burst, and dash trail all route through a room-level `Effects` container.
- `J4` is now implemented: a shared procedural `SfxEngine` provides fire, hit, explosion, dash, damage, enemy death, room clear, and UI click sounds without external audio assets.
- `J5` is now implemented: player health bars, a boss health bar, floating damage and gold text, low-time pulse feedback, and button/panel motion in the bootstrap and run-flow menus.
- `J6` is now implemented: player lean, turn squash, fire recoil, downed pulse, enemy idle bob and spawn pop, projectile facing cleanup, player spawn-in animation, and revive burst particles.
- `J7` is now implemented: screen-edge vignette and low-health/combat warmth overlays, spawn warning pulses, smoother modifier tint transitions, wave announcement text, subtle floor shader noise, and room-transition wipe passes in run flow.
- Arena readability pass: the room is now a cleaner rectangular grid with plain walls, brighter base contrast, closer camera framing, larger player/enemy silhouettes, and higher-contrast projectiles.
- Enemy behavior pass: chasers now stalk and lunge, spitters now strafe and fire short bursts, and a new charger archetype adds windup dash pressure to room and boss-support waves.
- Secondary identity pass: `Grenade` remains the aimed standard throw, `Cluster` is now a splitting canister, and `Siege` is now a heavier aimed shell with repeated impact pulses.
- Debug bootstrap mode: the start menu can now override starting primary and secondary gear for local testing without changing the normal progression path.
- All current secondaries now use `hold to aim, release to throw`; the preview only shows while held and only when the secondary is ready.
