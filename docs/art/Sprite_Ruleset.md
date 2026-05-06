# Sprite Ruleset

All sprites must follow these rules to maintain visual consistency and integrate cleanly into gameplay.

## Visual Language

- **Style**: Rubberhose-inspired 2D cartoon with thick black outlines
- **Perspective**: Shallow 3/4 top-down gameplay view (slightly elevated, looking slightly downward)
- **Colors**: Flat, bold, readable first — no gradients, no shading
- **Outline thickness**: Consistent thick black outline on all shapes
- **Background**: Transparent (no fill, no pattern)
- **Details**: Minimal, cartoonish — no realistic rendering, no tiny details

## Size and Format

All sprites must be:
- **Format**: PNG with transparent background
- **Color space**: sRGB
- **No anti-aliasing**: Crisp pixel edges only
- **Pivot**: Center of the sprite (for rotation/animation)

### Dimensions by Category

| Category | Dimensions | Notes |
|----------|-----------|-------|
| Player | 128×128 | Body only, no weapon |
| Weapon | 64×64 | Single weapon, attachable |
| Enemy | 128×128 | Full silhouette |
| Boss | 256×256 | Larger scale |
| Pickup | 48×48 | Gold, food, etc. |
| Objective | 96×96 | Generators, destructibles |
| Projectile | 32×32 | Bullets, grenades in flight |
| Secondary visual | 64×64 | Mine, grenade at rest |

## Character Design Rules

### Player

- Single body shape, no weapon
- Color: Player-specific (P1: teal, P2: magenta, P3: yellow, P4: orange)
- Must be readable at 128×128 from top-down view
- Silhouette must fit inside the circular hitbox (diameter ~100px)
- Weapon is attached separately in-engine

### Enemies

Enemies have strong silhouettes to read at a glance:

- **Chaser** (small, red): Dart or arrow shape, pointed forward
- **Spitter** (medium, magenta): Hexagon or blob with mouth opening
- **Charger** (large, brown): Wedge or shield shape, boxy
- **Boss** (oversized, crimson): Crown or spike pattern, unmistakably larger

Each enemy must read distinctly by shape first, color second.

### Weapons

Weapons are separate from the player body:

- **Rifle**: Linear, barrel-forward
- **Scatter**: Wide, gun-like
- **Slug**: Heavy, compact
- **Grenade** (thrown): Round, spiky, explosive look
- **Cluster Grenade**: Multiple bumps, explosive look
- **Siege Grenade**: Large, heavy, slow-moving explosive
- **Mine** (placed): Round, dome-shaped, with proximity indicator
- **Shrapnel Mine**: Spiky mine variant
- **Heavy Mine**: Large, reinforced mine variant

## Naming Convention

All filenames follow this pattern:

```
<category>_<name>.png
```

Examples:
- `player_p1.png` (player body)
- `enemy_chaser.png` (Chaser silhouette)
- `weapon_rifle.png` (Rifle)
- `grenade_standard.png` (Standard grenade thrown)
- `mine_standard.png` (Standard mine placed)
- `pickup_gold.png` (Gold pickup)
- `objective_generator.png` (Generator)

## What to Avoid

- ❌ Realistic rendering or textures
- ❌ Tiny details (they disappear at gameplay scale)
- ❌ Backgrounds or patterns
- ❌ Text or labels
- ❌ Gradients or soft shading
- ❌ Anti-aliased edges
- ❌ More than one object per file
- ❌ Non-transparent areas outside the sprite shape

## Approval Criteria

A sprite is approved when:

1. ✅ It matches the visual language (rubberhose, thick outline, flat color)
2. ✅ Silhouette is readable at gameplay view angle and scale
3. ✅ Transparency is clean (no white halos, no soft edges)
4. ✅ Dimensions match the category spec
5. ✅ Filename follows the naming convention
6. ✅ It reads correctly when scaled in-engine (test at 1x and 2x scale)

## Integration Notes

- Player and enemy sprites are owned by the graphics layer and loaded at startup
- Weapon sprites are attachable and positioned by the weapon attachment system
- All sprites are loaded from `assets/sprites/<category>/` at runtime
- Godot scales sprites to match hitbox dimensions; sprites are not clipped or distorted
