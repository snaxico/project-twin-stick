# Choices & Builds Patch — vision & roadmap

> Status: **all phases Codex-ready (specs below), not built yet.** Sits on top of the implemented
> structure rework (`v3/structure-rework`). The "what makes it replayable" patch — a phased roadmap, not
> a single commit. (Phase C is scaffolding-only — art assets are a human/art task, not Codex-buildable.)
>
> **Includes the next-room-choice work as Phase 0** — it shares one rarity/reward economy with the
> build-depth Signature tier (room rare-nudge ↔ Signature roll), so it's designed here. The theme that
> unifies the whole patch: **make the player's choices matter** — *which room* (Phase 0) and *which
> upgrade* (Phase A).

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
danger-score + dominant-trait derivation, and the **room rare-odds nudge** on the spicier option (its
nudge is reconciled with Phase A's Signature tier in *Rarity & reward economy* below). Full Codex-ready
detail in *Phase 0 — Next-room choice* under *Codex-ready specs*.

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

## Remaining = tuning only (specs are Codex-ready)

The Codex-ready specs above leave only **playtest-tunable numbers**, not design gaps:
- Phase 0: `RARE_NUDGE`, danger-pip thresholds/weights.
- Phase A: `PER_TAG_RATE`, amplifier stack sizes, `_signature_share(depth)` curve, parasite values, the
  final card list.
- Phase B: the score formula constants, the free starting set + unlock costs/order, unlock-menu UX.
- Phase C: the full art-asset effort (separate, human/art) + the re-skin scaffolding scope.

Recommended next: a **review pass** (the loop that's caught real bugs each time), then build **Phase 0**.

## Codex-ready specs (per phase)

Numbers are placeholders (tune in playtest); shapes/touch-points are decided. Each phase is sliced into
bounded hand-offs. Every slice: `git diff --check` + headless parse/boot; symbol-removal greps over
runtime paths only.

### Phase 0 — Next-room choice

Turn the placeholder 2-room choice (random-differ, same reward, text button) into a readable pick with a
light push-your-luck layer + a styled card. **Modifier-led, flavor / near-equal reward, fully shown**:
the two options are different *kinds* of fight; the spicier one carries the small rare-odds nudge from
*Rarity & reward economy* above. No new room/enemy content; champion steps unchanged.

**Mechanics** (all in `RunState._build_choice_step` / `_build_run_node` + a per-room field CoopManager reads):
- **Danger score → pips:** `danger_score = minor_mods*1 + major_mods*2 + clampi(enemy_pool.size()-2,0,2)`;
  pips = 1 (≤1) / 2 (≤3) / 3. Store `danger_score`, `danger_pips`.
- **Dominant-trait label + icon** (first match, majors first): `fire_floor`→Hazard zone/flame ·
  `ice_zone`→Frost field/snow · `mine_field`→Scanlines/scan · `shrinking_arena`→Closing walls/shrink ·
  `swarm`→Swarm · `shielded`→Fortified/shield · `enemy_speed`→Frenzied/bolt ·
  `accelerating_waves`→Escalating/rising · `explosive_death`→Volatile/bomb · none→Open room. Store
  `trait_label`, `trait_icon`. Presentation only.
- **Rare-odds nudge:** the higher-`danger_score` option gets `rare_bonus = RARE_NUDGE` (≈0.06), the
  other 0.0 — the *only* reward difference. CoopManager reads it per the economy section
  (`_get_current_rare_chance() += _room_rare_bonus`, clamped).
- **Differ guarantee:** if both options' `trait_label` match, re-roll option b's modifiers (≤4 tries)
  until traits differ; keep `_ensure_route_options_differ` as the signature backstop.

**Card UI (`RunFlow._build_route_card` rewrite):** a `Button` (focus/controller nav) + child VBox
(`mouse_filter=IGNORE`), `custom_minimum_size (252,196)`, `StyleBoxFlat` dark neon bg, 1px accent border
(**2px brighter when `rare_bonus>0`**). Rows: (1) trait icon + `trait_label` · danger pips (filled dots);
(2) `HFlowContainer` modifier chips with **real names** (read `modifiers.json` **`name`** by id,
replacing `_modifier_abbreviation`); (3) Enemies / Objective; (4) "Rare odds NN%" + a `+N%` marker when
nudged. Existing HUD neon colors, no new theme.

**Slices:** 0a = RunState data (danger/trait/nudge + differ) + CoopManager rare-bonus read
[headless-testable] · 0b = the styled card. **Touch:** `RunState` (`_build_choice_step`/`_build_run_node`,
`_danger_score_for`/`_trait_for`, `RARE_NUDGE`), `CoopManager` (`_room_rare_bonus` in `_start_room` +
`_get_current_rare_chance`), `RunFlow` (`_build_route_card` + `modifier→name/icon` maps; drop
`_modifier_abbreviation`/`_build_modifier_badge_text`). **Accept:** headless walk asserts both options
differ in `trait_label`, `danger_pips∈1..3`, exactly one `rare_bonus>0` (unless tie) on the higher-danger
node; manual = cards read as different fights with real modifier names and the `+N%` marker.

### Phase A — Build depth (tag synergies)

**A1 — Tag infrastructure.**
- `data/mutations.json`: add `"tags": [...]` to upgrades. Seed: `fire_trail→["fire"]`,
  `freeze_shot→["frost"]`, `poison→["toxic"]`, `ricochet→["split"]`.
- `MutationSystem.gd`: `_compute_tag_power(player_index) -> Dictionary` — per tag, `count` = equipped
  upgrades carrying it (+ amplifier bonus stacks); `tag_power[tag] = 1.0 + count * PER_TAG_RATE`
  (`const PER_TAG_RATE := 0.12`). In `get_compiled_weapon_stats` / `_get_compiled_beam_stats`, **after**
  the existing fire/frost/toxic/split blocks, multiply their magnitudes by the tag power:
  fire → `trail_damage_percent`, `impact_pool_damage_percent`; toxic → `poison_dps`, `poison_duration`;
  frost → `slow_step`, `slow_duration`; split → `split_count += round((tag_power["split"]-1)/PER_TAG_RATE)`
  (split is integer). **Accept:** equipping N fire upgrades scales the fire magnitudes by `1+N*0.12`.

**A2 — Signature tier + rolling.**
- `data/mutations.json`: new cards with `"rarity":"signature"`. **Depth input:** `roll_mutation_options`
  has no depth arg today — **add a `signature_share: float` parameter** that `CoopManager` computes from
  `_room_depth` (`_signature_share(_room_depth)`, 0 shallow → ~0.5 deep) and passes at the existing call
  site (`CoopManager` ~1384). `MutationSystem`: when a rare is rolled, draw from `{existing rares} +
  {signature pool}`, choosing the signature pool with probability `signature_share`. Cards (effects in
  params): **Accelerant** `[fire]` (+2 fire stacks),
  **Virulent** `[toxic]` (+2 toxic stacks), **Ember Spread** `[fire]` (`ignite_on_death`), **Chain
  Reaction** `[split]` (`split_count += 1`, `split_can_split=true`), **Cryo Shatter** `[frost]`
  (`shatter_on_frozen_death`), **Momentum Surge** `[momentum][pierce]` (`pierce_at_max_momentum=3`).
- Amplifier stacks read in `_compute_tag_power`; transformer flags compiled into the weapon stats and
  consumed by `Projectile`/`CoopManager` (ignite/shatter on death, split-can-split, momentum pierce
  hook in `Player`/`CoopManager`).
- **Rarity rank (required):** code today checks `rarity == "rare"` literally for the dry-streak reset
  (`CoopManager._options_contain_rare` ~1403) and pick presentation (`MutationPickUI` ~262). Add a
  `_rarity_rank(rarity)` helper (`common 0 / rare 1 / signature 2`) and use **rank ≥ rare** at those
  sites so **Signature counts as rare-or-better** (resets dry streak, satisfies `force_rare`), and give
  Signature its **own distinct color/label** in `MutationPickUI`.

**A3 — Parasites (mixed, declinable).**
- Cards with a downside param: **Glass Cannon** (`damage_bonus +0.8` / `max_health_mult -0.4`),
  **Pyromaniac** `[fire]` (`+3 fire stacks` / `heal_disabled=true`). Compile applies stat ones;
  `heal_disabled` read by the HP-pickup path.
- **Roll invariant (concrete):** after `roll_mutation_options` fills the option set, if **every** option
  is a parasite **and** a non-parasite is available in the eligible pool, **replace at least one** with a
  non-parasite. So a pick is never all-downside. (`is_parasite` = a flag on the card.)

**Slices:** A1 (tags + scale existing effects) → A2 (Signature cards + rolling + amplifiers/transformers
+ their behavior flags) → A3 (parasites + heal-disabled). **Touch:** `mutations.json`, `MutationSystem`,
`Projectile`/`CoopManager`/`Player` (behavior flags), `MutationPickUI` (show tags + parasite downside).
**Accept:** equipping N fire upgrades scales fire magnitudes ×`(1+N*0.12)`; signature share rises with
depth; **a forced all-parasite roll with a non-parasite available replaces ≥1** (headless-testable).

### Phase B — Meta: score currency + unlock menu

**B1 — Save + score.**
- `ProfileState.gd` (today a screen-effect stub): add `banked_score: int`, `unlocked_ids: Array[String]`;
  real `load_profile`/`save_profile` for them; `add_score(n)`, `spend_score(n)->bool`,
  `is_unlocked(id)`, `unlock(id)`.
- **Run-score state lives in `RunState`** (persists the whole run). `CoopManager` is **re-instantiated
  per room** and `_start_room()` resets its room counters (`_enemies_killed`, etc.), so run score
  **cannot** live there. Add `RunState.run_score: int` + `add_run_score(delta)`.
- `CoopManager` tracks only the **current room's** contribution (`+100 cleared + kills +
  champion_kills*250 + room_max_momentum_tier*50`) and **writes the room delta to `RunState` on BOTH
  room clear AND player death** — i.e. call `RunState.add_run_score(room_delta)` in `_handle_room_clear`
  **and** right before emitting `all_players_dead` (which is **arg-less today** — the failed room's
  kills/champion/momentum would otherwise be lost). So `RunState.run_score` is always current with no
  signal-payload change. (Alt: emit `all_players_dead(score_context)` and bank in `RunFlow`; the
  live-write is simpler.)
- **Bank ONCE at terminal run end only** — death (`RunFlow._on_room_failed`) or End Run (milestone
  secondary): `ProfileState.add_score(RunState.run_score)`. **Not** at the room-10 milestone (`Continue`
  keeps the run going, [RunFlow.gd:172](scripts/ui/RunFlow.gd:172) → double-count). Surface
  `RunState.run_score` on the in-run HUD (reuse the dropped `_score_label` slot) + on the resolution screens.
**B2 — Unlock menu.**
- The scene **already has** `MetaButton`s + a `meta_panel`, **but `Bootstrap` hides them and does not
  connect them** (`home_meta_button`/`meta_button`/`reset_profile_button`/`meta_panel` set
  `visible = false` at `Bootstrap.gd` ~141–146). So B2 must: **make them visible + wire**
  open (show `meta_panel`) / back / reset. Build the `UnlockMenu` UI **into the existing `meta_panel`**:
  lists locked items (weapons / abilities / signature cards / perks) with a score cost; `spend_score` →
  `unlock(id)`; shows banked total; `reset_profile_button` → `ProfileState.reset_profile()`.
**B3 — Lean start + filtering.**
- Define `UNLOCK_TABLE` (id → cost, with a small **free starting set**: e.g. `rifle` + 1 weapon, 2
  abilities, base commons). `Bootstrap` pre-run weapon/ability options (`debug_*`/loadout populators)
  **filter to unlocked**; `MutationSystem` upgrade/weapon-card pool **filters to unlocked**.
- ⚠️ Re-gates existing content — confirm early runs don't feel thin; tune the free set + costs.

**Slices:** B1 (save+score, no spending) → B2 (unlock menu) → B3 (lean start + pool/setup filtering).
**Touch:** `ProfileState`, `CoopManager` (room-delta score + write on clear/`all_players_dead`), `RunState`
(`run_score` + `add_run_score` + pool filter), `RunFlow` (HUD/resolution surfacing + bank on terminal end),
`Bootstrap` (+`Bootstrap.tscn` `meta_panel` unlock UI + show/wire meta buttons + filtering),
`MutationSystem` (pool filter). **Accept:** a run that reaches the milestone, Continues, then dies banks the score **once**
(not the milestone portion twice); spending in the menu unlocks and persists across a restart.

### Phase C — Rubberhose art *(scaffolding only — assets are human/art work)*

**Honest scope:** art *assets* (hand-drawn rubberhose sprites/animation) are **not Codex-buildable** —
that's an artist task. What an agent *can* do is the **re-skin scaffolding**:
- Replace the procedural `_draw()`-based visuals (player/enemy/projectile polygons in `Player`/`Enemy`/
  `ProjectileRenderer`) with a **sprite/AnimatedSprite swap layer** gated behind a flag, so art can be
  dropped in without touching gameplay. Catalog every procedural-draw site to convert.
- Keep the bloom/HDR pipeline; define the asset slots (idle/move/attack per entity, projectile frames).
- This is a **separate later effort**; spec the pipeline when Phases 0/A/B are in. Listed here for
  completeness, not as a near-term Codex task.

## Relationship to other plans

- The former `next-room-choice-plan.md` is now **fully folded in as Phase 0** of this single doc.
- This supersedes the parked Part-C "arcade layer" for now (flow stays light, per decision).
- Rubberhose art = the long-committed restyle, now slotted as Phase C.
