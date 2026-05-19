# Game Direction v3 — Neon Roguelite

## One-Line Pitch

Neon co-op roguelite where your character auto-attacks and you focus on movement, positioning, and watching your build snowball into screen-filling chaos.

## The Feel

You're a glowing shape in a dark arena. Enemies swarm from the edges. Your weapon fires by itself — your job is to move. Weave through gaps, kite clusters, dash out of danger, shockwave when they close in. Every room you pick a mutation and your auto-attack gets crazier. By the boss room the screen is a light show and you're at the center of it. Brain off, flow state, power fantasy.

## Reference Mix

- **Vampire Survivors** — auto-attack escalation, visible power snowball, brain-off gameplay
- **Brotato** — wave structure, camera zoom, build variety through upgrades
- **Geometry Wars** — neon aesthetic, abstract shapes, clean visual language, screen-filling chaos
- **Deep Rock Galactic: Survivor** — side objectives while you survive
- **Slay the Spire** — mutation pick model (1 of 3 after each room)

## Core Loop

1. Pick a room on the node map
2. Room starts — enemies spawn, objective is active
3. Auto-attack fires at nearest enemy. You focus on dodging and positioning.
4. Trigger shockwave for crowd control moments. Dash to reposition.
5. Room clears — game pauses, each player picks 1 mutation from 3 options (independently)
6. Room auto-advances to map — pick next room, enemies scale, but you're stronger
7. Repeat until boss

## Combat

### Weapon (Auto-Attack): Rifle

- Fires automatically at the nearest enemy. Always. No trigger, no aiming.
- Player controls movement (left stick), primary skill (RT), and secondary skill (LT / B)
- Baseline: ~3 shots/sec — slow, chunky, each orb feels impactful
- Bolt visual: glowing dot/orb that flies toward the target
- Perfectly accurate at baseline — no spread. Mutations like split_shot add spread.
- Targeting: **pure nearest** — fires at closest enemy in weapon range (950px)
- The weapon is the main mutation target — it starts as a single weak orb and snowballs
- Fire rate, projectile count, pierce, ricochet, trails — all visible, all stacking
- The player never thinks about aiming. They think about where to stand.

### Primary Skill: Shockwave

- Expanding ring/pulse centered on the player that pushes + damages everything nearby
- Fully player-centered (offset = 0). No directional aiming — blast radiates equally in all directions.
- Triggered by **RT** (gamepad) or **Space** (keyboard P2)
- Also mutates but separately from the weapon (bigger radius, more damage, slow effect)
- Used for: panic button, cluster clear, objective pressure, boss damage windows

**Locked primary skill (shockwave) stats:**
- Cooldown: **5 seconds** — available for most dangerous moments, can't spam
- Blast radius: **~250px** — clears the immediate threat bubble around the player
- Knockback force: **950** — primary purpose is space creation, damage secondary
- Damage: **30** per hit
- Behavior: **damage + strong knockback** — sends enemies flying
- Expansion: ring expands outward over ~0.15s (not instant, but fast)
- Does NOT damage through arena walls
- Knockback direction = away from player center
- Mutations can affect: radius, cooldown, damage, add effects (slow, burn, stun)

### Secondary Skill: Dash

- Quick burst of movement in the current move direction
- Triggered by **LT / B** (gamepad) or **Ctrl** (keyboard P2)
- Cooldown: **5 seconds** (separate from primary skill cooldown)
- Uses `_move_facing` direction — always dashes where the player is moving
- Primary and secondary skill cooldowns are fully independent

### Why This Works

- Solves the "twin-stick aiming isn't satisfying" problem — you barely aim at all
- All skill expression is positioning: where do I stand relative to enemies, objectives, partner?
- Mutations are instantly visible because auto-attack is constant — every upgrade changes what you see on screen immediately
- Co-op splits naturally: two auto-attack circles covering different angles
- Passes the GF test hard: pick up controller, move around, things die

### What Creates Tension

- Enemy density and variety — chasers swarm, chargers punish bad positioning
- Objective pressure — "enemies left, capture zone right, where do I go?"
- Revive decisions in co-op — partner is down, enemies are between you
- Primary skill cooldown — it's not ready, enemies closing in, gotta kite
- Secondary skill cooldown — can't reposition instantly, have to weave manually
- NOT: precise aiming, ammo management, weapon swapping, build math

## Upgrades / Mutations

- Weapon and skills both mutate over the run
- Every upgrade is always positive — no trap picks, no sidegrades
- Upgrades are VISIBLE immediately:
  - Bolt count: 1 → 3 → 5 projectiles
  - Pierce: bolts pass through enemies
  - Ricochet: bolts bounce between targets
  - Fire trail: bolts leave burning ground
  - Chain: bolts arc to nearby enemies on hit
  - Split: bolts fragment on hit
  - Size: bolts get physically bigger
  - Speed: fire rate visibly increases
- No percentage stat text — the player SEES the difference, doesn't read it
- By late run the weapon should look and feel completely different from room 1
- Slay the Spire reward model:
  - After each room: each player independently picks 1 of 3 mutation cards
  - On shop nodes: buy mutations from a larger selection with gold (design TBD)

## Visual Direction — Neon Geometric

### The Style

- Dark background, neon everything
- Grid floor (already built) is the arena foundation
- Grid and wall colors shift per room depth — deeper rooms get warmer/more intense
- Player is a **chevron/arrow** pointing in move direction, P1 cyan, P2 magenta
- Auto-attack bolts are **glowing orbs** — small, bright, round
- Enemies are distinct shapes — **triangles** swarm, **pentagons** charge, big **star/crown** is the boss
- Mutations add visible layers — more orbs, colored trails, orbit effects
- Screen shake + bloom + particle bursts on kills = juice
- Audio: punchy arcade SFX — crisp pops, crunches, dings on every hit and kill

### Why Neon Geometric

- Zero art asset dependency — everything is code (Polygon2D, Line2D, particles, shaders)
- Already halfway there — current enemies and arena use this style
- 30+ enemies stay readable because silhouettes are distinct
- Mutations are instantly readable — more lines, more glow, more trails
- Proven style: Geometry Wars, Just Shapes & Beats, Thumper

### Future Art Pivot

- Visual layer is fully swappable — Polygon2D → Sprite2D/AnimatedSprite2D
- Gameplay code doesn't reference visuals directly
- Rubberhose style is the intended future direction — thick outlines, bouncy squash-and-stretch, bold shapes
- Shares DNA with geometric: simple silhouettes, strong readability, exaggerated motion
- Plan: validate fun with neon shapes → art-pass to rubberhose when the game proves itself
- Estimated pivot effort: ~1 week once sprites exist

## Arena

- Large open space (currently 4800x2700, may adjust)
- Dark floor with neon grid lines
- Glowing wall boundaries
- No obstacle layouts for now (revisit later)
- Camera zooms in when players are close, zooms out when apart
- Hard zoom-out limit acts as player leash in co-op
- Arena is a playground for movement — no dead corners, enemies approach from all edges

## Enemies

Core roster — add more later once these feel right:

- **Chaser** (triangle) — small, fast, melee. Swarms in numbers. The fodder that makes auto-attack feel good. Dies in 1-3 hits.
- **Charger** (pentagon) — winds up with a telegraph, dashes through you. Punishes standing still. Forces repositioning.
- **Boss** (large star/crown) — end-of-run fight. Fires projectile bursts. Has phases or escalating patterns.
- Spitter and Bruiser code removed. Recoverable from git history if needed later.

## Room Objectives

Every room is "survive + do something." Auto-attack handles the fighting. The objective creates the positioning decisions.

- **Survive** — flat 60-second timer. Enemies scale with room depth, not with time in room. Baseline mode.
- **Hold Zone** — capture and hold a glowing area. Progress only increases while player is inside the zone. Does NOT decrease when enemies enter. Do you stay in the zone or kite away to survive?
- **TBD third** — collect pickups, protect a target, destroy nodes, hunt a mini-boss. Decide after core works.

## Difficulty

- Scales with room depth, NOT with time spent in a room
- No timer pressure punishing slow players
- Player power grows faster than enemy scaling
- Deaths happen from positioning mistakes, not from being outscaled
- The power curve should feel like winning an arms race
- Easy mode: full heal after every room (already built)

## Co-Op

- Same-screen, no split screen
- 1-2 players primary target (up to 4 deferred)
- Both players auto-attack independently — two kill circles covering the arena
- Each player picks their own mutations — builds diverge naturally
- Co-op coordination happens through positioning, not communication
- Revive flow: stand near downed partner to revive — creates risk/reward moments
- Primary skill coordination: "I'll blast left cluster, you handle right"

## Run Structure

- Connected node-map progression (RunFlow — already built)
- Player picks a path through rooms on the map
- Each room is one arena encounter with an objective
- After each room: mutation pick screen (1 of 3, per player)
- Rest nodes for healing
- A run is roughly 10-15 minutes
- Power curve: weak → coming online → strong → ridiculous → boss payoff
- **Shop nodes are deferred** — not in the v3 vertical slice. Gold economy + shop UI added later once the room → mutation pick core loop validates.

## HUD

- Minimal and neon-styled to match the aesthetic
- Health bar (glowing, matches player color)
- Primary skill + secondary skill cooldown indicators
- Small mutation icons showing current build
- Room objective + progress indicator (timer bar or capture %)
- Keep the screen CLEAN — combat readability is the priority

## The GF Test

A non-gamer should be able to:
- Pick up a controller, move around, enemies die. Immediate understanding.
- Never touch the triggers and still be useful (weapon auto-fire carries)
- Use the primary skill trigger when they're ready — natural skill progression
- Feel stronger every 60 seconds from mutations
- Laugh at the screen by the boss room
- Want to play again

---

## Migration Plan — What Changes from v2

### Already Done (from v2 refactor)
- Zoom camera, bigger arena, grid floor
- 1 primary + 1 secondary per player
- Chaser + Charger + Boss only
- Mutation system + pick screen
- Hold zone objective
- Encounter builder adapted
- Obsolete v1 systems archived

### v3 Changes (all implemented)

| Change | Status |
|--------|--------|
| Weapon auto-fire — auto-targeting nearest enemy, no trigger input | ✅ Done |
| AimAssist.gd → AutoTarget.gd — repurposed for weapon targeting | ✅ Done |
| Primary skill (shockwave) — expanding ring/pulse, 5s cooldown, 950 knockback, centered on player | ✅ Done |
| Secondary skill (dash) — movement burst on LT/B (gamepad) or Ctrl (keyboard), separate 5s cooldown | ✅ Done |
| Player chevron visual — arrow shape, P1 cyan / P2 magenta | ✅ Done |
| Arena color shifts — grid/wall HSV hue rotation per depth | ✅ Done |
| Neon visual pass — orb projectiles, glow, particle effects | ✅ Done |
| Enemy speed rebalance — all speeds +50% from plan values | ✅ Done |
| Auto-advance after room clear — no exit zone walk | ✅ Done |
| Mutation pick pauses game | ✅ Done |
| Gold + shop system | Deferred — not in v3 vertical slice |

### Architecture (as implemented)

**What changed from v2:**
- `Player.gd` — fire input removed, auto-target + auto-fire loop, two direction vars (`_move_facing`, `_auto_attack_direction`), primary skill cooldown + signal, secondary skill (dash) cooldown, chevron visual
- `AimAssist.gd` → `AutoTarget.gd` — repurposed for weapon target acquisition (pure nearest)
- `CoopManager.gd` — primary skill blast handler + visual, arena color shifts, auto-advance room flow, mutation pick pause, GrenadeProjectile removed
- `weapons.json` — primary skill entry is shockwave (cooldown 5.0, knockback 950, radius 250, damage 30)
- `mutations.json` — `blast_radius` → `shockwave_radius`, `extra_charge` → `shockwave_cooldown`
- `RunState.gd` — default primary skill = "shockwave", move_speed = 390

**What stayed identical:**
- Mutation system, pick screen
- Run map, run state (structure)
- Enemy spawning, wave logic (structure — values retuned)
- Camera, co-op, revive
- Projectile system (still fires projectiles, just auto-aimed)

## Resolved Design Decisions

| Question | Answer |
|----------|--------|
| Player shape | **Chevron / arrow** — points in move direction, reads as fast and forward |
| Player speed | **390** — base move speed |
| Weapon bolt | **Glowing dot / orb** — round energy ball, scales well with size mutations |
| Primary skill | **Shockwave / pulse** — expanding ring centered on player, pushes + damages nearby. Fully player-centered, no directional aiming. |
| Primary skill input | **RT** (gamepad), **Space** (keyboard P2) — brain reads "attack button" |
| Primary skill cooldown | **5 seconds** — available for dangerous moments, can't spam. Mutation brings to 1s with 2 stacks. |
| Primary skill radius | **~250px** — clears immediate threat bubble. |
| Primary skill knockback | **950 force** — primary purpose is space creation. Sends enemies flying. |
| Primary skill damage | **30** — kills ~1.5 chasers per blast |
| Secondary skill input | **LT / B** (gamepad), **Ctrl** (keyboard P2) — separate from primary skill |
| Secondary skill cooldown | **5 seconds** — separate from primary skill cooldown |
| Weapon spread | **No spread** — perfectly accurate at target. Mutations (split_shot) add spread instead. |
| Baseline fire rate | **~3 shots/sec** — slow, chunky, each shot feels impactful. Big headroom for fire rate mutations. |
| Arena visual variety | **Color shifts per room** — grid and wall colors change with depth via HSV hue rotation. Deeper = warmer/more intense. |
| Audio direction | **Punchy arcade** — crisp retro-inspired SFX. Satisfying pops, crunches, dings. Impact over atmosphere. |
| Third objective | **Deferred** — get Survive and Hold Zone feeling good first, then decide. |
| Shop design | **Gold from kills, spend at shop nodes** — deferred from v3 vertical slice. Added later once core loop validates. |
| Co-op player identity | **Same chevron shape, different color** — P1 cyan, P2 magenta. Clear, simple. |
| Weapon targeting | **Pure nearest** implemented. Directional-nearest can be added later if needed (recoverable from git). |
| Survive duration | **Flat 60 seconds** — all depths. Difficulty comes from enemy scaling, not longer timers. |
| Hold zone contest | **No contest** — progress only increases when player in zone, never decreases. |
| Room clear flow | **Auto-advance** — no exit zone walk. Room clears → mutation pick (game pauses) → next room. |
| Enemy speeds | **+50% from original plan** — Chaser 292.5, Charger 247.5, Boss 157.5 |
