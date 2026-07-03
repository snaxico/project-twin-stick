# V4 Class System — Implementation Plan (Codex-ready)

> **Design source of truth:** [`docs/design/class-system-redesign.md`](../design/class-system-redesign.md)
> (spec) + [`docs/design/class-design.xlsx`](../design/class-design.xlsx) (per-class data grid + every
> mutation). Read those first; this plan is the *build* order.
> **Branch/worktree:** implement on `v4/class-system` in the `Project_Twin_stick_v4` worktree. The original
> `D:/GameDev/Project_Twin_stick` tree stays the untouched **playtest v3 build** for A/B testing.

## How to work this plan
- **One vertical slice at a time**, in the order below (dependency-ordered). Each slice must leave the game
  **runnable** and pass the validation gate before moving on. Commit per slice.
- **Validation gate (run after every slice):**
  ```powershell
  & 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\GameDev\Project_Twin_stick_v4' --quit                 # parse
  & '...console.exe' --headless --path 'D:\GameDev\Project_Twin_stick_v4' res://scenes/ui/Bootstrap.tscn --quit                                                   # smoke boot
  & '...console.exe' --headless --path 'D:\GameDev\Project_Twin_stick_v4' -- --profile=champion:hive --players=2 --build=heavy                                     # PerfRunner
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
    "weapon_pool": ["shotgun","whirlwind"],
    "ability_pool": ["dash","ground_slam","quake","orbit","overcharge","blood_lance"], "tags": ["tank"] },
  { "id": "controller", "hp": 110, "move_speed": 520, "passive": "radiance", "ultimate": "overload_grid",
    "weapon_pool": ["beam","arc_wand"],
    "ability_pool": ["dash","turret","minefield","orbit","summon","reinforce"], "tags": ["controller"] },
  { "id": "risk", "hp": 90, "move_speed": 560, "passive": "overheat", "ultimate": "firestorm",
    "weapon_pool": ["flamethrower","rocket"],
    "ability_pool": ["dash","overcharge","shockwave","shield","fireball","ignite"], "tags": ["risk"] }
] }
```
### Tags on weapons / abilities (add a `"tags": [...]` field)
Per the spec §4 vocabulary (17 tags). E.g. `rifle:["projectile"]`, `beam:["beam"]`, `whirlwind:["melee"]`,
`arc_wand:["chain"]`, `flamethrower:["cone"]`; `dash:["mobility"]`, `turret:["summon"]`,
`ground_slam:["blast"]`, `afterburn:["field"]`, `blood_lance:["bolt"]`, `fireball:["bolt","blast","dot"]`,
`ignite:["dot"]`, `overcharge:["buff"]`, `shield:["defense"]`.
### Mutation schema (`data/mutations.json` — replace scope/requires_ability with a unified form)
```json
{ "id": "piercing_rounds", "name": "Piercing Rounds", "rarity": "rare",
  "requires": ["projectile"], "effect": { "pierce": 3 } }
{ "id": "executioner", "requires": ["blast","tank"], "effect": { "execute_below_pct": 0.20, "exclude_champions": true } }
{ "id": "combustion", "requires": ["risk"], "effect": { "high_heat_ignite": true } }
```
Offer rule: a mutation is eligible iff every tag in `requires` is present in the player's **kit tag set** =
union of tags from equipped weapon + 3 abilities + ultimate + passive + class.

---

## Slice 0 — Foundations: data schemas + 4-slot kit + input
**Goal:** the kit is 4 ability slots (LT/RT/LB/RB); data schemas above exist and load. No new content yet —
existing 2 abilities still work, just in a 4-slot array.
**Files:** `scripts/player/Player.gd` (`_ability_slots` array → size 4; the `for slot_index in range(2)` input
loop → `range(4)`), `scripts/player/PlayerConfig.gd`, the input map in `project.godot` (add `p%d_ability_3`
/`p%d_ability_4` bound to LB/RB + keyboard), `scripts/ui/WeaponSlotHUD.gd` / ability HUD (show 4 slots).
**Tasks:** rename slot actions to `p%d_ability_1..4` (keep back-compat aliases if simpler); expand
`_build_runtime_ability` calls to 4; add `data/classes.json` loader (in `RunState` or a new `ClassRegistry.gd`);
add `"tags"` fields to `data/weapons.json` + `data/abilities.json` (values per spec §4).
**Acceptance:** game boots; a player can fire 4 mapped ability buttons; classes.json + tags parse without error.

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
high_caliber/range; re-fold ability-rares per spec §4 table; add per-class sets from the xlsx Mutations tab).
**Tasks:** build the kit-tag-set from equipped weapon+abilities+ultimate+passive+class; filter offers by it;
keep reroll/skip flow.
**Acceptance:** in a debug run, a projectile-weapon kit is offered Pierce but a cone/melee kit is not; a Risk
kit is offered Combustion, others never are; a kit with no `summon` item is never offered Overgrowth.

## Slice 3 — New passive systems
**Goal:** the 4 passives work. **Files/notes:**
- **Momentum (Mobile):** reuse `scripts/game/MomentumTracker.gd`; make it class-exclusive (only when class=mobile).
- **Bloodthirst (Tank):** new — **on-kill flat HP heal** + overheal → decaying overshield; no passive regen.
  Hook enemy-death → heal owner. Overshield as a separate pool that decays.
- **Radiance (Controller):** new — deployables (tag `summon`) always +dmg/+survivability; aura around player
  gives nearby allies+self +dmg.
- **Overheat (Risk):** new — abilities use a fixed **0.5s** global cooldown (no long CDs); each ability cast
  adds Heat; Heat → +weapon-damage % AND +damage-taken %; Heat decays when idle. (Dash also builds heat.)
**Acceptance:** each passive observably functions in a debug room for its class.

## Slice 4 — New weapons (new attack types)
**Goal:** Whirlwind, Arc Wand, Flamethrower fire correctly. **Files:** `data/weapons.json` (+ per_level),
`scripts/game/ProjectileSystem.gd` + `MutationSystem.get_base_projectile_visual` (new `projectile_kind`:
`melee`/`cone`/`chain`), `RunState._resolve_weapon_stats`.
- **Whirlwind** (`melee`): auto-swings, hits all enemies in a radius each tick.
- **Arc Wand** (`chain`): a bolt that jumps between nearby enemies (N chains).
- **Flamethrower** (`cone`): sustained short cone applying damage (+ optional burn).
**Acceptance:** equip each on its class; damage lands as described; PerfRunner stable.

## Slice 5 — New abilities + ultimates
**Goal:** author the ~10 new skills + 4 ultimates (`data/abilities.json` + `scripts/game/AbilityRegistry.gd`
+ runtime nodes as needed). New skills: Afterburn, Momentum Burst, Deflect, Sonic Boom, Ground Slam, Quake,
Blood Lance, Summon (persistent melee constructs w/ pet AI), Reinforce, Fireball, Ignite. Ultimates: Slipstream,
Blood Frenzy, Overload Grid, Firestorm. Reuse Dash/Shockwave/Overcharge/Orbit/Shield/Turret/Minefield.
**Sub-order:** do reuse-heavy classes first (Risk, then Tank) to validate the pipeline, then Mobile/Controller.
**Acceptance:** each new ability + ultimate works on its class in a debug room.

## Slice 6 — Deployable persistence + HP (global rule)
**Goal:** all summons/deployables are **persistent with HP** (destroyed, not timed). **Files:**
`scripts/game/TurretNode.gd`, `OrbitNode.gd`, `DecoyNode.gd`, `scripts/modifiers/MineFieldModifier.gd`, new
Summon node. Add an HP pool + damage handling + death; remove lifetime timers where present.
**Acceptance:** deployables take damage and die; Radiance survivability keeps them alive longer.

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
