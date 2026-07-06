# V4 Polish & Fix Round — Plan (Codex-ready)

> **Design source of truth:** [`docs/design/class-system-redesign.md`](../design/class-system-redesign.md).
> This plan is the *build* order for the first post-implementation polish round on the V4 class system.
> **Branch/worktree:** implement on `v4/class-system` in the `Project_Twin_stick_v4` worktree.
> **Decisions captured (2026-07-04, from playtest feedback):** contact-damage bug = **Slice 1**; class
> visual identity = **color + silhouette + VFX within the current abstract-geometric style** (no sprite/
> rubberhose work yet); balancing = **a concrete stat audit** (HP/damage/cooldowns/spawn counts), not by-feel.
> Philosophy: **faster game; many low-HP trash that die in 1–2 hits over a few sponges — elites/champions stay
> meaty.** Targets locked: fast/fluid pace, ultimate ~1 per room, moderate lethality (~3–5s to down when
> surrounded), ~20–30% class deltas (full detail in Slice 7).

## How to work this plan
- **One vertical slice at a time**, in order. Each slice leaves the game runnable and passes the validation
  gate before moving on. Commit per slice. Update `current-state.md` + a `history/` entry per the process doc.
- **Validation gate (run after every slice):** `$GODOT` is re-set so the block is self-contained.
  ```powershell
  $GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
  & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick_v4' --quit                                                 # parse
  & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick_v4' res://scenes/ui/Bootstrap.tscn --quit                  # smoke boot
  & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick_v4' -- --profile=champion:hive --players=2 --build=heavy   # PerfRunner
  git -C 'D:\GameDev\Project_Twin_stick_v4' diff --check
  ```
- **Placeholder-first:** VFX/tuning numbers are first-pass; the balance pass (Slice 7) is where numbers get
  locked. Keep art abstract-geometric — do **not** start sprite/rubberhose work.

---

## Slice 1 — Fix enemy contact damage (surrounded ⇒ no damage)

**Symptom (playtest):** enemies cluster around the player but deal no contact damage.

**Diagnosis (from code trace).** The enemy-side contact code is unchanged from the pre-V4 (working) build:
`Enemy._attempt_contact_damage` ([Enemy.gd:737](../../scripts/enemies/Enemy.gd)) iterates the
`player_target` group and damages every member in range; `Enemy._find_target`
([Enemy.gd:682](../../scripts/enemies/Enemy.gd)) picks the **nearest** `player_target` as the aggro/movement
target. The V4 change is that **the new deployables now join `player_target`** (via
`DeployableNode.configure_deployable_health` → `add_to_group("player_target")`,
[DeployableNode.gd:14](../../scripts/game/DeployableNode.gd)). So enemies now (a) may pick a deployable as
their nearest target and stop at *its* contact range, and (b) Orbit orbs (which ring the player at ~84px) and
Summons form a wall that keeps enemies outside the *player's* contact range — they surround but never reach you.

**Step 1 — reproduce & confirm** before changing code:
- Play **Mobile** (no deployables) and stand in a swarm → do you take contact damage? Play **Controller** with
  Orbit/Summon/Turret out → same test. Record which case fails.
- If Mobile-with-no-deployables also fails, the cause is elsewhere (instrument
  `Enemy._attempt_contact_damage`: log `_target`, `contact_range`, and whether the player candidate is reached)
  — **do not assume**; find the real cause and note it before fixing.

**Step 2 — fix (decision 2026-07-04: aggro-targeting fix only, NO physical blocking).** The two concerns that
currently share `player_target` get split; **deployables do not obstruct enemy movement** (they're `Node2D`, not
physics bodies, and orbit orbs can't sensibly wall) — enemies simply stop aggroing them. Summons still get
attacked/destroyed as contact-damage targets; they no longer physically hold the line.
- **Aggro / movement target** (`_find_target`) → a **players-only** source (put players in a dedicated `player`
  group, or filter to players). Enemies path to players, **never** to a deployable. *(The old `decoy_taunt`
  taunt source is gone — decoy + its taunt path are removed in Slice 5, so `_find_target` is players-only.)*
- **Contact-damageable set** (`_attempt_contact_damage`) → **players + `player_deployable`** (the group already
  exists, [DeployableNode.gd:14](../../scripts/game/DeployableNode.gd)), so turrets/summons/mines still take
  contact damage and get destroyed.
- **Remove deployables from whatever group `_find_target` reads** (they were pulled into `player_target` by
  `DeployableNode.configure_deployable_health`) so they stop diverting aggro. Confirm nothing else relies on a
  deployable being an aggro target. **No collision / physics-body work.**

**Files:** `scripts/enemies/Enemy.gd` (`_find_target`, `_attempt_contact_damage`, other `player_target` reads),
`scripts/game/DeployableNode.gd` (group membership — aggro vs contact-damage groups), `scripts/player/Player.gd`
(ensure players are in the aggro group), `scripts/game/CoopManager.gd` (`get_player_target_nodes`).
**Acceptance:** in a swarm, an enemy adjacent to the player deals contact damage on its ~0.45s cadence **for
every class**, with and without deployables out; enemies always path to players (a deployable never diverts enemy
movement); deployables still take contact damage and can be destroyed. Add a note to `current-state.md`.

---

## Slice 2 — Control-scheme UI: button remap + in-game HUD + loadout screen

**Problem:** the HUD doesn't read well with the face-button scheme; the loadout screen is clunky (you can't see
which of your 3 abilities you're replacing); and the new passive/ultimate state (heat, overshield, charge) isn't
surfaced.

### ① Button remap — ultimate → **Y** (decision 2026-07-04)
The 4 slots map: **A / X / B = your 3 chosen abilities, Y = the locked ultimate.** (Changes the shipped mapping,
where the ultimate was the 4th button = B.) Update: `scripts/player/Player.gd` `ABILITY_FACE_BUTTONS` (currently
`[A, X, Y, B]`; make the ultimate slot — index 3 — map to **Y** and abilities to A/X/B, i.e. order `[A, X, B, Y]`
so ultimate stays slot index 3 = Y and `_is_ultimate_slot` is unchanged); `project.godot` (swap the
`p%d_ability_3` / `p%d_ability_4` joypad bindings so ability_3 → **B**, ultimate → **Y**);
`scripts/game/GameHud.gd` `HUD_ABILITY_TRIGGERS` `["A","X","Y","B"]` → `["A","X","B","Y"]`; the loadout summary
in `Bootstrap.gd`.

### ② In-game HUD (`GameHud.gd`, `PlayerInventoryHUD.gd`), per player
- 4 slots labelled by the remapped buttons; **the Y slot = ultimate**, rendered distinctly — a charge meter with
  a clear **READY** state, not just a cooldown bar.
- **Ultimate readiness:** combat-charge meter (Mobile/Tank/Controller); **Heat gauge** for Risk. From
  `Player.get_health_state()` (`ultimate`, `heat`).
- **Passive state:** Risk Heat bar (+dmg/+vuln), Tank overshield (health-bar overlay; `overshield` exists),
  Mobile Momentum pips (exist), Controller Radiance indicator (optional).
- **Class readout:** class name + passive on the card, using the **per-class color from `ClassVisuals.gd`**
  (created in this slice — see ④).
- **Files:** `GameHud.gd`, `PlayerInventoryHUD.gd`, `WeaponSlotHUD.gd` (ready/charge variant), `Player.gd`
  (`get_health_state` / per-slot heat/charge fields). Reuse the card UI style [[feedback-card-ui-style]].

### ③ Loadout screen rework (`scripts/ui/Bootstrap.gd`) — fix the clunky picker
Today the 6 abilities are one toggle-grid and picking a 4th **silently drops the oldest** (`_on_ability_card_toggled`
FIFO `pop_front`, ~L1536) — you can't see or choose what you replace. Replace with a **slot-targets + pool** model
(decision 2026-07-04):
- **3 slot cards up top, labelled A / X / B**, each showing its currently-assigned ability, **+ a locked Y =
  Ultimate card.** Below them: the class ability **pool**.
- Interaction: focus/click a slot (it highlights) → pick an ability from the pool → it fills that slot and the
  replaced ability returns to the pool. **Always shows exactly which slot changes — no FIFO surprise.** Works on
  **gamepad + mouse** (d-pad/stick navigate + A to assign; mouse click-slot-then-ability, with optional
  drag-onto-slot for mouse).
- **Also show:** the class's **ultimate + passive** (full kit visible before starting), and style the class/
  ability cards with the **per-class color from `ClassVisuals.gd`** (④) so classes read distinctly here too
  (Slice 4 adds the in-arena silhouettes from the same table).
- Touchpoints: `_build_ability_rows`, `_on_ability_card_toggled`, `_sync_ability_row_buttons`,
  `_get_player_ability_pair`, `_format_ability_card_text`, `_style_loadout_card` (rename the legacy "pair"/2-slot
  naming while here).

### ④ Class-visual data foundation (`ClassVisuals.gd`) — shared with Slice 4 (decision 2026-07-04)
Create a small const table `class_id → { accent_color, silhouette_points, trail_style }` — the single source of
truth for class identity. **This slice defines it and consumes the COLORS** (HUD + loadout styling above).
**Slice 4 consumes the same table's silhouette points + trail styles** for the in-arena body. One source, no
placeholder color, no double-pass over the styling.

**Acceptance:** in-game HUD shows 4 correctly-labelled slots with **Y = a distinct ultimate readiness meter**
(Risk = Heat), Tank overshield + class/passive labelled, at 1P and 2P without overflow; the loadout screen lets
you assign each of the 3 ability slots explicitly (you always see which one changes — no silent replace) and
shows the locked **Y-ultimate + passive + per-class color** (from `ClassVisuals.gd`, created here); the **A/X/B
abilities + Y ultimate** mapping is consistent across input map, in-game HUD, and loadout.

---

## Slice 3 — VFX & animation pass for new weapons, abilities, and ultimates

**Problem:** the new content (Whirlwind, Arc Wand, Flamethrower + the new abilities/ultimates) has weak/
placeholder effects (thin `Line2D`/ring shapes that fade in ~0.1s). Style anchor = the existing **neon-geometric
+ bloom** look. Extend the [`ParticleFactory.gd`](../../scripts/juice/ParticleFactory.gd) vocabulary
(impact_ring, explosion_ring/burst, impact_sparks, dash/attack trails, projectile_trail styles) — **don't rebuild.**

**LOCKED direction (2026-07-04):**
- **Intensity = readable-first, juice the moments.** Per-hit VFX stay restrained (short-lived, **pooled + capped**)
  so a dense screen stays legible and holds 60 fps; concentrate juice on **kills, ability casts, ultimates.**
- **Ultimates = bold but contained** — strong VFX centered on the player/effect, **no full-screen takeover**, so
  2 players ulting at once stays readable.

**New weapons** (`ProjectileSystem._spawn_weapon_arc/_cone/_chain`):
- **Whirlwind (melee):** a **rotating neon crescent** sweeping around the player each swing + short motion-blur
  trail + pooled per-hit sparks. The arc reads as the hit zone. (Replaces the static impact ring.)
- **Arc Wand (chain):** a **jagged forking lightning bolt** between chained targets — zig-zag segments, slight
  flicker, a bright node-flash at each jump, quick fade (cyan). Shows the chain path. (Improve `_spawn_chain_visual`.)
- **Flamethrower (cone):** a **flickering gradient flame-cone polygon** (animated alpha — NOT heavy particles,
  it's sustained and must stay cheap) + heat-shimmer edge + ignite-flash on burning enemies. (Improve `_spawn_weapon_cone`.)

**New abilities** (`CoopManager._on_player_ability_activated`) — signature but restrained (juice = the cast):
fields (Afterburn/Quake) = neon zone-ring + inner pulse; blasts (Ground Slam/Momentum Burst) = expanding ring +
impact flash (Ground Slam heavier + small shake); Deflect = reflect-pulse flashing each erased projectile; bolts
(Sonic Boom/Blood Lance/Fireball) = distinct shaped projectiles + trails + Fireball explosion burst; Summon =
materialize-flash + construct idle glow; Reinforce = repair pulse + heal-glint on deployables; Ignite = embers on
marked enemies.

**Ultimates** (bold but contained): **Slipstream** = player speed-streak aura here; **the world-slow tint + the
dash-recharge flash ship *with* that behavior in Slice 7 (5b), since the world-slow/dash-recharge are authored
there — Slice 3 only does the self-buff aura.** **Blood Frenzy** = red drain-aura ring + life-tendrils
from nearby enemies + heal-glint; **Overload Grid** = grid-pulse burst + constructs materialize with overcharge
glow; **Firestorm** = brief telegraph rings → contained fire-pillar impacts in the ring around the player.

**Files:** `scripts/game/ProjectileSystem.gd` (`_spawn_weapon_arc/_cone/_chain`), `scripts/juice/ParticleFactory.gd`
(extended effects), `scripts/game/CoopManager.gd` (per-ability/ultimate VFX), small new effect nodes under
`scripts/weapons/` or `scripts/juice/` as needed, `scripts/game/CombatEffects.gd` (shared shockwave/zone visuals).
Respect `should_suppress_combat_vfx()` and pool/cap all per-hit effects.
**Acceptance:** each new weapon/ability/ultimate has a distinct, readable neon effect; ultimates feel like a
payoff without full-screen takeover; **PerfRunner stays stable at `--build=heavy --players=2` at the higher enemy
counts** (VFX must not tank frame rate).

---

## Slice 4 — Per-class visual identity (color + silhouette + VFX)

**Problem:** all classes render as the same chevron `Polygon2D` differing only by player tint
([Player.gd:1078 `_apply_visual_state`](../../scripts/player/Player.gd)). Classes must be
distinguishable at a glance. Stay abstract-geometric (no sprites).

**LOCKED identities (2026-07-04) — silhouette + color + static VFX per class:**

| Class | Silhouette (body polygon) | Color scheme | Static VFX signature |
|---|---|---|---|
| **Mobile** | sleek **arrow/dart** (sharp, elongated) | electric **cyan / white** | kinetic cyan movement streaks |
| **Tank** | heavy **hexagon/shield** (broad, armored) | deep **crimson / iron-grey** | weighty crimson movement motes |
| **Controller** | **diamond/rune** with an orbiting node | arcane **violet / teal** | ambient arcane motes |
| **Risk** | jagged **ember shard** (sharp, unstable) | **orange-hot / char-black** | ambient embers + heat-haze |

- **Silhouette:** author a distinct body polygon per `_class_id` (currently all `_chevron_polygon`).
- **Color:** per-class base color **layered under the per-player tint** — different classes read apart by
  silhouette + accent; two players on the *same* class still read apart by tint.
- **VFX signature = STATIC identity only** (movement trail + ambient flavor). **Decision 2026-07-04: the body
  does NOT dynamically react to passive state** — no heat-glow / overshield-shimmer / momentum-brighten /
  radiance-pulse on the body. **Passive state lives on the HUD (Slice 2).** (Radiance's *aura* remains a
  gameplay-area VFX, since it's a spatial buff effect, not body state.)

**Files:** `scripts/player/Player.gd` (`_apply_visual_state`, the polygon/`_chevron_polygon` setup, body/outline/
shadow — pick the polygon + color by class). **Consume `ClassVisuals.gd`** (the `class_id → {silhouette_points,
accent_color, trail_style}` table **created in Slice 2 ④**) — this slice reads its silhouette points + trail
styles for the in-arena body; Slice 2 already used its colors for HUD/loadout. Same single source, no
duplicate table.
**Acceptance:** the 4 classes are instantly distinguishable in-arena by silhouette + color + trail; two players
on the same class stay tint-distinct; the class color matches the HUD + loadout (Slice 2); the body carries **no**
dynamic passive-state VFX (that's HUD-only).

---

## Slice 5 — Retire unused content (full cleanup: data + dead code)

**Goal (decision 2026-07-04: full removal):** delete the retired weapons and unused abilities entirely — data
**and** now-dead code — so nothing stale is loadable, tunable, or documentable. Do this **before** Encyclopedia
(Slice 6) and Balance (Slice 7) so neither documents nor tunes dead content. `ProfileState.UNLOCK_TABLE` is
already clean (verified — the retired entries are gone).

**Remove — data:**
- `data/weapons.json`: **cannon**, **railgun**, **boomerang** (in no class pool).
- **De-dupe `shockwave`:** delete the legacy `weapons.json` shockwave entry (`type:"primary_skill"`, damage 30);
  the ability in `data/abilities.json` (damage 22) is the single source of truth.
- `data/abilities.json`: **blink** (merged into dash), **decoy** (used by no final class).

**Remove — dead code (full removal):**
- **blink** — `scripts/player/Player.gd` charge/teleport/detonate paths (~L407, 425, 519, 554, 575, 816),
  `scripts/game/CoopManager.gd:837` case, `scripts/ui/IconFactory.gd` blink cases. **Verify** the
  `blink_twin_charge` mutation (`data/mutations.json:190`) is re-folded to dash (`requires:["mobility"]`,
  `apply:"ability"`), not pointing at blink; keep it.
- **decoy** — `scripts/game/DecoyNode.gd` (whole node), `CoopManager.gd:842` spawn case + `_active_decoys`,
  `Player.gd:839` case, IconFactory decoy cases, the `decoy_health` key in Radiance's stat loop
  (`CoopManager:476`). **Also remove the taunt path — it is decoy-only (verified):** `_find_taunting_decoy` +
  the `decoy_taunt` group lookup in `Enemy.gd` (~L686-717) and `is_taunting`/`get_taunt_radius`/`taunt_radius`/
  the `decoy_taunt` group in `DecoyNode.gd`. No other mechanic produces a taunt, so it all goes.
- **boomerang** — `scripts/weapons/Projectile.gd` return-arc behavior (~L255, 305, 337, 343, 352),
  `MutationSystem.gd:108` visual case, IconFactory boomerang cases.
- **cannon / railgun** — no code beyond data, except the two `railgun` `icon` refs in `data/mutations.json`
  (L89, 289): retarget those icons to a current weapon/effect.

**Acceptance:** game boots + parses clean; no class pool, encyclopedia, icon lookup, mutation, or enemy-targeting
code references a removed id; a grep for `cannon` / `railgun` / `boomerang` / `"blink"` / `"decoy"` / `taunt`
returns only intentional leftovers (`glass_cannon`, `blink_twin_charge` re-folded to dash); the taunt path is
gone; no dead code paths for removed content remain.

---

## Slice 6 — Encyclopedia update

**Problem:** [`EncyclopediaUI.gd`](../../scripts/ui/EncyclopediaUI.gd) predates the class system and doesn't
document the new content.

**Add/refresh entries for:**
- **Classes (4):** name, role, base stats, passive, ultimate, weapon pool, ability pool — source from
  `RunState.get_class_catalog()` / `get_class_definition()`.
- **Weapons:** the 3 new (Whirlwind/Arc Wand/Flamethrower) + how the retired ones (cannon/railgun/boomerang) are
  gone; note each weapon's tags.
- **Abilities + ultimates:** all new skills and the 4 ultimates, with the ultimate-charge / Heat-gating rule.
- **Passives (4):** Momentum, Bloodthirst, Radiance, Overheat — what each does.
- **Mutations + the tag system:** how upgrades are offered (`requires ⊆ kit tags`) and applied; new/re-folded
  mutations; premium (signature) unlocks.
**Files:** `scripts/ui/EncyclopediaUI.gd`, its data source (pull from the JSON catalogs / RunState getters
rather than hardcoding where possible so it stays in sync), `scripts/ui/Bootstrap.gd` if entry points changed.
**Acceptance:** the encyclopedia lists all 4 classes, every current weapon/ability/ultimate/passive, and
explains the tag/mutation system; no stale references to retired content (cannon/railgun/boomerang, weapon
switching, retired stat-stick mutations).

---

## Slice 7 — Balance pass: full stat audit + retune (faster · density over sponge)

**Problem:** V4 numbers are first-pass placeholders. This is a **concrete stat audit** — go value-by-value
through HP, damage, cooldowns, spawn counts, and set them; not an abstract "measure the feel" pass.

**Core philosophy (LOCKED with the user 2026-07-04):** the game should be **faster**, and **enemies must not be
spongey.** Prefer **many low-HP trash enemies that die in 1–2 hits over a few high-HP sponges.** Density + speed
is the challenge, not per-enemy grind. **Only elites and champions/bosses keep meaty HP** as deliberate,
readable threats. Every stat below is set to serve this + the outcome targets in Step A.

**Difficulty-scaling model (LOCKED with the user 2026-07-04):** **power fantasy / density.** Trash HP is **flat
across the run** (no depth HP scaling for trash) and low; leveling your weapon makes you shred faster and faster.
**The escalating challenge is DENSITY + elites/champions, not trash toughness** — more enemies and more/bigger
elites the deeper you go. NB: today trash already has no depth HP scaling (only a 0.5× "swarm"-room multiplier);
this model keeps it that way and instead ramps `WaveDirector` spawn counts + elite frequency with depth.
- **Weapon level curve — FLATTEN to ~+15–20% per level** (was ~+25–30%, e.g. rifle 10→13→17→21→25). Smaller,
  steadier per-level gains so one level-up doesn't cliff the balance; applied to every weapon in §Weapons.
- **Trash HP anchor:** set so basic trash survives **~3 hits at base weapon L1** (headroom for leveling) and
  **~1–2 hits by L5** — fast, but leveling visibly matters. Flat HP, so the L5 speed-up is the power fantasy.

**Current-state audit — actual values + flagged imbalances (2026-07-04, read from the data files):**
- **Weapon single-target DPS (L1→L5):** rifle 65→192 · scattergun ~106→211 · beam 110→185 (ramped) · rocket
  64→160 (+AOE) · arc_wand 61→129 (+chains) · whirlwind 48→106 per-target (AOE all-adjacent) · flamethrower
  56→104 per-target (AOE cone + burn). The 3 new AOE weapons are **~half** rifle/scattergun single-target —
  acceptable vs crowds (suits the many-enemies direction) but weak 1-v-1; confirm their AOE reliably hits
  multiple trash so they pull their weight.
- **Trash TTK:** rifle L1 (65 DPS) kills a 30-HP chaser in ~3 shots (~0.46s). Fix by **cutting trash HP** (not
  inflating weapons) — **see the LOCKED values in Step B item 1** (chaser 30→**24**, ~3 hits at L1 → ~1–2 by L5,
  per the "survive a bit at L1" decision). *(Supersedes an earlier draft note that said chaser →15–18.)*
- **⚠ Ultimate power is uneven.** Slipstream (Mobile) is only **+12% damage** / +35% atk / +55% move, while
  Blood Frenzy is **+28% dmg / +35% atk / +35 heal** and Firestorm / Overload Grid are big AOE / summon bursts.
  Mobile's ultimate won't feel like a payoff — raise Slipstream (higher damage mult and/or an offensive
  component) so the 4 ultimates are roughly equal-impact.
- **Class durability — DECISION (2026-07-04): keep Tank tanky, ease Risk.** Raw HP is 90 / 100 / 110 / **150**
  (Tank ~67% above Risk). **Keep the spread** — Tank ~150 stays a genuine tank; the wide durability lead is
  intentional. **But soften Overheat's vulnerability** so Risk (90 HP) isn't one-shot: `Player.gd`
  `OVERHEAT_VULNERABILITY_PER_HEAT` is currently `0.005` (= **+50% damage taken at max heat** → effective ~60
  HP → downed in ~1.5–2s). Lower it so a max-heat Risk still survives **~3–5s** in a surround (per the Lethality
  target) — Risk stays glassy, not instant-death. The "~20–30% moderate delta" applies to **damage output**,
  not durability.
- **Deployable damage is lopsided:** turret 18 × 4.5/s = **~81 DPS persistent** (+Radiance ×1.2) ≈ a whole
  extra weapon, vs orbit **9 dmg** (weak) and summon construct ~51 DPS. Even out the deployable DPS band.
- **Data hygiene → fully handled in Slice 5 (Cleanup):** retired cannon/railgun/boomerang, unused blink/decoy,
  and the duplicated shockwave are all removed there (data + dead code). The balance pass **assumes they're
  gone** — do not tune retired content.

**Step A — targets (LOCKED 2026-07-04 with the user; tune the Step-B stats to hit these, don't re-derive them):**
- **Combat pace — FAST / FLUID.** A basic chaser dies in **~3 hits at rifle L1 → ~1–2 by L5** (flat HP;
  leveling speeds you up — see the Difficulty-scaling model above). Throughput/density is the challenge, not
  per-enemy grind; elites/champions stay meaty. Weapon L5 + stacked tags sharply raises clear speed (design's
  bounded-power model: clears the room-10 milestone; endless out-scales).
- **Ultimate cadence — FREQUENT (~1 per room).** In normal combat the ultimate charges to full about **once per
  room**. Tune `UltimateCharge.KILL_CHARGE` / `DAMAGE_CHARGE_RATE` so ~one room of kills+damage = 1.0 charge;
  tune Risk's `OVERHEAT_ULTIMATE_HEAT_THRESHOLD` so Firestorm is ready ~once per room of ability casting.
- **Lethality — MODERATE.** A full surround of basic enemies downs a baseline 100-HP class in **~3–5s** with no
  mitigation active. ⚠ Depends on Slice 1: once contact damage is restored it will likely be **too** lethal at
  current `contact_damage` values — retune enemy contact damage and/or how many enemies reach contact range to
  land in the 3–5s band.
- **Class deltas — MODERATE (~20–30%) on DAMAGE OUTPUT; durability is intentionally wider on the Tank end
  (decision 2026-07-04).** Damage output stays within ~20–30% across classes (Risk highest, at the cost of
  fragility). **Durability is deliberately asymmetric:** Tank ~150 HP + Bloodthirst is a real tank (large lead);
  Risk ~90 HP stays glassy but Overheat vulnerability is softened so it survives ~3–5s in a surround (not
  one-shot); Controller/Mobile near baseline. **No class clears the room-10 milestone more than ~25% faster/
  slower than another** (parity check — no class trivially dominant or unviable).
- **Passive feel (sized to the deltas above):** Overheat ramp/decay + dmg/vuln coefficients sized to the Risk
  delta; Bloodthirst heal-per-kill + overshield cap/decay sized to the Tank delta; Radiance buff magnitudes and
  Momentum ramp tuned so Controller/Mobile stay near baseline.

**Step B — the stat audit (set every value; the first two levers carry the "faster / less spongey" feel):**
1. **Enemy HP per tier — the sponginess dial** *(primary lever).* Set trash `max_health` per-type in
   `scripts/enemies/Enemy.gd._configure_type` (`data/enemies.json` is empty — the `.gd` blocks are the source).
   **LOCKED values (2026-07-04):** chaser 30→**24**, charger 52→**36**, spitter 15→**14**, splitter 25→**22**,
   splitter_mini 8→**7**, bomber 30→**20**; elites light trim — elite_charger 500→**460**, elite_spitter
   380→**360**, elite_support 440→**400**; **bosses (800–1000) unchanged.** HP is **flat all run** — no depth
   `health_mult` for trash (keep only the existing 0.5× "swarm"-room mult). Anchor: ~3 hits at rifle L1 → ~1–2
   by L5. The difficulty ramp is density + elites (item 2), never trash HP.
2. **Spawn density / rate — the "more enemies" dial** *(primary lever — THE difficulty ramp, since trash HP is
   flat).* `scripts/game/WaveDirector.gd`: `_spawn_interval` (1.6s → **~1.1s**), opening burst size
   (`spawn_opening_burst` / `_scale_spawn_count`, ×**~1.4**), continuous-spawn rate/count, **and elite frequency
   — all scaling UP with room depth.** Lower HP is offset by more bodies; deeper rooms get harder via numbers +
   elites, not tankier trash. ⚠ **Respect the perf ceiling** (~200 enemies+projectiles → ~60 FPS; see
   solo-dev-rules §Performance) — validate every density bump with PerfRunner `--build=heavy --players=2`
   (lower HP = faster deaths, so concurrent count stays bounded).
3. **Enemy damage.** `Enemy.gd` per-type `contact_damage` + `projectile_damage`. **LOCKED starting values
   (2026-07-04, playtest-tuned to the ~3–5s surround-to-down target):** chaser 12→**6**, charger 20→**10**,
   spitter 6→**4**, splitter 8→**5**, splitter_mini 6→**4**, bomber **5** (unchanged — its blast is the threat);
   elites 28/12/10→**18/8/7**; bosses 35→**28**. ⚠ Coupled to Slice 1 — these only bite once contact damage is
   restored, so confirm the final feel in playtest.
4. **Weapons — `data/weapons.json` — LOCKED curves (2026-07-04; flattened to ~+15–20%/level; L1 kills a 24-HP
   chaser in ~3 hits → ~1–2 by L5; AOE weapons trade single-target DPS for crowd coverage):**
   - **rifle** — `damage` [10,12,14,16,19], `fire_rate` [6.5,6.6,6.8,7.0,7.2] → 65→137 DPS (top single-target).
   - **beam** — `max_damage_per_second` [100,115,130,148,168] (ramp 1.8s / start 0.25 unchanged) → ~70→168.
   - **scattergun** — `damage` per_level [12,13,14,16,18], `pellet_count` [5,6,7,8,9], `spread_degrees`
     [11,10,9,8,7], fire_rate 2.2 → close burst (one-shots trash), weak at range.
   - **whirlwind** — `damage` [20,23,27,31,36], fire_rate 2.2, hits all adjacent → 44→79/target (AOE).
   - **arc_wand** — `damage` [18,21,24,28,33], `chain_count` [3,3,4,4,5] (falloff 0.82) → 61→112 first + chains.
   - **flamethrower** — `damage` [7,8,9,11,13], fire_rate 8, burn 4 dps/1.2s, cone → 56→104/target + burn.
   - **rocket** — `damage` [40,46,54,62,72], fire_rate 1.6, blast 0.9 → 64→115 direct + splash.
   Risk's flamethrower/rocket also get the Overheat damage bonus → highest effective DPS (glass cannon); all
   land within the ~20–30% damage-delta band.
5. **Abilities — `data/abilities.json` — LOCKED changes (2026-07-04):** shockwave 22→**28** (was below the 24
   trash-HP floor), momentum_burst base 24→**28**, orbit 9→**14** (was far weaker than other deployables),
   turret 18→**16** (~72 DPS; trimmed now that enemies destroy deployables + Radiance ×1.2), afterburn tick
   9→**10**, quake tick 10→**12**. **Keep as-is:** ground_slam, fireball, blood_lance, sonic_boom, ignite,
   minefield, summon, reinforce, deflect, shield, dash. **Watch-item (unchanged):** overcharge CD 12 / dur 6 =
   50% uptime — re-check in playtest. Ultimate params: see item 5b.
5b. **Ultimates — `data/abilities.json` + `CoopManager` activation — LOCKED (2026-07-04). Power bar =
   "momentum swing": strong enough to turn a fight, NOT auto-win a room; tune all four to that.**
   - **Slipstream (Mobile)** — rebuild the control fantasy (lighter variant, no damaging wake): keep self move
     ×1.55 / attack ×1.35, **raise damage ×1.12 → ~1.3**, **add a world-slow** on all enemies + their
     projectiles (~50–60% for the 5s duration, **co-op-friendly — allies unaffected**), and **instant dash
     recharge** during the ult. The current build ships only the self-buff + a one-time deflect; the slow +
     dash-recharge are the missing pieces. **Author the matching world-slow tint + dash-recharge VFX here too**
     (Slice 3 only did the self-buff aura).
   - **Blood Frenzy (Tank)** — keep flat **+35 heal** + buff (attack ×1.35, damage ×1.28); tune to the swing bar.
   - **Overload Grid (Controller)** — keep (repair + overcharged constructs); tune to the swing bar.
   - **Firestorm (Risk)** — keep the ring of burning zones; tune tick damage so it meaningfully clears trash over
     its duration, at the swing bar.
6. **Ultimate charge — `scripts/game/UltimateCharge.gd`.** `KILL_CHARGE` / `DAMAGE_CHARGE_RATE` + Risk
   `OVERHEAT_ULTIMATE_HEAT_THRESHOLD` → ~1 ult per room. ⚠ With more low-HP kills the meter fills faster — keep
   it ~1/room, not constant.
7. **Classes — `data/classes.json`.** HP (90/100/110/150) + move_speed. **Decision 2026-07-04: keep the wide
   HP spread** (Tank ~150 stays a real tank); the ~20–30% "moderate delta" is on **damage output**, not
   durability. Pair with item 8 (soften Overheat vulnerability so Risk isn't one-shot).
8. **Passive constants — LOCKED (2026-07-04):**
   - **Overheat (Risk) — `scripts/player/Player.gd`:** keep **+60% damage dealt at max heat**
     (`OVERHEAT_DAMAGE_PER_HEAT` = 0.006); **halve the damage-taken penalty to ~+25% at max**
     (`OVERHEAT_VULNERABILITY_PER_HEAT` 0.005 → **0.0025**) so Risk survives the ~3–5s target while staying the
     glassiest. Keep +12 heat/cast, decay 14/s; revisit the ult threshold (70) against the ~1/room cadence in
     playtest.
   - **Bloodthirst (Tank) — `scripts/game/CoopManager.gd` `_apply_bloodthirst_on_kill`:** **lower heal-per-kill
     8 → ~5** (density = many more kills, so flat 8/kill would over-sustain); keep overshield cap 65% max HP +
     decay 5/s; rescale the Gorge (+heal) / Overflow (overshield) mutation bonuses to the new base.
   - **Momentum (Mobile) / Radiance (Controller):** keep near baseline; re-verify Radiance's deployable buffs
     (+dmg / +HP / +fire-rate) read right after the turret 18→16 / orbit 9→14 changes.
9. **Mutations — `data/mutations.json` — LOCKED direction (2026-07-04):**
   - **Mutations carry the build spike.** Weapons scale flatter now, so mutations are the top-end power — keep,
     and where needed slightly boost, the damage-amp multipliers (shattering ×1.4, blue_flame/thermal_surge
     ×1.25, inferno ×1.35, backdraft ×1.2) and the tag-stacking signatures (accelerant/virulent ×2, pyromaniac
     fire ×3) so a fully-stacked build still ramps hard (preserves the "weapon L5 + tags clears room 10" target).
   - **Elements = strong single-target DoT** — keep poison 5 dps/3s, fire-pool 40%, frost slow, burn multipliers
     potent. This is the answer to the **meaty elites/champions** (which keep HP): fast weapons handle trash, DoT
     chews elites. On-death spreads (ember_spread, cryo_shatter, chain_reaction) stay **secondary**, not the focus.
   - **Parasites stay swingy:** glass_cannon (+80% dmg / −40% HP) and pyromaniac (fire ×3, no heal) unchanged —
     opt-in premium extremes.
   - Most other mutations are **behavioral** (pierce / split / chain / slow / execute / extra-deployables) — no
     number tuning; just verify they still fire correctly after the weapon / ability / deployable changes.

**Step C — measure & document.** Use `scripts/dev/PerfRunner.gd` scenarios + manual playtest, per class. Record
a **stat table in `current-state.md`** with before→after for every tier/weapon/ability/class touched, plus the
measured result.
**Acceptance:** basic trash dies in **~3 base-weapon hits at L1 → ~1–2 by L5** and arrives in **greater numbers**
that scale with depth (HP flat + low, density up) while elites/champions still feel meaty; the locked targets
hold for **all 4 classes** (fast pace, ~1 ult/room, ~3–5s surround-to-down, ~20–30% damage deltas, ≤25% class
clear-time spread); PerfRunner stays stable at the higher enemy counts; the stat table is documented.

---

## Cross-cutting notes
- Keep art abstract-geometric; the sprite/rubberhose pass remains deferred (design spec §3).
- Reuse existing systems (ParticleFactory, CombatEffects, the card UI style [[feedback-card-ui-style]]) — extend,
  don't rebuild.
- Validate + commit per slice; the `D:/GameDev/Project_Twin_stick` tree stays the untouched v3 playtest baseline.
- Suggested order is dependency-first: **bug → UI (HUD + loadout + Y-remap) → VFX → identity → cleanup →
  encyclopedia → balance** (cleanup before encyclopedia + balance so neither documents/tunes retired content;
  balance last, so it retunes working, readable systems). Note: Slice 2 creates the shared `ClassVisuals.gd`
  table (colors + silhouettes) and uses its colors; Slice 4 reuses the same table for the in-arena bodies — so 2
  and 4 share one source with no ordering dependency or placeholder.
