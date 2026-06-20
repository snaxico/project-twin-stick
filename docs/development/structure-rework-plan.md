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

1. **Keep two modes**, but differentiate by *boundedness*, not *structure*.
2. **Remove the branching map.** Replace with a between-room **risk/reward choice card**.
3. **Remove dedicated boss rooms.** **Convert all four boss kits** (Warden / Hydra / Hive / Pulsar)
   into **elite champions** that spawn inside normal wave rooms.
4. Champions appear on **fixed beats + choosable** (guaranteed at set depths, plus an opt-in champion
   room from the choice card).
5. Runs may **end on completion (a timer/sequence), no mandatory boss climax**.

## Mode identity (post-rework)

| | Structured | Endless |
|---|---|---|
| Shape | Bounded curated run | Unbounded |
| End | Completes a fixed sequence → **win screen** | Runs until death → **score** |
| Length | **~10 rooms / ~15 min** (two acts of ~5) | Until death |
| Pacing | Hand-curated difficulty backbone (acts kept only as a difficulty curve, **not** a map) | Flat escalation cadence |
| Champions | Fixed at **room 5** (act finale) + **room 10** (run finale) + choosable | **Every 5 rooms** + choosable |
| Score | — | Rooms cleared |

Both modes are the **same loop**: linear wave rooms + risk/reward choice card between rooms +
champions woven into waves. Momentum/Flow is the connective tissue.

**Run stake = the run itself.** Nothing carries across rooms — **health resets each room and momentum
resets each room** (unchanged). There is deliberately **no persistent resource** (no carried HP, no
heals, no lives). The thing at risk is therefore the **whole run**: dying in any room ends it. This is
what gives the choice card teeth, and it shapes how that card is built (below).

## Structured room curve

- **10 rooms, two acts of ~5.** Difficulty is a **steady climb** — each room a notch harder than the
  last, Act 2 baseline (rooms 6–10) above Act 1. Predictable forward motion, no big cliff at the break.
- **Champions** at room 5 (act finale) and room 10 (run finale), plus any opt-in champion rooms.
- **Major modifiers are forced by depth** (ambient): rooms acquire a modifier automatically as depth
  rises, independent of the card. The card layers its risk kind + reward *on top* of whatever modifier
  the room already carries (so e.g. a deep room can be `swarm` **and** Fire Floor at once). Exact depth
  thresholds = a phase-1 number.
- Endless reuses the same per-room escalation, just unbounded.

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
- **Cadence:** guaranteed champion at fixed depths (**structured: room 5 + room 10; endless: every 5
  rooms**), plus the choice card can offer an extra opt-in **champion room**. Champion rooms inherit the
  old **elite-room bonus** (guaranteed rare + extra pick). The room-10 champion is the run's send-off
  without being a dedicated boss.

## What gets removed

- Branching map: `MapUI`, map flow in `RunFlow`, route-graph generation, node layout/positions.
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

1. **Strip the map.** Run generator emits a **linear room sequence**; replace MapUI with the
   choice-card overlay (reuse route-card UI). Unify with endless, which is already linear.
2. **Choice card.** Risk/reward option generation + selection → feeds the next room config.
3. **Champions.** Convert elite-add-wave delivery to spawn former-boss kits as champions; trim boss
   scripts to 1–2 attacks; remove boss-room / HP-HUD / add-budget machinery.
4. **Mode framing.** Structured bounded length + win screen; endless champion cadence + score.
5. **Enemy / power re-tune (last).** Numeric pass lands here — *after* champions-in-waves exist, since
   that's what shifts the curve. **Philosophy: low-HP / high-threat** — enemies pressure via counts +
   telegraphed attacks, not HP-sponge bloat. Keep current enemy values until this phase; ship the
   stronger Patch-1 player against current enemies, then hand-tune.

Each phase: headless parse + boot validation; phases 3–5 also need **PerfRunner** — champions inside a
full wave are a **new** perf case (champion attack VFX + dense wave), distinct from the old isolated
boss-room profiles.

## Risks to watch in playtest

- **Structured vs endless feeling identical** — mitigated by bounded+win vs unbounded+score, and by
  curated champion beats vs flat cadence. Confirm it actually reads as two modes.
- **Champion readability in a swarm** — champion + wave can be visually noisy; telegraphs must stay
  legible (prewarm + clear tells).
- **Choice-card differentiation** — options must feel like real decisions, not flavor.
- **New perf case** — champion + full wave needs profiling; old boss-room profiles no longer represent
  the worst case.

## Resolved (2026-06-20)

- **Run length** → ~10 rooms / ~15 min, champions at room 5 + 10. (above)
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

- **Exact numbers, to set when writing each phase's Codex task:** rare-weight nudge per risk kind; the
  per-room difficulty values across the 10 rooms; the modifier depth-thresholds; endless escalation rate.
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
