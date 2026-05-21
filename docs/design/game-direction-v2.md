# Game Direction v2

## Status

- This file is a historical design document.
- It captures an earlier direction that fed into `v2/core-refactor`.
- Do not use it as the source of truth for the current runtime.
- Use these instead for active work:
  - `docs/development/current-state.md`
  - `docs/development/start-of-day.md`
  - `docs/design/roadmap.md`
  - `docs/process/architecture.md`

## One-Line Pitch

Co-op arena roguelite where your weapon visibly mutates every room and each room gives you a different job to do while surviving.

## The Feel

Brain-off flow state. Kill stuff, get stronger, watch your weapon become ridiculous. No hard decisions. Every upgrade is good. The fun is the snowball.

## Reference Mix

- **Brotato** — wave structure, camera zoom model, baseline combat feel
- **Slay the Spire** — loot drops after fights + shop nodes on the map
- **Deep Rock Galactic: Survivor** — side objectives while you survive
- **Gauntlet** — directional twin-stick combat, point at danger, things die
- **Vampire Survivors** — power fantasy snowball, screen fills with your effects
- **Everything is Crab** — visible mutations, multiple playstyles from upgrades

## Core Loop

1. Pick a room on the node map
2. Room starts — enemies spawn, objective is active
3. Player fights enemies while working toward the objective
4. Room clears — each player picks 1 mutation from 3 options (independently)
5. Back to map — pick next room, enemies scale, but you're stronger
6. Repeat until boss

## Combat

- Directional Gauntlet-style: point the stick toward danger, attacks go that way
- Heavy aim assist by default, full auto-aim as accessibility option, manual aim as skill option
- 1 primary weapon + 1 secondary ability per player — both can mutate
- Mostly melee enemies — dodge bodies, not bullets
- Very few ranged enemies — screen stays clean
- Skill expression comes from: positioning, dash timing, secondary timing, target priority, objective pressure, co-op revive decisions
- NOT from precise aiming

## Upgrades / Mutations

- Primary weapon and secondary ability both mutate over the run
- Every upgrade is always positive — no trap picks, no sidegrades
- Upgrades are visible immediately — ricochet, pierce, fire trail, chain lightning, split shots, bigger projectiles
- No percentage stat math — no "+12% fire rate"
- By late run the weapon should look and feel completely different from room 1
- The variety between runs comes from which mutations stacked, not from deliberate build planning
- Slay the Spire reward model:
  - after each room: each player independently picks 1 of 3 mutation cards
  - on shop nodes: buy mutations from a larger selection with gold

## Room Objectives

Every room is "survive + do something." The combat stays the same, the task changes.

Start with 2-3 objectives, add more later:
- **Survive** — pure wave clear, baseline
- **Hold Zone** — capture and hold an area while enemies contest it (already partially built as capture_the_hill)
- **1 more TBD** — collect, protect, destroy targets, or hunt — pick after core works

The side objective is what creates positioning decisions. "Enemies left, objective right — do I push now?"

## Arena

- Bigger than current — roughly 2-3x current size
- Open — no obstacle layouts for now (removed, revisit later if needed)
- Big enough that objectives in different corners feel like a trip
- Small enough that you can reach your partner in a few seconds
- Camera zooms in when players are close, zooms out when they spread apart
- Hard zoom-out limit acts as the natural arena boundary / player leash

## Enemies

Stripped to core for now, add back others later:
- **Chaser** — small, fast, melee fodder. Dies quick. Fills space.
- **Charger** — winds up, charges, punish the recovery. Breaks kiting.
- **Boss** — end-of-run fight.
- Spitter and Bruiser removed from active roster. May return later.

## Difficulty

- Scales with room depth on the map, NOT with time
- No timer pressure punishing the player for being slow
- Player power grows faster than enemy difficulty
- Deaths happen from mistakes, not from the game outscaling you
- The power curve should feel like winning an arms race

## Co-Op

- Same-screen, no split screen
- 1-2 players primary target (up to 4 later)
- Both players snowball together
- Each player picks their own mutations independently — no loot competition
- Co-op splits naturally through objectives — "I cover left, you do the objective"
- No coordination required, it just happens
- Revive flow creates natural tension moments

## Run Structure

- Keep the current connected node-map progression (RunFlow)
- Player picks a path through rooms on the map
- Each room is one arena encounter with an objective
- After each room: each player picks 1 of 3 mutations independently
- Shop nodes exist on the map for buying from a larger mutation selection
- Rest nodes can still exist
- A run is roughly 10-15 minutes
- Early rooms: weak but manageable, getting first mutations
- Mid rooms: build coming online, feels good
- Late rooms: strong, enemies tougher but player is winning
- Boss room: ridiculous power, screen is chaos, this is the payoff

## Long-Term Progression

- Removed for now — no meta progression until the core run is fun
- Future: unlock starting weapons + mutation pools between runs

## HUD

- Minimal: health + current weapon + current secondary + mutation icons
- Keep the screen clean — combat readability is priority

## Visual Direction

- Not pixel art
- 2D top-down
- Clean, readable — you should always know what's happening
- Weapon mutations are the star visually
- Enemies read by silhouette first
- Arena stays neutral so combat reads clearly

## The GF Test

A non-gamer should be able to:
- Pick up a controller and be useful in 5 seconds
- Understand what's happening by watching
- Feel stronger every 60 seconds
- Laugh at how ridiculous the screen looks by the boss room
- Want to play again

---

## Migration Plan — What Changes

### KEEPS (works as-is or with minor tweaks)

| System | Files | Notes |
|--------|-------|-------|
| Run map / node progression | `RunFlow.gd`, `RunFlow.tscn` | Core room-to-room flow stays. Rethink later, don't touch now. |
| Player movement / dash | `Player.gd`, `Dash.gd`, `Player.tscn` | Stays. |
| Aim assist | `AimAssist.gd` | Stays, central to new direction. |
| Juice stack | `ParticleFactory.gd`, `ScreenShake.gd`, `ScreenEffects.gd`, `SfxEngine.gd`, `FloatingText.gd`, `HealthBarHUD.gd` | All stays. |
| Projectile base | `Projectile.gd`, `Projectile.tscn` | Stays as foundation for weapon mutations. |
| Bootstrap / settings | `Bootstrap.gd`, `Bootstrap.tscn` | Menu shell stays. Simplify pre-run setup. |
| Capture hill zone | `CaptureHillZone.gd` | Stays as one objective type. |
| Encounter builder | Debug launcher | Keep and adapt to new systems for testing. |

### HEAVY REFACTOR (concept stays, implementation changes)

| System | Files | What Changes |
|--------|-------|-------------|
| Room combat manager | `CoopManager.gd`, `GameWorld.tscn` | Strip: obstacle layouts, recipe selection, loot drop flow, shop flow, multi-weapon execution. Add: bigger arena, zoom camera, objective assignment, wave-end mutation pick. |
| Run state | `RunState.gd` | Strip: 2+2 weapon slots, passive compilation, tag filtering, shop offers. Replace: 1 primary + 1 secondary per player, mutation list. |
| Player inventory | `PlayerInventory.gd` | Simplify from 2+2 slots to 1 primary + 1 secondary + mutation list. |
| Combat HUD | `PlayerInventoryHUD.gd`, `WeaponSlotHUD.gd` | Minimal: health + weapon + secondary + mutation icons. |
| Weapon data | `data/weapons.json` | Starting weapon definitions only. Remove level-up tiers. |
| Enemy roster | `Enemy.gd`, `data/enemies.json` | Keep Chaser + Charger + Boss only. Disable/remove Spitter + Bruiser for now. |

### OBSOLETE (remove or archive)

| System | Files | Why |
|--------|-------|-----|
| Recipe engine | `RecipeEngine.gd`, `data/recipes.json` | Objectives replace recipes. |
| Modifier engine | `ModifierEngine.gd`, `data/modifiers.json` | Removed. May return later. |
| Layout / obstacle spawning | Logic inside `CoopManager.gd` | Open arena only. Revisit later. |
| Hot floor hazard | `HotFloorZone.gd` | Tied to modifiers. Obsolete. |
| Death puddle hazard | `DeathPuddle.gd` | Tied to modifiers. Obsolete. |
| Generator objectives | `GeneratorObjective.gd`, `GeneratorObjective.tscn` | Fully cut. |
| Loot drop / vote | `LootDrop.gd`, `LootDrop.tscn`, `LootVoteUI.gd`, `LootVoteUI.tscn` | Replaced by per-player mutation pick screen. |
| Weapon replacement UI | `WeaponReplaceUI.gd`, `WeaponReplaceUI.tscn` | No multi-weapon slots. |
| In-world shop | `ShopStation.gd`, `ShopStation.tscn`, `ShopUI.gd`, `ShopUI.tscn` | Shop redesign deferred. |
| Mine projectile | `MineProjectile.gd`, `MineProjectile.tscn` | May return as mutation. |
| Grenade projectile | `GrenadeProjectile.tscn` | May return as mutation. |
| Passive trigger system | `PassiveTriggerSystem.gd`, `data/passives.json` | Replaced by mutation system. |
| Meta progression | `ProfileState.gd` (meta gold/unlock logic) | Removed for now. Shell stays. |
| Balance docs | `docs/design/weapons-passives-balance.xlsx`, `docs/design/enemies-arenas-modifiers-balance.xlsx` | Multi-weapon/recipe/modifier balance obsolete. |
| Items data | `data/items.json` | Obsolete. |
| Unlocks data | `data/unlocks.json` | Deferred with meta progression. |

### NEW SYSTEMS NEEDED

| System | Description |
|--------|-------------|
| Zoom camera | Brotato-style: zoom in when close, zoom out when apart, hard limit as arena leash. |
| Bigger arena | 2-3x current size, open, no obstacles. Bounds tied to camera zoom limit. |
| Mutation system | Definitions, visual application to weapon/secondary, stacking, always-positive. |
| Mutation pick screen | After each room: each player independently picks 1 of 3 mutations. |
| Mutation data | New `data/mutations.json` defining mutations and their effects. |
| Objective system | Per-room objective assignment. Start with survive + hold zone. |

### BUILD ORDER

1. **Zoom camera + bigger arena** — spatial foundation, everything depends on it
2. **Strip to 1 primary + 1 secondary** — simplify inventory, get clean combat working
3. **Strip enemies to Chaser + Charger + Boss** — remove Spitter/Bruiser from spawns
4. **Minimal HUD** — health + weapon + secondary + mutations
5. **Mutation system + pick screen** — the new upgrade loop
6. **Objective variety** — add hold zone alongside survive
7. **Adapt encounter builder** — test rooms with new systems
8. **Tune the loop** — enemy pacing, power curve, run length

## Open Questions

- What is the player character? (mage, warrior, creature, abstract?)
- What are the starting weapons? (1 primary + 1 secondary to begin with)
- What are the first 5 mutations to build?
- Shop design — what do you buy, how does gold work?
- Does the arena change between rooms or stay the same shape?
- Art style direction?
- What is the third objective type?
