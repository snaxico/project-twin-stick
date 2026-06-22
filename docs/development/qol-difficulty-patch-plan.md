# QoL & Difficulty Patch — plan

> Status: **design shaped with the user (2026-06-22), not implemented.** On `v3/structure-rework`. The
> next patch after Choices & Builds. Numbers below are placeholders tuned in playtest; shapes are decided.

Playtest findings → reward-UX, early-game difficulty, and encyclopedia polish. Build order: reward UX
first (fixes a felt frustration), then the early-game balance pass, then encyclopedia visuals.

**Co-op economy is SHARED (confirmed).** Both players share one `RunState.run_score` (the reroll budget),
and meta unlocks + banked score in `ProfileState` apply to both. So rerolls spend from a **single shared
pool** — if both players have simultaneous picks, they draw from and deplete the same budget (coordinate,
not separate wallets).

## 1. Reroll + Skip *(reward UX — fixes "all-weapon-cards, didn't want to swap")*

**Decided:** reroll costs the **current run's unbanked score** (so rerolling = less to bank for unlocks —
a power-now-vs-progress-later tradeoff, no new currency); **escalating cost** per reroll within a pick;
**skip = free decline**.

- `RunState`: `run_score` is the budget. Add `spend_run_score(amount) -> bool` (subtract if affordable,
  never below 0). **Shared in co-op** (one pool both players' rerolls draw from).
- **Reroll cost** = `base * 2^reroll_count_this_pick` (placeholder base `100` → 100/200/400/…). The
  reroll counter **resets at the start of each pick round**.
- **Rare dry-streak must stay neutral on reroll (functional trap).** Today `rare_dry_streak` is
  updated when offers are *generated* (`CoopManager._show_mutation_pick` ~1408–1411: reset if the offered
  set contains a rare, else +1). If reroll reused that, one pick round would increment/reset the streak
  multiple times before the player chooses. **Rule:** the streak updates **only on a round's initial
  offer**; the reroll path regenerates options **without touching `rare_dry_streak`** (and without
  re-applying `force_rare` pity — pity is decided once, at the initial offer).
- **UI signal contract (`MutationPickUI` today only emits `selections_confirmed`, and input is custom
  per-player navigation, not button focus).** Add:
  - signals `reroll_requested(player_index)`, `skip_requested(player_index)`;
  - method `replace_options_for_player(player_index, options)` so `CoopManager` can swap a player's cards
    in place after a reroll;
  - per-player **Reroll (cost)** + **Skip** affordances reachable via the existing per-player
    navigation/confirm inputs (not Control focus) — define the input action (e.g. a dedicated button or
    a navigation slot), and disable Reroll when `run_score < cost`.
- `CoopManager`: on `reroll_requested(p)` → if `RunState.spend_run_score(cost(p))` succeeds, re-roll p's
  options (dry-streak-neutral) → `replace_options_for_player(p, new_options)` + bump p's reroll counter;
  on `skip_requested(p)` → mark p resolved with **no upgrade**. Owns the per-pick reroll counters; show
  `run_score` + next cost in the UI.
- **Reroll cost** = `base * 2^reroll_count_this_pick` (placeholder base `100` → 100/200/400/…); counter
  **resets at the start of each pick round**.
- **Touch:** `RunState` (`spend_run_score`), `CoopManager` (`_show_mutation_pick` + reroll/skip handlers
  + dry-streak-neutral reroll), `MutationPickUI` (signals/method/inputs above).
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

**Decided:** too generous, especially with the harder early game. Two separate knobs in two files:
- **Drop chance** = `HEALTH_DROP_CHANCE := 0.10` in `CoopManager` → lower (~`0.06`).
- **Heal amount** = `heal_amount = 10` in **`HealthPickup.gd`** (not CoopManager) → lower if needed.

**Touch:** `CoopManager` (`HEALTH_DROP_CHANCE`) **and** `HealthPickup.gd` (`heal_amount`). **Open:** final
values.

## 4. Kill-streak target *(tuning)*

`_kill_streak_target = 18` is too low → raise (~28–32). **Touch:** `CoopManager` (~1129). **Open:** value.

## 5. Encyclopedia visuals = the in-game visuals

**Decided:** the encyclopedia shows the **same visual each thing has in-game** — not a separate icon
set — so what you see in the encyclopedia is exactly what you fight/use. (Replaced wholesale when the
rubberhose art lands.)

- **Single source of truth.** Where a visual is built inline today (e.g. the enemy `Polygon2D`
  shape/color set per type in `Enemy.gd._update_visual_state`), **extract it into a reusable builder**
  that both the live node and the encyclopedia preview call — so the preview can never drift from the
  real thing.
- **Enemies:** render the enemy's actual shape + feedback color (via the shared builder) as a small
  static preview of the real in-game body.
- **Weapons:** the **base** projectile visual from `weapons.json` (the weapon's default
  `projectile_shape`/color), **not** the current-run *compiled* visual — mutations (fire/frost/split,
  velocity streaks, etc.) modify the live projectile, and the encyclopedia should show the bounded,
  stable base form, not whatever a particular run happens to compile.
- **Abilities / mutations:** their in-game icons (`IconFactory`) — these are already the same ones shown
  on reward cards, so reuse is automatically "same as in-game".
- **Modifiers:** the modifier's actual visual (e.g. the Ice Zone ring, Fire Floor zone) rendered small.
- `EncyclopediaUI`: add the preview to each list row + detail panel; prefer a lightweight `_draw` that
  calls the shared shape builder over a per-entry `SubViewport` where the visual is a simple polygon.
- **Touch:** `EncyclopediaUI`, `Enemy.gd` (extract the per-type visual builder), `IconFactory`, the
  modifier draw code.
- **Open:** the render surface for the live previews (`_draw` + shared builder, preferred) vs a
  `SubViewport` per entry for anything that's an animated/composite node.

## Build order / slicing

1. **Reroll + Skip** (RunState `spend_run_score` → MutationPickUI buttons → CoopManager wiring).
2. **Early-game balance** (chaser/charger stats + early spawn curves + HP-drop reduction + kill-streak)
   — one tuning task, all in `Enemy.gd` + `CoopManager` constants.
3. **Encyclopedia visuals** (IconFactory enemy/modifier rendering → EncyclopediaUI previews).

Each: `git diff --check` + headless parse/boot; reroll/skip gets a manual pick-flow check.
