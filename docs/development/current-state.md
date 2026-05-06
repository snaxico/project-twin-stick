# Current State

## Project Role

Godot `4.6.2` prototype for a same-screen local co-op twin-stick roguelite. The first-playable bar is still the Patch 7 target: one readable, stable `10–15` minute run that works without explanation.

## Current Runtime

- bootstrap setup menu before gameplay
- `1–4` player pre-run configuration
- run mode selection before gameplay:
  - `Normal`: HP carries between cleared rooms
  - `Easy`: all players fully heal after each cleared room
- settings are available before the run and from the in-run pause menu
- screen effects level is profile-backed and selectable in both menus
- connected node-map run flow with enforced links between floors
- run map is now procedural instead of fixed:
  - `5–7` pre-boss rows plus one boss row
  - `3` starting nodes
  - `2–4` nodes on each non-boss row
  - only connected next-row nodes are selectable
  - guaranteed reachable rest/shop presence
- shared gold, shared upgrades, and shop flow
- persistent meta-gold, unlock purchases, and return-to-menu spending loop
- combat rooms with downed/revive flow
- combat rooms can now be either:
  - timer-based `survive`
  - objective-based `destroy_generators`
- boss endpoint and run-end summary handoff
- headless Godot validation passes with `Godot_v4.6.2-stable_win64_console.exe`
- startup check passes with the local Godot console executable

## Active Combat State

- primary profiles:
  - `Rifle`
  - `Scatter`
  - `Slug`
- secondary profiles:
  - thrown: `Grenade`, `Cluster Grenade`, `Siege Grenade`
  - proximity: `Mine`, `Shrapnel Mine`, `Heavy Mine`
- grenade path and mine path are now separate scene/script runtimes
- mines place instantly on secondary press and use proximity fuse detonation
- mine proximity radius was doubled from the initial mine implementation
- expanded shared item pool now supports `20` items
- modifier pool now includes tactical rules, not just stat pressure
- wave composition now scales by room depth instead of using one fixed enemy mix
- boss health now scales modestly with rooms survived before the boss
- gauntlet V1 layer is in:
  - neutral generators spawn pressure enemies
  - generator rooms clear only after generators are destroyed and the room is swept
  - enemies can drop gold pickups
  - generators always drop one gold pickup and one food pickup
  - food heals `1` HP and gold goes straight into shared run gold
- enemy roster:
  - `Chaser`: small red dart silhouette
  - `Spitter`: medium magenta hex silhouette
  - `Charger`: large brown wedge silhouette
  - boss: oversized crimson crown silhouette

## Active Systems

- `ProfileState` for save data, meta gold, and unlock ownership
- `RunState` for run progression, loadouts, run-mode health rules, gold, and outcomes
- `RunFlow` for connected map rendering, node inspection, node selection, and room transitions
- `CoopManager` for room orchestration, combat spawning, and room-state signaling
- bootstrap debug launcher for:
  - normal run override starts
  - single-room debug launches
  - explicit room/objective/modifier/layout/depth selection
- JSON-backed items, modifiers, unlocks, enemies, and weapon/loadout tuning
- per-player aim mode selection now lives in the shared settings menu instead of debug-only controls
- screen effects are user-selectable through the shared settings menu:
  - `Off`
  - `Minimal`
  - `Full`
- current default profile setting is `Off`
- styled combat HUD with stacked player bars, modifier chip, timer bar, and polished result/pause/intro panels
- modifier intro panel plus active room tinting
- darkness overlay, left-side spawn filtering, and optional friendly fire modifier hooks
- fixed fullscreen same-screen arena with layout presets: `default`, `crossfire`, `pinch`, `offset`, `boss gate`
- gauntlet layout preset: `gauntlet_pockets`
- arena presentation is now cartoon-styled:
  - thick player/enemy outlines
  - one shared olive-neutral floor across all rooms
  - subtle fullscreen grid lines for room texture
  - only subtle room-to-room line/accent changes remain
- player visuals are now partially sprite-backed:
  - player 1 now uses `assets/sprites/player/player_p1_standing.png` while idle
  - player 1 alternates between `assets/sprites/player/player_p1_running.png` and `assets/sprites/player/player_p1_running_alt.png` while moving
  - player 1 now carries a visible rifle sprite attached to aim direction and mirrored on left aim
  - player projectiles now use `assets/sprites/weapons/player_bullet.png`
  - players 2–4 still use the procedural polygon body
  - the imported sprite set had its white background removed and the player footprint was enlarged by roughly `33%` to match the current presentation
- shared placeholder visual language with player color identity and shooter-tinted projectiles/effects
- juice stack through `J7`: hit flash, knockback, hitstop, shake, particles, procedural SFX, health bars, floating text, motion polish, screen overlays, and transition polish
- sprite-generation documentation now lives in-project under `sprites/guidelines/`, separate from runtime assets in `assets/sprites/`

## Recent Accepted Direction

- core loop is approved and should not be replaced casually
- current work should favor tuning and readability over new systems
- ranged pressure has been softened to make the game less oppressive
- aim lines, projectiles, and arena contrast were pushed toward clearer combat reads
- player-facing weapon and projectile art should stay readable and anchored to gameplay direction, not just cosmetic placement
- arena color should read as one world first, with only minor room accent variation
- enemy readability now depends on silhouette first, color second
- layout identity should come from geometry and encounter shape more than full-room palette swaps
- the combat HUD should read at a glance instead of exposing debug strings
- grenade and mine roles should stay distinct instead of drifting back into one blended secondary design
- run structure should vary between attempts through map length, room order, and enemy mix without changing the run-flow contract
- aim-mode switching should stay in the shared settings UI, not developer-facing controls
- screen effects should be selectable from the same settings flow and default to clear combat readability
- sprite generation should follow the in-project guidelines and stay separate from runtime asset storage

## Known Gaps

- `3–4` player runtime validation and tuning still need real play coverage
- full-run pacing and solo-vs-group balance are still not finished
- bootstrap/front-end productization still has not happened; debug setup still dominates first impression
- grenade-vs-mine role clarity still needs a live feel pass
- procedural run pacing and boss scaling still need live validation across several attempts
- connected-map readability, route feel, and row-to-row pathing still need live validation
- generator-room pacing and pickup feel still need live tuning
- enemy contact damage and pickup drop flow were recently fixed in code but still need live validation under combat load
- single-room debug launcher still needs interactive coverage across room types and modifiers
- new tactical modifiers still need live-behavior tuning and edge-case validation
- `J1` and `J2` feedback layers still need final intensity tuning in active play
- no custom art, audio asset pipeline, export flow, or distribution polish yet

## Next Step

If work resumes, prefer connected-map validation first, then tuning:

- verify multiple run seeds for connected-path variety, readability, and route pressure
- verify reachable/locked/current/visited node states stay clear on the map screen
- verify rest/shop/boss placement and routing feel understandable without explanation
- verify multiple run seeds for map variety, pacing, and boss scaling
- verify generator-room duration, pickup feel, and enemy-cap pressure in `1P` and `2P`
- verify grenade and mine usefulness, cooldowns, and role separation
- verify `3–4` player pressure, HUD readability, and revive fairness
- verify enemy silhouettes and the brighter neutral arena stay readable during heavy combat
- verify `Darkness`, `One-Way`, and `Friendly Fire` individually in live play
- verify menu and pause settings for each player-count configuration
- verify `Off` / `Minimal` / `Full` screen-effect levels behave as expected in live play
- verify `Normal` and `Easy` run modes both apply the intended HP persistence behavior
- verify player 1 sprite fit, rifle placement, and motion readability against the enlarged hitbox
- verify player projectile sprite readability and muzzle alignment during heavy fire
- verify chaser contact damage now triggers reliably at close range
- verify debug single-room launches for combat, elite, rest, shop, and boss
- verify hit feedback and camera feel in live play
- verify save/load, unlock gating, and relaunch persistence
- tune full-run duration toward the intended `10–15` minute target
