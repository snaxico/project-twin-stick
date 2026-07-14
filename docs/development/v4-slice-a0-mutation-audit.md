# V4 Slice A0 — Mutation Build-Fit Audit (review seam)

Branch: `v4/class-system`. **Analysis only — no code changed.** This is the A0 deliverable feeding Slice A1.
Companion to `v4-playtest-findings-2026-07-14.md` (Category 1 + Category 2 Duration).

**Method:** every mutation in `data/mutations.json` was cross-checked against `data/abilities.json`
(tag sources), `MutationSystem.gd` (offer gating + effect injection), and the actual effect-consumer in code.
Line refs are load-bearing — Codex should re-open them, not trust the summary blindly.

**How offers + effects flow today:**
- Offer gate: `_can_still_pick` → `_mutation_requirements_met` (`MutationSystem.gd:324`) checks every tag in
  `requires` against the **whole-kit** tag set (`_kit_tag_set`, `:351`).
- Ability/deployable effect: `get_ability_rare_effects(player_index, ability_id)` (`:180`) injects a mutation's
  `params` into an ability's stats **iff** `_mutation_targets_item` (`:395`) passes — i.e. the ability's tags
  satisfy the mutation's *functional* `requires` (class tags skipped). Applied in `_build_runtime_ability`
  (`CoopManager.gd:453`).
- Weapon effect: `get_compiled_weapon_stats` (`:124`) reads specific mutation ids directly.
- Passive/attribute effect: dedicated getters (`get_move_speed_bonus`, `get_ability_area_multiplier`,
  `get_ability_duration_multiplier`, …) — all **global**.

---

## Section 1 — Confirmed dead / mis-gated offers (FIX in A1)

Each verified against its real consumer. "Offer leaks via" = equipped items whose tag currently unlocks the card.

| # | Mutation (id) | apply | current `requires` | offer leaks via | effect consumer (verified) | verdict | recommended gate |
|---|---|---|---|---|---|---|---|
| 1 | Twin Charge (`blink_twin_charge`) | ability | `mobility` | dash, slipstream | none — `extra_charges` unread anywhere | **DEAD** | **remove mutation** |
| 2 | Twin Turret (`turret_twin`) | deployable | `summon` | turret, minefield, orbit, summon | `gun_count` → `TurretNode.gd:22` | **DEAD off-turret** | `requires_ability: "turret"` |
| 3 | Extra Mines (`mf_extra_mines`) | deployable | `summon` | turret, minefield, orbit, summon | `mine_count_bonus` → `CoopManager.gd:1449` | **DEAD off-minefield** | `requires_ability: "minefield"` |
| 4 | Expanding Orbit (`orbit_expanding`) | deployable | `summon` | turret, minefield, orbit, summon | `extra_orbs` → `OrbitNode.gd:21` | **DEAD off-orbit** | `requires_ability: "orbit"` |
| 5 | Shockdash (`dash_shockdash`) | ability | `mobility` | dash, slipstream | `passthrough_damage` → `Player.gd:596` (dash pass-through loop) | **DEAD via Slipstream w/o Dash** | `requires_ability: "dash"` |
| 6 | Shockwave Resonance (`sw_resonance`) | ability | `blast` | shockwave, momentum_burst, ground_slam, fireball | `extra_pulses`/`pulse_interval` → `schedule_player_shockwave_resonance`, called **only** for `"shockwave"` (`CoopManager.gd:1358`) | **DEAD via other blasts** | `requires_ability: "shockwave"` |
| 7 | Aegis Burst (`shield_aegis_burst`) | ability | `defense` | shield, deflect | `burst_*` → `_pending_shield_burst` on shield expiry (`Player.gd:554-566`); Deflect is instant (no expiry) | **DEAD via Deflect** | `requires_ability: "shield"` |
| 8 | Piercing Overdrive (`oc_piercing_overdrive`) | ability | `buff` | overcharge, reinforce, blood_frenzy, overload_grid | `pierce_bonus`/`projectile_speed_mult` read from `overcharge_stats` and mutate `projectile_config` (`Player.gd:733-738`) | **DEAD via other buffs / on melee** | `requires_ability: "overcharge"` + `requires_weapon_tags: ["projectile"]` |

## Section 2 — Mis-gated commons (NEW findings, FIX in A1)

All three carry a copy-paste `requires: ["projectile"]` that doesn't match their effect.

| Mutation (id) | apply | current `requires` | effect (global getter) | problem | recommended gate |
|---|---|---|---|---|---|
| Move Speed (`move_speed`) | passive | `["projectile"]` | `get_move_speed_bonus` (`:221`) | melee build (Tank+Whirlwind, no `projectile`) never offered a universal move-speed common | `requires: []` (universal) |
| Wide Pulse (`wide_pulse`) | ability | `["projectile"]` | `get_ability_area_multiplier` (`:203`), applied in `_build_runtime_ability` to only `radius`/`orbit_radius`/`distance` (`CoopManager.gd:473`) | three faults: (a) gated on an unrelated weapon tag; (b) even "universal" it is **dead for kits with no area ability** (e.g. Tank: Dash+Overcharge+Blood Lance — none of those keys); (c) misses area keys `trail_radius`/`spread_radius`/`explosion_radius`/`attack_radius`/`trigger_radius`/`ignite_radius`/`impact_pool_radius` | **`area_scalable` treatment (like Duration), NOT blind universal:** flag area abilities; offer iff kit has one; scale the full area-key set; verify each flagged ability changes behavior |
| Duration (`duration`) | ability | `["projectile"]` | `get_ability_duration_multiplier` (`:215`), applied in `_build_runtime_ability` where `scales_duration = type != instant/movement` (`CoopManager.gd:466`) → scales **every** sustained ability incl. Turret + ults | availability keys off weapon tag; effect over-broad | **offer:** kit has a `duration_scalable` ability; **effect:** multiply only `duration_scalable` abilities (Orbit → `orbit_lifetime`, not slot-active `duration`) |

## Section 3 — Class ability-rares: precision tightens (APPROVED for A1, 2026-07-14)

These are correctly class-gated, but their functional tag can match >1 ability in the class pool, so
`get_ability_rare_effects` injects their params into sibling same-tag abilities (currently an inert leak — the
sibling ignores the extra param). **DECISION (approved): tighten in A1** via `requires_ability` for cleanliness.

| Mutation | class+tag | intended ability | also injected into | A1 gate |
|---|---|---|---|---|
| Implosion (`implosion`) | mobile+blast | Momentum Burst (`pull_force`) | Shockwave (also `blast`) | `requires_ability: "momentum_burst"` |
| Legion (`legion`) | controller+summon | Summon (`construct_count_bonus`) | turret/minefield/orbit | `requires_ability: "summon"` |
| Aegis (`aegis`) | controller+buff+summon | Reinforce (`shield_amount`) | other buff+summon combos | `requires_ability: "reinforce"` |

(Verified
single-ability and thus already FINE: `resonance`→sonic_boom, `vampiric_wake`→afterburn, `shattering_quake`→
quake, `bloodletting`→blood_lance, `napalm`→fireball, `static_field`→arc_wand, `wide_cyclone`→whirlwind.)

## Section 4 — Fine as-is (no change)

Weapon effects (`ricochet`, `piercing_rounds`, `fire_trail`, `freeze_shot`, `poison`) — correctly `projectile`
gated, read by id in `get_compiled_weapon_stats`. Element signatures (`accelerant`, `ember_spread`,
`pyromaniac`, `chain_reaction`, `momentum_surge`, `cryo_shatter`, `virulent`) — tag gated, fine. Class passives
(`overclocked`, `flow_state`, `kinetic_charge`, `peak_pierce`, `gorge`, `overflow`, `combustion`,
`thermal_surge`, …) — class gated, fine. Generic-by-design class rares (`executioner`, `chain_explosion`,
`backdraft`, `inferno`, `empowerment`, `beacon`, `overgrowth`) — intended to apply across their tag. `tough`,
`glass_cannon` — universal, fine. `quick_reflexes` — universal, with a hardcoded Risk exclusion in
`_can_still_pick` (`:314`); leave.

---

## Section 5 — Runtime support required before the data gates work (A1)

Data-only gate edits are insufficient — the system must learn two new keys, honored in **both** offer and effect:

1. **`requires_ability: "<id>"`**
   - *Offer:* in `_mutation_requirements_met` (`:324`), if present, require that ability id to be equipped
     (check `inventory.get_ability_ids()` / `RunState.get_ability`).
   - *Effect:* in `_mutation_targets_item` (`:395`) / `get_ability_rare_effects` (`:180`), if present, inject the
     mutation's params **only** into the matching ability id — not every same-tag ability.
2. **`requires_weapon_tags: ["<tag>", ...]`**
   - *Offer:* in `_mutation_requirements_met`, require the active weapon (`RunState.get_weapon`) to carry all
     listed tags. (Used by Piercing Overdrive.)
3b. **`area_scalable` eligibility** (Wide Pulse) — mirror of `duration_scalable`.
   - Add an `area_scalable: true` flag to abilities with a meaningful area; **A1** flags the eligible non-Orbit
     area abilities (Shockwave, Shield, Minefield, Momentum Burst, Deflect, Ground Slam, Quake, Reinforce,
     Afterburn, Summon, Fireball, Ignite — verify each). *Offer:* Wide Pulse eligible iff the kit has ≥1
     `area_scalable` ability. *Effect:* expand the `_build_runtime_ability` area loop (`CoopManager.gd:473`) from
     `[radius, orbit_radius, distance]` to also include `trail_radius, spread_radius, explosion_radius,
     attack_radius, trigger_radius, ignite_radius, impact_pool_radius`; only scale keys the ability actually has.
     (Orbit already scales via `orbit_radius` — no lifetime coupling, so no B dependency here.)

3. **`duration_scalable` eligibility** (Duration)
   - Add a `duration_scalable: true` flag to the qualifying abilities in `data/abilities.json` — **A1:** Afterburn,
     Quake, Shield, Overcharge. **Slice B (atomic):** Orbit, together with its `orbit_lifetime` stat + node expiry.
     Turret only if its node lifetime is ever wired to duration (not planned).
   - *Offer:* Duration eligible iff the kit has ≥1 `duration_scalable` ability.
   - *Effect:* in `_build_runtime_ability` (`CoopManager.gd:466`), replace `scales_duration = type !=
     instant/movement` with a `duration_scalable` check (A1); the Orbit special-case that multiplies
     `orbit_lifetime` (new stat) instead of slot-active `duration` (`:472`) is added in Slice B.

## Acceptance criteria (A1)

- **Data:** `data/mutations.json` — `blink_twin_charge` removed; `turret_twin`/`mf_extra_mines`/`orbit_expanding`/
  `dash_shockdash`/`sw_resonance`/`shield_aegis_burst` gain `requires_ability`; `oc_piercing_overdrive` gains
  `requires_ability` + `requires_weapon_tags`; **Tier 3** `implosion`/`legion`/`aegis` gain `requires_ability`
  (momentum_burst/summon/reinforce); `move_speed` → universal (`requires: []`); `wide_pulse` → `area_scalable`
  eligibility + expanded area-key set; `duration` re-gated to `duration_scalable`. `data/abilities.json` gains
  `duration_scalable` + `area_scalable` flags. All JSON parses.
- **Runtime:** `requires_ability` and `requires_weapon_tags` honored in offer AND effect paths; Duration effect
  gated by `duration_scalable`.
- **Behavior checks (temp headless script or manual):**
  - Tank(Orbit, no Turret/Minefield) is NOT offered Twin Turret / Extra Mines; IS offered Expanding Orbit only
    if Orbit equipped.
  - Mobile(Slipstream, no Dash) is NOT offered Shockdash.
  - Non-Shockwave-blast build is NOT offered Shockwave Resonance.
  - Deflect-without-Shield build is NOT offered Aegis Burst.
  - Piercing Overdrive offered only with Overcharge AND a projectile weapon; absent on melee Whirlwind.
  - Twin Charge absent from all pools.
  - Melee Tank IS offered Move Speed (universal). Wide Pulse offered only when the kit has an `area_scalable`
    ability and scales that ability's area keys; a no-area kit (e.g. Tank: Dash+Overcharge+Blood Lance) is NOT
    offered Wide Pulse.
  - Duration offered only when a `duration_scalable` ability is equipped; multiplier changes Afterburn/Quake/
    Shield/Overcharge uptime and does NOT alter Turret/ult behavior. (**Orbit's `duration_scalable` +
    `orbit_lifetime` land atomically in Slice B** — Orbit's Duration behavior is verified there, not A1, so A1
    never ships a Duration card whose Orbit effect is a no-op.)
- **Regression:** headless parse + Bootstrap smoke boot pass; a run can roll upgrade cards without error.
