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

Optional objectives available in some Combat and Elite rooms. Not required to clear the room.

| Objective | Gameplay |
|---|---|
| Hold Zone | Stand in a marked area for X seconds total (not consecutive) |
| Beacon Defense | Keep enemies away from a beacon for X seconds |
| Collection | Gather X special pickups scattered around the arena |

- Authored per encounter template, not randomly assigned to rooms
- Must be completable WHILE fighting, not instead of fighting

### Temporary Buff System
**Status: Locked (design), Future (implementation)**

- Completing a side objective rewards a **random temp buff** from the pool
- Buff type is random — not tied to a specific objective type
- Player sees the buff on offer before deciding whether to attempt the objective
- Buff lasts **until room end** (not a fixed timer — completing early = more value)
- Buff is **shared across all players**
- Buff does NOT persist between rooms

**Buff Pool (3 buffs):**

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

**Status: Open — design decision needed**

How exactly does the player receive a rare mutation after clearing an elite room?

Options to discuss:
- A. Separate bonus pick screen after the normal room-end common picks
- B. One slot on the room-end pick screen is always a rare (replaces one common slot)
- C. Auto-awarded — no choice, you just get a random rare
- D. Rare mutation appears as a physical pickup in the room (collect it during combat)

---

## Tier 5: Encounter Depth

### Modifier System
**Status: Future**

Modifiers are authored encounter properties that change arena behavior. Not random noise.

| Modifier | Effect | Gold Multiplier |
|---|---|---|
| None | Standard room | 1.0x |
| Minor (directional spawns, accelerating waves) | Light pressure change | 1.15x |
| Major (fire floor, ice zones, corruption zones) | Significant positioning challenge | 1.3x |

- Combat rooms: 0 or 1 modifier
- Elite rooms: 1 or 2 modifiers (stacked multipliers)
- Authored per encounter template

### Mini-Boss / Elite Enemy Archetypes
**Status: Future**

Need 3-4 archetypes minimum to give elite rooms unique anchor threats. Not yet designed.

### Boss Redesign
**Status: Future**

Current boss is the old v2 fight shape. Needs a v3 redesign.

---

## Tier 6: Content & Meta

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

Next design topic to continue: **Tier 4 — Elite room rare mutation delivery** (options A/B/C/D above).
