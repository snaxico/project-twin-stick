# V3 Economy and Encounter Design

## Status

Design document. Not yet implemented. All values are placeholders for balancing later.

Implementation plan: [v3-economy-implementation-plan.md](v3-economy-implementation-plan.md)

## Context

The v3 prototype validated the core auto-attack loop (rifle + shockwave + dash + mutations). First playtest and GF test both approved the baseline feel. This document captures the next layer: economy, encounter structure, progression, and shops.

## Problem Statement

The current v3 loop has structural issues:

1. **Running away is viable.** Survive mode ends on a timer. A player who dodges for 60 seconds wins the room without fighting.
2. **Mutations are free.** Every room awards a mutation pick regardless of performance. Passive play is rewarded equally.
3. **No economy.** There is no resource earned from combat. Nothing ties killing to progression.
4. **Room variety is limited.** Only Survive and Hold Zone exist. Hold Zone conflicts with kill-based incentives because standing still in the zone is optimal.

This document resolves all four by introducing a gold economy, restructuring encounters, and tying all progression to earned gold.

---

## Core Principles

- One universal room goal: **Survive**. Room variety comes from encounter types, modifiers, and enemy composition, not competing objectives.
- One currency: **Gold**. Dropped by enemies on kill. Spent on mutations and shop services.
- All progression is primarily earned. No free mutations. Gold is the main progression driver.
- A small flat survival bonus (placeholder: 20g) is awarded on room clear to prevent hard-bricking runs after one bad room. This is a safety net, not a reward for passive play.
- Harder routes pay more because the encounters are actually harder, not because of arbitrary node labels.
- Keep the upgrade language simple: **Mutations** (run upgrades) and **Gold** (currency). Avoid piling on terms like perks, relics, traits, augments.
- **Abilities** (weapon, primary skill, secondary skill) and **Mutations** (run upgrades that modify abilities) are conceptually separate systems.

---

## Gold Economy

### Drops

- Enemies drop gold on death as a visible pickup (glowing coin/orb, distinct from projectiles).
- Gold does NOT decay. It stays on the ground until collected.
- Gold has a magnetic pull radius (~80px). Walking near gold snaps it to the player.
- All remaining gold on the ground is auto-collected when the room clears.
- Gold persists across rooms. Unspent gold carries forward.

### Placeholder Drop Values

| Enemy Type | Gold Dropped |
|------------|-------------|
| Chaser | 3-5 |
| Charger | 8-12 |
| Elite / Mini-boss | 25-40 |
| Boss | 0 (reward is winning the run) |

These values are placeholders. Balance after playtesting.

### Spending

Gold is spent in two contexts:

1. **Room-end mutation picks** (after every combat room)
2. **Shop nodes** (dedicated map nodes)

Details for each are described in their own sections below.

### Economy Loop

```
Kill enemies --> Gold drops --> Collect gold --> Spend on mutations --> Get stronger --> Kill more
```

The economy is self-reinforcing. Aggressive play earns more gold, buys more mutations, makes future rooms easier. Passive play earns less gold, buys fewer mutations, falls behind enemy scaling.

### Survival Bonus

Every room clear awards a small flat gold bonus (placeholder: 20g) on top of kill-earned gold. This prevents a single bad room from hard-bricking a run. Even a struggling player or weaker co-op partner earns enough baseline gold to stay in the game.

The survival bonus is a safety net, not a primary income source. An aggressive player earns 100-250g per room from kills; the 20g bonus is marginal. A passive player earns only the 20g bonus and falls behind, but does not hit a zero-progression wall.

All bonus values are placeholders. Balance after playtesting.

### Soft Punishment for Passive Play

There is no hard kill gate. Survive = room clear regardless of kills. The gold economy is the soft incentive:

- Running away = few kills = mostly just the survival bonus = fewer mutations
- Fewer mutations = less power scaling = harder next room
- Aggressive play earns 5-10x more gold than passive play

The economy punishes avoidance naturally without adding explicit kill requirements. The survival bonus ensures the punishment is a gradual fall-behind, not an instant death spiral.

---

## Encounter Model

### Map Structure

The run map uses a connected node-map (already built in RunFlow). Players choose their route through the map. Each node has an encounter type visible before selection.

### Node Types

| Type | Icon | Challenge | Gold Yield |
|------|------|-----------|------------|
| **Combat** | Sword | Standard enemies + modifier. May include a minor anchor threat. | Low-Medium |
| **Elite** | Skull | Tougher enemies + complex modifier + elite mini-boss. | Medium-High |
| **Rest** | Heart | No combat. Healing opportunity. | 0 |
| **Shop** | Coin | No combat. Spend gold on curated mutations, healing, rerolls. | 0 |
| **Boss** | Crown | End-of-run boss fight. | 0 |

Only these five node types exist on the map. Hazards (fire floor, corruption, etc.) are room modifiers applied to Combat or Elite nodes, not a separate node type.

### Encounter Composition

Each Combat or Elite encounter is composed of:

| Layer | Description |
|-------|-------------|
| **Enemy package** | Which enemy types spawn and in what mix (chaser-heavy, charger-heavy, mixed). |
| **Modifier** | Arena behavior change (fire floor, directional spawns, ice zones, etc). |
| **Anchor threat** | Optional mini-boss or elite enemy that anchors the room identity. More common in Elite nodes. |
| **Side challenge** | Optional bonus objective (hold a zone, collect something, etc). Rewards bonus gold. Not required to clear the room. |

Room identity comes from the combination of these layers. A "fire floor + charger pack + bruiser anchor" feels completely different from "directional spawns + chaser swarm + no anchor."

### Encounter Authoring

Encounters are authored combinations, not random rolls. Each encounter template defines:

- Enemy types and weights
- Which modifier(s) apply
- Whether an anchor threat is present and which type
- Whether a side challenge is available
- Approximate gold yield range

The encounter deck for each run is procedurally assembled from these templates, constrained by:

- Every run has a mix of Combat and Elite nodes
- Elite nodes appear in mid-to-late rows
- At least one Rest node is guaranteed reachable
- At least one Shop node is guaranteed reachable
- Boss node is always the final row
- No back-to-back identical encounter templates

### Dynamic Reward Scaling

Gold yield is not fixed per node type. It scales dynamically based on actual encounter difficulty:

- Tougher enemy types drop more gold per kill
- Elite anchors drop significantly more gold
- More enemies = more total gold available
- Modifiers apply a gold multiplier to all drops in the room, reflecting increased difficulty:
  - No modifier: 1.0x
  - Minor modifier (directional spawns, accelerating waves): 1.15x
  - Major modifier (fire floor, corruption zones, ice zones): 1.3x
  - Stacked modifiers (elite with two): multiply both

A Combat node with an easy modifier and chasers-only yields less gold than a Combat node with fire floor and mixed chargers. An Elite node with a bruiser anchor and complex modifiers yields the most. The reward reflects what the player actually survived.

### Finite Spawn Budget

Survive rooms always run the full 60-second timer. There is no early clear. Enemies spawn continuously until the timer ends. Strong builds kill faster, more enemies spawn to fill the gap, and they earn more gold. Weak builds kill slower and earn less. Players cannot extend or shorten rooms. Gold yield per room is roughly predictable by depth:

- Early rooms (~depth 1-2): ~20-25 enemies, ~80-120g potential from kills
- Mid rooms (~depth 3-4): ~30-35 enemies, ~120-180g potential from kills
- Late rooms (~depth 5+): ~35-40 enemies, ~180-250g potential from kills

These ranges do not include the flat survival bonus. All values are placeholders.

---

## Modifiers

### Role

Modifiers are a major source of room identity. They change arena behavior and force different positioning decisions within the universal Survive framework.

Modifiers are authored encounter properties, not random noise. Each encounter template specifies which modifier(s) apply.

### Modifier Directions

| Modifier | Effect |
|----------|--------|
| **Fire Floor** | Sections of the floor deal damage over time. Forces players to manage safe zones. |
| **Ice / Slow Zones** | Areas of the arena slow player movement. Punishes bad positioning. |
| **Directional Spawns** | Enemies only enter from one or two sides. Creates a frontline and a safe side. |
| **Corruption Zones** | Areas of the arena are hostile. Standing in them is dangerous but may be required for side challenges. |
| **Accelerating Waves** | Enemy spawn rate increases over the room duration. Pressure builds toward the end. |

More modifiers can be added later. The system is data-driven (loaded from encounter definitions).

### Modifier Stacking

Elite encounters may combine two modifiers for higher difficulty (e.g., fire floor + directional spawns). Combat encounters typically use one modifier or none.

---

## Room-End Mutation Picks

### Flow

1. Room clears (survive timer ends)
2. All remaining gold on the ground is auto-collected
3. Mutation pick screen appears
4. Screen shows: total gold available, 3 random mutation options, cost per pick
5. Player buys 0, 1, 2, or 3 mutation picks depending on available gold
6. Unspent gold is banked for future rooms/shops
7. Advance to map, pick next node

### Mutation Pick Costs (Placeholder)

| Pick | Cost |
|------|------|
| 1st mutation | 15 gold |
| 2nd mutation | 50 gold |
| 3rd mutation | 100 gold |

Costs scale per pick within a single room-end screen. Costs reset each room (the 1st pick is always 15, even if you bought 3 last room).

Room-end mutation picks are intentionally cheap. They are the **primary** use of gold and the main progression path. Even a mediocre room should yield enough gold for 1 pick. All cost values are placeholders for balance tuning.

### Co-Op

Gold pickups are shared: when any player collects a gold pickup, the full amount is added to **every** player's wallet. Each player has their own personal gold total and picks mutations independently at the room-end screen.

This means:
- No stealing. Every pickup benefits all players equally.
- No routing arguments. It does not matter who physically collects the gold.
- Personal spending agency. Each player decides what to buy with their own wallet.
- One set of gold pickups on the ground. No per-player colored drops. Clean visuals.

---

## Shops

### Role

Shops provide build-shaping and support services. They complement room-end mutation picks but serve a different purpose:

- Room-end picks: random mutations, always available after combat, steady progression
- Shops: curated selection, targeted purchases, support services, build direction

### Shop Services

| Service | Description |
|---------|-------------|
| **Curated mutations** | Browse a selection of specific mutations. Buy exactly what you want. |
| **Healing** | Restore HP. Costs gold. |
| **Reroll** | Pay to reroll the available mutation selection. |
| **Consumables** | One-use items (TBD). Design later. |

### Shop Economy

- Shop purchases cost gold (same currency as room-end picks)
- Visiting a shop costs a node on the map (opportunity cost: you're not fighting an Elite for more gold)
- Shop nodes do not award gold (no combat)

### Spending Hierarchy

Room-end mutation picks are the **primary** use of gold. Shops are the **secondary/luxury** use. This is enforced through pricing:

- Room-end picks are cheap (15 / 50 / 100 gold)
- Shop mutations are expensive (placeholder: 80-150 gold each)
- Shop healing is moderate (placeholder: 40 gold)
- Shop rerolls are cheap (placeholder: 20 gold)

The natural spending pattern is: spend most gold at room-end for steady progression, arrive at shops with leftover gold, buy targeted upgrades or healing if affordable. Players should never feel "wrong" for spending at room-end. Hoarding for shops is a deliberate advanced strategy, not the default.

All shop prices are placeholders. Balance after playtesting.

### Design Constraint

The run must not depend entirely on visiting shops. A player who skips all shops and only does combat should still progress through room-end mutation picks. Shops add flexibility and optimization, not mandatory progression.

---

## Abilities

### Definition

Abilities are the player's active kit pieces:

- **Weapon** (auto-attack): currently Rifle
- **Primary skill**: currently Shockwave (RT / Space)
- **Secondary skill**: currently Dash (LT / B / Ctrl)

### Abilities vs Mutations

| | Abilities | Mutations |
|---|-----------|-----------|
| **What** | Kit pieces (weapon, skills) | Run upgrades that modify abilities |
| **When acquired** | Pre-run loadout selection | During run (room-end picks, shops) |
| **Persistence** | Permanent unlocks (meta progression) | Run-only (reset each new run) |
| **Examples** | Rifle, Beam, Shockwave, Teleport, Dash, Shield | Pierce, Ricochet, Split Shot, Rapid Fire, Shockwave Radius |

### Current Prototype State

The prototype uses a fixed loadout:

- Weapon: Rifle (auto-attack, 3 shots/sec)
- Primary skill: Shockwave (5s cooldown, 250px radius, 950 knockback)
- Secondary skill: Dash (5s cooldown, movement burst)

This is the default starting loadout. It is NOT the permanent universal kit. Future work will add alternative abilities unlocked through meta progression.

### Acquisition Model

**Prototype direction: Pre-run loadout (Option A). Not locked — revisit after playtest.**

- Abilities are unlocked permanently through meta progression (completing runs, achievements, milestones)
- Before each run, the player selects their loadout from unlocked abilities
- During the run, abilities cannot be swapped. Mutations modify the chosen abilities.
- The in-run economy (gold) only buys mutations and shop services, not abilities.

**Fallback plan:** If playtesting reveals pre-run loadout feels too static, switch to a hybrid model (Option C) where unlocked abilities can also appear in shops during the run for in-run acquisition. This does not require architectural changes — it only adds abilities to the shop item pool.

---

## Side Challenges (Optional Objectives)

### Role

Side challenges are optional bonus objectives available in some Combat and Elite rooms. They provide extra gold but are not required to clear the room.

### Design Constraints

- Side challenges must not conflict with the kill economy. The player should never feel punished for completing a side challenge.
- Side challenges should be completable WHILE fighting, not instead of fighting.
- Side challenges are authored per encounter template, not randomly assigned.

### Possible Side Challenge Directions

| Challenge | Description |
|-----------|-------------|
| **Hold Zone** | Stand in a marked area for X seconds total (not consecutive). Gold bonus on completion. |
| **Beacon Defense** | Keep enemies away from a beacon for X seconds. Gold bonus if beacon survives. |
| **Collection** | Gather X special pickups that spawn around the arena. Gold bonus on completion. |

Side challenges are a future design task. The economy and encounter system work without them. They are an additive layer for skilled/aggressive players.

---

## Run Structure Summary

A typical run looks like this:

```
[Combat] -> [Combat] -> [Elite] -> [Rest] -> [Shop] -> [Combat] -> [Elite] -> [Boss]
    |            |           |                              |           |
  ~100g       ~120g       ~250g        heal     spend     ~130g      ~280g
  1-2 mut     1-2 mut     2-3 mut                         1-2 mut    2-3 mut
```

- 5-7 pre-boss rooms plus one boss room
- Mix of Combat and Elite encounters
- At least one Rest node reachable
- At least one Shop node reachable
- Player chooses route on the map
- Harder routes (more Elites) yield more gold and more mutations
- Easier routes (more Combat, Rest) yield less gold but more safety

### Power Curve Target

- Room 1: 3 shots/sec, single orb, ~100 gold earned, 1-2 mutations. Manageable.
- Room 3: rapid fire + pierce, ~150 gold earned, 4-6 total mutations. Feeling strong.
- Room 5+: split shot + ricochet + fire trail, ~200+ gold earned, 8-12 total mutations. Screen is chaos.
- Boss: full build, huge auto-attack, shockwave for emergencies. Power fantasy payoff.

---

## Open Items

| Item | Status | Notes |
|------|--------|-------|
| Gold drop values per enemy type | Placeholder | Balance after playtesting |
| Mutation pick costs (15/50/100) | Placeholder | Balance after playtesting |
| Survival bonus (20g) | Placeholder | Balance after playtesting |
| Shop item prices (80-150g mutations, 40g heal, 20g reroll) | Placeholder | Balance after playtesting |
| Modifier detailed design | Future | Authored per encounter, not random |
| Mini-boss / elite enemy archetypes | Future | Need 3-4 archetypes minimum |
| Side challenge implementation | Future | Additive layer, not required for core loop |
| Shop node implementation | Future | Curated mutations + healing + rerolls. Node type defined, implementation deferred. |
| Meta progression / ability unlocks | Future | Pre-run loadout selection (prototype direction, not locked) |
| Ability variety (beyond rifle/shockwave/dash) | Future | New weapons and skills |
| Consumable design | Future | One-use shop items, TBD |
| 3-4 player economy scaling | Deferred | Validate 1-2 player first |
