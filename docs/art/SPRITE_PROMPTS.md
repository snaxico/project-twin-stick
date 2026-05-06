# Sprite Generation Prompts

Use these templates when requesting sprites from ChatGPT. Fill in the bracketed fields and paste into a new ChatGPT web chat window.

## Setup (do this first in every new chat)

```
Use these sprite generation rules:
- rubberhose-inspired 2D cartoon
- shallow 3/4 top-down gameplay view
- thick black outline
- flat colors, no gradients
- readable first
- transparent background
- one sprite per file
- minimal details
- no text, no background, no realistic rendering

Generate sprites at these sizes:
- Player: 128×128
- Weapon: 64×64
- Enemy: 128×128
- Boss: 256×256
- Pickup/secondary: 48×48
- Objective/generator: 96×96

Reference style: [paste URL of an approved sprite, e.g., player_p1.png]
```

## Player Sprite

```
Create one sprite:
Category: player
Filename: player_p2.png
Gameplay role: second player avatar
Perspective: shallow 3/4 top-down
Size: 128×128
Color: Magenta/pink
Silhouette: Simple cartoon humanoid, small and readable
Must include: clear top-down outline, no weapon attachment, distinct from player 1
Must exclude: weapon, armor, complex details, white background, soft edges
```

## Enemy Sprites

### Chaser

```
Create one sprite:
Category: enemy
Filename: enemy_chaser.png
Gameplay role: fast, small homing enemy
Size: 128×128
Shape/silhouette: Small dart or pointed arrow shape
Color: Bright red
Must include: pointed forward shape, small readable form, speed visual
Must exclude: legs, wings, complex anatomy, realistic features
```

### Spitter

```
Create one sprite:
Category: enemy
Filename: enemy_spitter.png
Gameplay role: ranged enemy that fires projectiles
Size: 128×128
Shape/silhouette: Medium hexagon or blob with a mouth/opening
Color: Magenta
Must include: visible mouth or opening for projectile, medium size, organic blob shape
Must exclude: legs, wings, eyes, realistic features
```

### Charger

```
Create one sprite:
Category: enemy
Filename: enemy_charger.png
Gameplay role: large, slow, heavy melee enemy
Size: 128×128
Shape/silhouette: Large brown wedge or shield shape, boxy and heavy
Color: Dark brown
Must include: large readable form, heavy/solid appearance, charging position
Must exclude: legs, wings, realistic features, complex anatomy
```

### Boss

```
Create one sprite:
Category: boss
Filename: boss_main.png
Gameplay role: final boss, intimidating and unmistakably large
Size: 256×256
Shape/silhouette: Oversized crimson crown or spike pattern, symmetrical
Color: Crimson red
Must include: crown-like or spike structure, large scale, boss-level presence
Must exclude: realistic features, tiny details, non-transparent areas
```

## Weapon Sprites

### Rifle

```
Create one sprite:
Category: weapon
Filename: weapon_rifle.png
Gameplay role: primary weapon, standard hitscan rifle
Size: 64×64
Shape/silhouette: Linear gun shape with barrel pointing right
Color: Steel grey with dark accents
Must include: clear barrel direction, compact form, gun-like silhouette
Must exclude: realistic details, stock, scope, wood texture
```

### Scatter

```
Create one sprite:
Category: weapon
Filename: weapon_scatter.png
Gameplay role: primary weapon, wide spread shotgun
Size: 64×64
Shape/silhouette: Wide, splayed gun shape with multiple barrel openings
Color: Steel grey with orange accents
Must include: wide spread appearance, multiple barrel openings, compact form
Must exclude: realistic details, wood texture, tiny details
```

### Slug

```
Create one sprite:
Category: weapon
Filename: weapon_slug.png
Gameplay role: primary weapon, heavy single-shot cannon
Size: 64×64
Shape/silhouette: Heavy, compact, barrel-forward cannon shape
Color: Dark grey with metallic accent
Must include: heavy/solid appearance, single large barrel, compact form
Must exclude: realistic details, ammo belts, tiny details
```

## Secondary Sprites (Grenades)

### Standard Grenade

```
Create one sprite:
Category: secondary
Filename: grenade_standard.png
Gameplay role: thrown explosive, arcing projectile
Size: 64×64
Shape/silhouette: Round or ovoid with spiky protrusions
Color: Olive green
Must include: explosive appearance, round form, spiky or knobbed texture
Must exclude: realistic rendering, fuse details, tiny features
```

### Cluster Grenade

```
Create one sprite:
Category: secondary
Filename: grenade_cluster.png
Gameplay role: thrown explosive that splits into submunitions
Size: 64×64
Shape/silhouette: Bumpy cluster shape with multiple protrusions
Color: Olive green with yellow highlights
Must include: clustered/bumpy appearance, explosive look, multiple bumps
Must exclude: realistic rendering, tiny fuse, sub-grenades visible
```

### Siege Grenade

```
Create one sprite:
Category: secondary
Filename: grenade_siege.png
Gameplay role: thrown explosive, heavy slow-moving variant
Size: 64×64
Shape/silhouette: Large, angular, fortress-like explosive shape
Color: Dark grey with red bands
Must include: heavy appearance, angular/armored look, larger than standard
Must exclude: realistic details, moving parts, tiny features
```

## Secondary Sprites (Mines)

### Standard Mine

```
Create one sprite:
Category: secondary
Filename: mine_standard.png
Gameplay role: placed proximity explosive, defensive tool
Size: 64×64
Shape/silhouette: Dome or mushroom shape with flat base
Color: Matte black
Must include: dome/mushroom shape, stable placement look, proximity indicator ring (subtle)
Must exclude: realistic rendering, buried appearance, spikes
```

### Shrapnel Mine

```
Create one sprite:
Category: secondary
Filename: mine_shrapnel.png
Gameplay role: placed proximity explosive with shrapnel effect
Size: 64×64
Shape/silhouette: Dome with spiky protrusions
Color: Matte black with grey spikes
Must include: spiky appearance, dome base, shrapnel-like spikes
Must exclude: realistic details, buried look, movement indicators
```

### Heavy Mine

```
Create one sprite:
Category: secondary
Filename: mine_heavy.png
Gameplay role: placed proximity explosive, tank variant
Size: 64×64
Shape/silhouette: Large reinforced dome with ribbed structure
Color: Dark grey with reinforcement bands
Must include: heavy/armored appearance, ribbed or segmented structure, stable base
Must exclude: realistic details, movement, tiny features
```

## Pickup Sprites

### Gold Pickup

```
Create one sprite:
Category: pickup
Filename: pickup_gold.png
Gameplay role: collectable currency, shared team reward
Size: 48×48
Shape/silhouette: Coin or treasure shape
Color: Bright gold/yellow
Must include: recognizable coin or gem form, shiny appearance, readable at small scale
Must exclude: realistic details, shadows, non-transparent areas
```

### Food Pickup

```
Create one sprite:
Category: pickup
Filename: pickup_food.png
Gameplay role: collectable health restore, shared team reward
Size: 48×48
Shape/silhouette: Simple food item (apple, bread, etc.)
Color: Red or warm earth tone
Must include: recognizable food form, healing visual, readable at small scale
Must exclude: realistic rendering, plate/dish, non-transparent background
```

## Objective Sprites

### Generator

```
Create one sprite:
Category: objective
Filename: objective_generator.png
Gameplay role: destructible objective, spawn source for enemies
Size: 96×96
Shape/silhouette: Machine or tower shape with a glowing core
Color: Neutral grey with glowing core (green or yellow)
Must include: machine-like appearance, clear core/weak point, readable destruction target
Must exclude: realistic industrial details, tiny components, non-transparent areas
```

## Projectile Sprites

### Standard Bullet

```
Create one sprite:
Category: projectile
Filename: projectile_bullet.png
Gameplay role: primary weapon projectile, hitscan visual
Size: 32×32
Shape/silhouette: Small round or teardrop shape
Color: Yellow or bright colour to contrast with arena
Must include: bright, readable form, motion-forward appearance
Must exclude: complex details, trails, tiny features
```

## Variant Template (when creating alt colors/sizes)

```
Create one sprite:
Category: [category]
Filename: [filename]
Gameplay role: [description]
Size: [WxH]
Color: [color description]
Shape/silhouette: [silhouette description]
Must include: [required visual elements]
Must exclude: [what to avoid]
Reference style: [URL of approved sprite to match]
```
