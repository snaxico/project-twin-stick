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
- run flow now uses the full node map:
  - `combat`
  - `elite` (harder encounters, 1.3x gold multiplier, charger-heavy mix)
  - `rest`
  - `shop` (buy mutations, healing, rerolls with gold)
  - `boss`
- elite nodes appear in mid-to-late rows with ~35% chance
- one rest and one shop row guaranteed reachable per run
- meta progression remains out of the live runtime
- gold economy is now live:
  - enemies drop gold pickups on death
  - pickups magnet to the nearest living player
  - gold is shared on collection and copied into every player's personal wallet
  - room clear auto-collects leftovers and adds a flat survival bonus
  - latest pickup tuning doubled the gold orb size and doubled pickup reach

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
- room objective: `survive` only (capture_the_hill removed)
- map node types: `combat`, `elite`, `rest`, `shop`, `boss`
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
  - script warning cleanup completed so the pickup path is parse-clean without unused-signal / unused-field noise
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
- shop UI now also follows the live per-player bindings and actual assigned gamepad device IDs
- pause menu now also follows the live per-player bindings and actual assigned gamepad device IDs
- encounter builder now supports:
  - room type (`combat`, `elite`, `rest`, `shop`, `boss`)
  - objective (`survive` only)
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
- the economy loop is now implemented structurally, but gold values, survival bonus, and mutation costs are still placeholder and too cheap
- shop nodes are now live but shop UI is basic (list-based, not polished)
- elite rooms are functional but have no unique anchor enemies (mini-bosses) yet
- mutation rarity split (common/rare), upgradable commons, side objectives (Hold Zone), temp buffs, modifier system (6 modifiers), Spitter enemy, elite mini-bosses (3 archetypes), and economy flatten are all designed and locked in `docs/design/roadmap.md` — a detailed 8-slice implementation plan exists at `docs/design/implementation-plan.md` but none of it is implemented yet
- heavy projectile scenes now have first-pass runtime guard rails:
  - HUD refresh is throttled instead of updating every physics frame
  - dense projectile trails are suppressed under load
  - projectile/effect spam is capped under extreme load
- heavy enemy-count scenes now also have first-pass CPU guard rails:
  - active-player lists are cached once per physics frame instead of rebuilt repeatedly
  - enemy/player target getters no longer duplicate arrays on every query
  - enemy target selection, separation, and obstacle-feeler steering are throttled when crowd counts get high

## Next Step

Implementation of roadmap Tiers 1–6 via the 8-slice plan in `docs/design/implementation-plan.md`:

- Slice 0: fix elite debug path + add reversible Player stat modifier layer (prerequisite)
- Slice 1: economy flatten (1g per enemy, remove survival bonus)
- Slice 2: mutation rarity system (commons Lv1–3, rares binary, new scaling)
- Slice 3: elite rare-only picks (1 rare per elite room-end)
- Slice 4: Spitter enemy (new type + kiting AI)
- Slice 5: modifier system (6 modifiers, data JSON, run gen, 3 new scripts)
- Slice 6: elite mini-bosses (3 archetypes, aura system)
- Slice 7: Hold Zone side objective + temp buffs

After implementation, validate in live play before expanding further. Remaining future work:
- boss redesign for v3
- `3-4` player support
- meta progression / ability unlocks
- shop UI polish
