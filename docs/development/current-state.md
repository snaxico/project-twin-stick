# Current State

## Project Role

Godot 4.6.2 prototype for a same-screen local co-op twin-stick roguelite with a first-playable target at Patch 7.

## What Currently Runs

- A bootstrap main scene that opens a setup menu before the game
- A selectable `1–4` player pre-run setup flow
- A simple node-map flow with two choices per step
- Shared gold, post-combat upgrade picks, and a shop choice flow
- A downed-and-revive combat loop for co-op recovery
- A bounded room with solid collision walls
- A 2D faux 3/4-view placeholder presentation layer
- Light camera/tint juice for intros, damage, revives, and clears
- Two placeholder `Player` instances spawned by `CoopManager.gd`
- Primary fire with placeholder projectiles
- One shared primary loadout with runtime variants
- One shared secondary loadout with runtime variants
- Keyboard control now uses mouse aim, left-click primary fire, and right-click secondary fire
- Gamepad secondary on `L2`
- A timed survival room with recurring chaser and spitter spawns
- A placeholder boss room that ends the run
- A JSON-backed room modifier system with pre-fight telegraphing
- Expanded room layout presets for combat and elite rooms
- HP/damage flow for players and enemies
- Room-end state for `Victory` after 30 seconds or `All players down`
- A shared fixed room camera
- Runtime aim-mode cycling through a small debug HUD
- Headless project launch validation passes in Godot 4.6.2

## Active Systems

- project structure and documentation baseline
- bootstrap menu for player count and per-player control source
- `RunState` autoload for cross-room progression and health persistence
- shared gold economy and shared item inventory
- shared build-state/loadout application across both players
- `RunFlow` scene for node selection and room transitions
- pooled reward-choice and shop-choice UI
- run win/lose resolution through the node-map flow
- faux 3/4-view room presentation with fixed camera
- input action namespace for `p1` through `p4`
- one-to-four player spawning
- Player 1 and Player 2 movement
- Player 3 and Player 4 gamepad-first spawning
- per-player aim assist modes with enemyless fallback behavior
- dash timing and cooldown state
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
- frenzy, armoured, inferno, and explosive death room rules
- stampede and crossfire room rules
- survival timer, recurring enemy spawns, and retry flow
- room clear and room fail state signaling
- real shop node resolution with shared gold spending
- reward preview, health carry-over, and shared upgrade rewards across rooms
- fixed room camera
- layout presets: default, crossfire, pinch, offset, and boss gate
- placeholder-only Godot-native runtime visuals with default styling
- player color identity: P1 green, P2 blue, P3 yellow, P4 orange, enemies red
- room boundary collision
- JSON data stubs for weapons, enemies, modifiers, and items

## Constraints And Known Gaps

- Patch 0 is implemented but still needs an interactive control and collision check
- Patch 1 is implemented but still needs interactive validation for dual-keyboard controls, mixed aim modes, dash feel, and controller reconnect tolerance
- `3–4` player support is now implemented but still needs real runtime validation and tuning
- Patch 2 is implemented but still needs interactive validation for combat feel, projectile readability, enemy pressure scaling, survival pacing, and retry flow
- Patch 3 and Patch 4 are implemented but still need interactive validation for grenade feedback, modifier readability, and whether each room rule is strong enough to judge
- Patch 5 is implemented but still needs interactive validation for node-map readability, per-room handoff correctness, and current placeholder room-type pacing
- full run-length tuning and broader solo-vs-3/4-player balancing are not implemented yet
- the current aim-mode switcher is a debug HUD, not the final pause-menu flow
- headless validation is currently blocked by local Godot execution access outside the workspace, so Patch 8 still needs an interactive runtime check

## Next Step

Finish Patch 0 and Patch 1 validation:

- verify `WASD` movement in the editor or desktop runtime
- verify wall collision behavior and basic feel
- confirm the room is readable at runtime
- verify both players can control independently on keyboard
- verify the bootstrap menu launches the correct player count and control setup
- verify dash cadence and invulnerability timing feel acceptable
- verify runtime aim-mode switching for both players
- verify controller disconnect and reconnect behavior
- verify primary fire cadence and projectile feel
- verify grenade timing, blast feel, and cooldown readability
- verify chaser and spitter readability
- verify two new enemies spawn on the intended cadence
- verify the player wins after surviving 30 seconds
- verify the retry button resets the room cleanly
- verify the room telegraphs the modifier clearly before combat starts
- verify frenzy, armoured, inferno, and explosive death all feel distinct in play
- verify node choices are readable and correctly preview room type, modifier, and reward
- verify health persists correctly between rooms and reward nodes
- verify rest/shop placeholder nodes advance the run correctly

Next, validate Patch 7:

- verify `L2` reliably triggers the secondary on gamepad
- verify free reward picks appear after combat and elite rooms
- verify shop purchases consume shared gold and apply the selected upgrade
- verify the rifle/scatter/slug and grenade/cluster/siege variants feel distinct enough in play
- verify health bonuses, cooldown changes, and damage changes persist correctly across rooms
- verify downed players can be revived consistently under pressure
- verify the boss room intro, boss pressure, and boss-death clear path all read correctly
- verify the run resolves cleanly into the new victory/defeat screens
- verify `3–4` player joins, HUD readability, and encounter pressure scaling
- verify the new layout presets feel meaningfully different in play
- verify stampede and crossfire read clearly against the earlier modifier set
- after that, tune the boss, revive timing, and run length toward the intended milestone
