# Playtest Round 10 — Plan & Implementation (for Codex)

Single self-contained build doc for Round 10. Built collaboratively, point by point. Work on
`v3/main` in `D:\GameDev\Project_Twin_stick` (main checkout, no new worktrees). Do not commit unless
asked. **Round 9 (weapon system) is committed/pushed and is the stable baseline.**

> STATUS: **DESIGN COMPLETE.** All clusters decided and recorded below. Ready to convert to a
> Codex build spec / implement.
> - ✅ **Map** → next-choices cards (real risk/reward), re-eval after playtest.
> - ✅ **Bugs & perf** → room-end freeze fix; **Perf Runner tool built + validated + committed**
>   (`bfbca64`); entity-count perf fix **deferred** to a dedicated perf round.
> - ✅ **UI & features** → card trim, ability-text detail panel, scanline density, starting-weapon
>   loadout, Debug Menu (+ Encounter Builder rework), 2P camera tuning.
> - ✅ **Combat feel** → Hive offense buff, boss entrance windup + ≥0.8s tells, rarity rework
>   (15/25/35 + pity-after-4), minefield stacking.
> - ✅ **Audio** → procedural SFX retune, generated adaptive music, Master/Music/SFX volume sliders.
> - **Repo state:** the Perf Runner is **committed** (`bfbca64`, so `v3/main` is ahead of origin
>   by 1). The docs cleanup + this plan are committed as **docs-only** (separate from gameplay).
>   **No Round-10 gameplay code is built yet** — round 9 is the gameplay baseline. Start
>   implementation from a clean tree so doc moves don't mix into the patch.

## Findings (from the round-9 playtest)

**Bug / regression**
- Room-end doesn't freeze the world — scanlines keep running and can kill the player after clear;
  should behave like the pause screen.
- Pulsar lag — profile with the round-6 dev perf harness; find + fix the cause.

**Combat feel & balance**
- Hive offense too weak — needs more ways to pressure the player.
- Bosses need a few-second **windup/telegraph** before attacks (reaction window + readability).
- Rarity drops need rework.
- Minefield should **stack**: place new mines while old ones are still alive (each with a lifetime).

**Audio**
- SFX still generic/annoying → rework + **background music / track**.
- Settings: **sound + volume** controls.

**UI / readability**
- Ability text fully visible (not hover-only).
- Upgrade cards have too much info → simplify (the round-9 4-group cards).
- Too many scanlines at once → hard to navigate.
- Map: misaligned/overlap/no scroll → **decided: rework to next-choices cards** (see Decisions).

**Features / systems**
- Starting weapon choice in the pre-game loadout (full weapon pool).
- Separate debug menu.
- Encounter Builder rework for the new round-9 systems.

**Camera**
- 2P camera — zoom works but players get pinned to edges, empty middle. Needs rework.

---

## Decisions (locked)

### Map → "Next-choices cards" (replaces the branching graph)
- **Why:** the current map (`RunFlow.gd` `_get_node_graph_position`) uses hand-rolled absolute
  positioning (`column_rank/(count-1)` + a ±18px odd-row jitter) inside a fixed `Control` with a
  fake computed scroll offset (`_graph_scroll_offset`, not a real `ScrollContainer`). Dense rows +
  92px buttons overlap; no real scroll. Brittle, broken repeatedly.
- **New design:** each route step shows the **2–3 branch options as cards** + a compact
  **"Floor X / Y"** progress bar. No full-map overview, no scroll, can't overlap, controller-friendly.
- **Choice must be a real risk/reward:** each step offers a genuine tradeoff — e.g. a safer Combat
  room vs a higher-pressure **Elite** (which grants the bonus guaranteed-rare pick), and/or rooms
  with differing modifier stakes. Not "Combat A vs Combat B."
- **Re-evaluate after playtest:** if the choice still doesn't feel meaningful, dropping it for
  endless-style auto-progression (random rooms + scheduled boss/elite) is a trivial follow-up.
- **Implementation sketch:** `RunState` still generates the branch options per step (keep the
  node/`next_node_ids` data); `RunFlow._show_map` / `_rebuild_map_graph` are replaced by a simple
  card list of the reachable next nodes. Remove the graph positioning math, line layer, and
  scroll-offset code. Keep node identity (room type, modifiers, boss/elite tag) shown on each card.
- **Generator differentiation rules (so the choice is actually a tradeoff, not cosmetic).** Cards
  alone don't guarantee meaningful choice — `RunState`'s branch generation must make each step's
  reachable options **differ on at least one axis**. When a step has ≥2 reachable options, enforce:
  - they are **not all the same room type** — bias toward offering **one safer Combat** and **one
    higher-pressure option** (Elite when an elite is legal for that depth; Elite grants the bonus
    guaranteed-rare pick), OR
  - if both are Combat, they must differ in **modifier load** (count and/or a minor-vs-major
    severity), so one is the "clean/safe" route and one is the "loaded/risky" route.
  - On the final pre-boss step, options may differ by **which boss/path** they lead to.
  Each card surfaces these differentiators (room type, elite/boss tag, modifier chips + severity) so
  the tradeoff is legible. (Update `_build_branching_row` / `_assign_modifiers_to_map` accordingly.)

### Bug → Freeze the world on room clear
- **Cause:** `_handle_room_clear()` ([CoopManager.gd:1099](scripts/game/CoopManager.gd)) only locks
  player *input*; hazards (Scanline `_mine_field_modifier`, Fire Floor, etc.) keep ticking on their
  own `_process` and can damage/kill the player during the clear + mutation-pick window.
- **Fix:** call `_set_runtime_pause_state(true)` at the top of `_handle_room_clear()` (freezes
  projectiles/enemies/hazards/mines/decoys/turrets/orbits + all modifiers). `_start_room()` already
  resumes via `_set_game_paused(false)`. **Do NOT** use `_set_game_paused(true)` — it also pops the
  pause panel.
- **Acceptance:** clearing a room with active scanlines/fire-floor deals no player damage during
  the pick/map; hazards visibly stop.

### Perf → Automated Perf Runner (new reusable dev tool) + findings
- **Built `scripts/dev/PerfRunner.gd`** (autoload, inert unless `--profile=` is passed). Run unattended:
  `Godot…console.exe --path <project> -- --profile=<scenario> [--players=N] [--build=heavy]`
  - Scenarios: `boss:<id>` / `room:<type>` (REAL CoopManager rooms via the debug single-room path);
    `entity_ramp` (the isolated 50→200 harness). Samples FPS / min-FPS / process / physics / draw /
    nodes, prints CSV, quits. `RunState.debug_profiling` makes players immortal for the full window.
  - **Reusable**: future "profile X" = just pass a new `--profile`. Later: wire into the debug menu.
- **Findings (this machine, vsync off):**
  - `boss:pulsar` 1P base → **683 / 664 FPS**, 92 draw, 534 nodes.
  - `boss:pulsar` 2P heavy (Scattergun L5 + Rapid Fire×3 + Fire Bullets) → **647 / 629 FPS**,
    physics 2→6 ms, 114 draw, 671 nodes.
  - `entity_ramp` → 50:1027 · 100:419 · 150:167 · **200:62.6 FPS** (662 draw, 3192 nodes).
- **Conclusion: Pulsar is NOT the bottleneck** (600+ FPS even worst-case). The real cost is **raw
  entity count** — ~200 enemies+projectiles → ~62 FPS. Reported Pulsar lag = a busy moment nearing
  that ceiling. Round 9 added a small regression vs round-6 (62.6 vs 73.8 @ 200/200).
- **Fix direction (general, not Pulsar-specific):** round-6-deferred **MultiMesh rendering** for
  projectiles/enemies (biggest win — ~3 draw calls/entity), tighter caps (projectile / add-wave /
  fire-pool), draw-call reduction. Boss-windup also spreads burst spawns.
- **DECISION: perf fix DEFERRED** to a dedicated perf round. **Round 10 ships only the room-end
  freeze fix + the Perf Runner tool** (which makes that future perf round easy to drive). The
  MultiMesh/caps work is parked, not dropped.

### UI & features

**Upgrade card info trim** (`MutationPickUI._build_card`, ~189). Current card stacks 7 elements;
declutter (all real info stays — descriptions remain visible):
- Merge the `RARE/COMMON` + `GROUP` labels into **one line** `"COMMON · ATTRIBUTE"`, tinted by the
  group color (border still = rarity, icon bg still = group). Removes a row.
- Move the per-card footer prompt to a **single shared hint** under the card row; keep only a small
  "Selected" check on the locked card.
- Shorten the level line to **`Lv X→Y`** (common, non-weapon only).

**Ability text always-visible** (`Bootstrap.gd` ~898). Today the ability card shows
`"<name> - <desc truncated to 40>"` with the full text only in the hover **tooltip** — unreadable
at a glance / on controller. Decision: keep ability **cards compact (name)** and add a **fixed
detail panel** that shows the focused/selected ability's **full description, always-on** (updates
on focus/selection, not hover) — same pattern as the existing map detail panel. Drop the 40-char
truncation + hover reliance. One detail panel reflects the currently-focused ability card.

**Scanline density** (`scripts/modifiers/MineFieldModifier.gd`). Today a new sweep spawns every
~5–6s and each takes longer to cross, so 2+ perpendicular sweeps overlap with mismatched gaps.
Fix (cap-2 + space-out + wider gaps):
- **Max 2 concurrent sweeps** — in `_spawn_sweep`/`_physics_process`, don't spawn if `_sweeps.size() >= 2`.
- **Longer interval:** `_spawn_at` 5.0 → **8.0** (+ rand 0–1.5).
- **Wider gaps:** `GAP_WIDTH_MIN/MAX` 150/180 → **200/240**.

**Starting-weapon choice in loadout** (new feature; `Bootstrap.gd` loadout + `RunState`). Today
every player starts hard-coded `weapon_id = "rifle"` Lv1. Add a **weapon-select row per player**
(5 compact cards from `RunState.get_weapon_catalog()` — Rifle/Rocket/Scattergun/Cannon/Railgun),
full description in the **shared detail panel** on focus, starts at **Lv1**. Thread the choice
through `debug_start_options` (`player_weapons: [id,…]`) → `_build_default_player_inventories`
sets `inventory.weapon_id`. Applies to both Play and Encounter Builder.

**Debug Menu (consolidates the "debug menu" + "Encounter Builder rework" findings).** A dedicated
dev hub, opened from a **main-menu Debug button shown only when a dev flag is on** (hidden in
normal builds). Contents:
- **Room/boss launcher** = the **reworked Encounter Builder**: configure room type, boss, modifiers,
  enemy mix, player count, AND the new round-9 systems (starting weapon + level, abilities, optional
  starting upgrades). Reuses the existing debug single-room path.
- **Perf scenario launcher** — runs Perf Runner scenarios (`boss:<id>`, `room:<type>`,
  `entity_ramp`, + players/build) from the menu and surfaces the CSV. **Requires an API:** refactor
  `PerfRunner` so the `_ready()` `--profile=` path and a new **`PerfRunner.run_from_menu(profile,
  players, build)`** share a common `_run(profile, players, build)` core; the menu calls
  `run_from_menu(...)`. The command-line `--profile=` path stays for unattended automation.
- **Player cheats (launch-time only)** — applied when launching a room from the Debug Menu (access
  is main-menu-only): god mode (reuse `debug_profiling`), set starting XP/level, grant a weapon +
  level, grant specific starting upgrades. These configure the run at launch, not mid-room.
- **Live spawn controls — DEFERRED (cut from Round 10).** Spawning into a *running* room needs
  in-room access, which conflicts with the main-menu-only decision. Revisit with a dedicated in-room
  dev panel in a later round.

**2P camera tuning** (`scripts/game/ZoomCamera.gd`). Empty-middle/edge-pinning comes from staying
zoomed out even when players are close (`zoom_max 0.7`) + large padding. Tune (no new system):
- `zoom_max` 0.7 → **1.0** (zoom in tighter when players are near → view fills with action).
- `padding` (260,220) → **(160,140)** (less dead space around players).
- `zoom_min` keep **0.35** so far-apart players still both fit.
- **Future:** if tuning isn't enough, dynamic split-screen (separate viewports when players
  separate, merge when close) is the bigger fix — flagged, deferred.

### Combat feel

**Hive offense buff** (`Enemy.gd` `_update_hive_behavior`). Problem: all pressure is at Hive's own
position (it flees >240px), so it never threatens a kiting player. Add direct/ranged pressure (all
four), respecting the existing non-boss enemy cap (25) so the swarm stays in budget:
- **Player-targeted poison clouds:** redirect the periodic cloud to drop at/near a random player's
  position (telegraphed ~0.6s), not Hive's. `spawn_enemy_hazard_zone(player_pos, 140, 4.0, dps, green)`.
- **Spore volley (new ranged attack):** every ~3.5s fire 3–5 slow homing spores at the nearest
  player via `spawn_enemy_homing_orbs(pos, 3 + int(phase*2), ~110 spd, 4.0, dmg, green)`.
- **Heavier swarm:** minion cadence `2.0→0.8` → **`1.6→0.6`**; emergence burst `5+phase*3` →
  **`6+phase*4`**; elite minions sooner (charger @phase ≥ 0.25, bomber @ ≥ 0.5).
- **Poison trail while roaming:** every ~0.4s of movement drop a small short-lived poison zone at
  Hive (radius 50, 2.0s, dps 4) so chasing/cornering it is risky.
- **Number bump (modest):** poison-cloud dps 5 → **8**; spore projectile damage ~**10**. HP stays 900.
- **Perf:** more spawns — profile `--profile=boss:hive --players=2 --build=heavy` after build to
  confirm it stays in budget (poison trail/clouds are short-lived + small; swarm bounded by the 25 cap).

**Boss windup / telegraphs** (`Enemy.gd` boss setup + `_update_*_behavior`, `CoopManager` boss spawn).
- **Entrance windup ~2.5s:** on boss spawn set `_boss_windup_until = now + 2.5`; while active the
  boss is **invulnerable** (`_boss_invulnerable_until`) and its behavior update **idles** (no
  attacks/charges/spawns) with a clear spawn-in telegraph/VFX. Also delay boss add-waves until after
  windup. Then engage normally. Gives the player time to read the boss.
- **Min heavy-attack telegraph (`MIN_HEAVY_TELEGRAPH = 0.8s`).** Root cause:
  `_spawn_boss_attack_telegraph(radius)` only draws a ring VFX — most heavy attacks call it and
  then fire the **same frame**, so there's no reaction window. Fix: pair each heavy attack with a
  **delayed effect** — spawn the tell now, fire the damage/spawn `0.8s` later. Reuse/extend the
  existing delayed-shockwave pattern (`schedule_enemy_shockwave(...delay...)`) into a generic
  "schedule delayed boss effect" helper. Per-attack:

  | Boss | Heavy attack | Current tell | Round-10 change |
  |---|---|---|---|
  | Warden | Charge | charge windup (`handle_enemy_charge_windup`) | ensure windup ≥ 0.8s |
  | Warden | Ground-pound shockwave | scheduled ~0.45s delay | raise delay to **0.8s** |
  | Warden | Leap slam | leap travel + 140px ring; hazard at target | ensure landing delay ≥ 0.8s |
  | Hydra | 12-shot radial burst | 240px ring, fires same frame | **delay burst 0.8s** after ring |
  | Hydra | Arm sweep | rotates over ~1.5s | add **0.8s windup** before the sweep starts |
  | Hive | Poison cloud (player-targeted) | 160px ring, spawns same frame | **delay spawn 0.8s** |
  | Hive | Spore volley (new, Round-10) | none | add **0.8s tell** before firing |
  | Hive | Emergence burst | burrow 1s invuln then burst | OK (already ≥ 0.8) |
  | Pulsar | EMP | 520px ring, fires same frame | **delay EMP 0.8s** |
  | Pulsar | Shockwave + hazard | 210px ring, fires same frame | **delay 0.8s** |
  | Pulsar | Teleport | has telegraph window (`_pulsar_telegraph_until`) | OK (already delayed) |

  Light/frequent attacks keep no long tell: Hydra aimed snipes & homing orbs, Pulsar aimed fire,
  and all minion spawns. Re-confirm exact current delay values at edit time.

**Rarity-drop rework** (`CoopManager._get_current_rare_chance` + `_show_mutation_pick`).
- **Raise rare chance:** Act 1 `0.10 → 0.15`, Act 2 `0.20 → 0.25`, Endless `0.30 → 0.35`.
- **Pity / bad-luck protection — PER-PLAYER** (because `_show_mutation_pick` rolls options per
  player). Add a **per-player** `rare_dry_streak` (store in `PlayerInventory`, persists across rooms).
  Each reward round, **for each player**: if *that player's* offered options contained no rare,
  increment their counter; if they did, reset it to 0. When a player's counter reaches **4**, pass
  `force_rare = true` for **that player's** next roll, then reset. (An elite forced-rare round resets
  it for everyone who got the forced rare.)

**Minefield stacking** (`data/abilities.json` minefield + `Player.gd` activation + `_spawn_ability_mines`).
Mines already persist independently; the blocker is that Minefield is *sustained* — its 14s
"duration" both sets mine lifetime AND blocks recast, with cooldown (10s) < duration → no overlap.
- **Decouple:** make Minefield an **instant, cooldown-gated cast** (move it out of the sustained
  active-block group in `Player._try_activate_ability`; no active-duration block).
- **Exact data/keys** (`data/abilities.json` minefield): `type: "instant"`, `cooldown: 7`,
  `duration: 0` (no active-block), **`stats.mine_lifetime: 14`** (replaces the old `duration`-as-
  lifetime). `_spawn_ability_mines` reads `stats.mine_lifetime` for each spawned mine's lifetime.
  In `Player._try_activate_ability`, move `minefield` **out** of the sustained active-block group
  (`overcharge/turret/minefield/orbit`) and handle it as instant (cooldown-gated, no `_set_slot_active`).
- **Duration mutation interaction (special-case = YES):** `Duration` **extends `mine_lifetime`**
  (× the duration multiplier) even though minefield is now instant — a deliberate synergy exception
  to the round-6 "Duration affects sustained abilities only" rule. Implement + comment it in
  `MutationSystem` (apply the duration multiplier to `mine_lifetime` specifically).
- **No active-mine cap** — self-limited by CD 7s + lifetime 14s (~2–3 casts overlap; ~8–21 mines
  with the Extra Mines signature). Revisit only if the deferred perf work flags it.

### Audio

All **asset-free / procedural** (per user — accept it won't match real samples/tracks).
- **SFX retune** (`scripts/juice/SfxEngine.gd`): kill the harshness — softer envelopes (slower
  attack, gentler decay), a gentle **low-pass** to take the edge off, wider per-trigger variation
  (pitch/timbre) to cut repetition fatigue, and make the **constant auto-fire SFX subtler/quieter**
  (most-heard, most-grating). Final feel tuned by ear in playtest.
- **Generated adaptive music** (new; Music bus via `AudioStreamGenerator`): one procedural base
  loop with **intensity layers** — calm in menu/map, add a driving layer in combat, add an intense
  layer for boss/elite; layers fade in/out on context change. "Pushes the player" without assets.
- **Volume settings:** add **Master / Music / SFX** audio buses + three sliders in the main-menu
  Settings; persist like VSync (e.g. `user://audio_settings.cfg`). SFX already routes to an SFX bus
  (round-8); add Master + Music buses.

---

## Build Order & Acceptance (for Codex)

Conventions: after every slice run the headless parse check
(`Godot…console.exe --headless --path D:\GameDev\Project_Twin_stick --quit`); line numbers in the
sections above are **indicative — re-confirm against live code**. Each slice's detail is in the
matching section above. Build in this order (low-risk/foundational first; Debug Menu last):

1. **Room-end freeze** — `_set_runtime_pause_state(true)` in `_handle_room_clear`.
   *Accept:* clearing a room with active scanlines/fire-floor deals no damage during pick/map.
2. **Audio buses + volume settings** — Master/Music/SFX buses + 3 persisted sliders in Settings.
   *Accept:* sliders move bus volumes; persists across launches.
3. **SFX retune** — softer envelopes, low-pass, more variation, subtler auto-fire (on SFX bus).
   *Accept:* parse + by-ear in playtest (less harsh, less repetitive).
4. **Generated adaptive music** — procedural base loop + combat/boss intensity layers on Music bus.
   *Accept:* music plays, layers shift on context, respects Music slider.
5. **Rarity rework** — rare chance 15/25/35 + `RunState.rare_dry_streak` pity-after-4.
   *Accept:* more rares; a forced rare appears after 4 rare-less rounds.
6. **Minefield stacking** — instant cast, CD 7s, mine lifetime 14s, mines stack, no cap.
   *Accept:* re-cast while old mines live; both sets armed.
7. **Hive offense buff** — player-targeted poison clouds, spore volley, heavier swarm, poison
   trail, +numbers. *Accept:* Hive pressures a kiting player; then `--profile=boss:hive --players=2
   --build=heavy` stays in budget.
8. **Boss windup + telegraphs** — ~2.5s invulnerable entrance + ≥0.8s heavy-attack tells (all bosses).
   *Accept:* bosses idle/invuln on entrance; heavy attacks readable.
9. **Scanline density** — max 2 sweeps, interval→8s, gaps→200/240. *Accept:* ≤2 sweeps, navigable.
10. **Upgrade card trim + ability-text detail panel** — merge rarity/group line, shared confirm
    hint, `Lv X→Y`; compact ability cards + always-on detail panel. *Accept:* cards less cluttered;
    ability descriptions readable without hover.
11. **Starting-weapon loadout** — per-player weapon picker (5 weapons) → `inventory.weapon_id`, Lv1.
    *Accept:* chosen weapon is active at run start.
12. **2P camera tuning** — zoom_max→1.0, padding→(160,140). *Accept:* fills view when players near.
13. **Map → next-choices cards** — replace the graph; 2–3 route cards + Floor X/Y; real risk/reward.
    *Accept:* no overlap/scroll; route choice works; boss/elite/modifier shown per card.
14. **Debug Menu** (last; consolidates Encounter Builder rework) — dev-flag main-menu button →
    room/boss launcher + **Perf scenario launcher (drives PerfRunner)** + cheats + live spawn.
    *Accept:* launch any room/boss; run a perf scenario from the menu; cheats work.

**Parked:** entity-count perf ceiling (MultiMesh + caps) → dedicated perf round (Perf Runner ready
to drive it). Working tree currently holds only the Perf Runner (uncommitted); everything else above
is unbuilt spec. Round 9 is the committed baseline.
