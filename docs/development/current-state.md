# Current State

## Project Role

Godot `4.6.2` prototype for a same-screen local co-op neon roguelite.

Active gameplay work happens on `v2/core-refactor`:

- this is the current working branch
- this is now also the GitHub default branch / mainline
- older v1 gameplay is preserved as archived reference:
  - historically on `main`
  - additionally on `archive/v1-main`
  - tagged as `v1-main-archive`
  - locally under `archive/v1/`
- current target is strictly `1–2` players
- `3–4` player support is deferred until the current loop validates
- the live runtime on this branch currently follows the later auto-fire / shockwave / dash direction from the newer design docs

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
  - `elite` (harder encounters, rare reward flow, mini-boss spawn)
  - `rest`
  - `shop` (buy mutations, healing, rerolls with gold)
  - `boss`
- elite nodes appear in mid-to-late rows with ~35% chance
- one rest and one shop row guaranteed reachable per run
- meta progression remains out of the live runtime
- gold economy is now live:
  - enemies drop gold pickups on death
  - non-boss enemies also have an `8%` chance to drop a `5 HP` healing pickup
  - pickups magnet to the nearest living player
  - gold is shared on collection and copied into every player's personal wallet
  - room clear auto-collects leftovers
  - survival bonus is now `0`
  - latest pickup tuning doubled the gold orb size and doubled pickup reach
- combat and elite nodes now also roll room modifiers from `data/modifiers.json`
- combat and elite nodes now also carry the `hold_zone` side objective in the run-state map data

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
- base player move speed is now tuned up to `487.5` (`+25%` over the earlier `390`)
- dash travel range is now tuned up by `33%`
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
  - `Spitter`
  - `Boss`
- base `Spitter` pressure is now tuned down from the earlier rapid-fire version:
  - `1` projectile burst
  - `1.0s` fire interval
- elite mini-boss variants are now live:
  - `Elite Charger`
  - `Elite Spitter`
  - `Elite Support`
- room objective is still `survive`, but combat and elite rooms now also run the `hold_zone` side objective in parallel
- map node types: `combat`, `elite`, `rest`, `shop`, `boss`
- mutation rewards are now rarity-split:
  - combat room-end picks roll commons only
  - each player can buy `0–3` common picks from that set
  - current placeholder common-pick costs are `15 / 50 / 100`
  - elite room-end picks roll exactly `1` rare mutation per player (buy or skip)
  - elite rare pick cost is currently `50`
  - unspent gold carries forward between rooms
- common mutations are now upgradable to `Lv3`; rares are binary one-offs
- active room modifiers currently include:
  - `Accelerating Waves`
  - `Enemy Speed`
  - `Spitter Swarm`
  - `Fire Floor`
  - `Ice Zone`
  - `Mine Field`
- `Mine Field` tuning currently uses a larger `84` trigger radius, a `0.2s` detonation delay, and a visible explosion burst for readability
- hold-zone completion now grants a room-limited temporary buff:
  - `Speed`
  - `Damage`
  - `Attack Speed`

## Active Systems

- `RunState` remains the live run-state shell:
  - room progression
  - per-player health persistence
  - per-player `1 weapon + 1 primary skill + 1 secondary skill + mutations` inventory state
  - per-player gold wallet state
  - node modifier assignment
  - combat / elite hold-zone side-objective tagging
- `CoopManager` now drives the live room loop:
  - larger arena setup
  - depth-based arena color shifts
  - auto-attack projectile spawning
  - primary skill (shockwave) blast handling + visual ring
  - enemy gold drop spawning and room-end gold payout
  - revive / fail / clear handling
  - mutation pick handoff
  - elite rare reward flow
  - modifier runtime orchestration
  - hold-zone buff orchestration
  - elite support aura orchestration
  - elite mini-boss spawning
  - automatic room progression after mutation picks
- `GoldPickup.gd` is now the live room-currency pickup path:
  - procedural neon coin/orb visual
  - magnet pull to nearest player
  - no collision-shape dependency; `CoopManager` owns collection checks
  - script warning cleanup completed so the pickup path is parse-clean without unused-signal / unused-field noise
- `HealthPickup.gd` is now the live sustain pickup path:
  - procedural green health orb / cross visual
  - `5 HP` per pickup
  - dropped from non-boss enemies at `8%`
  - magnets to the nearest eligible living player and updates persisted run health state on collect
- `Player.gd` now implements:
  - movement-facing + auto-attack runtime
  - automatic weapon fire
  - primary skill cooldown ownership
  - chevron-only player visual
  - secondary skill (dash) damage mutation support
- `AutoTarget.gd` replaced the old aim-assist path for auto-attack targeting
- `MutationSystem` now handles:
  - common vs rare mutation pools
  - upgradable common levels
  - rare exhaustion handling
  - compiled weapon scaling for the new linear roadmap formulas
  - `skill_range` (primary skill radius)
  - `skill_cooldown` (primary skill cooldown)
- `Projectile.gd` is now the live glowing-orb projectile path
- `PlayerInventoryHUD` and `WeaponSlotHUD` remain the minimal HUD:
  - health
  - weapon icon
  - primary skill cooldown
  - secondary skill (dash) cooldown
  - mutation icons
- live combat HUD now also shows per-player gold
- live combat HUD now also shows:
  - active room modifiers
  - hold-zone progress / active buff state
- map route UI now also shows per-player gold totals
- map route UI now also shows modifier counts on nodes and modifier names on hover
- mutation pick UI now reuses each player's live input bindings instead of separate hardcoded menu keys
- shop UI now also follows the live per-player bindings and actual assigned gamepad device IDs
- pause menu now also follows the live per-player bindings and actual assigned gamepad device IDs
- encounter builder now supports:
  - room type (`combat`, `elite`, `rest`, `shop`, `boss`)
  - objective (`survive` only)
  - depth
  - enemy mix override
  - room modifier injection (`0–3`)
  - starting mutation presets

## Removed From Live Runtime

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
- no generator objective
- no alternative primary families in live combat
- no `3–4` player support target for the current validation phase

Obsolete v1 systems remain preserved under `archive/v1/` as archive/reference content only.

## Known Gaps

- the current branch runtime now matches the new control model structurally, but still has not had a full feel-validation pass
- primary skill (shockwave), weapon cadence, and mutation payoff still need live tuning
- boss behavior is still the older fight shape and has not yet had its current-branch redesign
- builder mutation presets are for testing, not polished end-user UX
- glow / neon presentation is improved, but this is still a gameplay-first pass rather than a final art pass
- full-screen effects are forced on for now and are no longer user-configurable
- the economy loop is now implemented structurally, but gold values and mutation costs are still placeholder and need pacing validation
- shop nodes are now live but shop UI is basic (list-based, not polished)
- elite support aura, room modifiers, and hold-zone buff rewards still need real gameplay tuning
- upgradable commons still render as duplicate mutation chips in the HUD instead of a single leveled badge
- heavy projectile scenes now have first-pass runtime guard rails:
  - HUD refresh is throttled instead of updating every physics frame
  - dense projectile trails are suppressed under load
  - projectile/effect spam is capped under extreme load
- heavy enemy-count scenes now also have first-pass CPU guard rails:
  - active-player lists are cached once per physics frame instead of rebuilt repeatedly
  - enemy/player target getters no longer duplicate arrays on every query
  - enemy target selection, separation, and obstacle-feeler steering are throttled when crowd counts get high

## Next Step

If work continues on `v2/core-refactor`, the next priority is play validation:

- validate the full encounter restructure across several runs:
  - combat, elite, rest, shop, boss node types visible and reachable on the map
  - elite rooms should feel noticeably harder and the rare reward flow should feel worth the risk
  - shop should be usable (buy mutations, heal, reroll, done)
  - gold economy pacing across a complete run
  - passive survival should fall behind gradually, not instantly
  - aggressive rooms should fund multiple picks reliably
  - `15 / 50 / 100` common pricing and `50` elite-rare pricing should feel fair in both `1P` and `2P`
  - the shared-pickup / personal-wallet model should feel natural in couch co-op
  - modifier combinations should stay readable and not overwhelm the base room loop
  - hold-zone buffs should be noticeable without becoming mandatory
- tune weapon cadence, primary skill feel, and room pressure
- future additions beyond this validation:
  - side challenges (optional bonus objectives for extra gold)
  - boss redesign for the current branch runtime
  - `3-4` player support
