# Start Of Day

Read this first to restore project context quickly, then read `current-state.md` and the latest file in
`history/`.

## Working Branch

- Canonical active branch: `v4/class-system`.
- Continue work from `D:\GameDev\Project_Twin_stick`; this local checkout is now `v4/class-system`.
- `v3/main`, `v3/structure-rework`, and older `v2/*` branches are historical baselines. Do not merge them into
  V4 wholesale; cherry-pick only reviewed changes that still fit the class-system direction.
- Do not push unless asked.

## Source Of Truth

- `docs/development/current-state.md` is the compact runtime source of truth.
- `docs/development/v4-implementation-plan.md` and `docs/development/v4-polish-round-plan.md` are the shipped
  V4 implementation sources.
- `docs/development/v4-round-2-plan.md` is the active follow-up plan.
- `docs/development/structure-rework-plan.md` is archived V3 context, not the current implementation target.
- `docs/design/game-direction.md` is the broader direction source of truth.
- `docs/design/class-system-redesign.md` is the V4 design spec (4 classes, kit/mutation/tag systems, art
  direction, implementation touchpoints). Companion data: `docs/design/class-design.xlsx`.
- `docs/development/history/` records what changed, why, and what remains open.
- If this file and `current-state.md` disagree, treat `current-state.md` as correct and update this file.

## Project Snapshot

- Godot `4.6.2` same-screen local co-op twin-stick roguelite prototype.
- Target player count is `1-2`.
- V4 class-system implementation and polish round are implemented.
- The July 14 V4 playtest patch in `docs/development/v4-playtest-findings-2026-07-14.md` is implemented. The
  active next validation is a focused 1P/2P live playtest of its upgrade gates, balance, UI, ability feel, and
  redesigned WHERE catalog.

## Live Runtime Summary

- There is one continuable run, no Structured / Endless mode split.
- Normal steps show two next-room cards.
- Champion steps show one forced champion card.
- Next-room cards show trait, danger pips, real modifier names, and rare-odds nudge.
- Room `10` is the milestone champion room.
- Clearing room `10` banks a win and offers `Continue` / `End Run`.
- Continuing keeps the same run scaling past room `10`.
- Branching map UI and graph generation are removed.
- Health resets every room because `GameWorld` / `CoopManager` is recreated.
- Momentum persists across the run through `RunState`; damaging hits still drop two tiers.
- Run score persists in `RunState` and banks once to `ProfileState` on terminal run end.

## Combat / Progression

- Enemy kills feed one shared XP bar.
- Level-ups bank room-end pick rounds.
- Champion rooms grant one additional forced-rare reward pick after XP picks resolve.
- Reward picks support shared-score rerolls and free skips.
- Rare odds scale continuously by depth and can receive a small room-choice nudge.
- Upgrades now include common, rare, and Signature tiers with class/tag synergies.
- `ProfileState` stores banked score and permanent unlocks. The Meta menu spends score to add weapons,
  abilities, rares, and Signatures into future pools.
- Continuation pressure now keeps rising past the milestone through:
  - room duration
  - spawn interval
  - burst interval
  - burst size
  - deeper enemy-pool weighting
  - champion damage/cooldowns/speed
- Enemy HP is intentionally not the main deep-run pressure driver.
- The early game is more active after chaser/charger buffs, tighter spawn cadence, larger bursts, fewer HP
  drops, and a higher kill-streak target.

## Live Loadout

- Every player has:
  - one active weapon, starting with `Rifle`
  - shared weapon level `1-5`
  - `1 OFF` ability on `LT`
  - `1 DEF` ability on `RT`
  - mutation inventory
- Live weapons:
  - `Rifle`
  - `Rocket Launcher`
  - `Shotgun`
  - `Cannon` - now tuned toward burst-AOE with splash
  - `Railgun`
  - `Beam` - sustained tracking DPS, softened slightly in Phase 4
  - `Boomerang`
- Live ability roster:
  - `Shockwave`
  - `Dash`
  - `Overcharge`
  - `Blink`
  - `Shield`
  - `Decoy`
  - `Turret`
  - `Minefield`
  - `Orbit`
- New profiles start with `Rifle`, `Shotgun`, `Overcharge`, `Dash`, and base common upgrades unlocked.
  Other weapons, abilities, rare upgrades, and Signature upgrades are meta unlocks.

## Champions

- Unified champion pool:
  - `Champion Warden`
  - `Champion Hydra`
  - `Champion Hive`
  - `Champion Pulsar`
  - `Champion Charger`
  - `Champion Spitter`
  - `Champion Support`
- Former elite IDs and boss IDs are kept internally as stable enemy IDs.
- Dedicated boss rooms, boss phases, boss phase pips, boss add-wave budgets, elite rooms, elite add-waves,
  and elite act scaling are removed.

## Known Risks

- Phase 4 tuning is first-pass and needs focused live validation.
- Replayability and QoL/difficulty patch values are first-pass and need live validation.
- Reroll cost, skip frequency, and shared-score spend pressure need live validation.
- The lean start may need a larger free set or cheaper early costs if early runs feel too narrow.
- Champion readability inside dense waves still needs live validation.
- Deep runs may exhaust upgrade variety; parked until real run depths are known.
- Objective-panel icons still use simple letter fallback glyphs (`H` / `K` / `C`).
- Pulsar EMP / hazard readability and Hive deflector readability need live feel validation in dense rooms.

## Validation Reminder

- Headless validation executable:
  - `D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`
- Standard parse check:

```powershell
& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' --quit
```

- PerfRunner champion profile example:

```powershell
& 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick' -- --profile=champion:hive --players=2 --build=heavy
```

## Development Guidelines

Canonical guidelines live in `docs/process/solo-dev-rules.md`. Key rules:

- Build one vertical slice at a time; give AI one bounded task at a time; review generated code.
- Stick to the approved plan; flag unclear items before implementing.
- Terminology: "Upgrade" is the player/doc word; "mutation" is code-only.
- Use the PerfRunner for perf tests.
- Commit only after a slice works and validation passes.
- Never treat a broken intermediate state as done.

## Session Read Order

- Before changing code, reread:
  - `start-of-day.md`
  - `current-state.md`
  - latest file in `docs/development/history/`
  - `docs/design/game-direction.md` if the task touches direction, economy, weapons, or upgrades
  - any process doc that the task touches
