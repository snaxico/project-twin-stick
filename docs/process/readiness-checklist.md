# Readiness Checklist

## Scope Note

- This checklist should be read against the active branch runtime on `v2/core-refactor`.
- Older v1 gameplay is archived reference only.

## Vision

- Project name is defined: `Project Placeholder`
- Genre is defined: local co-op twin-stick ranged action roguelite
- Core player fantasy is defined: short, readable couch co-op runs that work for both gamers and non-gamers
- Core loop is defined
- First playable goal is defined
- Version-one non-goals are written down

## Production Constraints

- Target platform is fixed: Windows desktop first
- Engine is fixed: Godot 4.6.2 stable
- Input model is fixed at the contract level
- Art direction is defined at a high level: rubberhose cartoon, placeholder-first production
- Audio expectations are deferred to post-first-playable polish
- Prototype performance target is 60 FPS with clean runtime output

## Scope

- The first playable is one full gameplay loop, not a content-breadth prototype
- Every early system is justified by the first playable
- Deferred systems are written down explicitly

## Architecture

- Core folder ownership is defined
- Simulation and presentation boundaries are defined
- Save/load is deferred until post-prototype
- Content authoring is JSON-first for the prototype

## Workflow

- Standards are reviewed
- `docs/process/` and `docs/development/` are in use
- Session history format is defined
- Major decisions will be logged in `docs/process/decisions/`
- Work is sliced into validated follow-up slices before expansion

## Readiness Answers

1. What is the player doing repeatedly?
   Pick a route, survive a room, grow through gold and mutation/shop choices, and repeat.
2. What makes that loop interesting?
   Positioning, room pressure, gold pacing, mutation choices, and route decisions.
3. What is intentionally not being built yet?
   `3-4` player support, deep art, meta progression in the live loop, and broader content expansion.
4. What is the smallest playable slice that proves the concept?
   A stable `1-2` player full run on the current branch map flow with readable combat, gold, mutation buying, shop pacing, and a boss encounter.
