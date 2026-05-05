# Sprite Ruleset

## Purpose
Create consistent, readable prototype sprites for a local co-op action roguelite.

## Core Principle
**Readable first. Stylish second. Detailed last.**

The sprite system must support:
- fast recognition in couch co-op
- same-role players
- modular weapon swapping
- simple AI-assisted generation
- low production cost for the prototype

---

## 1. Global Style

- **Style:** rubberhose-inspired cartoon
- **Tone:** friendly, playful, non-horror
- **Shapes:** rounded, soft, bouncy
- **Limbs:** tubular arms and legs
- **Outlines:** thick black outer outline
- **Shading:** flat colors + max 1 shadow tone
- **Detail level:** low; large readable shapes only
- **Rendering:** clean 2D game sprite, not painterly, not realistic
- **Priority:** gameplay readability over visual richness

---

## 2. View / Camera

- **View:** shallow 3/4 top-down gameplay view
- **Not allowed:** pure top-down, pure side view, isometric
- Sprites must read clearly in a fixed-room arena
- Character face/body should still be visible enough to show personality

---

## 3. Resolution / Canvas

### Character sprites
- **Canvas:** 128x128 px
- **Fill:** character fills ~80% of canvas height
- **Center:** sprite centered on canvas, slight vertical offset allowed for grounding

### Weapon sprites
- **Canvas:** 64x64 px
- **Fill:** weapon fills ~70% of canvas width (right-facing)
- **Pivot area:** rear/handle sits near the left-center of the canvas

### Projectile sprites
- **Canvas:** 32x32 px
- **Fill:** projectile fills ~60-70% of canvas

### Pickup / loot sprites
- **Canvas:** 48x48 px
- **Fill:** icon fills ~70% of canvas

### Enemy sprites
- **Canvas:** 128x128 px for normal enemies, 256x256 px for boss
- **Fill:** enemy fills ~75% of canvas (boss fills ~85%)

### Secondary weapon sprites (grenade, mine as world objects)
- **Canvas:** 48x48 px
- **Fill:** object fills ~65% of canvas

### Generator / objective sprites
- **Canvas:** 96x96 px
- **Fill:** object fills ~80% of canvas

### Rules
- All canvases use transparent background
- Sprites are always centered unless noted otherwise
- Final in-engine scale is handled by Godot, not baked into sprite size
- Export as individual PNG files, one sprite per file

---

## 4. Modularity Rule

### Locked Rule
**Characters and weapons are separate sprites.**

### Character sprite includes
- head
- torso
- arms
- legs
- hands/gloves
- shoes
- face
- simple clothing/accessories

### Character sprite excludes
- any primary weapon
- any secondary weapon
- muzzle flash
- projectile effects

### Weapon sprite includes
- weapon body
- visible front / muzzle direction
- readable handle / rear area
- same visual style as the character

### Weapon sprite excludes
- hands
- arms
- character body
- projectile effects
- background

---

## 5. Weapon Attachment Rule

### Locked Rule
**Weapons float slightly near the forward hand. They do not need to be physically gripped.**

Reason:
- easier modular setup
- easier AI generation
- easier weapon swapping
- better for prototype scope

### Technical convention
- all weapon sprites are generated **right-facing**
- weapon rotates in-engine toward aim direction
- projectiles spawn from a separate muzzle marker

### Recommended Godot hierarchy
```text
Player
  BodySprite
  WeaponPivot
    WeaponSprite
    MuzzleMarker
```

---

## 6. Animation Rule

### Current scope: static sprites only

All sprites are single static frames. Design every pose so it works as:
- a standalone static sprite during prototype phase
- keyframe 1 of a 2-frame idle bounce if animation is added later

### Pose guidance
- Characters: slight asymmetry in pose (one arm forward, weight shifted) so a simple scale-bounce reads as idle animation
- Enemies: lean or tilt that communicates movement intent even when static
- Weapons: horizontal rest pose that works when rotated 360 degrees

### Future animation (not current scope)
When animation is added, the target is 2-frame flipbook per state (idle, move, hit). Sprites should not have poses that make this impossible (no extreme perspective, no complex overlapping limbs).

---

## 7. Color Reference

### Player colors (accent/tint — body is recolored per player)
| Player | Color | RGB |
|--------|-------|-----|
| P1 | Green | `(0.2, 0.85, 0.2)` |
| P2 | Blue | `(0.2, 0.45, 1.0)` |
| P3 | Yellow | `(0.95, 0.82, 0.22)` |
| P4 | Orange | `(1.0, 0.56, 0.2)` |

### Enemy colors
| Type | Color Name | RGB |
|------|------------|-----|
| Chaser | Red | `(1.0, 0.2, 0.15)` |
| Spitter | Magenta | `(0.82, 0.18, 0.88)` |
| Charger | Orange-brown | `(0.88, 0.44, 0.08)` |
| Boss | Crimson | `(0.72, 0.06, 0.06)` |

### Pickup colors
| Type | Color direction |
|------|----------------|
| Gold | Bright yellow |
| Food/Health | Green |

### General rule
- Base sprite is generated in a neutral gray or white accent
- Player recoloring is done in-engine via modulate/tint
- Enemy sprites are generated with their specific accent color baked in (enemies don't recolor)

---

## 8. File Format / Pipeline

### Export format
- **Format:** PNG, 32-bit RGBA
- **One sprite per file** — no sprite sheets
- **Naming:** `[category]_[name].png` (e.g., `player_base.png`, `weapon_rifle.png`, `enemy_chaser.png`, `pickup_gold.png`)

### Godot import
- Sprites import as `Texture2D` with default settings
- Filter mode: nearest (pixel-crisp at all scales)
- No atlas packing at prototype stage

### Folder structure
```text
assets/sprites/
  player/
    player_base.png
    player_recolor_p1.png  (optional — can recolor in-engine)
  weapons/
    weapon_rifle.png
    weapon_scatter.png
    weapon_slug.png
  enemies/
    enemy_chaser.png
    enemy_spitter.png
    enemy_charger.png
    enemy_boss.png
  projectiles/
    projectile_bullet.png
    projectile_enemy.png
  secondaries/
    secondary_grenade.png
    secondary_mine.png
  pickups/
    pickup_gold.png
    pickup_food.png
  objectives/
    generator.png
```
