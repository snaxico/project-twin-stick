# Feature Roadmap

Design decisions locked during brainstorm sessions. Use this as the source of truth before starting implementation of any new feature.

---

## Status Key

- **Locked** — Design agreed. Ready for implementation planning.
- **In Progress** — Currently being designed or implemented.
- **Placeholder** — Implemented but values need a balance pass after playtesting.
- **Future** — Agreed direction, design not yet detailed.
- **Deferred** — Not touching until earlier work validates.

---

## Tier 1: Balance (Do First)

### Gold Economy Balance
**Status: Placeholder**

All current values are placeholder. Mutations are currently too cheap. Needs a dedicated balance pass after live playtesting.

| Value | Current | Notes |
|---|---|---|
| Chaser gold drop | 3-5g | Placeholder |
| Charger gold drop | 8-12g | Placeholder |
| Survival bonus | 20g | Placeholder |
| Mutation pick cost 1 | 15g | Too cheap |
| Mutation pick cost 2 | 50g | Placeholder |
| Mutation pick cost 3 | 100g | Placeholder |
| Shop mutation cost | 80g | Placeholder |
| Shop heal cost | 40g | Placeholder |
| Shop reroll cost | 20g | Placeholder |

---

## Tier 2: Mutation Rarity Split

### Rarity System
**Status: Locked**

- **Common**: upgradable (Lv1 → Lv2 → Lv3), available from all room-end picks
- **Rare**: binary one-off, only from elite room rewards and shop purchases
- Max level for commons: **3**
- Picking a common you already own upgrades it (no separate upgrade UI)
- Room-end pick pool contains **common mutations only**
- Rare mutations are **not** in the room-end pick pool

### Common Mutations (7 total)
**Status: Locked**

All use +33.3% per level → 2.0x at Lv3, unless noted.

| ID | Name | Lv1 | Lv2 | Lv3 | Notes |
|---|---|---|---|---|---|
| `pierce` | Pierce | +1 pass-through | +2 pass-through | +3 pass-through | +1 per level |
| `rapid_fire` | Rapid Fire | 1.33x fire rate | 1.67x fire rate | 2.0x fire rate | Base 3/s → 6/s at max |
| `big_shot` | Big Shot | 1.33x hitbox size | 1.67x hitbox size | 2.0x hitbox size | No damage bonus. Bigger hitbox hits more enemies. |
| `split_shot` | Split Shot | 2 projectiles | 3 projectiles | 4 projectiles | +1 per level |
| `skill_range` | Skill Range | 1.33x skill area/range | 1.67x skill area/range | 2.0x skill area/range | Applies to ALL primary and secondary skills |
| `skill_cooldown` | Quick Reflexes | 33.3% faster cooldowns | 50% faster cooldowns | 66.6% faster cooldowns | Applies to ALL primary and secondary skills |
| `knockback` | Knockback | 1.33x push force | 1.67x push force | 2.0x push force | Base 300 → 600 at max |

**Changes from current implementation:**
- `rapid_fire`: was exponential (`pow(2.0, count)`), now linear 33.3%
- `big_shot`: damage bonus removed, size scaling now linear 33.3%
- `split_shot`: was +2 per level, now +1 per level
- `shockwave_radius` → `skill_range`: now applies to all skills, not just shockwave
- `shockwave_cooldown` → `skill_cooldown`: now percentage-based and applies to all skills
- `knockback`: was flat 300 per stack, now linear 33.3%

### Rare Mutations (3 total)
**Status: Locked**

| ID | Name | Effect |
|---|---|---|
| `ricochet` | Ricochet | Projectiles bounce to a nearby enemy on hit |
| `fire_trail` | Fire Trail | Projectiles leave a burning trail |
| `dash_damage` | Impact Dash | Dash damages enemies you pass through |

---

## Tier 3: Side Objectives + Temp Buffs

### Side Objectives
**Status: Locked (design), Future (implementation)**

Only Hold Zone objective in Tier 3 scope. Appears in all Combat and Elite rooms (1 per room).

**Hold Zone:**
- Spawns a marked zone in the arena
- Players must stand inside zone continuously for 10 seconds total
- Timer counts if ANY player is in zone (co-op timer, not per-player)
- Timer pauses if no players are in zone, resumes when player re-enters
- Enemies present/absent does NOT pause the timer
- Completable while fighting (doesn't prevent combat)

### Temporary Buff System
**Status: Locked (design), Future (implementation)**

- Completing Hold Zone rewards a **random temp buff** from pool
- Buff lasts **until player leaves the room** (room transition / exit zone)
- Buff persists even if player dies and is revived within the same room
- Buff is **shared across all players** — one Hold Zone completion = buff for all living players
- Buff does NOT persist between rooms

**Buff Pool (3 buffs, random roll on completion):**

| Buff | Value |
|---|---|
| Speed boost | +50% move speed |
| Damage boost | +50% damage |
| Attack speed boost | +50% fire rate |

All values are placeholder. Balance after playtesting.

### Three-Layer Reward Stack

| Layer | Scope | Source | Persistence |
|---|---|---|---|
| Temp buffs | Single room | Side objectives | Expires at room end |
| Common mutations | Full run | Room-end picks | Upgradable (Lv1-3), persists all run |
| Rare mutations | Full run | Elites / shops | One-off, persists all run |

---

## Tier 4: Elite Room Rare Mutation Delivery

**Status: Locked**

- Elite rooms offer **1 rare mutation** at room-end. No common mutations available.
- Combat rooms continue to offer common mutations only (buy 0–3 picks).
- Elite room-end screen shows 1 rare mutation — player buys it or skips (no multi-pick).
- Shop remains the only other source of rares (outside elite rooms).

This creates a clean three-tier system:
- **Combat** = common mutations (gradual scaling)
- **Elite** = rare mutations (build-defining one-offs)
- **Shop** = both commons and rares (gold conversion)

---

## Tier 5: Encounter Depth

### Modifier System
**Status: Locked**

Modifiers are authored encounter properties that create encounter variety. Not random noise.

#### Modifier Architecture

**Modifier Categories:**
- **Minor modifiers** (+0.15x gold): affect enemy behavior/spawning/composition
- **Major modifiers** (+0.3x gold): affect arena environment/hazards

**Room Composition:**
- Combat rooms: 0–1 minor + 0–1 major modifier
- Elite rooms: 1–2 minor + 1 major modifier
- Rest/Shop/Boss: no modifiers

**Modifier Assignment:**
- Modifiers are applied at run generation time (not per-recipe)
- Curated list of valid combinations is randomly assigned to rooms
- Gold multipliers are additive (not multiplicative)

#### Minor Modifiers (All +0.15x Gold)

| Modifier | Effect |
|---|---|
| `accelerating_waves` | Spawn intervals shrink 67% over 40 seconds, then sustained hard pressure (0.33 multiplier) until room end. Creates escalating difficulty phase. |
| `enemy_faster` | All enemies move and attack 1.33x faster. Increases pressure without adding enemy count. |
| `spitter_swarm` | Spawn pool composition becomes: 25% Chaser, 25% Charger, 50% Spitter. Adds ranged pressure alongside melee. |

#### Major Modifiers (All +0.3x Gold)

| Modifier | Effect | Cycle |
|---|---|---|
| `fire_floor` | 4 arena quadrants ignite in 10-second cycle (1s ignition → 8s burn → 1s extinguish). Players take 5 damage per tick (0.5s interval) while in flames. Zones are fixed quadrant positions. | 10s total |
| `ice_zone` | 4 arena quadrants freeze in 10-second cycle (1s formation → 8s freeze → 1s melt). Players move and attack 33% slower while in frozen zones. Zones are fixed quadrant positions. | 10s total |
| `mine_field` | 2 of 4 arena quadrants spawn mines in 10-second cycle (1s spawn anim → 8s active → 1s despawn anim). 5 mines per active quadrant. Mines explode 0.5s after player enters trigger radius, dealing 10 damage. Quadrants rotate each cycle so different zones are dangerous. Visual: light ring around active mines. | 10s total |

**Environmental Hazard Rule:**
- All environmental hazards (fire, ice, mines) do NOT affect enemies
- Enemies are immune to all arena modifier effects
- Only players interact with hazards

#### Enemy: Spitter
**Status: Locked**

Ranged enemy positioned between Chaser and Charger in power/stats.

**Stats:**
- Size: medium (between Chaser and Charger)
- Health: mid-range (between Chaser and Charger)
- Base movement speed: 20% slower than player
- Gold drop: 1g (all enemies drop 1g flat)

**Attack:**
- 1 projectile every 0.5s
- Projectile damage: same as Chaser melee hit
- Behavior: circles player to maintain distance, retreats when player approaches (ranged positioning)

**Availability:**
- Can appear from depth 1 (early game)
- Primary appearance via `spitter_swarm` modifier

#### Economy Changes (Tier 5)

**Gold Generation:**
- All enemies: 1g flat on kill (Chaser, Charger, Spitter, Boss)
- Room-clear survival bonus: removed (was 20g)
- Gold economy is now leaner, primary income from enemy kills
- Note: This is a major economy shift. Values will need live balance pass after playtesting.

**Mutation Costs (placeholder, unchanged):**
- Pick 1: 15g
- Pick 2: 50g
- Pick 3: 100g

### Mini-Boss / Elite Enemy Archetypes
**Status: Locked (see Tier 6 above)**

3 archetypes designed: melee (`elite_charger`), ranged (`elite_spitter`), support (`elite_support`).

### Boss Redesign
**Status: Future**

Current boss is the old v2 fight shape. Needs a v3 redesign.

---

## Tier 6: Elite Room Identity

**Status: Locked**

Elite rooms now have 3 unique mini-boss anchor enemies that appear exclusively in elite rooms.

**Design Approach:**

Each elite room guaranteed 1 random mini-boss + standard Chaser/Charger/Spitter spawn mix.
- Creates tiered threat hierarchy
- Gives elite rooms distinctive identity
- Mini-bosses anchored to strategic roles (melee/ranged/support)

### Elite Mini-Boss: `elite_charger` (Melee Anchor)

**Stats (all values subject to playtest/balance):**
- Visual: Yellow hexagon, 2–3x Charger size, internal visual distinctions
- Health: 1,440 HP
- Movement speed: 371.25 (Chaser-level, ~95% player speed)
- Archetype: Charger + Chaser hybrid

**Behavior:**
- Charge + Slam combo attacks
- Fast, aggressive pursuit
- Closes distance quickly

**Gold drop:** 1g

### Elite Mini-Boss: `elite_spitter` (Ranged Anchor)

**Stats (all values subject to playtest/balance):**
- Visual: Cyan hexagon, medium size, internal energy distinctions
- Health: 576 HP (~40% of melee mini-boss)
- Movement speed: Similar to Spitter, kites away
- Archetype: Stronger Spitter variant

**Behavior:**
- Primary: 3-projectile burst every 0.33s (spread pattern)
- Secondary: AoE energy pulse every 4s (~200 radius, push + small damage)
- Maintains ranged distance

**Gold drop:** 1g

### Elite Mini-Boss: `elite_support` (Support/Utility Anchor)

**Stats (all values subject to playtest/balance):**
- Visual: Purple hexagon, large-medium size, swirling aura particles
- Health: 900 HP (between ranged and melee mini-boss)
- Archetype: Support/utility focused

**Aura (continuous, ~300 radius):**
- Buffs nearby allies: +33% attack speed, +33% movement speed
- Debuffs nearby players: -33% attack speed, -33% movement speed

**Main attack (AoE pulse every 2 seconds, ~400 radius):**
- Damage to players: 15 per pulse
- Healing to allies: 20 HP per pulse
- Visual: Purple/magenta energy burst

**Positioning strategy:**
- Maintains 200–300 distance from players
- Tries to keep players *inside* pulse range with buffer zone
- Zone control, not blindly close

**Gold drop:** 1g

### Mini-Boss Appearance Rules

- Each elite room: 1 guaranteed random mini-boss (50/50/50 distribution, subject to tuning)
- Mini-bosses do NOT appear in combat (non-elite) rooms
- Spitter spawn changes in elite rooms: standard enemy pool remains Chaser/Charger/Spitter balanced mix

---

## Tier 7: Content & Meta

### Ability Variety
**Status: Future**

New weapons beyond Rifle, new primary skills beyond Shockwave, new secondary skills beyond Dash.

### Meta Progression / Ability Unlocks
**Status: Future (prototype direction locked)**

Pre-run loadout selection from permanently unlocked abilities. Currently fixed loadout.
Fallback: hybrid in-run shop acquisition (Option C) if pre-run feels too static.

### Consumable Design
**Status: Future**

One-use shop items. Design TBD.

---

## Tier 7: Scale

### 3-4 Player Economy Scaling
**Status: Deferred**

Validate 1-2 player first. Do not expand casually.

### Shop UI Polish
**Status: Future**

Current shop UI is functional but basic (list-based). Needs a proper UI pass.

---

## Session Stopped At

Next design topic to continue: **Tier 7 — Content & Meta** (Ability Variety, Meta Progression, Consumables).
