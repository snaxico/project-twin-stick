# V4 Class System — Implementation Plan (Codex-ready)

> **Design source of truth:** [`docs/design/class-system-redesign.md`](../design/class-system-redesign.md) —
> the **authoritative prose spec** (all class kits + mutations are in §6). The companion
> [`class-design.xlsx`](../design/class-design.xlsx) is a **human-only** data grid (binary — do NOT use it as
> an implementation source). Read the `.md`; this plan is the *build* order.
> **Branch/worktree:** implement on `v4/class-system` in the `Project_Twin_stick_v4` worktree. The original
> `D:/GameDev/Project_Twin_stick` tree stays the untouched **playtest v3 build** for A/B testing.

## How to work this plan
- **One vertical slice at a time**, in the order below (dependency-ordered). Each slice must leave the game
  **runnable** and pass the validation gate before moving on. Commit per slice.
- **One-time worktree setup:** a fresh worktree has no `.godot/` cache (gitignored), so `class_name` types
  won't resolve until you import once. Import also (re)generates `*.gd.uid` files — **these ARE tracked in this
  repo, so `git add` and commit any new ones; do NOT add `*.uid` to `.gitignore`.** Set the Godot path once:
  ```powershell
  $GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
  & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick_v4' --editor --quit   # one-time import: builds .godot/ + .uid
  ```
- **Validation gate (run after every slice):**
  ```powershell
  & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick_v4' --quit                                                 # parse
  & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick_v4' res://scenes/ui/Bootstrap.tscn --quit                  # smoke boot
  & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick_v4' -- --profile=champion:hive --players=2 --build=heavy   # PerfRunner
  git -C 'D:\GameDev\Project_Twin_stick_v4' diff --check
  ```
- **Terminology:** "Upgrade" in player/UI text, "mutation" in code. Weapons auto-fire; abilities are the 4 buttons.
- **Design principle (do not violate):** the tag system is for **compatibility gating only** — a mutation is
  offered iff `requires ⊆ kit's tags`. No balance/synergy logic in the tag layer.

---

## Data schemas (define these first — Slice 0)

### `data/classes.json` (new)
```json
{ "classes": [
  { "id": "mobile", "name": "Stormrunner", "hp": 100, "move_speed": 560,
    "passive": "momentum", "ultimate": "slipstream",
    "weapon_pool": ["rifle","beam"],
    "ability_pool": ["dash","shockwave","afterburn","momentum_burst","deflect","sonic_boom"],
    "tags": ["mobile"] },
  { "id": "tank", "hp": 150, "move_speed": 480, "passive": "bloodthirst", "ultimate": "blood_frenzy",
    "weapon_pool": ["scattergun","whirlwind"],
    "ability_pool": ["dash","ground_slam","quake","orbit","overcharge","blood_lance"], "tags": ["tank"] },
  { "id": "controller", "hp": 110, "move_speed": 520, "passive": "radiance", "ultimate": "overload_grid",
    "weapon_pool": ["beam","arc_wand"],
    "ability_pool": ["dash","turret","minefield","orbit","summon","reinforce"], "tags": ["controller"] },
  { "id": "risk", "hp": 90, "move_speed": 560, "passive": "overheat", "ultimate": "firestorm",
    "weapon_pool": ["flamethrower","rocket"],
    "ability_pool": ["dash","overcharge","shockwave","shield","fireball","ignite"], "tags": ["risk"] }
] }
```
> **Ids are existing codebase ids** (see Appendix A): `scattergun` = Shotgun; `whirlwind`/`arc_wand`/
> `flamethrower` are new weapons to author. Do NOT invent a `shotgun` id.

### Tags on weapons / abilities (add a `"tags": [...]` field)
Per the spec §4 vocabulary (17 tags). E.g. `rifle:["projectile"]`, `beam:["beam"]`, `whirlwind:["melee"]`,
`arc_wand:["chain"]`, `flamethrower:["cone"]`; `dash:["mobility"]`, `turret:["summon"]`,
`ground_slam:["blast"]`, `afterburn:["field"]`, `blood_lance:["bolt"]`, `fireball:["bolt","blast","dot"]`,
`ignite:["dot"]`, `overcharge:["buff"]`, `shield:["defense"]`.
### Mutation schema (`data/mutations.json` — replace scope/requires_ability with a unified form)
Each mutation has TWO orthogonal fields: `requires` (**when** it's offered) and `apply` (**what** its `effect`
modifies). They are separate concerns — do not conflate them.
```json
{ "id": "piercing_rounds", "name": "Piercing Rounds", "rarity": "rare",
  "requires": ["projectile"], "apply": "weapon", "effect": { "pierce": 3 } }
{ "id": "executioner", "requires": ["blast","tank"], "apply": "ability", "effect": { "execute_below_pct": 0.20, "exclude_champions": true } }
{ "id": "combustion", "requires": ["risk"], "apply": "passive", "effect": { "high_heat_ignite": true } }
```
**Offer rule (gating):** a mutation is eligible iff every tag in `requires` is present in the player's **kit
tag set** = union of tags from equipped weapon + 3 abilities + ultimate + passive + class.
**Application rule (targeting):** `apply` ∈ `weapon` / `ability` / `passive` / `deployable` names the layer the
`effect` modifies. Within that layer it applies to the equipped item(s) whose tags include the mutation's
**non-class** required tags — e.g. `[projectile]` → your weapon; `[blast]` → **all** your equipped blast
abilities; `[summon]` → all your deployables. **Class tags are pure gates, never targets.** A mutation whose
`requires` is only a class tag (Combustion `[risk]`) has `apply:"passive"` and modifies the class passive /
global behavior. `apply` is **required on every mutation** — it is what disambiguates the re-folded
ability-rares (e.g. Aegis Burst `requires:["defense"] apply:"ability"`).

---

## Slice 0 — Foundations: data schemas + 4-slot kit + input
**Goal:** the kit holds 4 ability slots (LT/RT/LB/RB), fed by a **temporary default 4-ability loadout** (no
class-select UI yet — that arrives in Slice 1). Data schemas above exist and load. No new content.
**Vertical-slice note:** to actually *fire* 4 slots end-to-end you must move the loadout storage now, not just
the input — hence `PlayerInventory`/`RunState` are in this slice, providing 4 abilities to `Player`.
**Files:**
- `scripts/player/Player.gd` — `_ability_slots` array → size 4; input loop `for slot_index in range(2)` →
  `range(4)`; `_is_ability_pressed` handles 4 slots; expand `_build_runtime_ability` to 4.
- `project.godot` input map — see **LB/RB reclaim** below.
- `scripts/game/PlayerInventory.gd` — hold 4 ability slots.
- `scripts/game/RunState.gd` — `_build_default_player_inventories` + `get_player_runtime_loadout_for` supply a
  default 4-ability set so all four fire (real per-class selection is Slice 1).
- `scripts/player/PlayerConfig.gd`; `scripts/ui/WeaponSlotHUD.gd` / ability HUD (show 4 slots).
- add `data/classes.json` loader (in `RunState` or a new `ClassRegistry.gd`); add `"tags"` fields to
  `data/weapons.json` + `data/abilities.json` (values per spec §4).
**LB/RB reclaim (must resolve the binding conflict):** LB/RB are currently bound to
`p%d_switch_primary` / `p%d_switch_secondary` (in-run weapon switch — **obsolete** under the loadout model,
where you equip one weapon at loadout). **Remove or repurpose those two switch actions** and bind LB/RB to the
new `p%d_ability_3` / `p%d_ability_4` (+ keyboard). Rename the existing `p%d_secondary` / `p%d_dash` →
`p%d_ability_1` / `p%d_ability_2` (or keep as aliases). Note p3/p4 only have 2 ability actions today — add
`ability_3`/`ability_4` for them too.
**Acceptance:** game boots; a player fires **4** mapped ability buttons from the default loadout; **no input
collides with the old weapon-switch**; classes.json + tags parse without error.

## Slice 1 — Class data model + loadout / class-select UI
**Goal:** pick **class → weapon → 3 abilities** before a run (ultimate auto-equipped). 1-4 players, same class allowed.
**Files:** `scripts/game/PlayerInventory.gd` (add `class_id`; `ability_slots` = 3 chosen + `ultimate_id`),
`scripts/game/RunState.gd` (`_build_default_player_inventories`, `get_player_runtime_loadout_for` → class-aware,
ultimate slot), new `scripts/game/ClassRegistry.gd` (load classes.json, pools), `scripts/ui/Bootstrap.gd`
(class-select + weapon + 3-ability picker, reuse the card UI style).
**Tasks:** loadout validates picks against the class pool; ultimate is inserted as a locked 4th slot; wire the
chosen loadout into `Player.apply_loadout`.
**Acceptance:** start a run as each class with a chosen weapon + 3 abilities + its ultimate; abilities fire on
the 4 buttons; 2P with two different classes works.

## Slice 2 — Tag system + mutation rework
**Goal:** mutations gate by `requires ⊆ kit-tags`; retire stat-sticks; old ability-rares re-fold as tag mutations.
**Files:** `scripts/game/MutationSystem.gd` (replace `requires_ability` / `_can_still_pick` gating with a
`_kit_tag_set(player_index)` + `requires ⊆ tags` check in `roll_mutation_options`; drop `PER_TAG_RATE` synergy
if unused), `data/mutations.json` (convert every mutation to `requires:[tags]`; remove rapid_fire/velocity/
high_caliber/range; re-fold ability-rares per spec §4 table; add per-class mutation sets **from spec §6**, and
set each mutation's `apply` field per the schema above).
**Tasks:** build the kit-tag-set from equipped weapon+abilities+ultimate+passive+class; filter offers by it;
keep reroll/skip flow.
**Acceptance:** in a debug run, a projectile-weapon kit is offered Pierce but a cone/melee kit is not; a Risk
kit is offered Combustion, others never are; a kit with no `summon` item is never offered Overgrowth.

## Slice 3 — Deployable persistence + HP (global rule)
> **Ordering note:** this must land **before** passives — Radiance's "+survivability" (Slice 4) and Summon
> (Slice 6) both build on the HP/death interface created here. Do the EXISTING nodes now; the new Summon node
> inherits this same interface when authored in Slice 6.
**Goal:** all placed persistent units get an **HP pool + damage handling + death** (destroyed, not timed).
**Files:** `scripts/game/TurretNode.gd`, `OrbitNode.gd`, `DecoyNode.gd`,
`scripts/modifiers/MineFieldModifier.gd`. Add a shared HP/damage/death interface (small base or mixin so Summon
can reuse it); remove lifetime timers where present.
**Acceptance:** turret / orbit / mines take damage and can be destroyed; no more time-expiry despawn.

## Slice 4 — New passive systems
**Goal:** the 4 passives work (deployable HP from Slice 3 is available). **Files/notes:**
- **Momentum (Mobile):** reuse `scripts/game/MomentumTracker.gd`; make it class-exclusive (only when class=mobile).
- **Bloodthirst (Tank):** new — **on-kill flat HP heal** + overheal → decaying overshield; no passive regen.
  Hook enemy-death → heal owner. Overshield as a separate pool that decays.
- **Radiance (Controller):** new — deployables (tag `summon`) always +dmg AND +survivability (uses the Slice 3
  HP interface — e.g. regen / max-HP buff); aura around player gives nearby allies+self +dmg.
- **Overheat (Risk):** new — abilities use a fixed **0.5s** global cooldown (no long CDs); each ability cast
  adds Heat; Heat → +weapon-damage % AND +damage-taken %; Heat decays when idle. (Dash also builds heat.)
**Acceptance:** each passive observably functions in a debug room; Radiance visibly keeps deployables alive longer.

## Slice 5 — New weapons (new attack types)
**Goal:** Whirlwind, Arc Wand, Flamethrower fire correctly. **Files:** `data/weapons.json` (+ per_level),
`scripts/game/ProjectileSystem.gd` + `MutationSystem.get_base_projectile_visual` (new `projectile_kind`:
`melee`/`cone`/`chain`), `RunState._resolve_weapon_stats`.
- **Whirlwind** (`melee`): auto-swings, hits all enemies in a radius each tick.
- **Arc Wand** (`chain`): a bolt that jumps between nearby enemies (N chains).
- **Flamethrower** (`cone`): sustained short cone applying damage (+ optional burn).
**Acceptance:** equip each on its class; damage lands as described; PerfRunner stable.

## Slice 6 — New abilities + ultimates
**Goal:** author the ~10 new skills + 4 ultimates (`data/abilities.json` + `scripts/game/AbilityRegistry.gd`
+ runtime nodes as needed). New skills: Afterburn, Momentum Burst, Deflect, Sonic Boom, Ground Slam, Quake,
Blood Lance, **Summon** (persistent melee constructs w/ pet AI — reuses the Slice 3 HP interface), Reinforce,
Fireball, Ignite. Ultimates: Slipstream, Blood Frenzy, Overload Grid, Firestorm. Reuse
Dash/Shockwave/Overcharge/Orbit/Shield/Turret/Minefield.
**Sub-order:** do reuse-heavy classes first (Risk, then Tank) to validate the pipeline, then Mobile/Controller.
**Acceptance:** each new ability + ultimate works on its class in a debug room.

## Slice 7 — Meta / unlocks
**Goal:** all classes + base kits + base mutations **free**; premium content (element signatures, per-class
signatures, parasites) unlockable. **Files:** `scripts/meta/ProfileState.gd` `UNLOCK_TABLE` (classes free;
add premium entries with costs), the Meta menu UI.
**Acceptance:** new profile can play all 4 classes immediately; premium mutations gated behind score.

---

## Cross-cutting notes
- **Tuning** is placeholder throughout — first-pass numbers, then a balance pass (out of scope until it plays).
- **Art:** stay abstract-geometric; do NOT start billboard/rubberhose (future presentation-only pass). Define
  any directional mechanic by the aim/velocity vector, never visual body rotation.
- **Bosses:** unchanged (champions in waves).
- **Keep validated + committed per slice**; the v3 tree remains the playtest baseline for A/B comparison.

---

## Appendix A — Codex context (read this first)

### Sources & rules
- **Read `docs/design/class-system-redesign.md` (the `.md`), NOT the `.xlsx`.** The xlsx is a binary data grid
  for humans; the `.md` §6 carries every class kit + mutation in prose. Treat the `.md` as authoritative.
- **Tuning is placeholder everywhere** — pick sensible first-pass values (damage, cooldowns, radii, heat
  rate/decay, heal-per-kill, HP) and keep moving; do **not** stall waiting for numbers. Balance is a later pass.

### Design-name → code-id map (REUSE these ids — do not create duplicates)
**Weapons** (`data/weapons.json`): "Shotgun" = **`scattergun`** · `rifle` · `rocket` · `beam`.
- **Retired** (remove from pools, don't reuse): `cannon`, `railgun` (its pierce becomes a mutation), `boomerang`.
- **New to author:** `whirlwind` (kind `melee`), `arc_wand` (kind `chain`), `flamethrower` (kind `cone`).

**Abilities** (`data/abilities.json`, reuse): `dash`, `shockwave`, `overcharge`, `shield`, `turret`,
`minefield`, `orbit`. `blink` is merged into dash. `decoy` is used by no final class.
- **New to author:** `afterburn`, `momentum_burst`, `deflect`, `sonic_boom`, `ground_slam`, `quake`,
  `blood_lance`, `summon`, `reinforce`, `fireball`, `ignite` + ultimates `slipstream`, `blood_frenzy`,
  `overload_grid`, `firestorm`.

**Mutations** (`data/mutations.json`) — every entry needs `requires` **and** `apply` (see schema above):
- Element effects (reuse → tag mutations, all `apply:"weapon"`): **Split = `ricochet`** (`[projectile]`),
  Fire = `fire_trail`, Frost = `freeze_shot`, Toxic = `poison` (any weapon). **Pierce = new mutation**
  (`[projectile]`, `apply:"weapon"`).
- Ability-rares → re-fold as tag mutations (all `apply:"ability"`): `dash_shockdash`+`blink_twin_charge`→
  `[mobility]`; `turret_twin`+`orbit_expanding`+`mf_extra_mines`→`[summon]` (`apply:"deployable"`);
  `sw_resonance`→`[blast]`; `oc_piercing_overdrive`→`[buff]`; `shield_aegis_burst`→`[defense]`.
  **Drop** `decoy_volatile`.
- **Retire** (delete): `rapid_fire`, `velocity`, `high_caliber`, `range`. **Keep:** `move_speed`, `tough`,
  `quick_reflexes` (exclude on Risk), `wide_pulse`, `duration`.
- **Signatures = PREMIUM unlocks** (keep, gate via ProfileState): `accelerant`, `ember_spread`, `pyromaniac`,
  `chain_reaction`, `momentum_surge`, `glass_cannon`, `cryo_shatter`, `virulent`.

### Reuse inventory (extend these, don't rebuild)
- **Ability slots + input:** `scripts/player/Player.gd` — `_ability_slots` array (size 2), input loop
  `for slot_index in range(2)`, `_is_ability_pressed` uses actions `p%d_secondary`/`p%d_dash`.
- **Loadout/inventory:** `scripts/game/RunState.gd` (`_build_default_player_inventories`,
  `get_player_runtime_loadout_for`, `_load_weapons`, `_resolve_weapon_stats`) + `scripts/game/PlayerInventory.gd`.
- **Abilities:** `scripts/game/AbilityRegistry.gd`. **Mutations/gating:** `scripts/game/MutationSystem.gd`
  (`roll_mutation_options`; generalize `requires_ability` → `requires:[tags]`).
- **Passive to reuse:** `scripts/game/MomentumTracker.gd` (Mobile).
- **Deployable nodes (add HP + persistence):** `scripts/game/TurretNode.gd`, `OrbitNode.gd`, `DecoyNode.gd`,
  `scripts/modifiers/MineFieldModifier.gd`.
- **Weapons/projectiles:** `scripts/game/ProjectileSystem.gd`, `scripts/weapons/Projectile.gd` (add
  projectile kinds `melee`/`cone`/`chain`).
- **Meta:** `scripts/meta/ProfileState.gd` (`UNLOCK_TABLE`). **Loadout UI:** `scripts/ui/Bootstrap.gd`.
