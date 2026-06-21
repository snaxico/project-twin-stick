# Structure Rework Plan — "Trim"

> Status: **design locked, not implemented.** Supersedes the structural assumptions in
> `playtest-round-14-plan.md` Part B (especially **Patch 3 — boss set-pieces, which is cancelled**).
> Built on top of the Round 14 / Patch 1 build (manual aim, 7 weapons, Momentum/Flow).
>
> **Codex-ready. Phase 1 is sliced into three bounded hand-offs (1a RunState gen / 1b CoopManager depth
> fixes / 1c UI+scene+cleanup), with every spec concretized (node builder, champion-step rule, modifier
> ramp, rare-odds curve, fixed arena color, 2-card UI). Phases 2–3 detailed below; Phase 4 (enemy
> re-tune) is deliberately deferred to a tuning pass after the rest is built and playable.**
>
> **Branch / workflow:** this rework is implemented on the **`v3/structure-rework`** branch. **`v3/main`
> stays frozen as the current stable game** (Round 14 + fixes) — no rework code lands on it. The two
> rejoin only via an explicit merge once the rework is validated.

## Decision summary

The direction is a **trim**, not a genre pivot. We keep the game's roguelite identity but cut the two
heaviest, least-validated structural systems — the branching map and dedicated boss set-pieces — and
fold their value back into the core wave loop.

Locked decisions:

1. **One continuable run — no mode split.** Drop the separate Structured / Endless modes. There is a
   single run: a **curated arc** of clear-the-room rooms, then a **win milestone**, then optional
   **seamless continuation into endless scaling**.
2. **Remove the branching map.** Replace with a simple **pick-one-of-two** between rooms, using the
   **existing loot and modifier generation** (no new reward economy, no custom modifier rule).
3. **Remove dedicated boss rooms.** **Convert all four boss kits** (Warden / Hydra / Hive / Pulsar)
   into **elite champions** that spawn inside normal wave rooms (unified champion tier — see below).
4. Champions appear on a **depth-scaling cadence** (a stepped interval that **tightens with depth, with
   a floor**; exact numbers fixed in playtest), plus the guaranteed milestone champion. **There is no
   separate "elite" tier or concept** — every tougher-than-trash enemy is a *champion* (no elite room
   type, no elite scaling, no elite-specific state).
5. **Clear-the-room encounters** (current model — timed spawning, room clears when enemies dead), **not**
   survival-timer waves. No mandatory boss climax.

## One continuable run (post-rework)

There is **one run**, not two modes:

1. **Curated arc** — rooms `1 … RUN_LENGTH` (a tunable constant, target ~10). Steady-climb difficulty
   scaling continuously with depth, champion cadence, modifiers via the existing per-room rolling.
2. **Win milestone** — clearing the final arc room (room `RUN_LENGTH`, a champion room) shows a
   **win screen**: the run is banked as a **win** + score, and offers **"continue into Endless?"**.
3. **Continuation** — choosing continue keeps the *same run* going past `RUN_LENGTH` with
   **difficulty climbing seamlessly** (one smooth curve, champions on the tightening cadence, the
   2-option choice continues), score = rooms cleared, until death.

Menu shows just **Play** (the run) — no Structured/Endless selection. The old "Endless mode" is simply
the post-milestone continuation of this one run.

**Run stake = the run itself.** **Health resets each room** — no carried HP, heals, or lives, so the
thing at risk is the **whole run**: dying in any room ends it. The one thing that *does* now carry is
**Momentum** — see below — but that's a *power snowball*, not a saved resource you spend; you can't bank
it for safety, and a damaging hit dents it.

**Momentum now builds across the run** (decided 2026-06-21 — no longer per-room): it persists room to
room and only resets at run start, so the flow rewards a long continuation/score-chase. The −2-tier
hit penalty still applies. **Pick cadence stays XP-gated** (unchanged): you keep leveling as you clear,
so a long continuation keeps granting picks.

## Run curve

- **`RUN_LENGTH` rooms (tunable constant, target ~10).** Difficulty is a **steady climb** — each room a
  notch harder than the last, scaling **continuously with depth** (no discrete acts). The exact
  `RUN_LENGTH` is pinned in playtest tuning, not committed now.
- **Champion cadence:** a **depth-banded interval that tightens with depth, with a floor** — more
  frequent the deeper you go (e.g. illustratively ~every 5 early → ~every 4 → ~every 3, floored so it
  never becomes every-room; **exact band thresholds + floor fixed in playtest**). Room `RUN_LENGTH` is
  **always** a champion (the milestone). **Not** a fixed every-5.
- **Modifiers roll per room** via `_roll_modifiers_for_depth` (the existing roller, **de-acted to a
  continuous depth ramp** — see Phase 1). Each of the 2 next-room options carries its own rolled
  modifiers, so the modifier is part of the choice (pick the room flavor you'd rather fight).
- **Continuation past the milestone** reuses the same per-room escalation, climbing **seamlessly** from
  where the arc left off (one curve, no reset), unbounded until death. Score = rooms cleared.

## The core loop (per room)

1. **Wave room** — existing continuous time-based spawner, escalating with depth.
2. **Clear** — waves exhausted + enemies dead (existing).
3. **XP / level → banked picks** (existing reward sequencing).
4. **Choice** — pick the next room from **2 options** (replaces the map).

## Between-room choice (simple — "for now")

Replaces the branching map with a flat **2-option next-room choice**. **It deliberately keeps the
existing systems** — no new reward economy, no risk-kind taxonomy, no custom modifier rule:

- The **2 options are generated by the room builder** (enemy pool + per-room modifier roll via
  `_roll_modifiers_for_depth`), the same kind of options the map produced — just two of them, flat.
- The two options **differ** via the existing `_ensure_route_options_differ` check (distinct
  enemy/modifier signatures), so it's a real choice — typically "which modifier / room flavor do I
  want," same as picking between two map nodes today.
- **Loot is unchanged.** The post-clear pick uses the **existing reward sequencing** — no forced
  category, no rarity nudge. Rare odds use the **depth curve** (Phase 1 — see *Mechanical fixes*).
- **No card on champion steps.** When the next room is a champion step (on the depth-scaling cadence,
  or the milestone), it's forced — no 2-option choice that step. Non-champion steps are always two
  `combat` options.

**Reuse** the existing route-choice card UI (`_build_route_card` in `RunFlow.gd` already renders
room/enemy/modifier detail); strip the graph/positions and present the flat 2-option choice.

*("for now" = this is the simple version; a richer risk/reward economy is parked, not cancelled — see
Remaining open items.)*

## Champions (unified tier: former elites + former bosses)

Elites and bosses **collapse into one "champion" tier** above trash — a **two-tier ladder: trash →
champion**. The champion pool = **7 champions**: the 4 former bosses (Warden / Hydra / Hive / Pulsar) +
the 3 former Elite mini-bosses (Charger / Spitter / Support).

> **No "elite" *tier/concept* survives** — no elite room type, no elite generation
> (`_should_place_elite_node`), no elite scaling (`apply_elite_act_scale`/`_elite_cd_mult`), no
> elite-specific state (`_active_elite`, `_next_elite_add_spawn_at`, `_pending_elite_bonus_pick`). The
> former elites are handled **identically** to the former bosses: just champions.
>
> **BUT the enemy type IDs `elite_charger` / `elite_spitter` / `elite_support` are KEPT** as internal
> stable IDs (relabeled only in UI / Encyclopedia) — renaming them is a larger migration, out of scope.
> So cleanup gates grep the **elite tier symbols** listed above, **never `elite_` broadly**.

- Champions **spawn into a live wave room**, not a dedicated room.
- Each keeps **two signature telegraphed attacks** — the finalized per-champion kits are in the
  *Phase 2 — Champions* detail below (e.g. Warden = charge-combo + ground-pound).
- **Drop** multi-phase HP-threshold scripting and the entrance windup.
- **Look (readability):** champions are **visibly bigger**, carry a **colored aura**, and show a
  **named health bar** — repurpose the boss HP bar we're otherwise removing, **minus the phase pips**.
- **Delivery:** reuse the **boss-spawn path** (`_spawn_boss`), spawning the champion **partway** into
  the beat room (the old continuous elite add-wave system is removed).
- **Cadence:** a **depth-banded tightening interval with a floor** (numbers TBD in playtest); room
  `RUN_LENGTH` is **always** a champion. Champion steps have no 2-option choice. Champion rooms grant a
  **bonus pick** (the old elite-room bonus, now simply the champion-room bonus). The milestone champion
  is the run's "win" peak without being a dedicated boss.

## What gets removed

- Branching map: `MapUI`, map flow in `RunFlow`, route-graph generation, node layout/positions.
- **The Structured / Endless mode split** — one continuable run replaces both. The separate endless
  generation path collapses into the single run generator (endless = post-milestone continuation);
  the pre-run mode selection goes away (menu = just **Play**).
- Dedicated boss rooms: delayed-boss combat-room logic, boss **phase** HUD + phase pips, boss add-wave
  budget, boss-entrance windup set-piece, boss-every-5 endless cadence. (The boss **HP bar itself is
  repurposed** as the champion health bar, not deleted.)
- The separate **Elite tier** as a distinct concept — elites fold into the champion pool; their
  AIs/patterns survive as champions; **there are no elite rooms** (champions come only from the cadence
  + milestone).
- (Boss off-screen indicator already removed in Round 14.)

## What gets reused

- Continuous wave spawner, XP/pick economy, modifiers, side objectives, the **boss-spawn path**
  (`_spawn_boss` → champion delivery), reward-card UI, Momentum/Flow.
- All four boss AIs **+ the three elite AIs** → the 7 champion behaviors.
- The **boss HP bar** (minus phase pips) → champion health bar.
- **Keep** the boss telegraph **prewarm** (Round 12) — still needed so champion attack VFX don't
  first-use stutter inside a dense wave.

## Cleanup audit (delete / strip as part of this patch)

Cleanup is **part of each phase**, not an afterthought. Every phase's acceptance test ends with a
**no-dangling-references gate**: grep **runtime paths only** for the removed symbols → expect **zero**
hits, and headless parse must stay clean (catches orphaned `@onready` / deleted scene-node references).
**Scene (`.tscn`) nodes must be deleted in the same change as their script refs** or Godot errors.

> **Grep scope:** run the gate over runtime paths only — `rg <symbol> scripts scenes data project.godot`
> — **not** over `docs/` (the plan/history/archive intentionally still name the removed symbols, so a
> repo-wide grep would false-fail even when the code is clean).

### Phase 1 — map / endless / mode-select

- **RunState.gd functions:** `_generate_node_map`, `_build_branching_row`, `_roll_row_columns`,
  `_build_endless_node`, `_roll_endless_modifiers`, `is_endless_mode`, `_get_starting_reachable_node_ids`,
  and the reachability/visited accessors (`get_reachable_node_ids`, `get_visited_node_ids`). Keep
  **`_get_endless_enemy_pool`** (reused as the single depth-based pool). **Remove `_get_endless_wave_count`**
  too — `wave_count` is dead data (`CoopManager` never reads it; rooms are time-based), so the new node
  builder does **not** write it.
- **RunState.gd constants/vars:** `ACT_1_ROW_MIN/MAX`, `ACT_2_ROW_MIN/MAX`, `MAP_COLUMN_COUNT`,
  `START_ROW_COLUMNS`, `ENDLESS_BOSS_INTERVAL`, `ROOMS_PER_ACT` (acts dropped), `_should_place_elite_node`
  (no elite room type), `endless_room_index`, and **`visited_node_ids`** only.
  **KEEP `reachable_node_ids`** — it's reused as the current step's option IDs (already wired into
  `select_map_node` / `get_current_options`); name retained to avoid churn (it now means "current options").
- **RunState.gd acts → depth:** remove `current_act` / `get_current_act` / `set_current_act` and the
  `act` field on nodes; `_build_enemy_pool` folds into the single depth-based pool.
- **CoopManager.gd:** the `_room_type == "elite"` room-duration `+10` branch (no elite rooms); rework
  `_get_current_rare_chance()` → depth curve; replace `_apply_arena_color_for_act(act)` → no-arg
  `_apply_arena_color()` (**single fixed neon**); drop the `set_current_act` call in `_start_room`.
- **RunFlow.gd:** delete `_show_map` / `_rebuild_map_graph` + the route-graph helpers + the `@onready`
  map refs — a **new Next-Room panel** (`_show_next_room_choice()`) replaces them (see Phase 1 UI). May
  reuse `_build_route_card`'s card styling.
- **Bootstrap.gd:** `run_mode_row` / `run_mode_option` and all ~8 references (lines ~50–51, 137,
  198–200, 283, 305, 367, 463, 477).
- **Files:** delete `scripts/ui/MapNodeButton.gd` and its preload/usages (verify in `RunFlow` / others).
- **Scene nodes:** `Bootstrap.tscn` → delete `RunModeRow` / `RunModeOption`; `RunFlow.tscn` → delete the
  map-view nodes.

### Phase 2 — boss/elite machinery

- **Enemy.gd:** `_boss_phase_index`, `_update_boss_phase_transition`, `_spawn_phase_transition_telegraph`,
  the deflector **phase** index, `begin_boss_windup` + `_boss_windup_until` / `_boss_invulnerable_until`
  (entrance windup), `apply_elite_act_scale` + `_elite_cd_mult`, and the **dropped attack code + state
  vars** per the kit list (Warden leap/minions, Hydra radial-burst/aimed-snipes, Hive add-spawners/burrow,
  Pulsar aimed-fire/minions). Rename `apply_boss_scale` → `apply_champion_scale`.
- **CoopManager.gd:** `_update_boss_add_waves` (add-wave budget) + the boss-room constants
  (`BOSS_SPAWN_DELAY`, `BOSS_ADD_CAP`, `BOSS_ADD_WAVE_MIN/MAX`); the **elite tier** entirely —
  `_spawn_elite_miniboss`, `_update_elite_add_waves`, `_spawn_elite_entrance_vfx`, and the elite state
  vars (`_active_elite`, `_next_elite_add_spawn_at`, `_pending_elite_bonus_pick`); the boss-HP-bar
  **phase pips** drawing + `_boss_phase_label`; and the `notify_boss_phase_transition` hook.

### Phase 3 — resolution

- **RunFlow.gd:** collapse the old `"Run Victory"` / `"Endless Complete"` resolution branches into the
  single milestone screen + death game-over.

### Pre-existing dead code (fold in — not caused by the rework)

- **`wave_count`:** set-but-unused dead data — verify no runtime reader, then stop writing it
  (`_determine_wave_count` + the `node["wave_count"]` assignments). 
- **Stale `current-state.md` Known Risks note:** the "gold stub functions in `RunState.gd` remain" entry
  is **already false** (code is clean of gold) — delete the note.

## UI changes (per phase)

Beyond the headline UI (map removal, win screen), these secondary surfaces need updating:

### Phase 1

- **Remove** the map-view UI (`RunFlow.tscn` map nodes + `_show_map`) → present the choice via the **new
  Next-Room panel** (2 cards / 1 forced champion card).
- **Remove** the mode-select (`Bootstrap.tscn` `RunModeRow`/`RunModeOption`); menu = single **Play**.
- **In-run HUD:** keep `_room_label` showing **"Room N" always**; **delete `_score_label`** (the room
  number *is* the score). Replace the `is_endless_mode()` HUD/scaling gates (`CoopManager.gd` ~1422
  boss-room depth scale, ~1450 room-duration past room 20) with **unified depth-based** logic so
  scaling applies continuously, not only in "endless."
- **Encounter Builder room type** (`Bootstrap.gd` `debug_room_type_option`, ~line 211–213): **drop the
  "Elite" option** — the dropdown shows **Combat / Champion**. In Phase 1 "Champion" is a **label only**:
  its **metadata value stays `"boss"`** (the dependent visibility logic `debug_secondary_row` /
  `debug_room_objective_row` / `debug_layout_row` still keys on `"boss"`/`"combat"`). Phase 2 is what
  changes the metadata to `"champion"`.

### Phase 2

- **Boss HP bar** (`CoopManager.gd` `_boss_health_bar`): relabel `"Boss"` → the **champion's name**
  (named bar); **delete `_boss_phase_label`** + the phase-pip drawing.
- **Champion enemy visual:** bigger scale + colored aura.
- **EncyclopediaUI.gd:** replace the hardcoded `elite_*` + `boss_*` `ENEMY_ENTRIES` with the **7
  champions** and their **new 2-attack-kit descriptions** (no more "elite"/"boss" wording or stale kit
  text). Keep trash enemies; champions as their own group/section.
- **Encounter Builder champion picker** (`Bootstrap.gd` `debug_secondary_option`): the boss-type dropdown
  becomes a **champion dropdown** over the 7 champions.
- **In-room debug spawn roster** (`CoopManager.gd` ~lines 87–93): relabel the 7 entries as **champions**
  (drop the "Elite "/"Boss " prefixes); they're one group, not two (dev-tool).

### Phase 3

- **Resolution panel:** add the second button (`Continue` / `End run`) for the win milestone.
- **Game-over screen:** show **"Reached room N"** as the final score.

## Other surfaces audit (data / audio / dev tools / save)

Checked the remaining surfaces — most are no-ops, with one real dev-tool item:

- **`PerfRunner.gd` (Phase 2):** its `--profile=boss:<id>` and `room:elite|boss` scenarios use the old
  taxonomy + the single-room boss path. Update to **`champion:<id>`** + a **champion-in-dense-wave**
  scenario (the new perf worst case the Phase-2 acceptance already calls for). Also the stale
  `"run_mode": "structured"` string.
- **`is_endless_mode()` breadth (Phase 1):** referenced in **~10 spots** (`RunState` 86, 119–123, 144,
  158–166, 186, 332–333; `CoopManager` 1422, 1450) — collapse **all**, not just the generation branch.
- **`data/enemies.json` is empty** (`{"enemies": []}`) — enemy/champion stats are **hardcoded in
  `Enemy.gd`**; the per-champion base stats for `apply_champion_scale` live in code, **no JSON change**.
- **Audio (Phase 2/3):** boss SFX hooks (`_play_sfx("play_explosion", […, "boss"])`) just **reuse** for
  champions. Only a possible **win-milestone victory sting** is a new hook (Phase 3, optional).
- **No action — verified clean:** `ProfileState.gd` (`user://profile_state.save`) persists only
  `screen_effect_level` (a no-op stub) — nothing about mode/score/progress; `run_mode` is **not
  persisted** anywhere. No save/config changes from this rework.

## Implementation phasing (each = its own bounded, validated task)

1. **Strip the map → 2-option chooser + unify into one run.** Replace the branching map graph with a
   **lazily-generated 2-option choice per step**, using the **existing** room/modifier/loot generation;
   collapse the separate endless path into the same generator; remove the map graph UI and mode
   selection; champions (bosses, placeholder) on the depth-scaling cadence. See *Phase 1 (task detail)*
   below. (The old separate
   "choice card" phase is folded in here — the 2-option choice *is* the mechanic.)
2. **Champions.** Convert elite-add-wave delivery to spawn former-boss kits as champions; trim boss
   scripts to 1–2 attacks; remove boss-room / HP-HUD / add-budget machinery.
3. **Win milestone + continue.** Win screen at room `RUN_LENGTH` (banked win + score) with a
   **"continue into Endless?"** choice; continuation keeps the same run climbing seamlessly. Score = rooms cleared.
4. **Enemy / power re-tune (last).** Numeric pass lands here — *after* champions-in-waves exist, since
   that's what shifts the curve. **Philosophy: low-HP / high-threat** — enemies pressure via counts +
   telegraphed attacks, not HP-sponge bloat. Keep current enemy values until this phase; ship the
   stronger Patch-1 player against current enemies, then hand-tune.

Each phase: headless parse + boot validation; phases 2–4 also need **PerfRunner** — champions inside a
full wave are a **new** perf case (champion attack VFX + dense wave), distinct from the old isolated
boss-room profiles.

---

## Phase 1 — Strip the map → 2-option chooser (Codex-ready)

**Goal:** replace the branching map *graph* with a **lazily-generated 2-option choice per step**, using
the **existing** room / modifier / loot generation. Collapse the endless path into the same flow, remove
the map graph UI and mode selection, put champions (bosses as placeholders) on the **depth-scaling
cadence**. **Loot and modifier generation do not change** — only the map is replaced by a 2-card pick.
(Boss→champion = Phase 2; win screen = Phase 3.)

### What stays exactly as-is (do NOT rewrite)

- **Modifier helpers:** `_roll_modifier_selection`, `_ensure_route_options_differ`,
  `_build_route_option_signature`, `_build_distinct_modifier_load` — the option-differentiation check
  that makes the two choices distinct. (`_roll_modifiers_for_node` itself is **reworked** — it reads
  `act` today; see *Modifier ramp* below.)
- **Loot:** the post-clear reward / pick sequencing. (Rare *odds* are reworked — `_get_current_rare_chance`
  is act/endless-keyed; see *Rare odds*.)
- **Side objectives:** `_roll_side_objective(room_type)` — unchanged (returns "" for champion rooms,
  else 50% an objective).

### Constants (RunState.gd)

```
const RUN_LENGTH := 10     # tunable; the win milestone (Phase 3)
# No ROOMS_PER_ACT / acts — difficulty, pool, and rare odds key off `depth` (arena color is fixed; see
# "Mechanical fixes folded in").
# Champion cadence: a depth-banded interval that TIGHTENS with depth, with a floor.
# Numbers are placeholders pinned in playtest — e.g.:
const CHAMPION_INTERVAL_BANDS := [
    {"until_depth": 10, "interval": 5},   # rooms 1..10  → champion every 5
    {"until_depth": 20, "interval": 4},   # rooms 11..20 → every 4
    {"until_depth": -1, "interval": 3},   # deeper       → every 3 (the FLOOR)
]
```
Remove only the branching-graph sizing: `ACT_1_ROW_MIN/MAX`, `ACT_2_ROW_MIN/MAX`, `MAP_COLUMN_COUNT`,
`START_ROW_COLUMNS`, and `ENDLESS_BOSS_INTERVAL`.

### Champion-step test — exact rule

Don't use `% interval` against absolute depth (it skews when the band's interval changes). Instead track
the **last champion depth** and step forward by the band interval at that depth:

```
func _interval_for_depth(d): return the matching CHAMPION_INTERVAL_BANDS entry's interval
func _is_champion_step(room_number):
    if room_number == RUN_LENGTH: return true            # milestone always a champion
    if room_number <= 1: return false
    # next champion = last champion depth + interval(last champion depth); first champion at interval(1)
    var last := _last_champion_depth                      # 0 at run start
    return room_number == last + _interval_for_depth(maxi(last, 1))
```
The generator sets `_last_champion_depth = room_number` whenever it emits a champion node, so cadence
walks forward deterministically and band changes neither double- nor skip-place champions.

### `_build_choice_step(room_number) -> Array` — one step (= the choice)

```
# depth = room_number; no act (see Mechanical fixes folded in)
if _is_champion_step(room_number):
    return [ one champion node ]             # forced — no choice this step
else:
    return [ two option nodes ]              # the player picks 1 of 2
```

**Write a new `_build_run_node(room_number, room_type)`** that returns the node dict directly (do **not**
reuse `_build_map_node` — its signature is graph-oriented: `row_index, column, act, act_row_index,
act_total_rows`, and it calls `_build_room_title/_description`, `_determine_wave_count`, `_build_enemy_pool`,
**all act-keyed**). The new builder uses only depth:

```
func _build_run_node(room_number: int, room_type: String, slot: String) -> Dictionary:
    var is_champ := room_type != "combat"
    return {
        "id": "room_%d_%s" % [room_number, slot],     # UNIQUE per option — e.g. room_3_a / room_3_b / room_5_champion
        "room_type": room_type,                       # "combat" or "boss" — KEEP "boss" in Phase 1 (see rule below)
        "depth": room_number,
        "title": ("Champion — Room %d" if is_champ else "Room %d") % room_number,
        "description": "",                            # cosmetic; fill if desired
        "objective": "kill_all",
        "side_objective": "" if is_champ else _roll_side_objective("combat"),
        "enemy_pool": _get_endless_enemy_pool(room_number),            # reuse — depth-banded, exists
        # NOTE: no "wave_count" — it is dead data (CoopManager never reads it; rooms are time-based)
        "boss_type": _champion_boss_type(room_number) if is_champ else "",
        "modifiers": _roll_modifiers_for_depth(room_number, room_type),# reworked, see Modifier ramp
        "next_node_ids": [],
    }
```

- **Room-type metadata rule (important):** in **Phase 1 the champion step's `room_type` stays `"boss"`**
  so the **existing boss-room runtime runs unchanged** (CoopManager branches on `"boss"`). "Champion" is a
  **UI label only** in Phase 1. **Phase 2** is what switches the metadata to `"champion"` *and* the
  runtime that goes with it. Do **not** write `"champion"` metadata in Phase 1 — it would bypass the
  current boss-room code.
- **`_champion_boss_type(room_number)`:** `_structured_mid_boss_type` at the first arc champion,
  `_structured_final_boss_type` at `RUN_LENGTH`, else `_roll_boss_type()`. Keep `_assign_structured_boss_types()`.
- **`_build_choice_step(room_number)`:** champion step → `[_build_run_node(room_number, "boss", "champion")]`
  (one node). Normal step → `[_build_run_node(room_number, "combat", "a"), _build_run_node(room_number,
  "combat", "b")]` — **distinct slots so the two IDs differ** (`room_N_a` / `room_N_b`) — then run
  `_ensure_route_options_differ([a, b])` so they also differ in enemy/modifier signature. Both `combat`,
  **no "elite" room type**. (`_ensure_route_options_differ` already operates on a node array.)
- The old act-keyed `_build_map_node`, `_build_room_title`, `_build_room_description`,
  `_determine_wave_count`, `_build_enemy_pool` are **removed** (the debug single-room path uses the new
  builder too).

### Generation + advancement (RunState.gd)

- `start_new_run`: drop the `is_endless_mode()` branch. `node_map = [ _build_choice_step(1) ]`;
  `current_step_index = 0`; `reachable_node_ids` = step-1 node IDs; `current_node = {}`; set
  `_structured_total_combat_depth = RUN_LENGTH` (so `get_run_progress()` reaches 1.0 at the milestone).
- **Advancement happens in exactly ONE place — on room *clear*, not on select** (avoids a double-advance):
  - **`select_map_node(id)`** keeps its current behavior: **only** sets `current_node` / `current_node_id`
    from the chosen option (does **not** advance or append). A champion step has 1 option → UI confirms it.
  - **`resolve_current_combat_victory()`** (on clear) is the only advancer — generalize its existing
    `endless_next` branch to **all** rooms (no `is_endless_mode` / final-boss branches; Phase 1 never
    "completes"): `rooms_completed += 1`; `current_step_index += 1`; **append** `_build_choice_step(current_step_index + 1)`
    to `node_map`; `_rebuild_node_lookup()`; `reachable_node_ids` = the new step's node IDs; clear
    `current_node` / `current_node_id`; return a `"next"` outcome. The UI then shows `get_current_options()`.
  - Replace the structured `_advance_progress()` + endless-rebuild branches with this single linear advance.
- **Remove** the multi-row graph + branching + elite-room helpers: `_generate_node_map`,
  `_build_branching_row`, `_build_endless_node`, `_roll_row_columns`, **`_should_place_elite_node`**
  (no elite room type anymore).
- **Keep** the modifier helpers listed in *What stays* — they are reused, not removed.
- Navigation: `get_current_options()` returns the current step's nodes (2, or 1 champion) — i.e. the
  nodes for `reachable_node_ids`. `select_map_node(id)` only sets `current_node` (per the advance rule
  above — **it does not advance**). `reachable_node_ids` now holds just the current step's IDs; the
  visited list is unused. Keep `run_mode` (effectively one mode now).

### Difficulty / continuation

- Cadence (room duration / spawn interval / opening burst) keeps scaling off `get_run_progress()`,
  which **clamps at 1.0 by `RUN_LENGTH`** — so cadence *plateaus* at the milestone. Past the milestone
  the only thing still rising is the depth-banded **`enemy_pool`** (more enemy *types*) — **not**
  `wave_count` (dead) and **not** cadence (clamped).
- ⚠️ **Open tuning gap (Phase 4):** with cadence clamped and `wave_count` dead, deep continuation may
  **not actually escalate** beyond enemy variety. The Phase-4 re-tune must add a real continuation
  difficulty driver (e.g. uncap/scale the cadence past `RUN_LENGTH`, or a depth HP/count multiplier).
  Phase 1 just keeps generating; it does **not** solve deep-run escalation.

### Mechanical fixes folded in — concrete specs (decided 2026-06-21)

**Drop the `act` concept entirely** — remove `current_act` / `get_current_act` / `set_current_act` /
`ROOMS_PER_ACT` / the node `act` field. The three behaviors that read `act` are reworked as follows
(placeholder numbers are tunable in playtest, but the **shapes are decided**):

- **Modifier ramp → `_roll_modifiers_for_depth(room_number, room_type)`** (replaces `_roll_modifiers_for_node`).
  **Continuous** rise with depth (decided). Concrete placeholder:
  ```
  if room_type == "combat" and room_number <= 1: return []          # clean opener
  var t := clampf(float(room_number) / 20.0, 0.0, 1.0)              # 0 shallow → 1 by ~room 20
  var minor_max := 1 + int(round(t))                                # 1 → 2 minors
  var major_min := int(floor(t + 0.0001))                           # 0 → 1
  var major_max := 1 + int(round(t))                                # 1 → 2 majors
  if room_type != "combat": major_min += 1                          # champions heavier
  return _roll_modifier_selection(1, minor_max, major_min, major_max)
  ```
- **Rare odds → depth curve.** Replace `_get_current_rare_chance()` (`CoopManager` ~2294, act/endless-keyed)
  with: `return lerpf(0.20, 0.45, clampf(float(depth - 1) / 19.0, 0.0, 1.0))` — rises 0.20 (room 1) →
  0.45 (room 20+). `depth` from `RunState` current room depth. No `is_endless_mode()`, no act.
- **Enemy pool → one depth-based function:** use `_get_endless_enemy_pool(room_number)` everywhere (it
  already bands by depth); delete `_build_enemy_pool`.
- **Arena color → single fixed neon (decided).** Replace `_apply_arena_color_for_act(act)` with a no-arg
  `_apply_arena_color()` using **one fixed hue** (keep the current cyan, `hue 0.55`) for all rooms; drop
  the `set_current_act` / `get_current_act` calls in `_start_room`. No depth dependency.

### UI — replace the map panel with a new Next-Room panel (decided)

- **Build a new `NextRoom` panel** (scene nodes in `RunFlow.tscn`) + a new `_show_next_room_choice()`
  flow, and **delete the old map-view nodes** (`MapTitle`, `MapStatus`, `MapGraphArea`, `MapLineLayer`,
  `MapButtonLayer`, detail labels) and `_show_map` / `_rebuild_map_graph`. The new panel renders the
  step's option cards in a centered row.
  - Option cards: reuse `_build_route_card`'s *styling* if convenient (it returns a plain `Button`, not
    tied to map nodes), or write a small card builder — implementer's choice, but **don't keep the old
    map scene nodes**.
- **Normal step → 2 option cards.** **Champion step → ONE forced card** "Champion incoming — [name]"
  with a single confirm to enter (no skip — champions are **mandatory** at cadence steps). It is *not* a
  choice; it's a heads-up before a forced fight.
- **No `is_run_complete()` victory branch** — in Phase 1 the run never completes (`is_run_complete()`
  returns **false always**; the milestone/win is Phase 3).
- **Remove** the Structured/Endless mode selection in `Bootstrap.gd`; menu = a single **Play** entry.
- **Delete `MapNodeButton.gd`** if unused after the above (verify).

### Out of scope for Phase 1

- Champion conversion / unified tier (Phase 2); win screen + "continue?" (Phase 3); enemy re-tune
  (Phase 4).
- **Boss-room runtime is unchanged in Phase 1.** Champion (`"boss"`) steps keep the **current
  boss-room behavior exactly** (boss spawns after its delay, room clears on boss death — whatever the
  code does today); only the room *placement* moves to the cadence. The "champion drops into a normal
  wave that must also be cleared" behavior is **Phase 2**, not Phase 1.

### Acceptance test

- `git diff --check`; headless parse; headless boot (`--quit-after 1`).
- Temporary headless walk of `_build_choice_step(1..25)`: champion steps follow the **band intervals**
  (every 5 in 1–10, every 4 in 11–20, every 3 deeper) and `RUN_LENGTH` is always a champion; every other
  step returns **exactly 2** `combat` nodes with **distinct `id`s** (`room_N_a` / `room_N_b`) **and** a
  distinct route signature (no `elite` room type); enemy pool + rare odds rise with `depth`; arena color
  is the single fixed neon; steps keep generating past `RUN_LENGTH`. Also assert advancing one room
  bumps `current_step_index` by **exactly 1** (no double-advance on select + clear).
- Manual: launch a run → no map / mode-select screen; each non-champion step shows **2 cards**; picking
  one loads it; champions appear on the cadence (incl. room 10); play continues past room 10.
- **Cleanup gate:** grep for the Phase-1 removed symbols (`_generate_node_map`, `_build_endless_node`,
  `_build_map_node`, `current_act`, `_apply_arena_color_for_act`, `run_mode_option`, `MapNodeButton`, …)
  **over runtime paths only** (`scripts scenes data project.godot`, not `docs/`) → zero references;
  `Bootstrap.tscn` / `RunFlow.tscn` scene nodes deleted; headless parse clean.

### Sub-task slicing — hand to Codex ONE at a time

Phase 1 is too big for a single hand-off; build it as three bounded tasks, each validated before the next:

- **1a — RunState generation core.** New `_build_run_node` + `_build_choice_step` + `_is_champion_step`
  (+ `CHAMPION_INTERVAL_BANDS`, `RUN_LENGTH`); lazy advancement; `_roll_modifiers_for_depth`; drop the
  graph/endless/elite/act helpers and `current_act`; navigation → linear (`get_current_options`,
  `select_map_node` single-step; `is_run_complete()` → false). **Accept:** the headless `_build_choice_step(1..25)`
  walk above; grep removed RunState symbols → zero.
- **1b — CoopManager depth fixes.** `_get_current_rare_chance()` → depth curve; `_apply_arena_color_for_act`
  → no-arg fixed `_apply_arena_color()`; remove the `is_endless_mode()` / act / `_room_type=="elite"`
  gates (room duration, boss scale, set_current_act). **Accept:** headless boot; grep `is_endless_mode` /
  `current_act` / `_apply_arena_color_for_act(` → zero.
- **1c — UI + scene + cleanup.** **Build a new Next-Room panel** (`RunFlow.tscn` nodes +
  `_show_next_room_choice()`) rendering 2 option cards on a normal step / 1 forced "Champion incoming"
  card on a champion step; **delete the old map-view nodes** (`MapTitle`/`MapStatus`/`MapGraphArea`/
  `MapLineLayer`/`MapButtonLayer`/detail labels) + `_show_map` / `_rebuild_map_graph`; remove the
  `is_run_complete()` victory branch; `Bootstrap.gd` mode-select removal + delete `Bootstrap.tscn
  RunModeRow/RunModeOption`; delete `MapNodeButton.gd` if unused. **Accept:** manual launch (no
  map/mode-select; 2 cards on normal steps; forced single card on champion steps; bosses on cadence;
  past room 10); full cleanup gate; headless parse clean.

---

## Phase 2 — Champions (Codex-ready)

**Goal:** collapse the 4 bosses + 3 elites into one **champion** tier and convert beat rooms into
**"normal wave + a champion that drops in partway."** Strip the multi-phase boss machinery down to a
flat, readable 2-attack threat.

### Decisions (locked)

- **Two signature attacks each**, kept on cooldown (no third/phase attacks).
- **No multi-phase escalation** — flat behavior spawn→death. **Remove** `_boss_phase_index`,
  `_update_boss_phase_transition`, phase telegraphs, and the deflector-phase index.
- **Beat room = normal wave + champion** — the beat room runs the **existing room spawner** (adds
  throughout) and the champion **drops in partway** (see timing).
- **Entrance: partway through** — wave starts at room open; champion spawns after a delay with a brief
  telegraph (replaces the old 2.5s invuln windup).

### The unified champion tier

- Champion pool = **7**: `warden`, `hydra`, `hive`, `pulsar` (former bosses) + the 3 former elites
  (`elite_charger`, `elite_spitter`, `elite_support`).
- Add an `is_champion()` concept (generalize `is_boss()`); the former elites are promoted to champions,
  so **no enemy is an "elite" anymore** — `_spawn_elite_miniboss` / `_update_elite_add_waves` are
  **removed** (champion delivery uses the `_spawn_boss` path instead).
- **Each champion keeps 2 telegraphed attacks** (the bosses already have rich kits — pick their 2 best;
  the former elites keep their existing pattern + get **one** added telegraphed attack). The specific
  2-attack kit per champion is a **content decision — see Open below**.

### Champion runtime (Enemy.gd)

- Replace phase-driven attack selection with a **flat 2-attack loop**: alternate/randomly pick between
  the champion's two attacks on a cooldown; no HP-threshold branches.
- Keep telegraphs (`_spawn_boss_attack_telegraph`) and the R12 **prewarm**.
- **HP / power scaling with depth** — champions appear at every beat in an unbounded run, so their
  stats must scale with `room_number`. Generalize `apply_boss_scale` / `apply_elite_act_scale` into one
  depth-based `apply_champion_scale(room_number, player_count)`. **Exact curve = Phase 4 tuning**, but
  the hook lands here. (Approach is an Open below.)

### Champion delivery (CoopManager.gd)

- Champion step (on the cadence) → room runs the normal spawner **plus** a champion: at the spawn delay,
  call the (renamed) champion spawner, with a brief telegraph. Reuse `_spawn_boss` as the base.
- **Remove** boss-only room machinery: the boss add-wave **budget** (`_update_boss_add_waves`), the
  **phase HUD pips** (keep the HP bar, drop pips), the **entrance windup**, and the dedicated
  boss-room "spawn at 25s / clear on death" flow → the beat room is just a combat room with a champion.
- Room clears when the **champion is dead** (and the wave is handled by the normal clear rules).

### Champion look (readability)

- **Bigger** visual scale + a **colored aura** on the champion node.
- **Named health bar** = the existing boss HP bar **minus the phase pips**.

### Removed / renamed summary

- Gone: `is_boss()`-only phase system, `_boss_phase_index`, `_update_boss_phase_transition`, deflector
  phase index, boss add-wave budget, phase HUD pips, entrance windup, the separate elite tier
  (`_spawn_elite_miniboss`, `_update_elite_add_waves`, `apply_elite_act_scale`), `ENDLESS_BOSS_INTERVAL`
  remnants.
- Kept/renamed: boss AIs' attacks (trimmed to 2), boss HP bar (→ champion bar), telegraphs, prewarm,
  `apply_boss_scale`→`apply_champion_scale`.

### Resolved

- **Champion cadence** → **depth-banded interval that tightens with depth, with a floor** (stepped:
  ~every 5 early → ~every 4 → ~every 3 floor; exact numbers in playtest). Milestone room always a
  champion. **Not** a fixed every-5.
- **No "elite" tier** → former elites are handled **identically** to former bosses (champions); no elite
  room type / scaling / state survives.
- **Beat selection** → **random from the 7-pool, no repeat until the pool cycles.**
  - **Implementation:** the "bag" must live in **`RunState`** (not `CoopManager`, which is per-room, nor a
    local in the lazy generator) — e.g. `_champion_bag: Array` (shuffled pool) + draw on each champion,
    **refill+shuffle when empty**. `_champion_boss_type()` draws from it. In **Phase 1** the bag holds the
    4 boss types (`_assign_structured_boss_types` still seeds the arc mid/final); **Phase 2** expands it to
    all **7** champions.
- **Depth scaling** → **per-champion base stat block × a depth multiplier** (preserves identity;
  exact multiplier curve = last-phase tuning).

### Champion 2-attack kits (deciding one champion at a time)

Former bosses: trim their existing kit to the 2 keepers. Former elites: keep their existing pattern +
one added telegraphed attack. Filled in as we walk each champion:

- **Warden** — **Charge combo + Ground-pound** (drop leap + minion-spawn)
- **Hydra** — **Rotating arm-fire + Sweep** (drop radial burst + aimed snipes)
- **Hive** — **Deflectors + Poison cloud** (deflectors as a flat attack, no phase scripting; drop both add-spawners + burrow)
- **Pulsar** — **EMP + Shockwave/hazard** (teleport stays as movement; drop aimed fire + minions)
- **Elite Charger** — **charge-slam + Radial burst** (radial burst reused from Hydra's freed nova)
- **Elite Spitter** — **rapid aimed fire + Aimed snipes** (aimed snipes reused from Hydra's freed move)
- **Elite Support** — **Buff aura + Shockwave** (existing shockwave kept; **buff aura is new** — a
  speed/fire-rate aura that empowers nearby wave enemies, making Support a kill-priority force-multiplier)

**Net-new content in Phase 2:** only the **Elite Support buff aura** (every other champion attack reuses
an existing function — Warden charge/pound, Hydra arm-fire/sweep, Hive deflectors/poison, Pulsar
EMP/shockwave, plus Hydra's radial burst & aimed snipes reused on the two elite shooters). All
multi-phase / minion-spawn / extra-attack code is removed.

### Acceptance test

- `git diff --check`; headless parse; headless boot.
- **PerfRunner** champion-in-dense-wave profile (the new worst case).
- Manual: a beat room shows a normal wave; the champion drops in partway with a telegraph, has a named
  HP bar (no pips), uses 2 attacks with no phase jumps; room clears on champion death; former elites now
  appear as champions, never as the old elite mini-bosses.
- **Cleanup gate:** grep the Phase-2 removed symbols (`_update_boss_phase_transition`,
  `_spawn_elite_miniboss`, `_update_elite_add_waves`, `begin_boss_windup`, `apply_elite_act_scale`,
  dropped-attack vars) **over runtime paths only** (`scripts scenes data project.godot`, not `docs/`;
  and **not** `elite_` broadly — keep the `elite_*` type IDs) → zero references; headless parse clean.

---

## Phase 3 — Win milestone + continue (Codex-ready)

**Goal:** at room `RUN_LENGTH`, bank a **win** and offer **"continue into Endless?"**; continuation
keeps the same run climbing seamlessly until death. Reuses the existing `RunFlow` resolution panel.

### Decisions (locked)

- **Win banked at the milestone.** Clearing room `RUN_LENGTH` sets `run_outcome = "won"` **permanently**
  — dying later in the continuation never un-wins it. Continuing risks only **score**.
- **Minimal screen.** Title + score + the two buttons. No rich recap.
- **No persistence.** Session-only score; nothing written to `user://`. (Meta stays deferred.)

### Flow

1. **Reach room `RUN_LENGTH`** (a champion beat) and clear it → set `run_outcome = "won"`, show the
   **win resolution** with **two actions**: `Continue` (into Endless) and `End run`.
   - `Continue` → resume: advance to room `RUN_LENGTH + 1`, keep generating/climbing (Phase 1's lazy
     `_build_choice_step` already produces rooms past `RUN_LENGTH`). The 2-option choice + champion
     cadence continue unchanged.
   - `End run` → return to menu (the win is already recorded).
2. **Past the milestone:** room clears just advance — **no win screen again**.
3. **Death anytime:** game-over resolution showing **final score** ("Reached room N / Score: N rooms")
   → return to menu. If the milestone was passed, the run still counts as a **win** (banked); score is
   the rooms cleared.

### Touch points

- **RunState.gd:** `is_run_complete()` no longer ends the run — replace the "final boss = complete"
  logic. Instead, on clearing room `RUN_LENGTH`, set `run_outcome = "won"` and emit a milestone outcome
  (new `post_action = "win_milestone"`). After that, clears use the existing advance path
  (`resolve_current_combat_victory` → `endless_next`-style continuation). `rooms_completed` stays the
  score source for `get_run_summary_text()`.
- **RunFlow.gd:** the `resolution_panel` currently has **one** `resolution_button`. Add a **second
  button** (e.g. `resolution_button_secondary`) shown **only** for the `win_milestone` resolution:
  primary = `Continue`, secondary = `End run`. Wire `_post_resolution_action` to handle the two
  (`continue_run` advances like `endless_next`; `return_to_menu`). The old `"Run Victory"` /
  `"Endless Complete"` resolutions collapse into this single milestone screen + the death game-over.

### Momentum → build across the run (decided 2026-06-21)

> **Important — `CoopManager` is per-room.** `RunFlow._launch_room` does `_clear_active_game()` then
> `GAME_WORLD_SCENE.instantiate()` **every room** ([RunFlow.gd:310](scripts/ui/RunFlow.gd:310)), so
> momentum state in `CoopManager` is destroyed/recreated each room. **Just removing `_reset_momentum()`
> does nothing.** Momentum must persist in `RunState` (which lives for the whole run).

- **Store momentum in `RunState`:** add `momentum_tier` / `momentum_progress` (per player) to `RunState`;
  it's reset only in `start_new_run()`.
- **Restore on room start:** in `CoopManager` room setup (`configure_room` / `_start_room`), **seed the
  momentum tier/progress from `RunState`** instead of zeroing — and re-apply the tier bonuses to players.
- **Write back on change:** `_gain_shared_momentum` / `_drop_player_momentum` push the new tier/progress
  back to `RunState` so the next room's fresh `CoopManager` reads them.
- The **damaging-hit −2-tier drop is unchanged**. Net: momentum builds over a run (HP still resets per
  room because the GameWorld is fresh — that's intended).
- **Watch (playtest):** deep-run power could get oppressive — the −2 drop + tightening champion cadence
  are the intended counters; tune if needed.

### Out of scope

- Difficulty re-tuning of the continuation ramp (Phase 4 / tuning); any persistent best score or meta.

### Acceptance test

- `git diff --check`; headless parse; headless boot.
- Manual: clear to room `RUN_LENGTH` → win screen with **Continue** and **End run**; `Continue` resumes
  at room `RUN_LENGTH + 1` and keeps going; `End run` returns to menu; dying after the milestone shows a
  final-score game-over and the run is still recorded as a win.
- **Cleanup gate:** old `"Run Victory"` / `"Endless Complete"` branches gone; `wave_count` stripped;
  stale gold note removed from `current-state.md`; headless parse clean.

## Risks to watch in playtest

- **Win milestone feels arbitrary** — since the run just keeps going, the room-`RUN_LENGTH` "win" must
  feel like an earned peak (the champion + win screen), or it reads as a meaningless speed bump. Watch
  whether players feel a payoff there.
- **Continuation difficulty spike** — confirm the seamless climb past the milestone isn't a sudden
  unfair jump right after the finale champion; add a soft knee in tuning if it is.
- **Champion readability in a swarm** — champion + wave can be visually noisy; telegraphs must stay
  legible (prewarm + clear tells), especially under a stacked beat-room modifier.
- **2-option differentiation** — the two rooms must feel meaningfully different (the existing
  `_ensure_route_options_differ` carries this); confirm picks feel like real decisions, not flavor.
- **New perf case** — champion + full wave needs profiling; old boss-room profiles no longer represent
  the worst case.

## Resolved (2026-06-20)

- **One continuable run — no mode split** → curated arc → win milestone → seamless endless
  continuation. Menu = just **Play**; old "Endless" = the post-milestone continuation. (above)
- **Run length** → single **tunable constant `RUN_LENGTH`** (target ~10), pinned in playtest tuning;
  the milestone room is always a champion. (above)
- **Champion cadence** → **depth-banded tightening interval with a floor** (more frequent deeper;
  numbers in playtest), **not** a fixed every-5. (above)
- **Continuation difficulty** → **keeps climbing seamlessly** (one curve, no reset).
- **Pick cadence** → **stays XP-gated** (unchanged).
- **Run stake** → **health resets each room** (no carried HP/heals/lives); the run itself is the stake
  (death ends it). **Momentum is the exception** — it now **builds across the run** (decided 2026-06-21),
  a power snowball you can't bank for safety. (above)
- **Between-room mechanic** → **simple pick-one-of-two using the existing loot + modifier generation**
  ("for now"). No new reward economy, no risk-kind taxonomy, no custom modifier rule. (above)
- **Enemy re-tune** → tune **last**, low-HP / high-threat philosophy; keep current values until the last phase.
- **Onboarding** → **deferred** (see below). Not part of this rework.
- **Threat ladder** → **unified champion tier** (trash → champion, 7 champions = 4 bosses + 3 former
  elites); **no "elite" concept anywhere** — former elites handled identically to bosses. (above)
- **Champion look** → **bigger + aura + named health bar** (repurpose boss HP bar minus phase pips).
- **Champion rooms** → inherit the existing elite-room bonus pick (existing loot behavior).
- **R14 confidence** → playtest was thorough; build the rework straight on top, no extra R14 pass.
- **Difficulty curve** → **steady climb**, scaling **continuously with depth** (no discrete acts).
- **Modifiers** → per-room roll via `_roll_modifiers_for_depth` (existing roller **de-acted to a
  continuous depth ramp**, decided 2026-06-21); each of the 2 options carries its own modifiers, part of
  the choice.

## Remaining open items (decide during the relevant phase, not blocking)

- **Exact numbers, to set when writing each phase's Codex task:** final `RUN_LENGTH`; the
  continuation ramp rate (and any soft knee right after the milestone).
- **Tuning targets (last phase):** the actual enemy + champion stat values, hand-tuned in playtest.
- **Parked (not now):** the richer risk/reward card economy (risk kinds × reward categories, rarity
  nudges) and **risk/reward "parasite" items** (Part C) — revisit only if the simple 2-option choice
  feels too thin in playtest.

## Open from the critical system review

A critical pass over current gameplay systems vs the rework surfaced these.

**Design decisions — RESOLVED (2026-06-21):**

- ✅ **HP pickups → KEEP as-is** (10% drop / +5 HP). Intra-room safety net stays; no change.
- ✅ **Side objectives → KEEP as-is** (Hold Zone / Kill Streak / Collector + room buffs). No change.
- ✅ **Momentum → BUILD ACROSS THE RUN** (was per-room reset). **NOT just "remove the reset"** —
  `CoopManager` is re-instantiated per room ([RunFlow.gd:310](scripts/ui/RunFlow.gd:310)), so momentum
  must be **stored in `RunState`** (persists for the run), **restored into `CoopManager` on room start**,
  **written back on gain/loss**, and reset only in `start_new_run`. The damaging-hit **−2-tier drop still
  applies**. Slotted with **Phase 3**. See the Phase 3 *Momentum* sub-section for the concrete spec.
  (HP still resets per room "for free" because the GameWorld is fresh.)

**Mechanical fixes — RESOLVED (2026-06-21), folded into Phase 1:**

- 🔴 **Rare-odds → depth-based curve.** Replace `_get_current_rare_chance()` (`CoopManager` ~2294,
  hardcoded on the deleted `is_endless_mode()` + binary act) with odds that **rise continuously with
  `depth`** (exact curve in playtest tuning).
- ⚠️ **Enemy pool → one depth-based curve.** Drop `_build_enemy_pool` (act); use a single depth-scaled
  pool for all rooms.
- 🟢 **"Acts" → dropped.** Remove the `current_act` concept entirely (`current_act` / `get_current_act`
  / `set_current_act`); **rare odds and enemy pool scale continuously with `depth`**. **Arena color is a
  single fixed neon** (decided 2026-06-21) — `_apply_arena_color_for_act` becomes a no-arg
  `_apply_arena_color()`, *not* depth-driven.

**Notes for the re-tune / future (not blocking):**

- **Cannon ↔ Beam niche overlap (Phase-4 re-tune).** Cannon was the "boss-killer / big single hit" for
  isolated boss rooms; but **Beam** ramps its DPS on a single tough target (a champion) and barely ramps
  sweeping a wave → Beam is now the de-facto single-target champion-killer, **overlapping Cannon**.
  Rethink Cannon's identity (pivot toward burst-AoE/wave, or accept overlap) in the re-tune. No weapon is
  broken; the other five are wave-friendly.
- **Mutation × momentum × depth balance (Phase-4 tuning).** Additive-uncapped stat mutations + momentum
  now **persisting across the run** + depth scaling = very strong deep play (intended "OP", but watch it
  doesn't trivialize). No mutation needs *structural* rework — none reference bosses/elites/modes/acts.
- **`CoopManager` is a ~3000-line god-object** (room runtime + spawning + projectiles + abilities +
  champions + HUD + modifiers + objectives + momentum). The rework removes some of it but doesn't
  decompose it. Candidate for a later structural pass — **not** part of this rework.

**Parked (revisit after playtest):**

- **Upgrade-pool depth for deep runs.** Only **9 commons (cap lvl 3) + rares** → a long continuable run
  maxes the build and picks go hollow. **Decided to leave for now** (2026-06-21) — only bites in very
  deep runs; revisit once we see how far real runs go. Candidate fixes when we do: uncap commons with a
  soft curve, add depth-gated upgrade tiers, or convert dead picks to a flat bonus.
- **Debug weapon dropdown lists `shockwave`** (a `primary_skill` in `weapons.json`) — pre-existing minor
  nit, optional cleanup; not rework-caused.

**Audit confirmed covered (no new gaps):** in-room debugger (only the spawn-catalog relabel, in the UI
audit), Encounter Builder (room-type / champion dropdown, in the UI audit), PerfRunner (champion taxonomy
+ champion-in-dense-wave, in Phase 2), and the HUD (all items in the UI audit; momentum-persist is
display-fine).

## Carried forward from Part B/C/D (unaffected by this rework)

- **Patch 2 — Abilities:** Stance/Root, combat drone, Barrier dome (still queued).
- **Patch 4 — Biomes:** destructible cover, pits/gaps, pinball bumpers (still queued).
- **Parked (Part C):** arcade score-multiplier + "heat" dynamic difficulty, parasite items,
  rubberhose art restyle.
- **Deferred:** onboarding / tutorial (rising complexity — manual aim, momentum, 7 weapons — and couch
  co-op still need lightweight teaching eventually; explicitly not now).
- **Cancelled:** Patch 3 boss set-pieces (replaced by champions above).
