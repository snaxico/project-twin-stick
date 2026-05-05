# Current State

## Project Role

Godot `4.6.2` prototype for a same-screen local co-op twin-stick roguelite. The first-playable bar is still the Patch 7 target: one readable, stable `10–15` minute run that works without explanation.

## Current Runtime

- bootstrap setup menu before gameplay
- `1–4` player pre-run configuration
- node-map run flow with room choices
- shared gold, shared upgrades, and shop flow
- persistent meta-gold, unlock purchases, and return-to-menu spending loop
- combat rooms with downed/revive flow
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
- expanded shared item pool now supports `19` items
- modifier pool now includes tactical rules, not just stat pressure
- enemy roster:
  - `Chaser`: small red dart silhouette
  - `Spitter`: medium magenta hex silhouette
  - `Charger`: large brown wedge silhouette
  - boss: oversized crimson crown silhouette

## Active Systems

- `ProfileState` for save data, meta gold, and unlock ownership
- `RunState` for run progression, loadouts, health carry-over, gold, and outcomes
- `RunFlow` for node selection and room transitions
- `CoopManager` for room orchestration, combat spawning, and room-state signaling
- JSON-backed items, modifiers, unlocks, enemies, and weapon/loadout tuning
- styled combat HUD with stacked player bars, modifier chip, timer bar, and polished result/pause/intro panels
- modifier intro panel plus active room tinting
- darkness overlay, left-side spawn filtering, and optional friendly fire modifier hooks
- fixed same-screen arena with layout presets: `default`, `crossfire`, `pinch`, `offset`, `boss gate`
- each layout now has its own palette and floor landmarks
- shared placeholder visual language with player color identity and shooter-tinted projectiles/effects
- juice stack through `J7`: hit flash, knockback, hitstop, shake, particles, procedural SFX, health bars, floating text, motion polish, screen overlays, and transition polish

## Recent Accepted Direction

- core loop is approved and should not be replaced casually
- current work should favor tuning and readability over new systems
- ranged pressure has been softened to make the game less oppressive
- aim lines, projectiles, and arena contrast were pushed toward clearer combat reads
- enemy readability now depends on silhouette first, color second
- layouts should feel like distinct places even with placeholder art
- the combat HUD should read at a glance instead of exposing debug strings
- grenade and mine roles should stay distinct instead of drifting back into one blended secondary design

## Known Gaps

- `3–4` player runtime validation and tuning still need real play coverage
- full-run pacing and solo-vs-group balance are still not finished
- grenade-vs-mine role clarity still needs a live feel pass
- new tactical modifiers still need live-behavior tuning and edge-case validation
- `J1` and `J2` feedback layers still need final intensity tuning in active play
- runtime aim-mode switching is still a debug HUD, not the final UX
- no custom art, audio asset pipeline, export flow, or distribution polish yet

## Next Step

If work resumes, prefer tuning and validation:

- verify grenade and mine usefulness, cooldowns, and role separation
- verify `3–4` player pressure, HUD readability, and revive fairness
- verify enemy silhouettes and layout landmarks stay readable during heavy combat
- verify `Darkness`, `One-Way`, and `Friendly Fire` individually in live play
- verify hit feedback and camera feel in live play
- verify save/load, unlock gating, and relaunch persistence
- tune full-run duration toward the intended `10–15` minute target
