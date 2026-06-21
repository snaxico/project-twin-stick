# Next-Room Choice Plan — selection mechanic + card UI

> Status: **design locked, not implemented.** Sits on top of the implemented structure rework
> (`v3/structure-rework`, commit `1a3d840`). A "patch" on the next-room choice that today is a plain
> text-dump button with no risk/reward.
>
> **This is now Phase 0 of the merged `replayability-patch-plan.md` ("Choices & Builds").** The
> **rare-odds nudge below is reconciled with the build-depth Signature tier** in that doc's *Rarity &
> reward economy* section — treat that as the source of truth for the rare roll; the formulas here are
> the Phase-0 mechanic/UI detail.

## Goal

Turn the current placeholder next-room choice (two rooms that differ by a random roll, same reward,
text-button UI) into a **readable, meaningful pick** with a light push-your-luck layer and a proper
card UI — without adding new room/enemy content.

## Locked design (decided 2026-06-21)

- **Selection = flavor, near-equal reward.** The two options are *different kinds of fight*, not
  "safe vs greedy". The choice is "what suits my build/skill right now."
- **Modifier-led (no new archetypes).** Each option's identity comes from its already-rolled
  modifiers + enemy pool — no new content. The card surfaces a derived **dominant-trait label**.
- **Reward = rarity, with a modest nudge.** Both options pay through the existing depth-scaled rare
  odds. The **spicier (higher-danger) option gets a small rare-odds bump** so there's a light gamble,
  but no big swing. Same picks otherwise (no extra picks, no guaranteed rares).
- **Fully shown.** Both options display their trait, danger rating, modifiers, enemy mix, and objective
  up front — the choice is informed.

## How the new mechanics work

All four live in `RunState._build_choice_step` / `_build_run_node` (generation) + a per-room field that
`CoopManager` reads. Numbers below are **placeholders, tuned in playtest** — the shapes are decided.

### 1. Danger score → danger pips (per option)

A small integer score from what the room already rolled:

```
danger_score = minor_modifier_count * 1
             + major_modifier_count * 2
             + clampi(enemy_pool.size() - 2, 0, 2)   # +0..2 for broader/deeper pools
```

Bucketed to **1–3 pips** for display (thresholds tunable):

```
danger_pips = 1 if danger_score <= 1
              2 if danger_score <= 3
              3 otherwise
```

Stored on the node as `danger_score` (int) and `danger_pips` (int).

### 2. Dominant-trait label + icon (per option)

Pick the most salient modifier (majors first, then minors) and map it to a short label + an icon key
the UI resolves. First match wins; no modifiers → "Open room".

| Modifier (priority order) | Label | Icon key |
|---|---|---|
| `fire_floor` | Hazard zone | flame |
| `ice_zone` | Frost field | snow |
| `mine_field` (scanline) | Scanlines | scan |
| `shrinking_arena` | Closing walls | shrink |
| `swarm` | Swarm | swarm |
| `shielded` | Fortified | shield |
| `enemy_speed` | Frenzied | bolt |
| `accelerating_waves` | Escalating | rising |
| `explosive_death` | Volatile | bomb |
| (none) | Open room | dot |

Stored as `trait_label` (string) + `trait_icon` (string key). Pure presentation — does not change
runtime behavior.

### 3. Rare-odds nudge (the light risk/reward)

After both options are built, compare their `danger_score`:

- The **higher-danger** option gets `rare_bonus = RARE_NUDGE` (placeholder `0.06`).
- The other (and ties) get `rare_bonus = 0.0`.

Stored on the node as `rare_bonus` (float). It is the **only** reward difference between the two
options — everything else (pick count, categories) is identical.

**CoopManager consumes it:** `_start_room` reads `_room_rare_bonus = _room_config.get("rare_bonus", 0.0)`,
and `_get_current_rare_chance()` returns `depth_curve + _room_rare_bonus` (clamped ≤ ~0.6). Today
`_get_current_rare_chance()` is `lerpf(0.20, 0.45, (depth-1)/19)` — just add the room bonus.

### 4. "Make them differ" guarantee

Today `_ensure_route_options_differ` only forces distinct enemy/modifier *signatures*. Add a trait
check so the two cards never read the same:

- After rolling both options, if `trait_label(a) == trait_label(b)`, **re-roll option b's modifiers**
  (up to ~4 tries) until the traits differ; then still run the existing
  `_ensure_route_options_differ` for the signature check as a backstop.
- Champion steps are unchanged (one forced card, no choice).

## Card UI (RunFlow) — replaces the text button

Matches the approved layout mockup. Each option is a **styled card** (keep it a `Button` for
focus/controller nav, with child `Control`s laid inside, or a `PanelContainer` + transparent `Button`
overlay). In-game keeps the **neon-on-black** skin; the mockup only fixed the information layout.

Per card, top→bottom:
1. **Header row:** trait icon + `trait_label` (left) · **danger pips** (right, filled = danger level).
2. **Modifier chips:** one chip per modifier — **real name + icon** (replace the current `AW`/`SW`
   abbreviations via a `modifier → {name, icon}` lookup, sourced from `modifiers.json` display names).
3. **Info rows:** Enemies (`enemy_pool` joined) · Objective (`side_objective` or "Clear").
4. **Reward row:** "Rare odds NN%" — show the room's effective rare chance
   (`depth_curve + rare_bonus`), with a small **`+N%`** marker on the nudged option.
5. **Enter** affordance (the whole card is the button).

The spicier option gets a subtle accent (brighter border) so the light risk/reward reads at a glance.

### Touch points

- **`RunState.gd`:** `_build_choice_step` (compute danger/trait/nudge after building both options + the
  trait-differ guarantee); `_build_run_node` (write `danger_score`, `danger_pips`, `trait_label`,
  `trait_icon`, `rare_bonus`); a `_danger_score_for(node)` + `_trait_for(node)` helper; constant
  `RARE_NUDGE`.
- **`CoopManager.gd`:** read `_room_rare_bonus` in `_start_room`; add it in `_get_current_rare_chance()`.
- **`RunFlow.gd`:** rewrite `_build_route_card` into the styled card; add a `modifier → {name, icon}`
  + `trait_icon → glyph` lookup; drop `_modifier_abbreviation` / `_build_modifier_badge_text`.

## Out of scope / not changing

- No new modifiers, enemies, room types, or champions.
- Champion steps stay a single forced card.
- Pick count, categories, momentum, XP — unchanged. Rarity nudge is the *only* new reward lever.

## Acceptance

- `git diff --check`; headless parse + boot.
- Headless: build many `_build_choice_step(d)` and assert the two options always have **different
  `trait_label`**, both carry `danger_pips ∈ 1..3`, exactly one has `rare_bonus > 0` (unless danger
  tie), and `rare_bonus` is the higher-danger one.
- Manual: the two cards read as clearly different fights; modifiers show real names; the nudged card
  shows `+N%` and a higher rare odds; picking either still grants the normal post-clear pick.

## Open / tuning (playtest)

- `RARE_NUDGE` size, danger-pip thresholds, and the danger-score weights.
- Whether the nudge should scale with the *danger gap* between options rather than a flat bump.
- Trait labels/icons wording.
- Whether "near-equal" is actually balanced or one flavor dominates (watch in play).
