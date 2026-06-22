# QoL & Difficulty Patch — plan

> Status: **design shaped with the user (2026-06-22), not implemented.** On `v3/structure-rework`. The
> next patch after Choices & Builds. Numbers below are placeholders tuned in playtest; shapes are decided.

Playtest findings → reward-UX, early-game difficulty, and encyclopedia polish. Build order: reward UX
first (fixes a felt frustration), then the early-game balance pass, then encyclopedia visuals.

## 1. Reroll + Skip *(reward UX — fixes "all-weapon-cards, didn't want to swap")*

**Decided:** reroll costs the **current run's unbanked score** (so rerolling = less to bank for unlocks —
a power-now-vs-progress-later tradeoff, no new currency); **escalating cost** per reroll within a pick;
**skip = free decline**.

- `RunState`: `run_score` is the budget. Add `spend_run_score(amount) -> bool` (subtract if affordable,
  never below 0). **Shared in co-op** (one pool both players' rerolls draw from).
- **Reroll cost** = `base * 2^reroll_count_this_pick` (placeholder base `100` → 100/200/400/…). The
  reroll counter **resets at the start of each pick round**.
- `MutationPickUI`: per player, add a **Reroll (cost)** button (disabled when `run_score < cost`) and a
  **Skip** button. Reroll → `spend_run_score` + re-`roll_mutation_options` for that player + bump its
  reroll counter; show current `run_score` + the next cost. Skip → resolve the pick with **no upgrade
  taken**.
- `CoopManager._show_mutation_pick`: own the per-pick reroll counters and wire the buttons.
- **Touch:** `RunState` (`spend_run_score`), `CoopManager` (`_show_mutation_pick`), `MutationPickUI`.
- **Open:** base cost + escalation factor; confirm Skip still consumes the banked pick round (yes).

## 2. Buff chasers + early-game difficulty *(balance — "mainly early game")*

**Decided:** the early game is the problem; fix by **buffing chasers** (keep the pool ramp, **no** early
variety) and concentrating pressure on the opening rooms.

- `Enemy.gd` **chaser** is HP 20 / speed 150 / contact 8 — buff toward a real threat (e.g. HP ~30,
  speed ~175, contact ~12; tune in play). The other early enemies (charger) can take a smaller bump.
- **Early spawn pressure** (`CoopManager`): `_get_room_duration` / `_get_spawn_interval` /
  `_get_burst_size` scale off `get_run_progress` (low early), so rooms 1–5 are too soft. Raise the
  **shallow-depth** end (bigger opening burst, tighter early spawn interval) so the opening feels active.
- **Keep** `_get_endless_enemy_pool` (chaser-only early stays — chasers just hit harder and come in
  greater numbers).
- **Touch:** `Enemy.gd` (chaser/charger stats), `CoopManager` (early spawn curves).
- **Open:** exact chaser stats + early-curve values (playtest).

## 3. HP drops — reduce *(balance)*

**Decided:** too generous, especially with the harder early game. Lower `HEALTH_DROP_CHANCE`
(`0.10` → ~`0.06`) and/or the heal amount (5 HP). **Touch:** `CoopManager` (`HEALTH_DROP_CHANCE` +
heal amount). **Open:** final values.

## 4. Kill-streak target *(tuning)*

`_kill_streak_target = 18` is too low → raise (~28–32). **Touch:** `CoopManager` (~1129). **Open:** value.

## 5. Encyclopedia procedural visuals

**Decided:** procedural previews now (replaced when the rubberhose art lands).

- **Weapons / abilities / mutations:** reuse `IconFactory.get_weapon_icon` / `get_passive_icon` /
  `get_mutation_icon` in the list rows + detail panel.
- **Enemies (new):** a procedural shape preview from the enemy's representative polygon + feedback color.
  Add `IconFactory.get_enemy_icon(enemy_id)` (draw the enemy shape to a texture), sourced from the
  per-type shapes/colors in `Enemy.gd`.
- **Modifiers (new):** a representative glyph + color (reuse the Phase-0 `trait_icon`/modifier mapping
  where it applies, else a colored dot/letter).
- `EncyclopediaUI`: render an icon/preview per list entry + in the detail panel; entries carry an
  `icon` / `icon_kind` so the UI knows what to draw per category.
- **Touch:** `EncyclopediaUI`, `IconFactory` (+ enemy/modifier rendering), enemy-shape source in `Enemy.gd`.
- **Open:** enemy-shape source (extract `Enemy.gd` polygons vs simple representative shapes); modifier
  glyph set.

## Build order / slicing

1. **Reroll + Skip** (RunState `spend_run_score` → MutationPickUI buttons → CoopManager wiring).
2. **Early-game balance** (chaser/charger stats + early spawn curves + HP-drop reduction + kill-streak)
   — one tuning task, all in `Enemy.gd` + `CoopManager` constants.
3. **Encyclopedia visuals** (IconFactory enemy/modifier rendering → EncyclopediaUI previews).

Each: `git diff --check` + headless parse/boot; reroll/skip gets a manual pick-flow check.
