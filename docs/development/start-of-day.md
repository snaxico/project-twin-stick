# Start Of Day

Read this first to restore project context quickly, then read `current-state.md` and the latest file in
`history/`.

## Working Branch

- Active rework branch: `v3/structure-rework`.
- `v3/main` is the frozen stable Round 14 baseline until the rework is explicitly merged.
- Work in `D:\GameDev\Project_Twin_stick`; do not create new worktrees unless explicitly asked.
- Do not push unless asked.

## Source Of Truth

- `docs/development/current-state.md` is the compact runtime source of truth.
- `docs/development/structure-rework-plan.md` is the design/source plan for the trim.
- `docs/design/game-direction.md` is the broader direction source of truth.
- `docs/development/history/` records what changed, why, and what remains open.
- If this file and `current-state.md` disagree, treat `current-state.md` as correct and update this file.

## Project Snapshot

- Godot `4.6.2` same-screen local co-op twin-stick roguelite prototype.
- Target player count is `1-2`.
- The structure rework / "trim" is implemented through Phase 4 first-pass tuning.
- The initial structure-rework playtest was approved.
- Current next validation is a focused feel pass on Phase 4 tuning:
  - continuation pressure after room `10`
  - champion time-to-kill versus attack threat
  - Cannon burst-AOE versus Beam sustained single-target identity
  - modifier readability under deeper pressure

## Live Runtime Summary

- There is one continuable run, no Structured / Endless mode split.
- Normal steps show two next-room cards.
- Champion steps show one forced champion card.
- Room `10` is the milestone champion room.
- Clearing room `10` banks a win and offers `Continue` / `End Run`.
- Continuing keeps the same run scaling past room `10`.
- Branching map UI and graph generation are removed.
- Health resets every room because `GameWorld` / `CoopManager` is recreated.
- Momentum persists across the run through `RunState`; damaging hits still drop two tiers.

## Combat / Progression

- Enemy kills feed one shared XP bar.
- Level-ups bank room-end pick rounds.
- Champion rooms grant one additional forced-rare reward pick after XP picks resolve.
- Rare odds scale continuously by depth.
- Continuation pressure now keeps rising past the milestone through:
  - room duration
  - spawn interval
  - burst interval
  - burst size
  - deeper enemy-pool weighting
  - champion damage/cooldowns/speed
- Enemy HP is intentionally not the main deep-run pressure driver.

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
