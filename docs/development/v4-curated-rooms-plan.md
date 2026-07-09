# V4 — Curated Room Pool + Card Streamline (Codex-ready umbrella)

> Phases 2–4 of the room/enemy redesign. Replaces procedurally-assembled archetypes with a **big pool of
> authored rooms** (identity + tiered composition + layout + light-variation + reward) and **streamlines the
> choice cards**. Branch `v4/class-system`, active checkout `D:\GameDev\Project_Twin_stick`.
>
> **Validation gate (per slice):**
> ```powershell
> $GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
> & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick' --quit                      # parse
> ```
> (Play a few room choices in-editor for the card + selection slices.)
>
> **Sub-plans (sequenced):** [[v4-enemy-tiers-plan]] (composition layer, **Codex-ready**) ·
> [[v4-flowfield-perf-plan]] (layout prereq, **Codex-ready**) · [[v4-arena-pathfinding-plan]] (obstacle design).
>
> **Decisions (LOCKED via MC 2026-07-07):**
> - **Curated + light variation.** Each room fixes identity + layout; rolls **one modifier from its own themed
>   pool + enemy-mix jitter** (layout stays fixed).
> - **Danger = derived from composition** (auto, honest), not authored.
> - **2 combat choices per normal step** (champion steps stay 1 forced) — unchanged from today.
> - **Fix flow-field perf FIRST** ([[v4-flowfield-perf-plan]]) — obstacle authoring (Phase 3) gates on it.
> - **Card = name+icon · danger pips · ≤2 tags · reward.** Keep the current card *style*, cut the content.
>
> **⚠ MODEL SIMPLIFIED (2026-07-07) — read this first.** The "big authored pool / `data/rooms.json` / curated +
> light variation" framing below (Slice B's per-room schema) is **superseded**. User rejected authoring many
> fixed rooms as "too much" → chose **6 curated base archetypes (= the 6 compositions) + 1–2 THEMED random
> modifiers per room.** The designed hazards/layouts are the **modifier deck**, not fixed pairings; each
> archetype rolls from a themed pool. This **extends the existing `data/room_archetypes.json`** (which already
> has `themed_modifier_pool` + `modifier_count_max`), NOT a new rooms file. **Current model spec:
> [[v4-room-pool.md]].** Read Slices B–C below as *archetype + themed-modifier* — the composition profiles, card
> streamline, danger-derivation, and 2-choice selection still hold.

---

## Sequence

| # | Phase | Status | Dep |
|---|---|---|---|
| 0 | Enemy tiers / specials | **Codex-ready** ([[v4-enemy-tiers-plan]]) | — |
| 1 | Flow-field perf fix | **Codex-ready** ([[v4-flowfield-perf-plan]]) | — |
| 4a | **Card streamline (interim, current data)** | **this doc, Slice A — ship now** | — |
| 2 | Curated-room model + selection | this doc, Slices B–D | 0 |
| 3 | Author the pool (obstacles+hazards+tiers) | content pass | 1, 2 |
| 4b | Card wired to authored `tags` | this doc, Slice A note | 2 |

---

## Slice A — Card streamline (`scripts/ui/RunFlow.gd _build_route_card`, L73-166) — INDEPENDENT, ship now

Works against **today's** node data; no model dependency. Keeps the panel/glow style, cuts to four things.

- **Row 1 (keep):** `trait_icon + trait_label` (L99-105) left · `danger_pips` (L106-112) right.
- **Row 2 (collapse):** the modifier `chip_flow` (L114-124) → show **at most 2** chips (first two modifiers via
  `_format_modifier_name`); if none, render nothing (drop the "Open" filler). *(When the model lands, feed this
  from the room's authored `tags` instead of `modifiers`.)*
- **Row 3 (keep):** the `rare_label` reward line (L155-162).
- **CUT the whole `detail_label` block (L126-148):** the `Room N`, `Enemies: chaser, charger…` dump,
  `Objective: Clear`, `short_desc`, `reward_hint`. Replace with **nothing**, except: if `side_objective` is a
  **real** objective (non-empty, not "clear"), show a single small chip/icon for it in Row 2.
- **Champion card:** Row 1 name = `Champion: <boss>`; Row 2 = one `Champion` chip; keep danger + reward. (No
  enemy list.)

**Acceptance:** each card shows only name+icon · danger · ≤2 tags · reward; no enemy dump / objective / prose;
champion card reads cleanly; style unchanged. Parse clean.

---

## Slice B — Curated Room schema + pool (`data/rooms.json`, new)

A big authored pool; each entry:

```json
{
  "id": "ranged_gauntlet_a",
  "name": "Ranged Gauntlet", "icon": "bolt",
  "tags": ["telegraphed", "cover"],          // ≤2 signature tags → Slice A Row 2 (authored)
  "depth_min": 6, "depth_max": 99,
  "composition": {
    "melee_density": "low",                   // MELEE swarm dial (density-scaled)
    "melee_bias": ["chaser", "charger"],      // harassment + overflow-melee pool (Phase 0 cap)
    "shooters": ["spitter", "elite_spitter"]  // capped by the Phase 0 shooter budget
  },
  "layout": {                                 // obstacles need Phase 1; hazards/shape don't
    "obstacles": [ { "x": 0, "y": 0, "w": 0, "h": 0 } ],
    "hazards": ["fire_floor"], "arena_shape": "normal"
  },
  "variation": { "modifier_pool": ["enemy_speed","accelerating_waves"], "modifier_count": 1 },
  "reward": { "rare_bonus": 0.0, "side_objective_pool": [] }
}
```

- **Tag vocab** (authored, ≤2/room; a small fixed set for card consistency): `swarm, ranged, telegraphed,
  elite, cover, hazard, shrinking, explosive, fast, shielded, boss`. (Tune the set during authoring.)
- **Migration:** the 6 `room_archetypes.json` entries seed the pool — `enemy_bias`/`density_profile` →
  `composition`, `themed_modifier_pool`/`modifier_count_max` → `variation`, `short_desc`/`reward_hint` dropped
  (card no longer shows prose), plus authored `tags` + `layout`. Keep `room_archetypes.json` until parity, then
  retire.

## Arena layouts — design vocabulary (Phase 3 authoring)

**Decisions (LOCKED via MC 2026-07-07):** **fixed arena rect** (3600×2100 const) + **internal obstacles only**
(no size/shape variance; the `shrinking_arena` modifier is the only wall mover) · **mostly open** — cover-heavy
rooms are a deliberate **minority**, the default is open (swarm-kiting identity intact) · **layout × composition
freely mixed** — no mandatory pairing (a room can be "ranged in the open" or "swarm in a chokepoint"); avoid
flat/unfair combos by author judgment + playtest, not a hard rule.

**✅ VERIFIED mechanic — cover blocks shots** (not just movement): projectiles are `collision_layer 2 /
mask 1` (`Projectile.tscn`), obstacles are `StaticBody2D` on **layer 1**, and `Projectile._on_body_entered`
(L272-277) despawns on **any** `StaticBody2D`, **team-agnostic**. So a block between you and a shooter stops
its shots — the ranged-cover puzzle works with **no LOS AI**. (Flow field separately routes the melee swarm
*around* the block.) This is why layout matters: **cover → ranged puzzle, chokepoints → melee/AOE, open →
kiting.**

**Design principle (locked via visual co-design 2026-07-07):** rooms must be **dynamic, readable, and
fun-not-punishing.** What works = *hazards you weave around and exploit* (they hurt the swarm too) + *cover that
moves on a rhythm.* What was **rejected**: static lone obstacles (Pillars/Lanes/Redoubt/Chokepoint — "just an
obstacle"); **encroaching** hazards that chase/squeeze you (firewalls / closing ring / sweep — punishing);
floor-effect gimmicks (speed pads / conveyor / vortex / bumpers — off-brand for a horde game);
trigger-traps / turrets (too clunky mid-swarm); objective rooms (redundant with existing side-quests).

**THE POOL — 14 authored layouts** (each `layout` is hand-authored; Batch B `obstacles` connectivity-validated
per [[v4-flowfield-perf-plan]]). Reference board rendered in-session.

**Batch A — ships now** (hazard / safe-zone systems; **no flow-field**):

| Room | What it is | Motion |
|---|---|---|
| **Open Field** | empty arena, balanced mix | — (baseline) |
| **Fire Grid** | checkerboard fire cells | pulses (safe/hazard swap ~2.5s) |
| **Frost Grid** | same grid, ice (slows) | pulses |
| **Mine Grid** | grid of mines | arm/disarm on pulse |
| **Islands** | safe pads in a hazard sea | pads reshuffle each pulse |
| **Pinwheel** | rotating hazard arms from center | orbit the gaps |
| **Tesla Arcs** | arcs snap between fixed nodes | timed hazard lines |
| **Drifting Clouds** | toxic gas blobs | drift slowly across |

*The pulsing grid is one reusable system (Fire/Frost/Mine = fills). All Batch-A hazards also damage the swarm
(half-tool).*

**Batch B — needs the flow-field fix** (physical dynamic cover):

| Room | What it is | Motion |
|---|---|---|
| **Central Bastion** | one central block (blocks shooter fire) | static (the one static keeper) |
| **Drifting Cover** | small cover blocks wander | slow drift · follow for shelter |
| **Pop-up Pillars** | cover raises/lowers | on a rhythm · time your peeks |
| **Sliding Gates** | wall with a passage that slides | opens & closes · time it |
| **Shifting Maze** | pillar field, lanes open/close | reconfigures on a beat |
| **Bulwark** | one big wall that patrols | mobile shield · tuck behind it |

Keep obstacle counts modest (perf + "mostly open"), clear of spawn lanes / center (spawn-safety per
[[v4-arena-pathfinding-plan]]). Combined with **freely-mixed compositions**, 14 layouts → far more actual rooms.

## Composition profiles (the enemy half — LOCKED 2026-07-07)

Built from the [[v4-enemy-tiers-plan]] roster (trash-melee swarm · capped ranged specials · elites). A
composition = who shows up + how much; **freely paired** with any layout. Six profiles:

| Profile | `melee_density` | `melee_bias` | `shooters` / `elites` | The point |
|---|---|---|---|---|
| **Horde** | high | chaser, chaser, splitter | — | mow the swarm; feeds Bloodthirst/Momentum |
| **Splitters** | high | splitter, splitter_mini, chaser | — | multiplying crowd — rewards AOE, punishes single-target |
| **Pressure** | medium | charger, charger, bomber | — | aggressive space-denial, big hits, forces movement |
| **Gauntlet** | low | chaser | shooters: spitter, spitter, elite_spitter | the dodge / close-the-gap encounter (capped by shooter budget) |
| **Elites** | low | chaser | elites: 1–2 of elite_charger / elite_support | priority-target / focus-fire test |
| **Mixed** | medium | chaser, charger, splitter, bomber | shooters: spitter | the balanced "standard" |

- These populate the room's `composition` field (Slice B). **`elites` is a new composition key** (1–2 named
  elites spawned once); `shooters` obey the Phase-0 budget; `melee_density` is the swarm dial.
- **Depth gating:** early rooms draw **Horde / Mixed**; **Pressure / Splitters / Gauntlet** unlock ~room 4+;
  **Elites** ~room 7+. `melee_density` + shooter budget scale up with depth on top.
- **Showcase pairings** (author these as flagship rooms; freely mix beyond them): Gauntlet × Central Bastion
  (LOS puzzle) · Splitters × Fire Grid (AOE chaos) · Pressure × Bulwark (charge behind the moving wall) ·
  Elites × Open (focus-fire duel). Avoid flat/unfair combos by author judgment + playtest.

## Slice C — Selection + variation (`scripts/game/RunState.gd`)

- **Load** `data/rooms.json` into a `_rooms_by_id` / depth-indexed list (mirror `_load_modifiers`, L1047).
- **`_build_choice_step`** (L599) / **`_draw_archetypes_for_depth`** (L880): replace archetype draw with
  **draw 2 curated rooms** filtered by `depth_min/max`, **no-repeat** vs the previous room id, and
  **distinct from each other** (reuse the intent of `_ensure_route_options_differ` on room `id`/`tags`).
  Champion steps unchanged (1 forced).
- **`_build_run_node`** (L614): build the node from the curated room — carry `name`/`icon`/`tags`/`layout`/
  `composition`; **roll `variation`**: pick `modifier_count` modifiers from `variation.modifier_pool` +
  **jitter the enemy sub-mix** (shuffle/subset `composition.melee_bias`, keep `shooters`). Feed `layout.obstacles`
  into the existing `node["obstacles"]` path (L640-642).
- **Retire** `_roll_archetype_modifiers` / `_build_distinct_modifier_load` / `_ensure_route_traits_differ`'s
  archetype-reroll (now: differentiate by room id, draw modifiers only from the chosen room's pool).

## Slice D — Derived danger + consumption

- **Danger (`RunState._refresh_route_metadata`)** — compute `danger_pips` from composition instead of a fixed
  value: base by `melee_density` (low/normal/high → 1/2/3) `+1` if `shooters` non-empty `+1` if any
  elite/champion tier present `+`(modifier count), clamped to the pip max. (Keep the existing pip renderer.)
- **WaveDirector** (`start_room` / `_get_density_*`) — read `composition.melee_density` (already consumes a
  `density_profile`) + `composition.shooters`/`melee_bias` for the pool; the Phase 0 shooter cap still governs
  ranged.
- **CoopManager.configure_room** — pass `layout.obstacles` to `FlowField.build` (already wired) + spawn
  `hazards` (reuse existing fire_floor/ice_zone/mine_field modifier hazards).

**Acceptance:** choice step shows 2 authored rooms (by name/tags), no two consecutive identical; each plays its
identity; variation makes two draws of the same room differ (modifier + enemy mix) but layout stays put; danger
pips track the actual composition; obstacle rooms route + hold ≥60 fps (post Phase 1).

---

## Out of scope (follow-ups)
- Hover/expand card detail (cut info lives behind hover if wanted).
- New ranged types (lobber/sniper), boss/swarm separation — deferred ([[v4-enemy-tiers-plan]]).
- Branching run *maps* (this curates individual rooms, not the graph).

## Notes
- Canonical tree `D:\GameDev\Project_Twin_stick` on `v4/class-system`; **parallel Codex may edit — re-read
  before each edit** ([[feedback-parallel-codex]]).
- Order: **Slice A (now) → B → C → D**; Phase 3 authoring after [[v4-flowfield-perf-plan]] lands. Validate +
  commit per slice; **don't push unless asked.** Card style anchor: [[feedback-card-ui-style]].
