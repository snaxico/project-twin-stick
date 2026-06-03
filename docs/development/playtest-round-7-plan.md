# Round 7 Plan — Spectacle/Feel + Ability Slots + Distinct Mutations

## Context

Round-6 playtest (post perf patch) surfaced feel/content findings:
1. Game feels too defensive; wants higher fire rate + more visual "wow". → Track A (+ A8)
2. First level boring — low spectacle. → Track A (front-load juice)
3. Split abilities into OFF/DEF, pick one each. → **Track B** (decided: restrict)
4. Boss needs an HP bar. → A6
5. Weapons feel too similar. → **Track C** (decided: distinct mutations; single Rifle stays)
6. More content + more wow moments. → Tracks A, C & **D** (D = the net-new content: ability rares)
7. Better visuals/SFX at low effort. → Track A

**Decided:** **Track B ships first**; restrict ability slots to `1 OFF + 1 DEF`; make
**mutations** read distinctly rather than adding new weapons yet. Then implement the feel pass
(`A1-A7`). `A8` fire-rate bump and most ability rares are deferred until the real-room perf gate
still passes after the feel work.

Most of this is **independent of the parked art-style (rubberhose) decision** — juice on the
current vector art is high-impact and low-effort.

---

## Track A — Juice / Feel pass

A lot of infra already exists in `scripts/juice/` (`ScreenShake`, `ScreenEffects`,
`ParticleFactory`, `SfxEngine`, `HealthBarHUD`, `FloatingText`). The work is mostly *using it
harder* + a few new pieces.

- **A1. Bloom/glow (biggest visual win).** Add a `WorldEnvironment` with `Environment.glow`
  enabled to `scenes/game/GameWorld.tscn` (none exists today). Neon-on-black pops instantly.
  *Perf note:* glow is a fill-rate post-process, not draw calls — cheap on draw count but watch
  it on low-end; verify with the DebugOverlay.
- **A2. Hit-stop (new).** Brief `Engine.time_scale` dip (~0.05 for ~40-60ms) on big hits / elite
  kills / boss phase transitions. *Gotcha:* time_scale slows the restore timer too — drive the
  restore from a **real-time** measure (`Time.get_ticks_msec`) or an `ALWAYS` process-mode timer,
  not a scaled one. Implement this as a small manager/helper, not scattered inline calls:
  max duration `~70ms`, minimum interval `~120ms`, strongest event wins, and trash-kill/AOE chains
  must not be able to keep time_scale low continuously.
  - **This manager is the SOLE owner of `Engine.time_scale`.** Anything else that wants slow-mo
    (e.g. A5's level-up dilation) requests it through this manager — never sets `time_scale`
    directly — so two effects can't clobber each other into stuck slow-mo.
  - **Triggers: big hits, elite kills, boss phase transitions only. NOT trash kills** — a regular
    enemy dying must never hit-stop, or dense combat stutters constantly.
  - **Co-op caveat:** `Engine.time_scale` is engine-wide, so a hit-stop from P1's kill also slows
    P2 mid-action (dash/aim). Keep it short/subtle and gated to shared big moments; **must be
    feel-checked at 2P** before keeping.
- **A3. Screenshake scaled to events** (`ScreenShake.gd`) — more on kills, AOE, boss slams.
- **A4. Kill pops + muzzle flash + chunkier trails** (`ParticleFactory.gd`) — scale-punch +
  burst on death; additive-blended projectile trails.
- **A5. Level-up moment** — flash + SFX sting + pick-UI punch-in. Directly fixes #2's "low
  spectacle" (leveling is currently silent). **Timing:** levels accrue *mid-combat* but picks
  resolve at *room end* — so the mid-combat level-up is **flash + SFX only** (it can fire often;
  no slow-mo), and any **time-dilation is reserved for the room-end pick screen** and **routed
  through the A2 hit-stop manager** (single `time_scale` owner — never set directly here).
- **A6. Boss HP bar.** Add a top-center bar in `_build_hud` (`CoopManager.gd:253`), populated
  from `_active_boss` health each HUD refresh (`_active_boss` already tracked at :124; bosses
  expose `current_health`/`max_health`). Reuse `scripts/juice/HealthBarHUD.gd` if it fits;
  add phase pips. Show only while a boss is alive.
- **A7. SFX pass** (`SfxEngine.gd`) — layered fire/hit/kill/level-up with pitch variation; a
  bassy level-up sting. **Decided: procedural-only.** `SfxEngine.gd` already generates audio at
  runtime — round 7 **extends that procedurally and imports NO external/asset files** (keeps it
  low-effort, no asset pipeline, fits the neon/arcade aesthetic). Curated/imported audio is a
  later polish pass, explicitly out of scope here.
- **A8. Fire-rate bump (deferred, perf-aware).** Do not implement in the first round-7 patch.
  Raise base rifle cadence (`data/weapons.json` / `Player.gd`) only if A1-A7 still feel too slow.
  This trades against the round-6 perf gate (more projectiles = more entities). With bloom +
  hit-stop + shake the *same* cadence may already feel more aggressive; if A8 is later used, bump
  only as much as still passes the real-room gate (re-check with the DebugOverlay).

## Track B — Ability slots: restrict to 1 OFF + 1 DEF

**Categorization (decided):**
- **OFF (4):** `overcharge`, `turret`, `minefield`, `orbit`
- **DEF (5):** `dash`, `shield`, `blink`, `decoy`, `shockwave`

(20 combos; every build guaranteed real offense + survivability.)

- **`data/abilities.json`:** add a `"slot": "off" | "def"` field to each ability (none exists
  today — entries currently have id/name/description/type/cooldown/duration/stats).
- **`AbilityRegistry` (`scripts/.../AbilityRegistry*`):** expose `slot`; provide a sane default
  loadout of one OFF + one DEF.
- **Pre-run UI (`scripts/ui/Bootstrap.gd`):** the current free pick-2 (`_build_ability_rows`,
  `_get_player_ability_pair`, `_sync_ability_row_buttons`) becomes **two category-filtered
  slots** — one OFF picker, one DEF picker per player. **Slot order is fixed:** slot 1 / `LT` =
  OFF, slot 2 / `RT` = DEF. Validate the pair is exactly one of each before launch, and update
  menu/HUD copy to match that order.
- **Migration:** ensure existing/default `player_abilities` in `RunState`/debug setup resolve to
  a valid 1+1 pair AND **normalize slot order** — OFF must land in slot 1 (LT), DEF in slot 2
  (RT). It's not enough to accept "one of each": an old loadout with a DEF in slot 1 must be
  **reordered**, or the LT/RT mapping is backwards. Repair two-OFF / two-DEF configs to a valid
  default rather than crashing.

## Track C — Distinct mutations (single Rifle stays)

Make the **behavior-changing** mutations read as visually/aurally distinct so builds feel
different.

> **Constraint (consistency with the player-green change):** the player projectile *core fill*
> stays the player tint (bright green) — do **not** override the core color per mutation, or the
> green-player / red-enemy readability we just set is lost. Differentiate by **shape, trail,
> impact, and SFX**, with an **accent color** only in the trail/outline/impact (not the core).

Implemented in `scripts/weapons/Projectile.gd` (shape/trail/impact draw), applied via
`scripts/game/MutationSystem.gd`; add the per-mutation fields below to `data/mutations.json`.

| Mutation | Projectile shape | Trail / accent | Impact SFX profile |
|----------|------------------|----------------|--------------------|
| `split_shot` | smaller, multiple | short green streak | light/high "spread" |
| `pierce` | elongated lance | sharp green streak, cyan accent outline | thin "zip" |
| `big_shot` | large orb | heavy slow trail | low "thump" |
| `ricochet` | angular diamond | spark flecks, yellow accent | metallic "ping" |
| `fire_trail` (Fire Bullets) | ember orb | orange ember trail + burning pool on impact | "whoosh"/crackle |
| `explosive_rounds` | round "bomb" | smoky trail, red-orange accent | "boom" on impact |
| `freeze_shot` | crystalline shard | frosty trail, ice-blue accent | glassy "chime" |
| `poison` | irregular blob | bubbly trail, toxic-green/violet accent | wet "squelch" |

New optional `data/mutations.json` fields per behavior mutation:
`projectile_shape`, `trail_style`, `accent_color` (trail/outline/impact only), `impact_sfx`.
Core fill remains `player_config.tint`.
- **Stat mutations** stay numeric but get clearer feedback (already partly wired — streaks for
  rapid_fire/velocity, speed lines for move_speed, etc.): `rapid_fire`, `velocity`, `move_speed`,
  `tough`, `duration`, `quick_reflexes`, `knockback`, `wide_pulse`.
- **`data/mutations.json`:** add per-mutation visual/sfx hints if helpful (color, trail style).

## Track D — Ability-specific rare mutations (net-new content)

The actual *new content* for this round (#6). Rares that **transform an equipped ability**, not
just tweak weapon stats. This is high-risk because it touches mutation rolling, loadout compile,
player ability execution, and several helper nodes. Do **not** implement all 9 in the first patch.
Round 7 should ship a **2-3 rare pilot** only after Track B is stable.

- **Loadout-gated pool (the core mechanic):** an ability rare tagged `requires_ability: "<id>"`
  is only offered if the player has that ability equipped. Gate it in
  `MutationSystem.roll_mutation_options()` (:151) / `_can_still_pick()` (:195) by checking the
  player's equipped ability ids (one OFF + one DEF). Result: a player only ever sees rares for
  *their* two abilities — tight, relevant pool, and the slot choice now also shapes the rare
  pool. Needs MutationSystem to read per-player loadout (`RunState` player inventories).
- **Data:** add the rares to `data/mutations.json` as `rarity: rare`, `category: ability`, with
  `requires_ability`. Roll under the existing act-weighted rare chance + elite force-rare.
- **Runtime application path (required, not optional):**
  - `MutationSystem` must expose ability-rare effects/flags for the equipped ability ids.
  - `CoopManager._build_runtime_ability()` must compile those effects into ability stats/flags.
  - `Player.gd`, `CoopManager.gd`, and ability helper nodes must consume those explicit flags in
    each affected ability path.
  - Verification must prove the rare changes behavior, not only that it appears in the pick UI.
- **Pilot: ship exactly these TWO first** (one OFF + one DEF, both **non-entity-spawning** so the
  pilot proves the full pipeline — loadout-gate → compile → behavior — with zero perf risk).
  Expansion rares (incl. the entity-spawning ones) come later, each behind its own gate re-check.

  | Pilot rare ID | `requires_ability` | slot | params | behavior | implemented in |
  |---|---|---|---|---|---|
  | `oc_piercing_overdrive` | `overcharge` | OFF | `{ "pierce_bonus": 2, "projectile_speed_mult": 1.2 }` | While Overcharge is active, player projectiles pierce +2 enemies and travel 20% faster. | `Player.gd` overcharge path → adds to `projectile_config` (`pierce_remaining`, `speed`) at fire time |
  | `sw_resonance` | `shockwave` | DEF | `{ "extra_pulses": 2, "pulse_interval": 0.15 }` | Shockwave emits 3 total pulses (1 + 2 extra) staggered 0.15s, each at full damage/radius/knockback. | `Player.gd` shockwave activation (`match ability_id` :481) → schedule `extra_pulses` more emits via the existing shockwave damage/knockback path |

  Both are `rarity: rare`, `category: ability` entries in `data/mutations.json`.

  **Expansion backlog (NOT in the pilot):** Turret→twin (`TurretNode.gd`/`CoopManager`,
  *entity-spawning*), Minefield→cluster (`AbilityMine.gd`, *entity-spawning*), Orbit→+orbs
  (`OrbitNode.gd`, *entity-spawning*), Dash→damaging trail (`Dash.gd`/`Player.gd`), Shield→expiry
  AOE (`Player.gd`), Blink→dual detonation (`Player.gd`), Decoy→explode-on-death (`DecoyNode.gd`).
- **Synergy:** with 1 OFF + 1 DEF locked, ability rares make the pick feel build-defining
  (your turret build can become a *twin-turret* build), which also feeds #1/#6 (more wow, less flat).
- **Perf:** entity-spawning transforms (twin turret, +orbs, +mines, exploding decoy) add
  entities. Prefer the pilot to include at most one entity-spawning transform and re-check the
  round-6 gate before adding more.

---

## Perf note (ties to round-6)

Track A adds GPU load (bloom fill-rate, more particles), Track D can add entities, and A8 adds
projectiles if it is later used. Bloom/particles are mostly fill-rate (won't blow draw calls);
fire-rate and entity-spawning rares are the entity-count risks. **Re-validate against the
round-6 real-room gate** using the new `DebugOverlay` (F3) after A1-A7, after the Track D pilot,
and again before any A8 fire-rate bump: ~60 FPS at capped density, no spikes, 1P and 2P.

## Required implementation order

1. **Track B first:** ability slot data, registry support, `LT = OFF` / `RT = DEF` UI, launch
   validation, and default/debug migration.
2. **Track A1-A7:** bloom, managed hit-stop, shake, kill/muzzle/trail juice, level-up moment,
   boss HP bar, and SFX pass.
3. **Track C:** distinct visuals/SFX for existing behavior-changing weapon mutations.
4. **Track D pilot only:** exactly the 2 rares (`oc_piercing_overdrive`, `sw_resonance`) via the
   explicit runtime application path — both Player-side, non-entity-spawning.
5. **A8 remains deferred:** only consider a small fire-rate bump if the above still feels slow
   and the real-room performance gate has headroom.

## Files touched

| File | Track | Change |
|------|-------|--------|
| `scenes/game/GameWorld.tscn` | A1 | Add `WorldEnvironment` + glow |
| `scripts/juice/ScreenShake.gd`, `ScreenEffects.gd` | A2/A3 | Hit-stop; stronger event-scaled shake |
| `scripts/juice/ParticleFactory.gd` | A4 | Kill pops, muzzle flash, trails |
| `scripts/game/CoopManager.gd` | A5/A6 | Level-up moment; boss HP bar in `_build_hud` from `_active_boss` |
| `scripts/juice/SfxEngine.gd` | A7 | Layered SFX, level-up sting — **procedural only, no asset imports** |
| `data/weapons.json`, `scripts/player/Player.gd` | A8 | Deferred fire-rate bump only if needed after A1-A7 |
| `data/abilities.json` | B | Add `"slot"` field per ability |
| `scripts/.../AbilityRegistry*`, `scripts/ui/Bootstrap.gd` | B | OFF/DEF filtered slots + validation |
| `scripts/game/RunState.gd` | B | Default/migrate loadouts to 1 OFF + 1 DEF |
| `scripts/weapons/Projectile.gd`, `scripts/game/MutationSystem.gd`, `data/mutations.json` | C | Distinct per-mutation projectile visuals + SFX |
| `scripts/game/MutationSystem.gd`, `scripts/game/CoopManager.gd`, `data/mutations.json` | D | Loadout-gated ability-rare pool (`requires_ability`) + compile rare effects into ability stats/flags |
| `scripts/player/Player.gd` | D (pilot) | The 2 pilot rares: `oc_piercing_overdrive` (overcharge path) + `sw_resonance` (shockwave path). Both Player-side, no entities |
| `scripts/game/TurretNode.gd`, `OrbitNode.gd`, `AbilityMine.gd`, `DecoyNode.gd`, `Dash.gd` | D (expansion, NOT pilot) | Later transforms only — out of scope for the round-7 pilot |

## Verification

1. Headless parse: `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick --quit`
2. **Perf re-check** (DebugOverlay F3, real boss room, 1P + 2P) after A1-A7 and after the Track D
   pilot. A8 requires a separate re-check before shipping.
3. Manual feel checklist (write after implementation):
   - Combat reads as aggressive/punchy (bloom + hit-stop + shake + SFX); first level no longer flat.
   - Level-up is a clear moment.
   - Boss HP bar shows, tracks damage, shows phases.
   - Pre-run: exactly one OFF + one DEF per player; no invalid/old loadouts crash.
   - Each behavior mutation looks/sounds distinct; builds feel different.
   - Ability rares only appear for *equipped* abilities; each pilot transform actually changes
     that ability's behavior; entity-spawning transforms stay within the perf gate.
   - Hit-stop never chains into continuous slowdown during dense trash/AOE kills; **trash kills
     do not trigger it at all**; level-up dilation and hit-stop never fight (single time_scale owner).
   - **2P checks:** hit-stop from one player's kill doesn't ruin the other's control; boss HP bar
     reads correctly with two players; each player picks their own OFF/DEF slots; LT=OFF / RT=DEF
     mapping is correct for both.
