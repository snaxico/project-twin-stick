# Replayability Patch — vision & roadmap

> Status: **vision drafting (guided Q&A in progress).** Sits on top of the implemented structure rework
> (`v3/structure-rework`). This is the "what makes it replayable" patch — a phased roadmap, not a single
> commit.

## The problem (diagnosis)

The core loop is solid but the game "looks and plays like a prototype." Two separate gaps:

- **Plays flat / samey** — upgrades are mostly **flat stat boosts** (`rapid_fire`, `high_caliber`,
  `move_speed`, `tough`, `range`…). Runs don't *diverge*; you pick bigger numbers and play the same way.
  No synergies, no build-defining choices. **This is the real replayability gap.**
- **No reason to return** — meta-progression was removed; the only pull is "go deeper." A raw score chase
  isn't enough on its own.
- **Looks like a prototype** — placeholder neon. Cosmetic; fix it *last*.

## The bet (decided 2026-06-21)

Essentially the **Brotato recipe**: deep build synergies + a growing unlock pool + a distinct art
identity, with Momentum/Flow staying a supporting buff (no full score/heat economy).

| Direction | Decision |
|---|---|
| **Build depth** | **Build-defining rares + cross-synergies AND risk/reward "parasite" upgrades** (both). The primary replay hook. |
| **Flow identity** | **Light** — keep Momentum as the move/fire buff; just add a visible **score readout**. No multiplier/heat layer. |
| **Meta** | **Unlock pool** — play to unlock weapons / abilities / upgrades INTO the run pool. Recycles build content as unlocks; the "one more run" pull. |
| **Art** | **Rubberhose restyle, but LAST** — skin the loop once the hooks land. |

## Phased roadmap

Build order matters: the replay *hook* first, the reason-to-*return* second, the *skin* last.

### Phase A — Build depth & synergies *(the hook — biggest piece)*
Make upgrades transformative so runs diverge and you chase builds:
- **Build-defining rares** that change *how* weapons/abilities behave (not just numbers).
- **Synergies** — upgrades that amplify each other (mechanism TBD: tags/keywords vs explicit combos).
- **Risk/reward "parasite" upgrades** — real downsides for real power; tension in every pick.
- Likely needs the upgrade-pool depth fix (parked: 9 commons cap-3 is too shallow).
- *Detail via Q&A next.*

### Phase B — Meta unlock pool *(reason to return)*
- Play to **unlock** weapons / abilities / upgrades into the run pool (recycles Phase-A content).
- Add the **score readout** (light flow surfacing) here.
- Unlock *triggers* (depth reached, kills, challenges?) — TBD.
- *Detail via Q&A.*

### Phase C — Rubberhose art restyle *(identity skin)*
- The committed 1930s rubberhose (Cuphead-lineage) restyle, done once systems are stable.
- Build was already parameterized for a later re-skin.
- *Detail later.*

## Open questions (to resolve via guided Q&A)

Phase A first: synergy mechanism, how many/what scale of new upgrades, a new rare tier vs reworking
commons, what parasite downsides look like, and how this interacts with the just-planned next-room
rare-odds. Then Phase B unlock triggers + currency, then Phase C.

## Relationship to other plans

- **`next-room-choice-plan.md`** (rarity nudge / card UI) is independent and can ship before or alongside.
- This supersedes the parked Part-C "arcade layer" for now (flow stays light, per decision).
- Rubberhose art = the long-committed restyle, now slotted as Phase C.
