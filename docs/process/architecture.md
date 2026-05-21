# Architecture

## Scope Note

- This file describes the active runtime on `v2/core-refactor`.
- Older v1 gameplay is archive/reference material only.
- If this file conflicts with `docs/development/current-state.md`, update this file to match `current-state.md`.

## Folder Ownership

- `scenes/`: scene composition for runtime, UI, player, enemies, pickups, and flow scenes
- `scripts/`: gameplay and runtime logic
- `data/`: editable JSON definitions for the live runtime
- `assets/`: runtime art, audio, fonts, and imported content
- `archive/`: preserved old content that is no longer part of the live runtime
- `docs/process/`: source of truth for scope, roadmap, and architecture
- `docs/development/`: current runtime truth and session memory
- `docs/design/`: design direction, roadmap, and implementation history

## Runtime Boundaries

- Simulation owns:
  - movement
  - auto-targeting
  - auto-fire
  - dash and shockwave runtime
  - enemy spawning
  - revive/fail/clear rules
  - room progression
  - gold pickup and wallet flow
  - mutation reward flow
  - shop spending flow
- Presentation owns:
  - arena visuals
  - HUD
  - route-map presentation
  - pause/result/menu surfaces
  - particles, flashes, and readability effects
  - camera framing and zoom feel
- Scene files compose nodes but should not hide rule logic.
- Placeholder visuals remain acceptable as long as gameplay readability stays high.

## Singleton Policy

- `RunState.gd` is the live cross-room state owner.
- It owns:
  - player configs
  - node-map generation and progression
  - current node selection
  - player health persistence
  - player inventories
  - player gold wallets
  - run outcome
  - debug launch setup
- Persistent profile/meta state is not part of the active runtime loop right now.

## Input And Bootstrap

- Player setup starts in `Bootstrap.gd`.
- Current front-door flow is:
  - `Play`
  - `Encounter Builder`
- Player setup currently targets `1-2` players.
- Default control split is:
  - `P1` gamepad
  - `P2` keyboard
- Live input model is:
  - movement only as direct aim-independent movement input
  - weapon fire is automatic
  - primary skill is shockwave
  - secondary skill is dash
- Settings and meta menus are not part of the live front-door flow.

## Run Flow

- `Bootstrap.gd` starts the run and passes player/debug setup into `RunState`.
- `RunFlow.gd` owns:
  - map display
  - route-node selection
  - room transitions
  - noncombat room resolution handoff
- `CoopManager.gd` owns the in-room runtime.
- The live map flow is:
  - `combat`
  - `elite`
  - `rest`
  - `shop`
  - `boss`
- Current room objective runtime is `survive` only.
- Encounter Builder is a separate fast-iteration entry path, not a second source of truth.

## Main Runtime Ownership

- `scripts/game/RunState.gd`:
  - run graph generation
  - current node data
  - room-to-room persistence
  - inventory and wallet state
- `scripts/game/CoopManager.gd`:
  - arena runtime
  - player spawning
  - enemy spawning
  - room clear/fail handling
  - gold drop flow
  - mutation pick flow
  - shop flow
- `scripts/player/Player.gd`:
  - movement
  - auto-fire timing
  - shockwave cooldown ownership
  - dash runtime
- `scripts/player/AutoTarget.gd`:
  - nearest-enemy targeting
- `scripts/game/MutationSystem.gd`:
  - mutation definition loading
  - mutation compilation
  - mutation reward rolls
- `scripts/pickups/GoldPickup.gd`:
  - room-currency pickup behavior
- `scripts/weapons/Projectile.gd`:
  - projectile movement
  - impact logic
  - pierce / ricochet / trail behavior
- `scripts/ui/Bootstrap.gd`:
  - run launch
  - encounter builder
  - player configuration
- `scripts/ui/MutationPickUI.gd`:
  - room-end mutation-buy UI

## Core Data Contracts

- `PlayerConfig`:
  - `player_id`
  - `control_source`
  - `tint`
- `data/weapons.json`:
  - live weapon and primary-skill definitions
- `data/mutations.json`:
  - live mutation definitions
- `PlayerInventory`:
  - `weapon_id`
  - `primary_skill_id`
  - `mutations`
  - `gold`
- `RunState.get_player_runtime_loadout_for()` returns the runtime loadout contract consumed by `Player.gd`.

## Archived Content Rule

- `archive/v1/` is not part of the live runtime.
- Archived files may be referenced for recovery or comparison.
- Archived behavior should not be treated as default design intent for the current branch.

## Current Architecture Risks

- The main risk is no longer large-system ownership confusion.
- The main risk is gameplay validation:
  - pacing
  - reward feel
  - room pressure
  - economy balance
  - shop clarity
- New systems should be added only after the current loop stays readable and fun in live play.
