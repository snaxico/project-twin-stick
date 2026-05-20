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
- dedicated shop nodes and meta progression remain out of the live runtime
- gold economy is now live:
  - enemies drop gold pickups on death
  - pickups magnet to the nearest living player
  - gold is shared on collection and copied into every player's personal wallet
  - room clear auto-collects leftovers and adds a flat survival bonus

## Active Combat State

- arena remains the larger open room with same-screen zoom camera
- camera now follows living players and zooms out to keep the group on one screen
- hard player-to-player rubberbanding was removed; players are only constrained by arena bounds and camera framing
- arena readability remains supported by:
  - visible floor grid lines
  - stronger repeating major guide lines
  - visible perimeter wall visuals
- each player now has exactly:
  - `1` auto-firing weapon (rifle)
  - `1` primary skill (shockwave — RT / Space)
  - `1` secondary skill (dash — LT / B / Ctrl)
  - an ordered mutation list
- live starting loadout is now fixed to:
  - weapon: `Rifle`
  - primary skill: `Shockwave`
  - secondary skill: `Dash`
- weapon fire is automatic:
  - no fire trigger input
  - baseline rifle cadence is `3.0` shots per second
  - target selection is handled by `AutoTarget.gd`
- default control split is now:
  - `P1` = gamepad
  - `P2` = keyboard
- live input scheme is now:
  - gamepad left stick = movement
  - `L2` or `B` = secondary skill (dash)
  - `R2` = primary skill (shockwave)
  - keyboard `WASD` = movement (P2)
  - keyboard `Ctrl` = secondary skill / dash (P2)
  - keyboard `Space` = primary skill / shockwave (P2)
  - P1 keyboard bindings for skills are empty (P1 defaults to gamepad)
- nearest-enemy auto-targeting is always on; there is no aim-assist mode toggle in the menus
- only these enemy roles are currently live:
  - `Chaser`
  - `Charger`
  - `Boss`
- room objectives currently supported:
  - `survive`
  - `capture_the_hill`
- mutation rewards are no longer free:
  - each room-end pick screen shows `3` rolled mutations
  - each player can buy `0–3` picks from that set
  - current placeholder costs are `15 / 50 / 100`
  - unspent gold carries forward between rooms

## Active Systems

- `RunState` remains the live run-state shell:
  - room progression
  - per-player health persistence
  - per-player `1 weapon + 1 primary skill + 1 secondary skill + mutations` inventory state
  - per-player gold wallet state
- `CoopManager` now drives the v3 room loop:
  - larger arena setup
  - depth-based arena color shifts
  - auto-attack projectile spawning
  - primary skill (shockwave) blast handling + visual ring
  - enemy gold drop spawning and room-end gold payout
  - revive / fail / clear handling
  - mutation pick handoff
  - automatic room progression after mutation picks
- `GoldPickup.gd` is now the live room-currency pickup path:
  - procedural neon coin/orb visual
  - magnet pull to nearest player
  - no collision-shape dependency; `CoopManager` owns collection checks
- `Player.gd` now implements:
  - movement-facing + auto-attack runtime
  - automatic weapon fire
  - primary skill cooldown ownership
  - chevron-only player visual
  - secondary skill (dash) damage mutation support
- `AutoTarget.gd` replaced the old aim-assist path for auto-attack targeting
- `MutationSystem` still compiles weapon mutations, and now also handles:
  - `shockwave_radius` (primary skill radius)
  - `shockwave_cooldown` (primary skill cooldown)
- `Projectile.gd` is now the live glowing-orb projectile path
- `PlayerInventoryHUD` and `WeaponSlotHUD` remain the minimal HUD:
  - health
  - weapon icon
  - primary skill cooldown
  - secondary skill (dash) cooldown
  - mutation icons
- live combat HUD now also shows per-player gold
- map route UI now also shows per-player gold totals
- mutation pick UI now reuses each player's live input bindings instead of separate hardcoded menu keys
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
- primary skill (shockwave), weapon cadence, and mutation payoff still need live tuning
- boss behavior is still the older fight shape and has not yet had the separate v3 redesign
- builder mutation presets are for testing, not polished end-user UX
- glow / neon presentation is improved, but this is still a gameplay-first pass rather than a final art pass
- full-screen effects are forced on for now and are no longer user-configurable
- the economy loop is now implemented structurally, but gold values, survival bonus, and mutation costs are still placeholder tuning values
- dedicated shop nodes are still design-only; only the gold + room-end mutation spend loop is live

## Next Step

If work continues on v3, the next priority is play validation:

- run builder checks for:
  - `Survive`
  - `Hold Zone`
  - `Mixed` / `Chasers Only` / `Chargers Only`
  - stacked mutation presets
- tune weapon cadence, primary skill feel, and room pressure until the loop feels clearly better than v2
- validate the new gold economy across several full runs:
  - passive survival should fall behind gradually, not instantly
  - aggressive rooms should fund multiple picks reliably
  - `15 / 50 / 100` mutation pricing should feel fair in both `1P` and `2P`
  - the shared-pickup / personal-wallet model should feel natural in couch co-op
- only revisit shops, extra objectives, boss redesign, or higher player counts after the core v3 slice is fun
