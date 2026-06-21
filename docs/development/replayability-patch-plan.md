# Choices & Builds Patch — vision & roadmap

> Status: **vision drafting (guided Q&A in progress).** Sits on top of the implemented structure rework
> (`v3/structure-rework`). The "what makes it replayable" patch — a phased roadmap, not a single commit.
>
> **Absorbs the next-room-choice patch** (now **Phase 0**) — the two share one rarity/reward economy
> (room rare-nudge ↔ Signature-tier roll), so they're designed together here. The theme that unifies
> them: **make the player's choices matter** — *which room* (Phase 0) and *which upgrade* (Phase A).
> `next-room-choice-plan.md` stays as the detailed Phase-0 spec; this doc owns the shared economy.

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

Build order: the small choice-UI win first, then the replay *hook*, then the reason-to-*return*, the
*skin* last.

### Phase 0 — Next-room choice *(small, ships first)*
The *which-room* decision: the styled 2-card UI (trait label, danger pips, real modifier names),
danger-score + dominant-trait derivation, and the **room rare-odds nudge** on the spicier option.
Full detail in **`next-room-choice-plan.md`**; its rare-nudge is reconciled with Phase A's Signature
tier in *Rarity & reward economy* below. Mostly ready — needs one card-UI tightening pass.

### Phase A — Build depth via tag synergies *(the hook — biggest piece)*

**Decided:** keyword/tag synergies · a new "Signature" tier above current rares · mixed parasites
(stat + mechanical) · a minimal first cut that grows via unlocks.

**Tags.** Every upgrade carries one or more tags. Starter set, grounded in existing systems (expand via
unlocks later):
- `Fire` (Fire Bullets), `Frost` (Freeze Shot), `Toxic` (Poison), `Split` (Split) — the 4 existing
  weapon-rare effects become the first build themes.
- `Momentum` — the signature mechanic as a build axis.
- `Pierce` / `Projectile` — weapon-behavior builds. `Ability` — ability-focused builds.

**The new "Signature" tier** (rare/legendary, rolls above the current rares). Three card kinds:
1. **Amplifiers** — the synergy glue: boost *everything* of a tag. e.g. "Accelerant — Fire effects deal
   more." Worthless without tagged upgrades → a real commit.
2. **Transformers** — change behavior + carry a tag. e.g. "Chain Reaction — Split bolts can split again
   `[Split]`"; "Momentum Surge — at max Momentum your shots pierce `[Momentum][Pierce]`".
3. **Parasites** (mixed, tagged): +big power / -real cost. Stat ("Glass Cannon: +80% damage / -40% max
   HP") and mechanical ("Pyromaniac: Fire effects way up, but you can't heal `[Fire]`").

**Compilation** (`MutationSystem.gd`): add a `tags` field to upgrade data; compute a per-tag power value
from equipped amplifiers; tagged effects scale by their tag's power during the existing mutation compile.
The Signature tier rolls through the existing rare path (rare-weighted; the next-room rare-nudge feeds it).

**Amplifier model = tag-count scaling (decided).** Every owned upgrade of a tag boosts *all* effects of
that tag:
```
PER_TAG_RATE := 0.12                                   # +12% per tagged upgrade (tunable)
tag_count[tag] = (#equipped upgrades tagged `tag`) + bonus stacks from amplifiers
tag_power[tag] = 1.0 + tag_count[tag] * PER_TAG_RATE
# during compile, each tagged effect's magnitude *= tag_power[its tag]
```
So a Fire build snowballs the more Fire you stack; **amplifier** cards just add bonus stacks (e.g.
"+2 Fire") to accelerate it. Implemented in `MutationSystem` compile: count tags across equipped
upgrades → `tag_power`, scale tagged effect magnitudes by it.

**First cut (~12, illustrative — tune in playtest):**
- Tag the 4 existing weapon rares: Fire Bullets `[Fire]`, Freeze Shot `[Frost]`, Poison `[Toxic]`,
  Split `[Split]`.
- New Signature cards: **Accelerant** `[Fire]` (amplifier +2 Fire) · **Ember Spread** `[Fire]`
  (transformer: enemies dying while burning ignite nearby) · **Pyromaniac** `[Fire]` (parasite: +3 Fire,
  but can't heal) · **Chain Reaction** `[Split]` (transformer: split bolts split once more) · **Momentum
  Surge** `[Momentum][Pierce]` (transformer: at max momentum, shots pierce +3) · **Glass Cannon**
  (parasite, stat: +80% damage / −40% max HP) · **Cryo Shatter** `[Frost]` (transformer: frozen enemies
  shatter for AoE on death) · **Virulent** `[Toxic]` (amplifier +2 Toxic).
- Covers Fire (deep), Split, Frost, Toxic, Momentum + one mechanical and one stat parasite — enough to
  prove the loop. Everything else grows via Phase-B unlocks.

### Phase B — Meta: score currency + unlock menu *(reason to return)*

**Decided:** score is a **banked currency** spent in an **unlock menu** (VS-style); a **lean starting
pool** grown by unlocking weapons / abilities / Signature cards / loadout perks; **persistent save**.

- **Score = currency.** Earned per run from depth + kills + champion kills + momentum peaks (formula
  tunable, e.g. `rooms*100 + kills + champions*250 + max_momentum_tier*50`). **Banked cumulatively**
  across *every* run (win or death) into the save. The light "flow surfacing" is this score being
  visible and mattering.
- **Unlock menu** (new screen off the main menu): locked items listed with a score cost; spend banked
  score → unlock permanently → it enters the run pool / pre-run selection. Costs scale (cheap early →
  expensive deep).
- **Everything is gated** (your pick): Signature cards (this is where the Phase-A "grow via unlocks"
  lives), weapons, abilities, loadout perks/start options.
- **Lean start:** begin with a small free core (e.g. Rifle + 1 weapon, 2 abilities, base commons),
  unlock the rest. ⚠️ Note: this **re-gates content you already have** and shrinks the new-player
  starting set — more progression arc, but confirm it doesn't make early runs feel thin.
- **Persistent save:** extend `ProfileState.gd` (today only a screen-effect stub) with
  `banked_score: int` + `unlocked_ids: Array`; load on boot; `Bootstrap` setup + the run upgrade pool
  **filter by unlocked**. This **re-introduces meta progression** (deliberately removed in V3) — a real
  new system, the biggest part of Phase B.
- **Score readout:** current score on the in-run HUD; earned + new banked total on the win/death
  screens; banked total in the unlock menu.

*Open:* the score formula, the free starting set, unlock costs/order, and the unlock-menu UX.

### Phase C — Rubberhose art restyle *(identity skin)*
- The committed 1930s rubberhose (Cuphead-lineage) restyle, done once systems are stable.
- Build was already parameterized for a later re-skin.
- *Detail later.*

## Rarity & reward economy (shared — the reason to merge)

Phase 0 and Phase A touch the *same* rare roll, so define it once:

- **Rare chance** = depth curve (`lerpf(0.20, 0.45, …)`) **+ the Phase-0 room `rare_bonus`** (spicier
  option), clamped ≤ ~`0.60`. (Today `_get_current_rare_chance()` is just the depth curve.)
- **When a rare is rolled**, it draws from a pool of **{current rares} + {Signature tier}**. The
  Signature share is **weighted and rises with depth** (e.g. 0% shallow → a meaningful share deep), so
  build-defining cards show up more as a run matures — and the room nudge makes them show up *sooner*
  if you take the spicy room. That's the payoff that ties the two patches together.
- **Parasites** (Phase A) sit in the Signature pool but should be offered as a *choice you can decline*
  (e.g. they appear alongside non-parasite options, never forced).
- Tuning lever: Signature-share curve, the `rare_bonus` size, and the rare-chance cap are one balance
  problem now, not two.

## Open questions (to resolve via guided Q&A)

- **Phase A — SHAPE DECIDED** (tag synergies · Signature tier · mixed parasites · count-scaling ·
  minimal-then-grow). Remaining = numbers (`PER_TAG_RATE`, amplifier stack values, Signature rare
  weighting), the final card list, and the `MutationSystem` wiring detail (where `tag_power` multiplies
  in the compile). To turn into a Codex-ready task next, like the structure rework.
- **Phase B — SHAPE DECIDED** (score = banked currency · unlock menu · all categories gated · lean
  start · persistent save via `ProfileState`). Remaining = the score formula, the free starting set,
  unlock costs/order, the unlock-menu UX, and the pool/setup unlock-filter wiring.
- **Phase C — later:** the rubberhose restyle scope.

## Relationship to other plans

- **`next-room-choice-plan.md`** is now **Phase 0 of this patch** (merged), not independent. It stays as
  the detailed Phase-0 spec; this doc owns the shared rarity economy.
- This supersedes the parked Part-C "arcade layer" for now (flow stays light, per decision).
- Rubberhose art = the long-committed restyle, now slotted as Phase C.
