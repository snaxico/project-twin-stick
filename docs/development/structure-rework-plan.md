# Structure Rework Plan — "Trim"

> Status: **design locked, not implemented.** Supersedes the structural assumptions in
> `playtest-round-14-plan.md` Part B (especially **Patch 3 — boss set-pieces, which is cancelled**).
> Built on top of the Round 14 / Patch 1 build (manual aim, 7 weapons, Momentum/Flow).
>
> This is a **design + scope** plan. It is not yet Codex-ready; each phase below becomes its own
> bounded, Codex-ready task with stats before implementation.

## Decision summary

The direction is a **trim**, not a genre pivot. We keep the game's roguelite identity but cut the two
heaviest, least-validated structural systems — the branching map and dedicated boss set-pieces — and
fold their value back into the core wave loop.

Locked decisions:

1. **One continuable run — no mode split.** Drop the separate Structured / Endless modes. There is a
   single run: a **curated arc** of clear-the-room rooms, then a **win milestone**, then optional
   **seamless continuation into endless scaling**.
2. **Remove the branching map.** Replace with a between-room **risk/reward choice card**.
3. **Remove dedicated boss rooms.** **Convert all four boss kits** (Warden / Hydra / Hive / Pulsar)
   into **elite champions** that spawn inside normal wave rooms (unified champion tier — see below).
4. Champions appear on **fixed beats + choosable** (guaranteed at set depths, plus an opt-in champion
   room from the choice card).
5. **Clear-the-room encounters** (current model — timed spawning, room clears when enemies dead), **not**
   survival-timer waves. No mandatory boss climax.

## One continuable run (post-rework)

There is **one run**, not two modes:

1. **Curated arc** — rooms `1 … RUN_LENGTH` (a tunable constant, target ~10). Steady-climb difficulty,
   two-act enemy-pool backbone, champion beats, forced modifiers by depth.
2. **Win milestone** — clearing the final arc room (room `RUN_LENGTH`, a champion room) shows a
   **win screen**: the run is banked as a **win** + score, and offers **"continue into Endless?"**.
3. **Continuation** — choosing continue keeps the *same run* going past `RUN_LENGTH` with
   **difficulty climbing seamlessly** (one smooth curve, champions every 5, choice card continues),
   score = rooms cleared, until death.

Menu shows just **Play** (the run) — no Structured/Endless selection. The old "Endless mode" is simply
the post-milestone continuation of this one run.

**Run stake = the run itself.** Nothing carries across rooms — **health resets each room and momentum
resets each room** (unchanged). There is deliberately **no persistent resource** (no carried HP, no
heals, no lives). The thing at risk is the **whole run**: dying in any room ends it. This is what gives
the choice card teeth, and it shapes how that card is built (below).

Momentum/Flow remains the connective tissue. **Pick cadence stays XP-gated** (unchanged): you keep
leveling as you keep clearing, so a long continuation keeps granting picks.

**Run stake = the run itself.** Nothing carries across rooms — **health resets each room and momentum
resets each room** (unchanged). There is deliberately **no persistent resource** (no carried HP, no
heals, no lives). The thing at risk is therefore the **whole run**: dying in any room ends it. This is
what gives the choice card teeth, and it shapes how that card is built (below).

## Run curve

- **`RUN_LENGTH` rooms (tunable constant, target ~10), two acts.** Difficulty is a **steady climb** —
  each room a notch harder than the last, Act 2 baseline above Act 1. Predictable forward motion, no big
  cliff at the act break. The exact `RUN_LENGTH` is pinned in playtest tuning, not committed now.
- **Champion beats:** mid (act-1 finale, ~halfway) and **room `RUN_LENGTH`** (the win-milestone room),
  plus any opt-in champion rooms from the card. After the milestone, champions resume **every 5 rooms**.
- **Major modifiers are forced by depth** (ambient): rooms acquire a modifier automatically as depth
  rises, independent of the card. The card layers its risk kind + reward *on top* of whatever modifier
  the room already carries (so e.g. a deep room can be `swarm` **and** Fire Floor at once). Exact depth
  thresholds = a phase-1 number.
- **Continuation past the milestone** reuses the same per-room escalation, climbing **seamlessly** from
  where the arc left off (one curve, no reset), unbounded until death. Score = rooms cleared.

## The core loop (per room)

1. **Wave room** — existing continuous time-based spawner, escalating with depth.
2. **Clear** — waves exhausted + enemies dead (existing).
3. **XP / level → banked picks** (existing reward sequencing).
4. **Choice card** — pick the next room as **risk vs reward** (replaces the map).

## Choice card — risk vs reward

Replaces MapUI / route graph / node layout with a flat **2–3 option next-room card**.

Because **nothing persists across rooms**, the card can't trade a saved resource (no heals, no carried
HP/momentum). So the decision is framed as **"which threat do I want to face, for which kind of build
payoff"** — a **risk *kind*** paired with a **reward *category*** — with the run itself as the stake
(death ends it). Each option pairs:

- **Risk kind** (one of): `standard` · `swarm` · `champion room` (opt-in, on top of the fixed beats).
  - **Major modifiers are NOT a card option** — they're **ambient, forced by depth** (see *Structured
    room curve*). The card layers its risk kind on top of whatever modifier the room already carries.
  - **Elite-add pressure is gone** as a risk kind — elites are folded into the unified champion tier.
- **Reward** = a **forced pick category** for that room's post-clear pick (`Weapon` / `Effect` /
  `Attribute` / `Ability`) **+ a rarity nudge that scales with risk**:
  - `standard` → normal pick, normal rarity
  - `swarm` → normal pick, **rare-weighted**
  - `champion` → **guaranteed rare option + extra pick** (inherits the old elite-room bonus)

**Generation rule:** the 2–3 shown options must differ on **both** axes (no two identical risk kinds,
no two identical reward categories) so it's always a real decision — *what threat suits my loadout* ×
*what my build needs next* — not a flavor reshuffle. With only 3 risk kinds, the **reward category**
carries most of the differentiation; if the card feels thin in playtest, add more risk kinds (e.g. a
hazard/objective variant) rather than reintroducing forced-vs-chosen modifiers.

**Reuse** the existing route-choice card UI (it already renders room/enemy/modifier/reward detail);
strip the graph/positions and present the flat 2–3 option choice.

## Champions (unified tier: former elites + former bosses)

Elites and bosses **collapse into one "champion" tier** above trash — a **two-tier ladder: trash →
champion**, no separate elite tier. The champion pool = **7 champions**: the 4 former bosses
(Warden / Hydra / Hive / Pulsar) + the 3 former Elite mini-bosses (Charger / Spitter / Support).

- Champions **spawn into a live wave room**, not a dedicated room.
- Each keeps **1–2 signature telegraphed attacks** from its old kit:
  - **Warden** — leap gap-closer / ground-pound shockwave
  - **Hydra** — rotating sweep / aimed snipe
  - **Hive** — shield + poison cloud
  - **Pulsar** — EMP ability-lockout / sweeping beam
  - **former elites** — keep their existing telegraphed pressure patterns
- **Drop** multi-phase HP-threshold scripting and entrance windup; keep one readable threat each.
- **Look (readability):** champions are **visibly bigger**, carry a **colored aura**, and show a
  **named health bar** — repurpose the boss HP bar we're otherwise removing, **minus the phase pips**.
- **Delivery:** repurpose the existing **elite add-wave system** as the champion spawn mechanism.
- **Cadence:** guaranteed champion at the **mid beat** and at **room `RUN_LENGTH`** (the win-milestone
  room); after the milestone, champions resume **every 5 rooms**. The choice card can also offer an
  extra opt-in **champion room**. Champion rooms inherit the old **elite-room bonus** (guaranteed rare +
  extra pick). The milestone champion is the run's "win" peak without being a dedicated boss.

## What gets removed

- Branching map: `MapUI`, map flow in `RunFlow`, route-graph generation, node layout/positions.
- **The Structured / Endless mode split** — one continuable run replaces both. The separate endless
  generation path collapses into the single run generator (endless = post-milestone continuation);
  the pre-run mode selection goes away (menu = just **Play**).
- Dedicated boss rooms: delayed-boss combat-room logic, boss **phase** HUD + phase pips, boss add-wave
  budget, boss-entrance windup set-piece, boss-every-5 endless cadence. (The boss **HP bar itself is
  repurposed** as the champion health bar, not deleted.)
- The separate **Elite tier** as a distinct concept — elites fold into the champion pool; their
  AIs/patterns survive as champions, and "elite rooms" become "champion rooms."
- (Boss off-screen indicator already removed in Round 14.)

## What gets reused

- Continuous wave spawner, XP/pick economy, modifiers, side objectives, **elite add-wave system**
  (becomes champion delivery), reward-card UI, Momentum/Flow.
- All four boss AIs **+ the three elite AIs** → the 7 champion behaviors.
- The **boss HP bar** (minus phase pips) → champion health bar.
- **Keep** the boss telegraph **prewarm** (Round 12) — still needed so champion attack VFX don't
  first-use stutter inside a dense wave.

## Implementation phasing (each = its own bounded, validated task)

1. **Strip the map + unify into one run.** Run generator emits a **single linear room sequence**
   (`RUN_LENGTH` arc rooms then unbounded continuation, bosses kept at the beats, modifiers forced by
   depth); collapse the separate endless path into it; remove the map UI and mode selection; **auto-advance**
   between rooms. The card comes in Phase 2. See *Phase 1 (task detail)* below.
2. **Choice card.** Risk/reward option generation + selection → feeds the next room config.
3. **Champions.** Convert elite-add-wave delivery to spawn former-boss kits as champions; trim boss
   scripts to 1–2 attacks; remove boss-room / HP-HUD / add-budget machinery.
4. **Win milestone + continue.** Win screen at room `RUN_LENGTH` (banked win + score) with a
   **"continue into Endless?"** choice; continuation keeps the same run climbing seamlessly. Score = rooms cleared.
5. **Enemy / power re-tune (last).** Numeric pass lands here — *after* champions-in-waves exist, since
   that's what shifts the curve. **Philosophy: low-HP / high-threat** — enemies pressure via counts +
   telegraphed attacks, not HP-sponge bloat. Keep current enemy values until this phase; ship the
   stronger Patch-1 player against current enemies, then hand-tune.

Each phase: headless parse + boot validation; phases 3–5 also need **PerfRunner** — champions inside a
full wave are a **new** perf case (champion attack VFX + dense wave), distinct from the old isolated
boss-room profiles.

---

## Phase 1 — Strip the map + unify into one run (task detail)

**Goal:** replace the **branching node map** with a single **linear room spine** that runs an
**`RUN_LENGTH`-room curated arc and then continues unbounded**, collapse the separate Endless path into
it, remove the map UI and the mode-selection screen, and force modifiers by depth. **Bosses stay at the
beat rooms as placeholders** (the boss→champion conversion is Phase 3). The **choice card is Phase 2**
and the **win-milestone/continue UX is Phase 4** — Phase 1 just **auto-advances** room→room and keeps
generating rooms past `RUN_LENGTH` (no win screen yet).

### Locked numbers

- **`RUN_LENGTH` = 10** for now (a single tunable constant; pin the final value in playtest tuning),
  two acts of 5 (act swaps to the harder enemy pool at room 6). The generator must keep producing rooms
  **past `RUN_LENGTH`** with the same escalation (seamless continuation).
- **Beat rooms = room 5 (mid) and room `RUN_LENGTH` (milestone)** — keep the current mid-boss /
  final-boss for now; after `RUN_LENGTH`, a boss/champion beat **every 5 rooms**.
- **Forced-modifier schedule by room** for the arc (ambient, independent of any future card):

  | Room | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | Modifier | – | – | minor | minor | **major** | minor | major | major | major | **major** |
  | Beat | | | | | **boss** | | | | | **boss** |

  Beat rooms **5 & 10 carry a modifier too** (user decision — see readability watch-item below).
  Past the arc, continue the depth→modifier escalation (all major).
- Difficulty (room duration / spawn interval / opening burst) keeps scaling off `get_run_progress()`;
  for the **continuation**, progress should keep climbing past 1.0 (or switch to the
  endless-style unbounded ramp) so difficulty rises seamlessly — **steady climb** with no reset.

### Touch points (RunState.gd unless noted)

- Replace `_generate_node_map()` (branching builder) with a **linear room builder** that produces the
  `RUN_LENGTH` arc and can **extend on demand** past it (lazy-append rooms for the continuation, or
  generate-on-advance).
- **Merge `_build_endless_node` into the single generator** — endless rooms are just arc-continuation
  rooms (same escalation/beat/modifier rules), not a separate path.
- Retire the route-differentiation helpers: `_assign_modifiers_to_map`, `_ensure_route_options_differ`,
  `_build_route_option_signature`, `_build_distinct_modifier_load`, `_roll_modifiers_for_node` →
  replaced by a **depth→modifier lookup** matching the table.
- Replace variable act sizing (`ACT_1_ROW_MIN/MAX`, `ACT_2_ROW_MIN/MAX`) with `ROOMS_PER_ACT = 5` and a
  single `RUN_LENGTH` constant.
- Keep `_assign_structured_boss_types` / `_build_boss_node` for the beat rooms (5 & `RUN_LENGTH`, then
  every 5).
- Collapse map navigation (`get_map_rows`, `get_reachable_node_ids`, `select_map_node`,
  `_get_starting_reachable_node_ids`) to **linear next-room** advancement.
- **UI:** remove the branching map render (`MapNodeButton.gd` + the map view in `RunFlow.gd`) **and the
  pre-run mode-selection** (Structured/Endless) in `Bootstrap.gd`; replace with a minimal auto-advance
  transition and a single **Play** entry.

### Out of scope for Phase 1

- The risk/reward **choice card** (Phase 2).
- **Champion** behavior / the boss→champion conversion and unified-tier work (Phase 3).
- The **win screen + "continue?" UX** (Phase 4) — Phase 1 just keeps generating past `RUN_LENGTH`.
- Any **enemy/champion re-tune** (Phase 5).

### Validation

- `git diff --check`; headless parse; headless boot.
- Sanity-check a generated run = `RUN_LENGTH` arc rooms with bosses at 5 & `RUN_LENGTH` and the modifier
  schedule above; confirm rooms keep generating past `RUN_LENGTH` with the same escalation.

### Watch-item (from the beat-room modifier decision)

- Rooms 5 & 10 stack a **major modifier on top of the boss/champion**. Verify in playtest that the
  big telegraphed attacks stay readable under the modifier's visual noise; if not, drop the beat-room
  modifier (back to clean beats).

## Risks to watch in playtest

- **Win milestone feels arbitrary** — since the run just keeps going, the room-`RUN_LENGTH` "win" must
  feel like an earned peak (the champion + win screen), or it reads as a meaningless speed bump. Watch
  whether players feel a payoff there.
- **Continuation difficulty spike** — confirm the seamless climb past the milestone isn't a sudden
  unfair jump right after the finale champion; add a soft knee in tuning if it is.
- **Champion readability in a swarm** — champion + wave can be visually noisy; telegraphs must stay
  legible (prewarm + clear tells), especially under a stacked beat-room modifier.
- **Choice-card differentiation** — options must feel like real decisions, not flavor.
- **New perf case** — champion + full wave needs profiling; old boss-room profiles no longer represent
  the worst case.

## Resolved (2026-06-20)

- **One continuable run — no mode split** → curated arc → win milestone → seamless endless
  continuation. Menu = just **Play**; old "Endless" = the post-milestone continuation. (above)
- **Run length** → single **tunable constant `RUN_LENGTH`** (target ~10), pinned in playtest tuning;
  champion beats at room 5 + `RUN_LENGTH`, then every 5. (above)
- **Continuation difficulty** → **keeps climbing seamlessly** (one curve, no reset).
- **Pick cadence** → **stays XP-gated** (unchanged).
- **Run stake** → **nothing persists**; the run itself is the stake (death ends it). (above)
- **Choice-card economy** → risk-kind × reward-category, rarity nudge scales with risk; no heals. (above)
- **Enemy re-tune** → tune **last**, low-HP / high-threat philosophy; keep current values until phase 5.
- **Onboarding** → **deferred** (see below). Not part of this rework.
- **Threat ladder** → **unified champion tier** (trash → champion, 7 champions = 4 bosses + 3 former
  elites); no separate elite tier. (above)
- **Champion look** → **bigger + aura + named health bar** (repurpose boss HP bar minus phase pips).
- **Champion rooms grant the extra pick** → yes (inherit the old elite-room bonus).
- **R14 confidence** → playtest was thorough; build the rework straight on top, no extra R14 pass.
- **Difficulty curve** → **steady climb**, Act 2 baseline above Act 1.
- **Modifiers** → **forced by depth** (ambient), not a card option; card layers risk + reward on top.

## Remaining open items (decide during the relevant phase, not blocking)

- **Exact numbers, to set when writing each phase's Codex task:** final `RUN_LENGTH`; rare-weight nudge
  per risk kind; per-room difficulty values across the arc; modifier depth-thresholds; the
  continuation ramp rate (and any soft knee right after the milestone).
- **Tuning targets (phase 5):** the actual enemy + champion stat values, hand-tuned in playtest.
- **Risk/reward "parasite" items** (Part C) — synergize strongly with the choice card; candidate
  follow-up *after* the card ships, not part of this rework.

## Carried forward from Part B/C/D (unaffected by this rework)

- **Patch 2 — Abilities:** Stance/Root, combat drone, Barrier dome (still queued).
- **Patch 4 — Biomes:** destructible cover, pits/gaps, pinball bumpers (still queued).
- **Parked (Part C):** arcade score-multiplier + "heat" dynamic difficulty, parasite items,
  rubberhose art restyle.
- **Deferred:** onboarding / tutorial (rising complexity — manual aim, momentum, 7 weapons — and couch
  co-op still need lightweight teaching eventually; explicitly not now).
- **Cancelled:** Patch 3 boss set-pieces (replaced by champions above).
