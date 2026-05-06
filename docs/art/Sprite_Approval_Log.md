# Sprite Approval Log

Track generated sprites and their approval status.

## Approval Checklist

A sprite must pass all checks before moving to **approved**:

- ✅ Visual language matches (rubberhose cartoon, thick outline, flat color)
- ✅ Silhouette is readable at gameplay scale and view angle
- ✅ Transparency is clean (no white halos, no soft edges)
- ✅ Dimensions match category spec
- ✅ Filename follows naming convention
- ✅ Loads in Godot without scaling artifacts
- ✅ Gameplay reads correctly (color distinct, shape clear)

---

## Approved Sprites

| Sprite | Category | Status | Approved Date | Notes |
|--------|----------|--------|-----------------|-------|
| player_p1.png | player | approved | 2026-05-05 | readable, teal color, matches hitbox |

---

## In Review

| Sprite | Category | Status | Submitted | Notes |
|--------|----------|--------|-----------|-------|
| — | — | — | — | — |

---

## Rejected / Redo

| Sprite | Category | Status | Reason | Notes |
|--------|----------|--------|--------|-------|
| — | — | — | — | — |

---

## Review Notes Template

When reviewing a sprite, add a row to "In Review" with these notes:

```
Sprite: [filename]
Category: [category]
Submitted: [date]
First impression: [visual language match?]
Silhouette: [readable at scale?]
Transparency: [clean or needs cleanup?]
Dimensions: [correct size?]
Godot test: [loads and scales correctly?]
Status: [approved | redo with changes | rejected]
Changes if redo: [what to adjust]
```

---

## Approval Authority

- **User**: Final approval, can request changes or reject
- **Visual language**: Must match the rubberhose cartoon style exactly
- **Gameplay readability**: Priority over artistic perfection

---

## Integration Workflow

1. Sprite is submitted to "In Review"
2. Sprite is tested in Godot (load scene, verify scale/pivot)
3. Sprite is approved or marked for redo
4. Approved sprite is moved to `assets/sprites/<category>/`
5. Godot code is updated to reference the new sprite
6. Sprite moves to "Approved" in this log

---

## How to Request Changes

If a sprite needs tweaking (wrong size, wrong color, wrong silhouette):

1. Note the change in this log under "Redo"
2. Paste the original request + change notes into ChatGPT
3. Request a revised version
4. Move back to "In Review"

Example:

```
Changes needed for enemy_chaser.png:
- Make the dart shape more pointed (less rounded)
- Brighten the red by 20%
- Keep the size at 128×128

Regenerate with these adjustments.
```
