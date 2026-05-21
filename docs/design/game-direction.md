# Game Direction

## Scope Note

- This file describes the active direction on `v2/core-refactor`.

## One-Line Pitch

Same-screen co-op roguelite where your rifle auto-fires, you focus on movement and timing, and the run grows through gold, mutation buys, and route choices.

## The Feel

You move first. The weapon handles the basic fire loop. The decisions come from:

- where to stand
- when to shockwave
- when to dash
- whether to spend or save gold
- whether to route toward safety or pressure

The run should feel readable first and explosive second.

## Core Loop

1. Pick a node on the map.
2. Enter the room.
3. Survive while auto-fire, dash, and shockwave handle combat.
4. Collect gold through combat.
5. Buy room-end mutations or use a shop node when available.
6. Route toward the boss.
7. Repeat until the run ends.

## Combat Direction

### Weapon

- Auto-firing `Rifle`
- Nearest-enemy targeting
- Baseline cadence is intentionally readable, not hyper-dense
- Mutations should visibly change projectile behavior

### Primary Skill

- `Shockwave`
- Player-centered panic / space-making tool
- Distinct from the weapon because it creates breathing room rather than sustained DPS

### Secondary Skill

- `Dash`
- Repositioning and survival tool
- Not a replacement for normal movement

## Current Live Runtime Assumptions

- `1-2` players only
- same-screen dynamic zoom camera
- local co-op only
- current live enemies:
  - `Chaser`
  - `Charger`
  - `Spitter`
  - `Boss`
- current live room types:
  - `combat`
  - `elite`
  - `rest`
  - `shop`
  - `boss`
- current live room objective:
  - `survive`

## Progression Direction

- Gold is the active run currency.
- Gold comes from enemy deaths and room clear payout.
- Mutations are not free anymore.
- Room-end mutation buying and shop spending are both part of the live loop.
- Build identity should come from visible projectile/skill changes, not spreadsheet reading.

## Co-Op Direction

- Same-screen only
- No split-screen
- Shared combat space, but each player has their own wallet copy and their own mutation-buy decisions
- Co-op expression should come from movement overlap, revive moments, and route tension more than from role specialization

## Visual Direction

- Dark arena
- readable neon combat contrast
- geometric placeholder visuals are acceptable while tuning remains the priority
- spectacle should never bury enemy, projectile, or HUD readability

## What This Direction Is Not

- It is not the old manual-fire twin-stick version.
- It is not currently a modifier-heavy, layout-heavy, objective-heavy build.
- It is not a `3-4` player target yet.

## Current Design Priorities

- validate the current run loop in live play
- balance economy values
- tune modifier readability and pressure
- validate elite reward identity and side-objective payoff
- redesign the boss around the current branch runtime

## Next Expansion Areas

- side challenges beyond `hold_zone`
- elite reward identity follow-up
- encounter-depth reintroduction
- boss redesign
