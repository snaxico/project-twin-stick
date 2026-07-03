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
- **Validation gate (run after every slice):** `$GODOT` is re-set on line 1 so the block is self-contained in
  a fresh shell.
  ```powershell
  $GODOT = 'D:\GameDev\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
  & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick_v4' --quit                                                 # parse
  & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick_v4' res://scenes/ui/Bootstrap.tscn --quit                  # smoke boot
  & $GODOT --headless --path 'D:\GameDev\Project_Twin_stick_v4' -- --profile=champion:hive --players=2 --build=heavy   # PerfRunner
  git -C 'D:\GameDev\Project_Twin_stick_v4' diff --check
  ```
- **Stub-first for forward references (critical for slice order):** `classes.json` pools reference weapons,
  abilities, and ultimates that aren't authored until Slices 5-6. So the loadout in Slice 1 can validate and
  run against a resolvable id set, **Slice 1 must first register a placeholder stub for every pool id that
  doesn't exist yet** — a data entry + a runtime no-op (a weapon that fires a basic projectile; an ability/
  ultimate that goes on cooldown and does nothing). Content slices then *replace* each stub with real behavior.
  Loadout/validation must never hit a missing-id reject; it sees a stub instead.
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
**non-class functional** required tags — e.g. `[projectile]` → your weapon; `[blast]` → **all** your equipped
blast abilities; `[summon]` → all your deployables. **Class tags are pure gates, never targets.**
**No functional tag ⇒ target the layer's sole/default item.** When `requires` has no functional tag (empty, or
class-only), `apply` alone picks the target:
- `requires:[]`, `apply:"weapon"` → your **one equipped weapon** (offered to everyone — every kit has exactly
  one weapon). **This is how the "any weapon" element effects (Fire/Frost/Toxic) are encoded** — there is
  deliberately **no generic `weapon` tag** in the vocab; an empty `requires` *is* "any weapon".
- `requires:["<class>"]`, `apply:"passive"` → the class passive / global behavior (Combustion `[risk]`).

`apply` is **required on every mutation** — it also disambiguates the re-folded ability-rares (e.g. Aegis Burst
`requires:["defense"] apply:"ability"`).

---

## Slice 0 — Foundations: data schemas + 4-slot kit + input
**Goal:** the kit holds 4 ability slots mapped to the four controller **face buttons** (Xbox A/X/Y/B, PS5
✕/□/△/○), fed by a **temporary default 4-ability loadout** (no class-select UI yet — that arrives in Slice 1).
Data schemas above exist and load. No new content. **Scope: 1-2 players (V4).**
**Vertical-slice note:** to actually *fire* 4 slots end-to-end you must move the loadout storage now, not just
the input — hence `PlayerInventory`/`RunState` are in this slice, providing 4 abilities to `Player`.
**Files:**
- `scripts/player/Player.gd` — `_ability_slots` array → size 4; input loop `for slot_index in range(2)` →
  `range(4)`; `_is_ability_pressed` handles 4 slots; expand `_build_runtime_ability` to 4.
- `project.godot` input map — see **Input** below.
- `scripts/game/PlayerInventory.gd` — hold 4 ability slots.
- `scripts/game/RunState.gd` — `_build_default_player_inventories` + `get_player_runtime_loadout_for` supply a
  default 4-ability set so all four fire (real per-class selection is Slice 1).
- `scripts/game/AbilityRegistry.gd` — `get_default_loadout()` / `normalize_loadout()` currently hard-return a
  **2-item OFF+DEF** pair; expand to 4 slots (or add a 4-slot path RunState calls). The old 2-slot
  OFF/DEF picker in `Bootstrap.gd` feeds this too — either extend it to 4 or have RunState bypass it for the
  temporary default. Whichever you pick, nothing may still assume exactly 2 abilities.
- `scripts/player/PlayerConfig.gd`; `scripts/ui/WeaponSlotHUD.gd` / ability HUD (show 4 slots).
- `scripts/ui/Bootstrap.gd` + `scripts/game/CoopManager.gd` — see **Input** (both hard-code the removed switch
  action suffixes, not just `project.godot`).
- add `data/classes.json` loader (in `RunState` or a new `ClassRegistry.gd`); add `"tags"` fields to
  `data/weapons.json` + `data/abilities.json` (values per spec §4).
**Input — 4 ability face buttons + remove weapon switching (design decision, 2026-07-03):** the four ability
slots map to the controller **face buttons** (Xbox **A / X / Y / B**, PS5 **✕ / □ / △ / ○**) — *not* the
bumpers/triggers. **V4 has only one active weapon per run** (chosen at loadout), so **in-run weapon switching
is removed entirely** (design spec §2 updated to match). Do all three:
  1. `project.godot` input map — add `p%d_ability_1..4` bound to the four face-button `InputEventJoypadButton`
     indices (A=0, B=1, X=2, Y=3) + keyboard; **delete** `p%d_switch_primary` / `p%d_switch_secondary`
     (currently RB=10 / LB=9 + keys Q/E, T/Y). The existing `p%d_secondary` / `p%d_dash` become
     `p%d_ability_1` / `p%d_ability_2` (rename or alias).
  2. `scripts/game/CoopManager.gd` — the action-suffix list (`"switch_primary"`, `"switch_secondary"` ~L60-61):
     **remove** them; add `"ability_3"`, `"ability_4"` (and rename `secondary`/`dash` if you renamed the actions).
  3. `scripts/ui/Bootstrap.gd` — the binding-label rows (`"Swap LT"`/`"Swap RT"` → `switch_primary`/
     `switch_secondary` ~L27-28): **remove** the swap rows; add ability-3/ability-4 rows.
**Scope note (1-2 players):** wire the 4 face buttons for **p1 and p2 only**. p3/p4 are out of V4 scope — leave
their existing (empty) actions untouched; do not add `ability_3`/`ability_4` for them.
**Acceptance:** game boots; **p1 and p2** each fire **4** face-button abilities from the default loadout; the
weapon-switch inputs are gone (one weapon, no swap); classes.json + tags parse without error.

## Slice 1 — Class data model + loadout / class-select UI
**Goal:** pick **class → weapon → 3 abilities** before a run (ultimate auto-equipped). **1-2 players (V4 scope)**, same class allowed.
**Files:** `scripts/game/PlayerInventory.gd` (add `class_id`; `ability_slots` = 3 chosen + `ultimate_id`),
`scripts/game/RunState.gd` (`_build_default_player_inventories`, `get_player_runtime_loadout_for` → class-aware,
ultimate slot), new `scripts/game/ClassRegistry.gd` (load classes.json, pools), `scripts/ui/Bootstrap.gd`
(class-select + weapon + 3-ability picker, reuse the card UI style), `scripts/meta/ProfileState.gd`
(unlock-gate — see below).
**Unlock-gate (must resolve now, not in Slice 7):** `ProfileState.UNLOCK_TABLE` currently score-locks base
content class pools depend on (`shockwave` 600, `shield` 950, `turret` 1100, `minefield` 1300, `orbit` 1500,
`beam`, `rocket`, …). Class-select would reject those picks. **In this slice, make every class-pool weapon +
ability + ultimate `free:true` (or bypass the unlock check for class-pool content).** The *premium-only*
UNLOCK_TABLE trim (signatures/parasites) stays Slice 7 — only the free-ing happens here.
**Tasks:** **first register stubs** (per the stub-first rule above) for every not-yet-authored pool id —
weapons `whirlwind`/`arc_wand`/`flamethrower`, all new abilities + all 4 ultimates — as data + runtime no-ops
so pools resolve; free the base kits (above); then: loadout validates picks against the class pool; ultimate is
inserted as a locked 4th slot; wire the chosen loadout into `Player.apply_loadout`.
**Acceptance:** start a run as each class with a chosen weapon + 3 abilities + its ultimate (new content is a
stub until Slices 5-6, but the loadout resolves and runs — no missing-id error); abilities fire on the 4
buttons; 2P with two different classes works.

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
**Files:** `scripts/game/TurretNode.gd`, `OrbitNode.gd`, `DecoyNode.gd`, `AbilityMine.gd` (player
Minefield ability mines). Add a shared HP/damage/death interface (small base or mixin so Summon can reuse it);
remove lifetime timers where present. Only touch `scripts/modifiers/MineFieldModifier.gd` if the arena hazard
modifier should also use this interface; it is not the player Minefield ability.
**Acceptance:** turret / orbit / player ability mines take damage and can be destroyed; no more time-expiry
despawn.

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
**Goal:** Whirlwind, Arc Wand, Flamethrower fire correctly — **replace their Slice 1 stubs** with real
behavior (same ids). **Files:** `data/weapons.json` (+ per_level),
`scripts/game/ProjectileSystem.gd` + `MutationSystem.get_base_projectile_visual` (new `projectile_kind`:
`melee`/`cone`/`chain`), `RunState._resolve_weapon_stats`.
- **Whirlwind** (`melee`): auto-swings, hits all enemies in a radius each tick.
- **Arc Wand** (`chain`): a bolt that jumps between nearby enemies (N chains).
- **Flamethrower** (`cone`): sustained short cone applying damage (+ optional burn).
**Acceptance:** equip each on its class; damage lands as described; PerfRunner stable.

## Slice 6 — New abilities + ultimates
**Goal:** author the ~10 new skills + 4 ultimates — **replace their Slice 1 stubs** with real behavior (same
ids) (`data/abilities.json` + `scripts/game/AbilityRegistry.gd` + runtime nodes as needed). New skills: Afterburn, Momentum Burst, Deflect, Sonic Boom, Ground Slam, Quake,
Blood Lance, **Summon** (persistent melee constructs w/ pet AI — reuses the Slice 3 HP interface), Reinforce,
Fireball, Ignite. Ultimates: Slipstream, Blood Frenzy, Overload Grid, Firestorm. Reuse
Dash/Shockwave/Overcharge/Orbit/Shield/Turret/Minefield.
**Ultimate charge framework (build this FIRST — every ult plugs into it; spec §2):** ultimate charge is a
**unified combat meter** (damage dealt + kills) for **Mobile/Tank/Controller**; **Risk is the exception — its
ultimate (Firestorm) is gated by the Overheat Heat meter**, not the combat meter.
- **Ownership:** new `scripts/game/UltimateCharge.gd` — a per-player `0.0→1.0` meter filled by damage dealt +
  kills (placeholder rates). Risk does **not** use this meter; its readiness reads the Heat value (Slice 4).
- **Activation gating:** the ultimate occupies the locked 4th face-button slot; pressing it fires **only when
  ready** (meter full / Risk: Heat ≥ threshold). On activation it **resets** (combat meter → 0; Risk vents Heat
  → 0). While not ready, the button is a no-op.
- **HUD / readiness:** a per-player charging → ready → active indicator (reuse the ability-cooldown HUD pattern).
**Sub-order:** ultimate-charge framework → then reuse-heavy classes first (Risk, then Tank) to validate the
pipeline → then Mobile/Controller.
**Acceptance:** each new ability works on its class; each ultimate **charges from combat (Risk from Heat), shows
ready on the HUD, fires from its locked slot only when ready, and resets after use** — the ult button does
nothing while uncharged.

## Slice 7 — Meta / unlocks
**Goal:** finish the unlock model. Base kits were already freed in Slice 1; this slice **trims `UNLOCK_TABLE`
of the retired paid entries** (cannon/railgun/boomerang/blink/decoy + the 4 retired stat-stick mutations) and
**adds the premium entries** (element signatures, per-class signatures, parasites) with costs, plus the Meta
menu UI. **Files:** `scripts/meta/ProfileState.gd` `UNLOCK_TABLE`, the Meta menu UI.
**Acceptance:** new profile can play all 4 classes + full base kits immediately; only premium content is gated
behind score.

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
- Element effects (reuse → tag mutations, all `apply:"weapon"`): Fire = `fire_trail`, Frost = `freeze_shot`,
  Toxic = `poison` are **"any weapon" → `requires:[]`** (empty = universal; see the no-functional-tag rule).
  **Split = `ricochet`** and **Pierce = new mutation** need projectiles → **`requires:["projectile"]`**.
- Ability-rares → re-fold as tag mutations. **`apply` splits by target:** the summon group targets deployed
  units → `apply:"deployable"`; all others act on the equipped ability → `apply:"ability"`.
  - `apply:"deployable"`: `turret_twin`+`orbit_expanding`+`mf_extra_mines`→`[summon]`.
  - `apply:"ability"`: `dash_shockdash`+`blink_twin_charge`→`[mobility]`; `sw_resonance`→`[blast]`;
    `oc_piercing_overdrive`→`[buff]`; `shield_aegis_burst`→`[defense]`.
  - **Drop** `decoy_volatile`.
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
  `scripts/game/AbilityMine.gd` (the **player Minefield ability** mines — NOT `scripts/modifiers/MineFieldModifier.gd`,
  which is the separate arena hazard).
- **Weapons/projectiles:** `scripts/game/ProjectileSystem.gd`, `scripts/weapons/Projectile.gd` (add
  projectile kinds `melee`/`cone`/`chain`).
- **Meta:** `scripts/meta/ProfileState.gd` (`UNLOCK_TABLE`). **Loadout UI:** `scripts/ui/Bootstrap.gd`.
