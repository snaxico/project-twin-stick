# Game Direction

## Scope Note

- Describes the active direction on `v3/main`. Runtime detail of record is `docs/development/current-state.md`.
- This supersedes the old gold/shop economy direction (removed in the V3 redesign).

## One-Line Pitch

Same-screen local co-op roguelite where your weapon auto-fires by default, manual aim can override
when you want control, and the run grows through an XP economy of weapons, effects, attributes, and
ability upgrades.

## The Feel

You move first; the weapon handles the basic fire loop unless the player deliberately overrides with
right-stick or mouse aim. Decisions come from where to stand, when to manually aim, when to use your
OFF/DEF abilities, which **Upgrades** to take at level-ups, and which route to push. Readable first,
explosive second: spectacle must never bury enemy/projectile/HUD readability.

## Core Loop

1. Choose the next room (route choice).
2. Survive the room while auto-fire + your two abilities handle combat.
3. Kills feed one shared XP bar; level-ups bank room-end **Reward screens**.
4. Pick one Upgrade per Reward screen (elite rooms grant a bonus guaranteed-rare round).
5. Health resets at the start of every room.
6. Push toward the boss. Repeat until the run ends.

## Combat Direction

- **Weapons:** 7 peer weapons — `Rifle`, `Rocket Launcher`, `Shotgun`, `Cannon`, `Railgun`, `Beam`,
  `Boomerang`. One active at a time; a single shared `weapon_level` (1-5) is preserved when changing
  weapons. Weapons are chosen at the Reward screen (Level Up / Change cards). Weapon level is the
  primary offense axis.
- **Aim:** auto-targeting is the default feel, with seamless right-stick / mouse manual override and a
  manual-only option for players who want full aim control.
- **Momentum / Flow:** per-player passive meter that builds from shared kill gain, drops on actual HP
  loss, and gives uncapped additive movement/fire-rate bonuses.
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

- Dark arena, readable neon contrast, render-local over-bright bloom. Geometric visuals are
  placeholder scaffolding while tuning is the priority; the intended final style is a later rubberhose
  restyle once mechanics are stable.
- Audio is procedural (generated SFX + adaptive music); spectacle never buries readability.

## Current Priorities

- Validate and tune the round-14 build (see `playtest-round-14-plan.md`): controller ownership,
  manual aim, Momentum, Beam, Boomerang, Split, additive stat balance, and player/enemy/zoom
  readability.
- Boss feel/fairness (windups, telegraphs), rarity feel, readability (cards, ability text, scanlines).
- Keep using the Perf Runner for dense-room and boss stress checks; enemy MultiMesh remains deferred
  unless live playtest contradicts real-room performance.

## What This Direction Is Not

- Not the old gold/shop/mutation-buy economy.
- Not a `3-4`-player or split-screen target.
- Not pure manual-fire twin-stick; auto-targeting remains the default, with manual aim as an override
  and optional mode.
