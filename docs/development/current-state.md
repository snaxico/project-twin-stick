# Current State

## Project Role

Godot `4.6.2` prototype for a same-screen local co-op twin-stick roguelite. The first-playable bar is still the Patch 7 target: one readable, stable `10–15` minute run that works without explanation.

## Current Runtime

- player-facing front menu before gameplay:
  - `Play`
  - `Meta`
  - `Settings`
  - `Debug`
- `1–4` player pre-run configuration
- run mode selection before gameplay:
  - `Normal`: HP carries between cleared rooms
  - `Easy`: all players fully heal after each cleared room
- debug launcher now sits behind its own entry instead of dominating the first screen
- settings are available before the run and from the in-run pause menu
- screen effects level is profile-backed and selectable in both menus
- connected node-map run flow with enforced links between floors
- run map is now procedural instead of fixed:
  - `5–7` pre-boss rows plus one boss row
  - `3` starting nodes
  - `2–4` nodes on each non-boss row
  - only connected next-row nodes are selectable
  - guaranteed reachable rest/shop presence
- per-player gold wallets and inventories
- combat and elite rooms now end in:
  - physical loot drops
  - Take / Scrap resolution
  - contested winner rolls when multiple players want the same item
  - replacement UI when a new weapon collides with full matching slots
- shop rooms now run in-world:
  - personal offers per player
  - personal wallet checks
  - weapon replacement support on purchase
  - ready-up before exit opens
- room clear no longer auto-transitions:
  - loot or shop resolves first
  - exit zone opens after resolution
  - all living players can leave together or wait for auto-exit
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
  - `Incinerator`
  - `Beam Lance`
  - `Arc Caster`
- secondary profiles:
  - thrown: `Grenade`, `Cluster Grenade`, `Siege Grenade`
  - proximity: `Mine`, `Shrapnel Mine`, `Heavy Mine`
- primary runtime is no longer projectile-only:
  - `Rifle`, `Scatter`, `Slug` use `projectile`
  - `Incinerator` uses `cone`
  - `Beam Lance` uses `beam`
  - `Arc Caster` uses `chain`
- primary weapons now compile through the new standard stat model:
  - `damage`
  - `fire_rate`
  - `range`
  - `area`
  - `amount`
- projectile primaries now also consume behavior-specific compiled fields:
  - `projectile_speed`
  - `spread_radians`
  - `pierce_count`
- passive application is now per-slot for weapons instead of one shared inventory-wide combat state
- passive tag filtering is now live through optional `requires_tags`
- hook passives are now implemented with centralized runtime dispatch for:
  - `on_fire`
  - `on_hit`
  - `on_kill`
  - `on_explosion`
- grenade path and mine path are now separate scene/script runtimes
- mines place instantly on secondary press and use proximity fuse detonation
- mine proximity radius was doubled from the initial mine implementation
- each player now has:
  - `2` primary weapon slots
  - `2` secondary weapon slots
  - independent selected-slot state
  - passive ownership
  - `Lv1–Lv5` weapon progression on duplicates
- modifier pool now includes tactical rules, not just stat pressure
- wave composition now scales by room depth instead of using one fixed enemy mix
- boss health now scales modestly with rooms survived before the boss
- gauntlet V1 layer is in:
  - neutral generators spawn pressure enemies
  - generator rooms clear only after generators are destroyed and the room is swept
  - enemies can drop gold pickups
  - generators always drop one gold pickup and one food pickup
  - food heals `1` HP and gold is awarded into each player wallet
- enemy roster:
  - `Chaser`: small red dart silhouette
  - `Spitter`: medium magenta hex silhouette
  - `Charger`: large brown wedge silhouette
  - boss: oversized crimson crown silhouette

## Active Systems

- `ProfileState` for save data, meta gold, and unlock ownership
- `RunState` for run progression, per-player inventories, loadouts, wallet state, shop offers, run-mode health rules, outcomes, primary stat compilation, tag filtering, and trigger-passive compilation
- `RunFlow` for connected map rendering, node inspection, node selection, and room transitions
- `CoopManager` for room orchestration, combat spawning, loot/shop resolution, exit flow, room-state signaling, primary behavior execution, and trigger-event processing
- `PassiveTriggerSystem` for hook-passive throttling and trigger action collection
- bootstrap debug launcher for:
  - normal run override starts
  - single-room debug launches
  - explicit room/objective/modifier/layout/depth selection
- JSON-backed passives, weapons, modifiers, unlocks, enemies, and weapon/loadout tuning
- per-player aim mode selection now lives in the shared settings menu instead of debug-only controls
- screen effects are user-selectable through the shared settings menu:
  - `Off`
  - `Minimal`
  - `Full`
- current default profile setting is `Off`
- styled combat HUD with per-player inventory panels, modifier chip, timer bar, and polished result/pause/intro panels
- each player HUD now exposes:
  - compact wallet value
  - health state
  - two primary slots
  - two secondary slots
  - selected-slot highlight
  - secondary cooldown bars
  - passive chips
  - icon-first slot rendering with real primary weapon sprites where available
  - lighter transparency so the arena stays readable behind the HUD
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
  - player 1 now carries visible primary-weapon sprites attached to aim direction and mirrored on left aim:
    - `player_rifle.png`
    - `player_scattergun.png`
    - `player_slug.png`
  - player projectiles now use `assets/sprites/weapons/player_bullet.png`
  - players 2–4 still use the procedural polygon body
  - the imported sprite set had its white background removed and the player/weapon sprite scale was enlarged by roughly `33%`
  - the player collision radius was also increased to better match the larger presentation
- player combat pace is currently bumped above the earlier baseline:
  - primary fire intervals are globally reduced by `20%`
  - secondary cooldowns are globally reduced by `20%`
- dash follow-up changed the defensive timing:
  - dash cooldown is now `2.0s`
  - each successful dash grants a visible shield for `0.5s`
- loot/inventory/shop follow-up fixes now also landed:
  - player loadouts reapply immediately after loot, replacements, and shop purchases
  - `Rifle` and `Mine` are back in reward/shop pools, so starter weapons can level naturally
  - loot drops now keep their label/color even though setup happens before `_ready()`
  - shop reset correctly unlocks the active shopper
  - duplicate pickup-point gold floating text was removed
- replacement UI now ignores the same held confirm/cancel press that opened it, so it no longer closes instantly on entry
- recent combat spectacle pass also landed:
  - runtime weapon loadouts now carry `feedback_profile` and `impact_weight`
  - dash has a short input buffer and slow primaries like `Slug` have a short fire buffer
  - primary fire now drives weapon-specific muzzle flash, recoil, camera kick, and procedural SFX variation
  - enemy hits/deaths now use stronger hitstop, burst/ring effects, and heavier camera/audio response
  - grenade and mine detonations now use layered burst plus expanding ring feedback
- shared placeholder visual language with player color identity and shooter-tinted projectiles/effects
- juice stack through `J7`: hit flash, knockback, hitstop, shake, particles, procedural SFX, health bars, floating text, motion polish, screen overlays, and transition polish
- sprite-generation documentation now lives in-project under `sprites/guidelines/`, separate from runtime assets in `assets/sprites/`

## Recent Accepted Direction

- core loop is approved and should not be replaced casually
- current work should favor tuning and readability over new systems
- the primary ruleset/compiler migration is now implemented and should be validated before being widened further
- ranged pressure has been softened to make the game less oppressive
- aim lines, projectiles, and arena contrast were pushed toward clearer combat reads
- player-facing weapon and projectile art should stay readable and anchored to gameplay direction, not just cosmetic placement
- arena color should read as one world first, with only minor room accent variation
- enemy readability now depends on silhouette first, color second
- layout identity should come from geometry and encounter shape more than full-room palette swaps
- the combat HUD should read at a glance instead of exposing debug strings
- the combat HUD should stay compact and icon-first where possible, not drift back toward text-heavy debug cards
- the loot, shop, and replacement flows should feel player-facing rather than tool-like
- grenade and mine roles should stay distinct instead of drifting back into one blended secondary design
- run structure should vary between attempts through map length, room order, and enemy mix without changing the run-flow contract
- aim-mode switching should stay in the shared settings UI, not developer-facing controls
- screen effects should be selectable from the same settings flow and default to clear combat readability
- sprite generation should follow the in-project guidelines and stay separate from runtime asset storage
- gamepad dash now lives on `B / O`, not `A / X`

## Known Gaps

- the newly implemented primary-ruleset migration still needs live gameplay validation
- new primary behaviors still need feel/tuning passes:
  - `cone`
  - `beam`
  - `chain`
- hook-based passive interactions still need live balance and readability validation
- `3–4` player runtime validation and tuning still need real play coverage
- full-run pacing and solo-vs-group balance are still not finished
- menu cleanup is partially in; there is now a real front door, but setup/debug/meta presentation still needs more polish
- new loot, shop, and replacement flows still need live UX validation
- the new compact icon HUD still needs a live readability pass, especially for placeholder secondary/passive chips
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

If work resumes, prefer cleanup and presentation polish over new mechanics:

- run a live validation pass across:
  - `Rifle`, `Scatter`, `Slug`
  - `Incinerator`, `Beam Lance`, `Arc Caster`
  - `range`, `area`, `pierce`, and hook-passive behavior
- simplify the play-setup screen further now that `Play` and `Debug` are separate paths
- tighten HUD wording and spacing after a few more live readability checks
- validate the new loot, replacement, and shop UI flow with gamepad-first navigation
- standardize runtime sprite folder and naming conventions before more art lands
- update any remaining docs that still describe the old shared-economy progression model
- keep validating pause/settings/meta routes across different player counts
- verify debug single-room launches still cover combat, elite, rest, shop, and boss without UI regressions
