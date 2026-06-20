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

- **Risk kind** (one of): `standard` · `swarm` · `major modifier` (Fire Floor / Ice Zone / Scanline /
  Shrinking Arena) · `elite-add pressure` · `champion room` (opt-in, on top of the fixed beats).
- **Reward** = a **forced pick category** for that room's post-clear pick (`Weapon` / `Effect` /
  `Attribute` / `Ability`) **+ a rarity nudge that scales with risk**:
  - `standard` → normal pick, normal rarity
  - `swarm` / `modifier` → normal pick, **rare-weighted**
  - `champion` → **guaranteed rare option** (and optionally an **extra pick**)

**Generation rule:** the 2–3 shown options must differ on **both** axes (no two identical risk kinds,
no two identical reward categories) so it's always a real decision — *what threat suits my loadout* ×
*what my build needs next* — not a flavor reshuffle. This directly answers the old
route-differentiation worry: the choice is legible on two independent axes.

**Reuse** the existing route-choice card UI (it already renders room/enemy/modifier/reward detail);
strip the graph/positions and present the flat 2–3 option choice.

## Champions (former bosses)

- The four boss AIs are **reused** as elite **champions** that spawn **into a live wave room**, not a
  dedicated boss room.
- Each champion keeps **1–2 signature telegraphed attacks** from its old kit:
  - **Warden** — leap gap-closer / ground-pound shockwave
  - **Hydra** — rotating sweep / aimed snipe
  - **Hive** — shield + poison cloud
  - **Pulsar** — EMP ability-lockout / sweeping beam
- **Drop** multi-phase HP-threshold scripting and entrance windup; keep one readable threat per champion.
- **Delivery:** repurpose the existing **elite add-wave system** as the champion spawn mechanism.
- **Cadence:** guaranteed champion at fixed depths (**structured: room 5 + room 10; endless: every 5
  rooms**), plus the choice card can offer an extra opt-in **champion room** for a guaranteed-rare
  reward. The room-10 champion doubles as the run's send-off without being a dedicated boss.

## What gets removed

- Branching map: `MapUI`, map flow in `RunFlow`, route-graph generation, node layout/positions.
- Dedicated boss rooms: delayed-boss combat-room logic, boss HP/phase HUD, boss add-wave budget,
  boss-entrance windup set-piece, boss-every-5 endless cadence.
- (Boss off-screen indicator already removed in Round 14.)

## What gets reused

- Continuous wave spawner, XP/pick economy, modifiers, side objectives, **elite add-wave system**
  (becomes champion delivery), reward-card UI, Momentum/Flow.
- All four boss AIs → champion behaviors.
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

## Remaining open items (decide during the relevant phase, not blocking)

- **Exact numbers, to set when writing each phase's Codex task:** rare-weight nudge per risk kind;
  whether `champion` rooms also grant the extra pick; the per-room difficulty curve across the 10 rooms;
  endless escalation rate.
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
