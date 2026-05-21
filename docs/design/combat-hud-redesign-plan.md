# Combat HUD Redesign Plan

## Scope Note

- This file describes the active combat HUD redesign direction on `v2/core-refactor`.
- This is a design and implementation plan only. It does not change the live runtime by itself.

## Problem

The current combat HUD has two competing failures:

- the old corner HUD asks the player to look too far away from the fight
- the rejected replacement tried to solve that with more boxes near the player, which created overlap, noise, and a stronger "HUD panel" feeling

Playtest takeaway:

- the combat HUD should feel less like UI furniture
- the combat HUD should feel more embedded in the action
- player-critical information should be readable without covering the fight

## Design Goal

Replace combat panels with minimal combat indicators.

The new rule is:

- player-owned combat state should read as part of the player space
- shared run state should stay on the screen frame
- the combat layer should show signal, not inventory

This is a readability pass, not a feature-count pass.

## Core Decision

Do **not** replace the old corner HUD with another box-based mini HUD.

Instead:

- keep shared room info on the screen frame
- move only the most important player data into lightweight diegetic indicators
- remove framed combat panels, inventory strips, and card-like widgets from active combat

## What Stays On The Screen Frame

These remain fixed and global:

- top center:
  - room timer
  - current objective
  - hold-zone progress / active buff message
- top right:
  - active room modifiers
- top left:
  - compact gold strip

These are shared-information problems, not player-space problems.

## What Moves Into Player Space

These should become minimal player-attached combat indicators:

1. health
2. shockwave cooldown
3. dash cooldown
4. downed / revive readability

These should **not** stay in the live combat layer:

- weapon slots
- mutation chips
- large player labels
- inventory panels
- build summary text

Those belong in:

- map
- shop
- mutation pick
- pause / summary screens

## Visual Direction

The target feeling is:

- subtle
- geometric
- quiet in the normal state
- louder only when something matters

The combat HUD should feel like combat feedback, not menu UI.

Rules:

- no framed player cards
- no visible inventory boxes in active combat
- no long labels like `Shockwave` / `Dash`
- use shape language, fill, and glow instead of text whenever possible
- keep default opacity low and let urgency drive emphasis

## Player-Space Indicator Design

### Health

Health should be the most stable always-on player indicator.

Recommended first-pass form:

- a thin horizontal HP bar attached to the player space
- centered above the player body
- width: `36-48px`
- height: `4-6px`

Behavior:

- full / healthy: quiet
- damaged: brief brightness spike
- low HP: stronger saturation and subtle pulse
- downed: HP bar no longer behaves like a normal health read

Why a bar, not a big ring:

- a thin bar reads faster
- it occupies less visual area
- it overlaps less in co-op

### Shockwave Cooldown

Shockwave should read as a player-owned radial ability, not a slot icon.

Recommended form:

- outer cooldown arc or segmented ring around the player
- anchored to the player body, not to a box above it
- slightly larger than the body silhouette

Behavior:

- cooling down: partial arc fill
- ready: brief highlight pulse, then quiet ready state
- activation: strong expanding feedback already exists in the skill itself

### Dash Cooldown

Dash should read separately from shockwave without demanding another panel.

Recommended form:

- inner arc, short lower-body arc, or paired chevron marks near the player
- smaller and lighter than the shockwave indicator

Behavior:

- cooling down: partial fill or dim arc
- ready: brief readiness flash
- active dash window: use the dash shield / trail visuals as the dominant effect

### Ownership / Player Identity

If needed, ownership should be communicated by:

- player tint
- tiny marker notch or dot

Avoid:

- large `P1`, `P2`, `P3`, `P4` text in active combat unless testing proves it is necessary

## Downed / Revive State

Downed state must break the quiet default language.

Recommended form:

- the normal HP bar / cooldown indicators collapse into a much louder downed signal
- revive progress should appear as a single readable progress shape

Priority:

- nearby teammate must instantly notice who is downed
- revive progress must be readable without looking to a corner panel

Recommended first-pass shape:

- large red / white ring or pulse under or around the downed player
- revive progress fills that same shape

Do not solve this with a text-heavy floating panel.

## Gold Treatment

Gold still matters, but it should not live in player space.

Recommended treatment:

- compact top-left strip
- one short line per player for `1-2` players
- later expand to a compact `2 x 2` grid if local `4P` returns

Example:

- `P1 120g`
- `P2 95g`

Gold is an economy read, not a dodge-time read.

## 2-Player Layout

For the current live target:

- both players use the same player-space indicator set
- there are no corner-owned player cards in combat
- the only frame HUD elements are timer, objective, modifiers, and gold

This gives the largest readability win with the least screen pollution.

## 4-Player Future-Safe Rules

This direction should still hold if the game later supports `4` local players.

Why it scales better:

- boxes do not scale well in the same-screen co-op camera
- floating bars and arcs can stay small
- player attention is already on the avatar, not a dedicated corner

Future-safe rules:

- keep player-space indicators physically small
- keep normal-state opacity restrained
- rely on state-based emphasis instead of permanent brightness
- avoid systems that require a dedicated screen corner per player

## Overlap Rules

Because this is same-screen co-op, overlap will happen.

The solution is not a bigger panel.

The solution is:

- keep indicators small
- keep indicators body-adjacent
- make default state quiet
- make urgent states louder

Recommended overlap policy:

- health bar stays short and thin
- cooldown arcs stay close to the body radius
- do not offset indicators into separate stacked widgets during normal movement
- if readability still suffers, reduce indicator thickness before adding more layout complexity

## Relationship To Existing HUD Scripts

### Keep

- current timer / objective HUD
- current modifier chip HUD
- compact gold display on the frame
- `PlayerInventoryHUD.gd` for non-combat contexts if needed

### De-Emphasize In Combat

- `PlayerInventoryHUD.gd`
- `WeaponSlotHUD.gd`

These should stop being the active combat read.

### Add

- a lightweight player-space combat-indicator component

Suggested script name:

- `scripts/ui/PlayerCombatIndicator.gd`

This should not be a mini inventory panel. It should be a very small visual-state component.

## Recommended Runtime Structure

### New Component

`scripts/ui/PlayerCombatIndicator.gd`

Responsibilities:

- draw the small HP bar
- draw shockwave readiness / cooldown state
- draw dash readiness / cooldown state
- draw downed / revive state
- stay visually quiet by default

### CoopManager Ownership

`CoopManager.gd` should:

- keep building the frame HUD for shared room state
- build one lightweight player combat indicator per player
- feed it health, cooldown, and downed/revive state

### Positioning

The component should be attached to player space, not implemented as a large screen-space plate.

Recommended first pass:

- HP bar above player body
- shockwave arc around the player
- dash arc or chevron indicator closer to the body

## Implementation Plan

### Slice A: Strip Combat HUD Back To Essentials

Goal:

- remove combat inventory thinking before adding new visuals

Files:

- `scripts/game/CoopManager.gd`
- possibly `scripts/ui/PlayerInventoryHUD.gd`

Work:

- reduce active combat HUD to timer, objective, modifiers, and compact gold
- stop treating weapon slots and mutation chips as live combat requirements

Verification:

- parse check
- confirm no critical combat information is lost except the deliberately removed inventory detail

### Slice B: Add Health-Only Player Indicator

Goal:

- validate the most important player-space read with minimal noise

Files:

- new `scripts/ui/PlayerCombatIndicator.gd`
- `scripts/game/CoopManager.gd`

Work:

- add only the thin HP bar above the player first
- keep it very small and quiet
- add low-HP emphasis

Verification:

- parse check
- live test with `1P` and `2P`
- confirm this already feels better than both the corner panel and the boxed mini HUD direction

### Slice C: Add Shockwave Cooldown Arc

Goal:

- make primary-skill timing readable without panel UI

Files:

- `scripts/ui/PlayerCombatIndicator.gd`

Work:

- add outer shockwave cooldown arc
- add ready pulse

Verification:

- parse check
- confirm skill timing is readable while moving and fighting

### Slice D: Add Dash Cooldown Arc / Chevron

Goal:

- complete the player-space ability read

Files:

- `scripts/ui/PlayerCombatIndicator.gd`

Work:

- add a smaller dash indicator with distinct visual language from shockwave

Verification:

- parse check
- confirm both cooldowns can be told apart instantly

### Slice E: Add Downed / Revive State

Goal:

- make co-op recovery readable without bringing back panels

Files:

- `scripts/ui/PlayerCombatIndicator.gd`
- `scripts/game/CoopManager.gd`

Work:

- replace normal player-space read with a stronger revive-state read when downed

Verification:

- parse check
- force a downed state and confirm revive target readability

## Non-Goals

- no new combat inventory panel
- no screen-corner player cards
- no detailed weapon / mutation HUD in active combat
- no split-screen assumptions
- no `4P` implementation in this pass

## Success Criteria

The redesign is correct if:

- players no longer need to scan a corner panel for basic survival reads
- the combat layer feels less like UI and more like feedback
- overlap is lower than the rejected boxed mini HUD attempt
- `2P` readability improves without making the screen feel busier

## Recommendation

Do not implement this as one full HUD rewrite.

Implement it in the order above:

1. reduce the frame HUD
2. validate health-only player indicators
3. add one cooldown layer at a time
4. only then add revive-state emphasis

The key is to make the combat HUD feel smaller than the current one, not smarter than it.
