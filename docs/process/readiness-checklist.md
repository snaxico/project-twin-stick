# Readiness Checklist

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
- Work is sliced by patch and validated before expansion

## Readiness Answers

1. What is the player doing repeatedly?
   Fight through one room, make one cooperative decision, and repeat.
2. What makes that loop interesting?
   Room modifiers, layout variation, enemy compositions, and shared build choices.
3. What is intentionally not being built yet?
   3-4 player tuning, deep art, meta-progression, and polish systems.
4. What is the smallest playable slice that proves the concept?
   A stable bounded-room action prototype that grows into a two-player combat loop by Patch 2 and into a full run by Patch 7.

