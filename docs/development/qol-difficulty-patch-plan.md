# QoL & Difficulty Patch — plan

> Status: **implemented (2026-06-22).** On `v3/structure-rework`. The
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
- **Reroll cost** = `base * 2^reroll_count_this_pick` (implemented base `100` → 100/200/400/…). The
  reroll counter **resets at the start of each pick round**.
- **Rare dry-streak must stay neutral on reroll (functional trap).** Today `rare_dry_streak` is
  updated when offers are *generated* (`CoopManager._show_mutation_pick` ~1408–1411: reset if the offered
  set contains a rare, else +1). If reroll reused that, one pick round would increment/reset the streak
  multiple times before the player chooses. **Rule:** the streak updates **only on a round's initial
  offer**; the reroll path regenerates options **without touching `rare_dry_streak`**.
- **Force-rare split (champion reward vs pity).** `_show_mutation_pick(force_rare, …)` mixes two things:
  the **round-level** `force_rare` (true for Champion Reward, false for level-ups) and the **per-player
  dry-streak pity** (`force_rare or inventory.rare_dry_streak >= 3`). A reroll must **keep the round-level
  `force_rare`** (so a Champion Reward reroll still guarantees a rare) but **NOT** re-apply the
  dry-streak pity. Concretely: store the round's `force_rare`; reroll calls
  `roll_mutation_options(p, 3, rare_chance, round_force_rare, signature_share)` — passing the round flag
  only, *not* OR-ed with `rare_dry_streak`. Pity is applied (and the streak updated) only at the initial offer.
- **Input = two extra navigable slots (decided).** `MutationPickUI` navigates a horizontal row of
  `options.size()` cards via per-player left/right (`_get_player_menu_direction`) + confirm
  (`_is_player_confirm_pressed`); there is no Control focus. So **append two pseudo-slots — `[Reroll
  (cost)]` and `[Skip]` — to that row** (navigable count = cards + 2). Reusing the existing nav/confirm
  means **no new input bindings**. In `_confirm_player_selection`, branch on the selected slot:
  - a **card** → pick it (current behavior);
  - the **Reroll** slot → emit `reroll_requested(player_index)` (do **not** confirm the player); render it
    **disabled/greyed when `run_score < cost`** so confirming it is a no-op;
  - the **Skip** slot → emit `skip_requested(player_index)` (resolve the player with no upgrade).
  Cancel (`_is_player_cancel_pressed`) still unconfirms a confirmed card.
- **UI additions:** signals `reroll_requested(player_index)` / `skip_requested(player_index)`; method
  `replace_options_for_player(player_index, options)` for `CoopManager` to swap a player's cards in place
  after a reroll; show the player's `run_score` + the next reroll cost on the Reroll slot.
- `CoopManager`: on `reroll_requested(p)` → if `RunState.spend_run_score(cost(p))` succeeds, re-roll p's
  options (dry-streak-neutral, round-level `force_rare` only) → `replace_options_for_player(p, new_options)`
  + bump p's reroll counter; on `skip_requested(p)` → mark p resolved with **no upgrade** (still consumes
  the pick round). Owns the per-pick reroll counters.
- **Touch:** `RunState` (`spend_run_score`), `CoopManager` (`_show_mutation_pick` + reroll/skip handlers
  + dry-streak-neutral / force-rare-split reroll), `MutationPickUI` (slots/signals/method above).
- **Implemented values:** base cost `100`, escalation factor `2x`; Skip consumes the banked pick round.

## 2. Buff chasers + early-game difficulty *(balance — "mainly early game")*

**Decided:** the early game is the problem; fix by **buffing chasers** (keep the pool ramp, **no** early
variety) and concentrating pressure on the opening rooms.

- `Enemy.gd` **chaser** was buffed from HP 20 / speed 150 / contact 8 to HP 30 / speed 175 / contact 12.
  Charger received a smaller bump to HP 52 / speed 208 / contact 20.
- **Early spawn pressure** (`CoopManager`): `_get_room_duration` / `_get_spawn_interval` /
  `_get_burst_size` scale off `get_run_progress` (low early), so rooms 1–5 are too soft. Raise the
  **shallow-depth** end (bigger opening burst, tighter early spawn interval) so the opening feels active.
- **Keep** `_get_endless_enemy_pool` (chaser-only early stays — chasers just hit harder and come in
  greater numbers).
- **Touch:** `Enemy.gd` (chaser/charger stats), `CoopManager` (early spawn curves).
- **Implemented first-pass values:** tighter early spawn interval and larger opening/periodic bursts; tune
  after playtest.

## 3. HP drops — reduce *(balance)*

**Decided:** too generous, especially with the harder early game. Two separate knobs in two files:
- **Drop chance** = `HEALTH_DROP_CHANCE := 0.06` in `CoopManager`.
- **Heal amount** = `heal_amount = 8` in **`HealthPickup.gd`** (not CoopManager).

**Touch:** `CoopManager` (`HEALTH_DROP_CHANCE`) **and** `HealthPickup.gd` (`heal_amount`).

## 4. Kill-streak target *(tuning)*

`_kill_streak_target = 30`. **Touch:** `CoopManager` (~1129).

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
- **Weapons:** the **base** projectile visual, **not** the current-run *compiled* visual (mutations like
  fire/frost/split + velocity streaks modify the live projectile — show the bounded, stable base form).
  Note `weapons.json` has **no** `projectile_shape`/color field — only `projectile_kind`. Derive the base
  shape/trail from `projectile_kind` via the **existing `projectile_kind → projectile_shape/trail_style`
  mapping** in `MutationSystem` (`_map_weapon_stats_to_projectile_keys`, ~line 422), i.e. compile a base
  visual with **no mutations applied**. (Don't read non-existent JSON fields.)
- **Abilities / mutations:** their in-game icons (`IconFactory`) — these are already the same ones shown
  on reward cards, so reuse is automatically "same as in-game".
- **Modifiers:** the modifier's actual visual (e.g. the Ice Zone ring, Fire Floor zone) rendered small.
- `EncyclopediaUI`: add the preview to each list row + detail panel; prefer a lightweight `_draw` that
  calls the shared shape builder over a per-entry `SubViewport` where the visual is a simple polygon.
- **Touch:** `EncyclopediaUI`, `Enemy.gd` (extract the per-type visual builder), `MutationSystem`
  (base projectile-kind visual mapping), `IconFactory`, the modifier draw code.
- **Open:** the render surface for the live previews (`_draw` + shared builder, preferred) vs a
  `SubViewport` per entry for anything that's an animated/composite node.

## Build order / slicing

1. **Reroll + Skip** (RunState `spend_run_score` → MutationPickUI buttons → CoopManager wiring).
2. **Early-game balance** (chaser/charger stats + early spawn curves + HP-drop reduction + kill-streak)
   — one tuning task in `Enemy.gd` + `CoopManager` constants **+ `HealthPickup.gd`** (`heal_amount`).
3. **Encyclopedia visuals** (shared enemy/modifier visual builders → EncyclopediaUI previews; weapons
   via the base `projectile_kind` mapping; reuse `IconFactory` for abilities/mutations).

Each: `git diff --check` + headless parse/boot; reroll/skip gets a manual pick-flow check.
