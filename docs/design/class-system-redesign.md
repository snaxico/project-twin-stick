# Class-Based Redesign — Design Doc (next version)

> **Status:** Design complete, no implementation started. This is the review-ready spec.
> **Companion data:** [`class-design.xlsx`](class-design.xlsx) (Kits / Mutations / Reference tabs) is the
> live data table; this doc is the prose spec. Both are kept in sync.
> **Next step:** review this doc, then produce a Codex-ready implementation plan (see §8, §9).

---

## 1. Why this redesign

The current build is a competent ~5/10 that "feels made by AI" because it's the *average* of its inspirations
(Brotato build-craft + roguelite room-choice + Geometry Wars twin-stick) and commits to none. The fix is a
sharp identity: **a class-based twin-stick arena roguelite** — "Hades/Gauntlet in an arena" — built on the
existing weapon/ability/mutation foundations. You pick a **class** with a distinct fantasy, fight arena
waves with a real **ability kit**, and upgrade via **transformative mutations** (no filler stats).

The core run loop (pick a room → wave → reward → repeat, bounded by a room-10 milestone + optional endless)
stays; classes + a deeper kit + a real mutation system are what add the missing depth.

---

## 2. Core structure & global rules

- **Kit = 1 weapon + 4 ability slots** (3 chosen abilities + the auto-equipped ultimate), mapped to the four
  controller **face buttons** (Xbox **A / X / Y / B**, PlayStation **✕ / □ / △ / ○**); sticks = move/aim, the
  weapon **auto-fires**. Grows from today's 2 ability slots.
- **Per class:** 2 weapons (equip 1) · 6 skills (equip 3) · 1 **ultimate** (auto-equipped locked slot) ·
  1 passive. Rule: every class has **≥2 weapons, 1 ultimate, ≥6 abilities**.
- **Dash is the universal mobility hub** — every class can take it; its variants (Blitz charge-through,
  Phantom decoy, Shockdash, Twin Charge, Phase) are **mutations, not separate skills**.
- **Ultimate charge:** a unified combat meter (damage dealt + kills) for Mobile/Tank/Controller; **Risk's
  ultimate is gated by its Heat** instead.
- **All summons & deployables are persistent and have HP** — they exist until *destroyed*, never on a timer.
  (Turrets, mines, orbs, constructs, summons.)
- **One active weapon per run**, chosen at loadout from the class's weapon pool — **no in-run weapon switching
  in V4** (the face buttons carry abilities, not a weapon swap). The weapon still shares its level 1-5 progression.
- **Weapon roster (7):** base — rifle *(railgun merged in; pierce is now a mutation)*, shotgun, rocket, beam;
  new — Whirlwind (Tank melee), Arc Wand (Controller chain), Flamethrower (Risk cone). **Retired:** railgun
  (merged into rifle), boomerang (dropped), **cannon** (too similar to rocket). Every weapon has a class home.
- **Players: 1-2 in V4.** All 4 classes are selectable (the roster is 4 classes), but simultaneous play is
  capped at 2 for V4; wider co-op (3-4P) is deferred to a later pass.
- **Bosses stay as "champions"** (folded into waves) for now — diagnosis parked (they failed by being
  dropped into swarms; fix later = separate the boss from the swarm + threat via patterns not HP).

---

## 3. Art direction

- **Identity lives in color + VFX + silhouette**, not gear detail — reads in the current art and survives
  the art transition. Theme is **magic + medieval fantasy** (arcane/elemental), classes span
  martial↔magical, but expressed through *effects*, not equipment.
- **Now:** keep the current **abstract-geometric** style. **Later:** move to **billboard top-down**
  (Brotato/VS-style — top-down field + front-facing 2D sprites) which enables **rubberhose** characters.
- The art swap is a **presentation-layer change with no gameplay rework** — swap the visual node, stop
  rotating the body, add a rotating weapon/reticle. **No art or code change needed now; design art-agnostic.**
  Guardrail: define directional mechanics by the **aim/velocity vector**, never the visual body rotation.

---

## 4. Mutation & tag system

Build diversity comes from **mutations** that transform weapons/skills/passives (not bespoke per-skill trees,
not filler stats). The **tag system's job is compatibility gating** — never offer a mutation that can't buff
anything in your kit (no "dead" drops). It is *not* for build-synergy/balance.

### One universal rule
- Every **weapon, ability, and the class** carries **tags** (a flat namespace).
- Your **kit's tag set** = union of tags from your equipped weapon + 3 abilities + ultimate + passive + class.
- Every **mutation** declares `requires: [tags]`. A mutation is **offered ⟺ `requires ⊆ kit's tag set`.**
  That's the whole gating system — one rule. (This *generalizes* the existing `requires_ability` into
  `requires` over the tag namespace; class and function all live in the same tag space.)
- **Specificity via combinations, not item-ids:** broad = few tags (`[summon]` → all placed units); narrow =
  more tags (`[blast, tank]` → Tank's AOE bursts). If a true one-off is ever needed, give that one item a
  deliberate unique tag — no auto item-ids.
- **Expandable:** add an item with the right tags → it inherits every compatible mutation; add a mutation →
  it applies to every matching item, present and future.

### The tag vocabulary (17, needs-driven — every tag is targeted by a mutation)
| Kind | Tags |
|---|---|
| **class** | `mobile` · `tank` · `controller` · `risk` |
| **weapon delivery** | `projectile` · `beam` · `melee` · `cone` · `chain` |
| **ability kind** | `mobility` · `summon` *(all placed persistent units — turrets, mines, orbit, constructs)* · `blast` (instant AOE) · `field` (lingering zone) · `bolt` (ability projectile) · `buff` · `defense` |
| **effect** | `dot` |
| **weapon (implicit)** | any weapon is a valid element target (elements apply to all) |

*Item tagging (samples):* rifle/shotgun/rocket = `projectile`; beam = `beam`; Whirlwind = `melee`; Arc Wand
= `chain`; Flamethrower = `cone`. Dash = `mobility`; Turret/Minefield/Orbit/Summon = `summon`;
Shockwave/Ground Slam/Momentum Burst = `blast`; Afterburn/Quake = `field`; Blood Lance/Sonic Boom = `bolt`;
Fireball = `bolt, blast, dot`; Ignite = `dot`; Overcharge/Reinforce = `buff`; Shield/Deflect = `defense`.

### Mutation examples
- Piercing Rounds `[projectile]` → not offered on beam/cone/melee/chain.
- Overgrowth `[summon]` → only with a placed unit equipped.
- Executioner `[blast]` → all your AOE bursts execute low-HP enemies.
- Combustion `[risk]` · Bloodshot (class-spin on shared shotgun) `[projectile, tank]`.

### Reuse / Adjust / Add vs. current code
| | Reuse | Adjust | Add |
|---|---|---|---|
| **Targeting** | the `requires_ability` mechanism | generalize → `requires: [tags]` over one namespace | tags on weapons/abilities/class |
| **Mutations** | weapon-effects (fire/frost/toxic/split), the **9 ability-rares**, rarity tiers | retire the 4 pure weapon stat-sticks | per-class mutation sets |

**Old universal mutations are NOT removed — they re-fold as universal, tag-targeted mutations:** Shockdash/
Twin Charge → `[mobility]`; Twin Turret/Extra Mines/Expanding Orbit → `[summon]`; Shockwave Resonance →
`[blast]`; Aegis Burst → `[defense]`; Piercing Overdrive → `[buff]`; Fire/Frost/Toxic/Split → any weapon,
Pierce/Split → `[projectile]`. *(Volatile Decoy dropped — decoy isn't in any final kit.)*

- **Power model = bounded:** weapon level 1-5 + finite behavioral upgrades clears the room-10 milestone;
  endless intentionally out-scales you. No filler stat picks.
- **Stat-stick retirement:** cut the 4 pure weapon stats (rapid_fire/velocity/high_caliber/range); keep
  move_speed/tough/quick_reflexes/wide_pulse/duration (fix `quick_reflexes` for Risk — no cooldowns).

---

## 5. Meta / loadout / unlocks

- **Loadout (per player, 1-2 in V4):** pick **class** → **weapon** (from class pool) → **3 abilities** (from
  class pool); the **ultimate auto-equips**. Upgrades/mutations are in-run, not loadout. **Same class allowed** for
  multiple players.
- **Unlocks (`ProfileState`):** **all 4 classes + their full base kits + base mutations are FREE** from the
  start. Meta = build *depth*, not access. Banked score unlocks **premium build content** (via
  `UNLOCK_TABLE` costs):
  - **Universal element signatures** — powerful element-build amps shared across all classes (reuse the
    existing signatures: Accelerant/fire, Virulent/toxic, Cryo Shatter/frost, Chain Reaction/split, Ember
    Spread, Momentum Surge, …). Unlocking these enables *deep* element builds.
  - **Per-class signature mutations** — 1-2 top-tier, build-defining mutations per class (the strongest
    version of that class's fantasy), unlocked to deepen that class specifically.
  - **Parasites** — high-risk/high-reward mutations with a downside (e.g. Glass Cannon: big damage, low HP;
    Pyromaniac: fire surge but no healing). Powerful picks that cost you something.
  - These *add to your in-run mutation pool once owned* — they don't gate the base game. Same-class allowed
    for multiple players.

---

## 6. The four classes

Reflavoring note: names/flavor are working titles; the *mechanics* are the spec.

### 6.1 Mobile — Kinetic (baseline)
*Fast, aggressive kiter; movement is power. No element — pure kinetic.* **HP 100 / Speed 560.**
- **Passive — Momentum** *(reuse MomentumTracker, now class-exclusive):* moving + dodging cleanly builds
  Momentum tiers (→ +fire-rate & +damage); a damaging hit drops 2 tiers.
- **Ultimate — Slipstream:** ~5s — slow all enemies + their projectiles while you're boosted (move + fire),
  instant dash recharge, and a damaging wake. *Co-op-friendly (slows enemies, doesn't warp allies).*
- **Weapons:** rifle · beam.
- **Skills (6):** Dash (mobility hub) · Shockwave (AOE knockback + clears projectiles) · **Afterburn** ⭐
  (activate → ~4s your movement leaves a *lingering* damaging trail the chasing swarm runs into) ·
  **Momentum Burst** (a burst that *scales with* current Momentum, no consume) · **Deflect** (briefly
  reflect enemy projectiles) · **Sonic Boom** (fast kinetic wave that pierces a line).
- **Mutations:** *(universal: elements + dash-hub Blitz/Phantom/Shockdash/Twin Charge/Phase)* +
  *class — Momentum:* Overclocked (higher max tier) / Flow State (hits drop 1 tier not 2) / Kinetic Charge
  (build faster) / Peak Pierce (at max Momentum, shots pierce); *class — skills:* Vampiric Wake (Afterburn
  heals) / Implosion (Momentum Burst pulls in) / Resonance (Sonic Boom bounces).
- **Signature build axes:** dash-builds (mobility) and Momentum-builds (runaway damage snowball).

### 6.2 Tank — Blood / Juggernaut
*Durable AND hard-hitting, slow; sustains by clearing the swarm.* **HP 150 / Speed 480.**
- **Passive — Bloodthirst:** heal a **flat amount of HP per kill**; overheal (killing at full HP) banks a
  **decaying overshield**; ~no passive regen. Vulnerability: tough enemies give no heal until they die.
- **Ultimate — Blood Frenzy:** ~5s — a drain aura heals you off nearby enemies (stronger the more surround
  you) + all weapons gain lifesteal + near-unkillable in the crowd.
- **Weapons:** shotgun · **Whirlwind** *(NEW melee: auto-swings, hits ALL adjacent enemies each tick —
  max value when surrounded)*.
- **Skills (6):** Dash · **Ground Slam** (AOE burst + stun, no knockback) · **Quake** (lingering slow field) ·
  Orbit *(reuse — spinning guard: blocks projectiles + damages adjacent)* · Overcharge *(reuse — attack-speed
  surge → more kills → more heal)* · **Blood Lance** (ranged piercing line — its answer to ranged/kiting
  enemies).
- **Mutations:** *Bloodthirst:* **Gorge** (flat +heal/kill) / **Overflow** (kill-at-full → bigger
  overshield); *Ground Slam:* **Executioner** (instantly kills normal enemies <20% HP in radius; champions
  immune); *Quake:* **Shattering Quake** (enemies in field take ~+40% damage); *Blood Lance:* **Bloodletting**
  (stacking bleed DoT); *Whirlwind:* **Wide Cyclone** (bigger radius). *(Shotgun class-spin "Bloodshot" —
  optional.)*
- **Identity note:** for a lifesteal tank, **offense is defense** — it survives by fighting harder, with one
  reactive defensive option (Orbit). On-kill lifesteal makes tough enemies its danger window.

### 6.3 Controller — Arcane / deployables-summoner
*Fights through a field of deployables; controls the arena.* **HP 110 / Speed 520.**
- **Passive — Radiance:** your deployables are **always** empowered (+damage & +survivability — keeps the
  persistent army alive), and you project an **aura** that gives nearby allies + self +damage.
- **Ultimate — Overload Grid:** ~5s — all your active deployables are **supercharged + duplicated**; scales
  with how much you've built up (set your field, then unleash it).
- **Weapons:** beam · **Arc Wand** *(NEW: chain-lightning, bolts arc between multiple enemies)*.
- **Skills (6):** Dash · Turret *(reuse — auto-firing sentry)* · Minefield *(reuse — mines/traps)* · Orbit
  *(reuse — arcane orbs)* · **Summon** (2-3 **persistent melee constructs** that charge enemies and
  **body-block the swarm** for the fragile caster) · **Reinforce** (heal/restore all deployables + summons —
  keep the army alive for sustained DPS).
- **Mutations:** *Radiance:* **Overgrowth** (raise deployable cap) / **Empowerment** (deployables +attack
  speed) / **Beacon** (deployables pulse small AOE); *Summon:* **Legion** (extra construct); *Reinforce:*
  **Aegis** (Reinforced deployables gain a shield); *Arc Wand:* **Static Field** (hits briefly slow/stun).
- **Design note:** Detonate (blow up your own deployables) was rejected — it sacrifices your DPS sources,
  against the identity; Reinforce (sustain the army) replaced it.

### 6.4 Risk — Ember / glass-cannon
*Fragile, aggressive, plays with fire; reckless caster who rides the heat.* **HP 90 / Speed 560.**
- **Passive — Overheat:** abilities have only a **0.5s cooldown** (no long cooldowns) — you cast constantly;
  each cast builds **Heat** → **+damage dealt AND +damage taken** (glassier); heat **decays when idle**.
  Push-your-luck, no meter to babysit. *(All abilities build heat — including Dash: even escaping raises
  your stakes, by design.)*
- **Ultimate — Firestorm:** ~5s — rain of fire over a large area (centered on you), heavy AOE + burning
  ground. A wide-area delete button (clearing = survival for a glass-cannon).
- **Weapons:** **Flamethrower** *(NEW: close-range fire cone, huge DPS but forces dangerous positioning)* ·
  rocket.
- **Skills (6):** Dash · Overcharge *(reuse — fire-rate steroid)* · Shockwave *(reuse — AOE knockback +
  clear; the "get off me")* · Shield *(reuse — panic block: all damage blocked briefly, can't attack)* +
  **Fireball** (lobbed explosive + leaves burning ground) + **Ignite** (burning DoT that **spreads on
  death** — a chain reaction through the swarm).
- **Mutations:** *Overheat:* **Combustion** (at high heat, attacks also ignite) / **Thermal Surge** (heat
  boosts ability damage too); *Fireball:* **Napalm** (bigger/longer burning patch) / **Chain Explosion**
  (kills explode); *Ignite:* **Backdraft** (burning enemies take increased damage) / **Inferno** (stronger
  burn DoT); *Flamethrower:* **Longer Reach** (safer range) / **Blue Flame** (more damage).

---

## 7. New content to author (inventory)

- **3 new weapons:** Whirlwind (melee, hits-all-adjacent) · Arc Wand (chain-lightning) · Flamethrower (cone).
  Each needs a new `projectile_kind`/attack type in the projectile/weapon path.
- **New skills (~10):** Mobile — Afterburn, Momentum Burst, Deflect, Sonic Boom; Tank — Ground Slam, Quake,
  Blood Lance; Controller — Summon, Reinforce; Risk — Fireball, Ignite. *(Dash/Shockwave/Overcharge/Orbit/
  Shield/Turret/Minefield are reused.)*
- **4 ultimates:** Slipstream, Blood Frenzy, Overload Grid, Firestorm.
- **New passive systems:** Bloodthirst (on-kill heal + overshield), Radiance (deployable/aura buffs),
  Overheat (heat resource + damage/vulnerability + 0.5s CD model). Momentum is reused (made exclusive).
- **Mutations:** per-class sets listed in §6 + the universal element/dash-hub sets. Retire 4 stat-sticks.
- **Global:** make all deployables persistent + HP; expand kit to 4 slots; class data model + loadout UI.

---

## 8. Implementation touchpoints (for the plan)

Key existing files to modify (from codebase review):
- **Kit expansion 2→4 slots:** `scripts/player/Player.gd` (ability slot array is hardcoded to 2, `_is_ability_pressed`
  uses `p%d_secondary`/`p%d_dash`), the input map (add the 4 **face-button** actions A/X/Y/B; remove the
  weapon-switch actions — one weapon per run), `scripts/player/PlayerConfig.gd`.
- **Class data model + loadout:** `scripts/game/RunState.gd` + `scripts/game/PlayerInventory.gd` (add class,
  weapon+3 abilities selection); loadout/class-select UI in `scripts/ui/Bootstrap.gd`.
- **Abilities:** `scripts/game/AbilityRegistry.gd` + `data/abilities.json` (add the new skills).
- **Weapons:** `RunState._load_weapons` + `data/weapons.json`; new `projectile_kind` handling in
  `scripts/game/ProjectileSystem.gd` + `MutationSystem.get_base_projectile_visual`.
- **Mutations/tags:** `scripts/game/MutationSystem.gd` + `data/mutations.json` (add scope/class + tag-target
  fields; tags on weapons/abilities; retire stat-sticks; per-class sets).
- **Passives:** reuse `scripts/game/MomentumTracker.gd` (Mobile, make exclusive); new systems for
  lifesteal-on-kill + overshield (Tank), Radiance aura (Controller), Heat (Risk).
- **Deployables persistence + HP:** `TurretNode.gd`, `OrbitNode.gd`, `DecoyNode.gd`, `AbilityMine.gd`
  (the player Minefield ability — not the `MineFieldModifier.gd` arena hazard) + new Summon (pet AI). New:
  Whirlwind/Flamethrower/Arc Wand weapon behaviors.
- **Meta:** `scripts/meta/ProfileState.gd` UNLOCK_TABLE (classes free; premium content only).

Candidate slice order: **kit expansion 2→4 (+input/HUD)** → **class data model + loadout/class-select UI** →
**per-class content (weapons/skills/passives)** → **mutation-system rework + tags** → **meta/unlocks**.
Each an independently built + validated vertical slice per the solo-dev rules.

---

## 9. Open items (before/during implementation)

- **Universal mutation lists** — flesh the full shared pools (element effects + amps, all dash-hub variants).
- **Tuning numbers** — heat build/decay rates + damage curve, heal-per-kill, Momentum tier values, radii,
  durations, deployable HP, ultimate charge rates. All placeholders in the design.
- **Art perspective** — when/whether to move to billboard rubberhose (a separate future track).
- **Bosses** — the "separate from swarm" rework, deferred.

---

## 10. Source of truth

The full per-class data grid + every mutation lives in [`class-design.xlsx`](class-design.xlsx):
- **Kits** tab — rows = kit slots (passive/stats/ultimate/weapons/skills), columns = the 4 classes.
- **Mutations** tab — every mutation with scope / target / effect / status.
- **Reference** tab — base behaviors of all weapons & skills.
