# V2 Branch Summary

## Purpose

This document summarizes the current gameplay/runtime direction of `v2/core-refactor`.

It is not a plan for future migration.

## Branch Position

- `v2/core-refactor` is the active gameplay branch.
- This branch is also the GitHub default branch / mainline.
- The current branch runtime is the game that should be treated as live today.

## Current Runtime Direction

The branch now centers on a simpler `1-2` player loop built around:

- auto-firing `Rifle`
- `Shockwave`
- `Dash`
- node-map progression
- gold pickups and personal wallets
- room-end mutation buying
- shop rooms
- elite rooms
- a shared same-screen zoom-camera arena

## Live Runtime Shape

- player target:
  - `1-2` players
- live enemies:
  - `Chaser`
  - `Charger`
  - `Spitter`
  - `Boss`
- live room types:
  - `combat`
  - `elite`
  - `rest`
  - `shop`
  - `boss`
- live room objective:
  - `survive`

## Important Branch Shifts

Compared with older branch states, the current runtime:

- removed manual-fire combat from the live loop
- removed grenade from the live loop
- removed capture-the-hill from the live loop
- removed the old settings/meta front-door flow from the live menu
- removed loot-vote and replacement flow from the live loop
- reintroduced a live gold/shop economy
- narrowed the active validation target back to `1-2` players

## Current Systems That Matter Most

- `RunState.gd`
- `CoopManager.gd`
- `Player.gd`
- `AutoTarget.gd`
- `MutationSystem.gd`
- `Projectile.gd`
- `GoldPickup.gd`
- `Bootstrap.gd`
- `RunFlow.gd`
- `MutationPickUI.gd`

## Current Risks

- The runtime is structurally much cleaner than the old branch state, but gameplay validation is still the main risk.
- The current unanswered questions are about:
  - pacing
  - economy
  - modifier readability
  - elite identity
  - boss quality

## How To Use This Branch

- Treat this branch as the live game.
- Use `docs/development/current-state.md` for exact runtime truth.
- Use `docs/design/roadmap.md` for next feature-design decisions.
