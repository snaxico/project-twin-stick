# V2 Refactor Summary

## Purpose

This document summarizes the gameplay and codebase changes made on the `v2/core-refactor` branch after the decision to split away from the preserved v1 game on `main`.

The goal of this branch was not to extend the old patch line. It was to build a simpler v2 gameplay base around a more direct `1–2` player combat loop.

## Branch Direction

- stable v1 gameplay remains preserved on `main`
- v2 work happens on `v2/core-refactor`
- current v2 target is `1–2` players only
- `3–4` player support is deferred until the v2 loop is proven fun

## High-Level Result

The branch moved from a large multi-system roguelite prototype toward a smaller, cleaner gameplay core:

- one primary weapon
- one secondary ability
- per-player mutation progression
- larger shared arena
- zooming same-screen camera
- limited enemy roster
- minimal HUD
- reduced room/map system

This made the codebase simpler, but the gameplay result is still considered unvalidated and may still need another directional reboot.

## Major Runtime Changes

### Combat Loop

- player loadout was reduced to:
  - `1` primary
  - `1` secondary
  - mutation list
- live starting loadout is now:
  - `Rifle`
  - `Grenade`
- live enemy roster is now:
  - `Chaser`
  - `Charger`
  - `Boss`
- live room objectives are now:
  - `survive`
  - `capture_the_hill`
  - `rest`
  - `boss`

### Arena + Camera

- arena size was expanded to `4800 x 2700`
- shared camera was replaced with a zooming player-fit camera
- player separation is now hard-clamped to the camera leash distance
- later follow-up added:
  - stronger floor grid lines
  - repeating major guide lines
  - visible perimeter wall visuals on the arena boundary

### Progression

- per-player post-room mutation picks replaced the old loot/shop/passive progression loop
- mutation data now comes from `data/mutations.json`
- mutation categories currently affect:
  - primary fire behavior
  - grenade radius / charges
  - dash damage
  - knockback

### HUD + Front End

- HUD was reduced to:
  - health
  - primary icon
  - secondary icon / cooldown / charges
  - mutation icons
- front menu paths are now:
  - `Play`
  - `Settings`
  - `Encounter Builder`
- meta progression is hidden in the live v2 branch

### Encounter Builder

- builder was adapted away from the old layout/modifier/recipe setup
- builder now supports:
  - room type
  - objective
  - depth
  - enemy mix override
  - starting mutation presets
- old builder rows were intentionally reused rather than removed entirely

## Core Rewrites

### Rewritten

- `scripts/game/CoopManager.gd`
- `scripts/game/RunState.gd`
- `scripts/game/PlayerInventory.gd`
- `scripts/player/Player.gd`
- `scripts/ui/Bootstrap.gd`
- `scripts/ui/RunFlow.gd`
- `scripts/ui/PlayerInventoryHUD.gd`
- `scripts/ui/WeaponSlotHUD.gd`
- `scripts/meta/ProfileState.gd`
- `scripts/weapons/Projectile.gd`
- `scripts/weapons/GrenadeProjectile.gd`
- `data/weapons.json`

### Added

- `scripts/game/ZoomCamera.gd`
- `scripts/game/MutationSystem.gd`
- `scripts/ui/MutationPickUI.gd`
- `scenes/ui/MutationPickUI.tscn`
- `scripts/weapons/FireTrailZone.gd`
- `data/mutations.json`

## Systems Removed From Live V2

These systems are no longer part of the live runtime:

- shop runtime
- loot-drop and vote flow
- replacement UI flow
- meta-gold progression loop
- recipe engine
- modifier engine
- hazard systems tied to modifiers
- generator objective runtime
- mine secondary path
- multi-slot loadout runtime
- alternative primary weapon families in live combat
- live arena layout / obstacle preset flow

## Archived V1 Content

Obsolete v1 scripts, scenes, and data were moved under `archive/v1/` while preserving folder structure.

Archived categories include:

- recipe/modifier/hazard scripts
- generator / loot / shop / room pickup scripts
- old loot/shop/replacement UI scenes and scripts
- mine projectile scene and script
- old recipe / modifier / passive / item data

## Follow-Up Fixes After Initial Refactor

After the initial v2 refactor pass, several follow-up fixes landed:

### Combat / Input

- buffered dash-damage application now uses the actual stored dash direction instead of aim direction
- secondary charge behavior was confirmed and kept as:
  - spend both charges freely
  - start one shared cooldown after the final charge
  - refill the full stock when cooldown completes

### Room Pacing

- spawn pressure was increased significantly from the first v2 refactor pass
- rooms now begin spawning enemies almost immediately
- spawn cadence is faster
- live enemy cap is higher
- per-wave spawn count is higher
- survive rooms now clear immediately when the timer ends instead of waiting for the room to empty

### Arena Readability

- floor grid lines were made much more visible
- major guide lines were added across the arena
- a visible perimeter wall was added on top of the invisible collision walls

## Current Risks

- the codebase is much cleaner than the old branch, but gameplay feel is still not where you want it
- structural simplification does not guarantee better pacing or better combat feel
- this branch is now a strong technical base, but not yet a proven gameplay direction

## Recommended Use Of This Branch

Treat this branch as a reusable parts bin and test bed.

High-value reusable pieces:

- player movement / dash shell
- projectile runtime
- grenade runtime
- zoom camera
- mutation runtime
- builder shell
- minimal HUD shell

The systems most likely to change again if v2 restarts:

- room pacing
- spawn logic
- overall combat loop flow
- reward cadence
- objective rhythm
- run-state structure
