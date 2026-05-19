# Current State

## Project Role

Godot `4.6.2` prototype for a same-screen local co-op neon roguelite.

This branch is now the v3 gameplay line:

- stable pre-rework gameplay is preserved separately on `main`
- active rework continues on `v2/core-refactor`
- current target is strictly `1–2` players
- `3–4` player support is deferred until the v3 loop validates

## Current Runtime

- front menu paths:
  - `Play`
  - `Encounter Builder`
- settings menus were removed from both bootstrap and in-run pause flow
- player setup currently targets `1–2` players only
- run mode selection remains:
  - `Normal`
  - `Easy`
- run flow still uses the stripped node map:
  - `combat`
  - `rest`
  - `boss`
- shop / gold / meta progression remain out of the live runtime

## Active Combat State

- arena remains the larger open room with same-screen zoom camera
- camera now follows living players and zooms out to keep the group on one screen
- hard player-to-player rubberbanding was removed; players are only constrained by arena bounds and camera framing
- arena readability remains supported by:
  - visible floor grid lines
  - stronger repeating major guide lines
  - visible perimeter wall visuals
- each player now has exactly:
  - `1` auto-firing primary weapon
  - `1` cooldown secondary ability
  - an ordered mutation list
- live starting loadout is now fixed to:
  - primary: `Rifle`
  - secondary: `Shockwave`
- primary fire is now automatic:
  - no fire trigger input
  - baseline rifle cadence is `3.0` shots per second
  - target selection is handled by `AutoTarget.gd`
- default control split is now:
  - `P1` = gamepad
  - `P2` = keyboard
- live input scheme is now:
  - gamepad left stick = movement
  - `L2` = dash
  - `R2` = shockwave
  - keyboard `WASD` = movement
  - keyboard `Ctrl` = dash
  - keyboard `Space` = shockwave
- nearest-enemy auto-targeting is always on; there is no aim-assist mode toggle in the menus
- only these enemy roles are currently live:
  - `Chaser`
  - `Charger`
  - `Boss`
- room objectives currently supported:
  - `survive`
  - `capture_the_hill`

## Active Systems

- `RunState` remains the live run-state shell:
  - room progression
  - per-player health persistence
  - per-player `1 primary + 1 secondary + mutations` inventory state
- `CoopManager` now drives the v3 room loop:
  - larger arena setup
  - depth-based arena color shifts
  - auto-attack projectile spawning
  - shockwave blast handling + visual ring
  - revive / fail / clear handling
  - mutation pick handoff
  - automatic room progression after mutation picks
- `Player.gd` now implements:
  - movement-facing + auto-attack runtime
  - automatic primary fire
  - shockwave cooldown ownership
  - chevron-only player visual
  - dash-damage mutation support
- `AutoTarget.gd` replaced the old aim-assist path for auto-attack targeting
- `MutationSystem` still compiles primary mutations, and now also handles:
  - `shockwave_radius`
  - `shockwave_cooldown`
- `Projectile.gd` is now the live glowing-orb projectile path
- `PlayerInventoryHUD` and `WeaponSlotHUD` remain the minimal HUD:
  - health
  - primary icon
  - secondary cooldown
  - dash cooldown
  - mutation icons
- encounter builder still supports:
  - room type
  - objective
  - depth
  - enemy mix override
  - starting mutation presets

## Removed From Live V3

- no manual fire input
- no grenade runtime
- no grenade preview / charge system
- no aim-assist menu setting
- no screen-effects menu setting
- no sprite-based player body / weapon presentation
- no shop runtime
- no loot drops / vote flow
- no weapon replacement UI
- no meta progression loop
- no recipe engine
- no modifier engine
- no generator objective
- no alternative primary families in live combat
- no `3–4` player support target for the current validation phase

Obsolete v1 / v2 systems remain preserved under `archive/v1/`.

## Known Gaps

- v3 now matches the new control model structurally, but still has not had a full feel-validation pass
- shockwave, auto-attack cadence, and mutation payoff still need live tuning
- boss behavior is still the older fight shape and has not yet had the separate v3 redesign
- builder mutation presets are for testing, not polished end-user UX
- glow / neon presentation is improved, but this is still a gameplay-first pass rather than a final art pass
- full-screen effects are forced on for now and are no longer user-configurable

## Next Step

If work continues on v3, the next priority is play validation:

- run builder checks for:
  - `Survive`
  - `Hold Zone`
  - `Mixed` / `Chasers Only` / `Chargers Only`
  - stacked mutation presets
- tune rifle pulse cadence, shockwave feel, and room pressure until the loop feels clearly better than v2
- validate the mutation reward cadence across several full runs
- only revisit shops, extra objectives, boss redesign, or higher player counts after the core v3 slice is fun
