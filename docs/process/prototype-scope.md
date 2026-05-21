# Prototype Scope

## Scope Note

- This scope applies to the active branch runtime on `v2/core-refactor`.
- Older v1 gameplay is archived reference only.

## Current Prototype Goal

Build a same-screen local co-op roguelite prototype in Godot where one or two players can complete a readable full run through:

- node-map choices
- combat rooms
- elite rooms
- rest and shop pacing beats
- room-end mutation buying
- a boss encounter

The immediate success bar is a stable, understandable, `1-2` player run that feels good without explanation.

## Core Loop

Pick a node on the map -> enter room -> survive under room pressure -> earn and spend gold through mutation/shop flow -> continue toward boss.

## Locked Runtime Assumptions

- Same-screen camera only
- Dynamic zoom is part of the live runtime
- No split-screen
- Local co-op only
- Same role for all players
- Godot `4.6.2` stable only
- GDScript gameplay code only
- JSON-first content definitions
- No mid-run save system
- No class system

## Live Runtime Shape

- `1-2` players only
- weapon fire is automatic
- live loadout is:
  - `Rifle`
  - `Shockwave`
  - `Dash`
- live room types are:
  - `combat`
  - `elite`
  - `rest`
  - `shop`
  - `boss`
- current room objective is:
  - `survive`

## Explicit Non-Goals Right Now

- `3-4` player gameplay support
- meta progression as part of the live loop
- deep art production
- major frontend polish
- expanded enemy roster before current pacing validates
- modifier re-expansion before the base loop validates
- restoring archived v1 systems just because they already exist somewhere in the repo

## Current Validation Focus

- full-run pacing
- gold economy feel
- mutation-buy flow
- elite difficulty identity
- shop usability
- boss fairness
- general combat readability under stress

## Success Criteria

- The game launches quickly and is understandable without explanation.
- A `1P` or `2P` run reaches the boss through the live map flow without structural breakage.
- Combat, gold, mutation buys, and shop nodes feel like one coherent loop.
- The run stays readable enough to tune rather than needing another structural rewrite first.
