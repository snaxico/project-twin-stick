# Game Direction

## Scope Note

- Describes the active direction on `v3/main`. Runtime detail of record is `docs/development/current-state.md`.
- This supersedes the old gold/shop economy direction (removed in the V3 redesign).

## One-Line Pitch

Same-screen local co-op roguelite where your weapon auto-fires, you focus on movement and timing,
and the run grows through an XP economy of weapons, effects, attributes, and ability upgrades.

## The Feel

You move first; the weapon handles the basic fire loop. Decisions come from where to stand, when
to use your OFF/DEF abilities, which **Upgrades** to take at level-ups, and which route to push.
Readable first, explosive second — spectacle must never bury enemy/projectile/HUD readability.

## Core Loop

1. Choose the next room (route choice).
2. Survive the room while auto-fire + your two abilities handle combat.
3. Kills feed one shared XP bar; level-ups bank room-end **Reward screens**.
4. Pick one Upgrade per Reward screen (elite rooms grant a bonus guaranteed-rare round).
5. Health resets at the start of every room.
6. Push toward the boss. Repeat until the run ends.

## Combat Direction

- **Weapons (new — the round-9 system):** 5 peer weapons — `Rifle`, `Rocket Launcher`,
  `Scattergun`, `Cannon`, `Railgun`. One active at a time; a single shared `weapon_level` (1–5)
  preserved when changing weapons. Weapons are chosen at the Reward screen (Level Up / Change cards).
  Weapon level is the primary offense axis.
- **Abilities:** `1 OFF` (LT) + `1 DEF` (RT) from the 9-ability roster (Shockwave, Dash, Overcharge,
  Blink, Shield, Decoy, Turret, Minefield, Orbit). Each ability has a rare **Signature** upgrade.
- **Upgrade categories:** Weapon · Effect (burn/frost/venom/bounce on-hit riders) · Attribute
  (damage/fire-rate/HP/…) · Ability. Build identity should come from visible projectile/effect
  changes, not spreadsheet reading.

## Progression Direction

- **XP economy** (gold/shops/rest rooms are removed). Shared XP bar; banked room-end picks.
- Rare weighting scales by act/progress; pity protection guarantees rares aren't starved.
- Health resets per room (no carried-over health economy).

## Run Structure

- **Structured:** 2-act branching route (combat rows + optional elites + mid-boss + final boss),
  presented as next-choice route cards with real risk/reward.
- **Endless:** sequential rooms, boss every 5, score = rooms cleared.

## Enemies & Bosses

- Enemies: Chaser, Charger, Spitter, Splitter, Splitter Mini, Bomber.
- Elites: Elite Charger, Elite Spitter, Elite Support.
- Bosses: Warden, Hydra, Hive, Pulsar — each with phase escalation, telegraphed heavy attacks, and
  add pressure.

## Co-Op Direction

- `1-2` players, same-screen only, **no split-screen** (dynamic zoom camera). `3-4` deferred.
- Shared combat space + shared XP; each player picks their own Upgrades.
- Co-op expression comes from movement overlap, revives, and route tension — not role specialization.

## Visual / Audio Direction

- Dark arena, readable neon contrast, render-local over-bright bloom. Geometric placeholder visuals
  acceptable while tuning is the priority.
- Audio is procedural (generated SFX + adaptive music); spectacle never buries readability.

## Current Priorities

- Validate and tune the round-9 weapon system + the round-10 patch (see `playtest-round-10-plan.md`).
- Boss feel/fairness (windups, telegraphs), rarity feel, readability (cards, ability text, scanlines).
- A dedicated **performance round** for the ~200-entity ceiling (MultiMesh + caps), driven by the Perf Runner.

## What This Direction Is Not

- Not the old gold/shop/mutation-buy economy.
- Not a `3-4`-player or split-screen target.
- Not manual-fire twin-stick.
