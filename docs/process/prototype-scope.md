# Prototype Scope

## First Playable Goal

Build a same-screen local co-op twin-stick roguelite prototype in Godot where one or two players can complete a full 10-15 minute run through room-based combat, shared loot, node-map choices, and a boss encounter.

## Core Loop

Enter room -> fight under one active modifier -> clear the room -> make one shared loot or route decision -> continue to the next room.

## Locked Decisions Through Patch 7

- Same-screen camera with one fixed room view.
- No split-screen and no dynamic zoom.
- Same role for all players.
- Fully cooperative play with shared loot and shared failure.
- Godot 4.6.2 stable only during the prototype.
- GDScript only for gameplay code.
- JSON-first content definitions.
- No mid-run save system.
- No class system.
- No Skeleton2D rigging before the prototype loop is proven.

## Explicit Non-Goals Before Patch 8

- 3-4 player tuning
- deep art production
- advanced menus
- meta-progression
- export polish
- expanded content breadth beyond first-playable needs

## Prototype Success Criteria

- The game launches quickly and is understandable without explanation.
- A two-player run can be completed in 10-15 minutes.
- Shared decisions are readable in the moment.
- A non-gamer can complete a run without asking for help.

