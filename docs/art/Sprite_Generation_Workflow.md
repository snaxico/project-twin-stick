# Sprite Generation Workflow

Complete step-by-step process for generating, processing, approving, and integrating sprites.

## Overview

```
ChatGPT web chat → Download → Post-process → Godot test → Approval → Integration
```

- **ChatGPT**: Image generation (using DALL-E 3)
- **Post-processing**: Remove background, resize, verify transparency
- **Godot**: Load and verify scale/pivot
- **Approval**: Check against visual language and gameplay requirements
- **Integration**: Update Godot code, add to approval log

---

## Phase 1: Prepare ChatGPT (5 min)

### Step 1a: Open a New Chat

Start a fresh ChatGPT web chat window. ChatGPT forgets style between sessions, so each batch of sprites (~5–10) gets a new chat.

### Step 1b: Paste the Style Rules

Copy the complete "Step 1" from `Sprite_Context_Short.md`:

```
Sprite generation rules:
[paste the full rules block from Sprite_Context_Short.md]
```

### Step 1c: Paste a Reference Image URL

Paste the GitHub raw URL of an approved sprite to use as a style reference:

```
Reference image (match this visual style):
https://raw.githubusercontent.com/snaxico/project-twin-stick/main/assets/sprites/player/player_p1.png
```

(Adjust the URL path based on your approved sprite location.)

### Step 1d: Confirm ChatGPT Understood

Send:

```
Use this reference image to match the visual style.
Generate sprites that follow these rules and match this reference style.
```

Wait for ChatGPT to confirm it understood the rules and reference.

---

## Phase 2: Request Sprites One at a Time (2 min per sprite)

### Step 2a: Pick a Sprite from the Backlog

Choose the next unchecked sprite from `Sprite_Backlog.md`.

Start with **projectiles and pickups** (smallest, fastest to validate).

### Step 2b: Use the Prompt Template

Find the relevant sprite template in `SPRITE_PROMPTS.md` and copy it.

Fill in all bracketed fields. Example:

```
Create one sprite:
Category: projectile
Filename: projectile_bullet.png
Gameplay role: primary weapon projectile
Shape/silhouette: small round teardrop shape
Color: bright yellow
Must include: bright readable form, motion-forward appearance
Must exclude: complex details, trails, anti-aliasing
```

### Step 2c: Paste and Send

Paste the filled-in prompt into ChatGPT and send.

### Step 2d: Download the Image

When ChatGPT generates the image, download it. Save it **temporarily** with the filename (e.g., `projectile_bullet.png`) to your Downloads folder or a temp folder — don't put it in `assets/sprites/` yet.

### Step 2e: Repeat or Continue

Generate 3–5 sprites per session, then move to Phase 3.

When the chat starts to drift in quality (after 5–10 sprites), close it and start a new chat at Phase 1.

---

## Phase 3: Post-Process Each Sprite (5 min per sprite)

**This is the critical step.** ChatGPT generates images on white/grey backgrounds. You must remove the background to get a usable PNG with transparency.

### Step 3a: Remove the Background

Use one of these tools:

**Option A: remove.bg (free, fast, online)**
- Go to https://www.remove.bg
- Upload the sprite
- Download the PNG
- Verify the background is clean

**Option B: Photoshop / Affinity Photo (professional, one-time cost)**
- Open the sprite
- Use "Select by Color" or "Magic Wand"
- Invert selection (select the background)
- Delete the background layer
- Export as PNG with transparency

**Option C: GIMP (free, open-source)**
- Open the sprite
- Select by Color tool, click the background
- Invert selection
- Delete
- Export as PNG

**Option D: Online alternative**
- Use Photopea (free web-based Photoshop clone): https://www.photopea.com
- Upload, remove background, export PNG

### Step 3b: Verify the Output

After removing the background, check:

- ✅ No white halos around the sprite
- ✅ No soft/blurry edges (should be crisp)
- ✅ Transparent areas are actually transparent (not white)
- ✅ The sprite shape is intact and not clipped

If the background removal is poor, redo it in a different tool or request a redo from ChatGPT.

### Step 3c: Resize If Needed

If ChatGPT generated at the wrong size (e.g., 512×512 instead of 128×128), resize it:

**Use nearest-neighbor scaling** (not bilinear or cubic) to keep edges crisp.

**GIMP**: Scale Image → Interpolation: None
**Photoshop**: Image > Scale > Nearest Neighbor
**remove.bg**: Re-export at a specific size if supported

Target sizes by category (from `Sprite_Ruleset.md`):

| Category | Size |
|----------|------|
| Player | 128×128 |
| Weapon | 64×64 |
| Enemy | 128×128 |
| Boss | 256×256 |
| Pickup | 48×48 |
| Objective | 96×96 |
| Projectile | 32×32 |

### Step 3d: Save as PNG

Export/save the sprite as **PNG with transparency**:

- Filename: `[category]_[name].png`
- Format: PNG (not JPG, not WEBP)
- Compression: lossless
- Color space: sRGB

Save the processed sprite to a temp folder (`C:\temp\sprites\` or your Downloads) — **not to `assets/sprites/` yet**.

---

## Phase 4: Load and Test in Godot (3 min per sprite)

### Step 4a: Copy Sprite to Assets

Move the processed sprite from temp to the appropriate folder:

```
assets/sprites/
  ├─ player/
  ├─ weapons/
  ├─ enemies/
  ├─ projectiles/
  ├─ secondaries/
  ├─ pickups/
  └─ objectives/
```

Example: `projectile_bullet.png` → `assets/sprites/projectiles/projectile_bullet.png`

### Step 4b: Create a Simple Test Scene

In Godot, create a temporary test scene:

```
Scene: Sprite2D
  Texture: [drag the new sprite file]
  Scale: (1, 1) to (2, 2) — test both sizes
```

### Step 4c: Verify in Editor

Check:

- ✅ Sprite loads without errors
- ✅ Transparency background is black/empty (not white)
- ✅ No pink checkerboard artifacts (would indicate corruption)
- ✅ Pivot is center (or as specified)
- ✅ Sprite is readable at 1x and 2x scale
- ✅ Outline thickness is consistent
- ✅ Colors are flat and bright

### Step 4d: Delete Test Scene

After verification, delete the temporary test scene. Don't commit it.

---

## Phase 5: Approval and Logging (2 min per sprite)

### Step 5a: Update the Approval Log

Open `Sprite_Approval_Log.md`.

Move the sprite from **Backlog** to **In Review** with notes:

```
| Sprite | Category | Status | Approved Date | Notes |
|---|---|---|---|---|
| projectile_bullet.png | projectile | approved | 2026-05-06 | clean transparency, readable at 32×32, bright yellow |
```

### Step 5b: Update the Backlog

Open `Sprite_Backlog.md` and check off the sprite:

```
- [x] projectile_bullet.png
```

### Step 5c: Done

Sprite is ready for integration into gameplay. Move to the next sprite.

---

## Phase 6: Integrate into Godot Code

**Only do this when a sprite is approved and tested.**

Example: Integrating `projectile_bullet.png`:

### Step 6a: Update References

Find where projectiles are loaded/rendered in code:

```gdscript
# Example in a Bullet scene
@onready var sprite = $Sprite2D

func _ready():
    sprite.texture = load("res://assets/sprites/projectiles/projectile_bullet.png")
```

Or update a JSON data file:

```json
{
  "projectile_bullet": {
    "texture": "assets/sprites/projectiles/projectile_bullet.png",
    "scale": 1.0
  }
}
```

### Step 6b: Test in Gameplay

Load the game and verify:

- ✅ Sprite appears in the correct context (bullet in-flight, pickup on ground, enemy in arena)
- ✅ Scale and pivot are correct
- ✅ Transparency doesn't have artifacts
- ✅ No visual regression in other areas

### Step 6c: Commit

If everything passes:

```bash
git add assets/sprites/projectiles/projectile_bullet.png
git commit -m "Add projectile_bullet sprite"
```

---

## Troubleshooting

### Sprite looks blurry in Godot

- Verify you used nearest-neighbor resizing, not bilinear
- Check that the texture filter in Godot is set to "Nearest" (not "Linear")
- Godot may need `Filter: false` in the Sprite2D properties

### Transparency has white halos

- Redo the background removal with a different tool
- Try remove.bg or GIMP's "Grow" + "Feather" options
- Request ChatGPT regenerate with simpler geometry (less anti-aliasing)

### Sprite is the wrong size

- Resize with nearest-neighbor to the target dimensions
- Verify the size in the Sprite2D inspector in Godot

### ChatGPT keeps changing style between sprites

- Always paste the reference image URL at the top of each prompt
- Don't generate more than 5–10 sprites per chat; start a new chat window
- Paste the full style rules at the start of each new chat

### File won't load in Godot

- Verify the file is actually PNG (not WEBP or JPG)
- Verify the filename matches exactly (case-sensitive on some systems)
- Check the file path in the code matches the actual folder structure

---

## Checklist for Each Sprite

Print or copy this checklist for each sprite:

```
Sprite: ________________

Phase 2 (Request):
- [ ] Opened new ChatGPT chat (if first sprite)
- [ ] Pasted style rules
- [ ] Pasted reference image
- [ ] Used template from SPRITE_PROMPTS.md
- [ ] Downloaded image

Phase 3 (Post-process):
- [ ] Removed background (clean, no halos)
- [ ] Resized to target dimensions (if needed)
- [ ] Exported as PNG with transparency
- [ ] Saved to temp folder

Phase 4 (Godot test):
- [ ] Moved to assets/sprites/[category]/
- [ ] Created test scene
- [ ] Verified transparency (no white, no artifacts)
- [ ] Verified scale (1x and 2x)
- [ ] Verified readability
- [ ] Deleted test scene

Phase 5 (Approval):
- [ ] Updated Sprite_Approval_Log.md
- [ ] Updated Sprite_Backlog.md
- [ ] Notes recorded

Phase 6 (Integration):
- [ ] Updated Godot code/JSON
- [ ] Tested in gameplay
- [ ] Committed

Status: APPROVED ✅
```

---

## Example: Full Workflow for One Sprite

**Goal**: Generate `enemy_chaser.png`, approve it, and integrate it.

**Time**: ~20 minutes total.

### Minute 1–5: Request (Phase 2)

1. Open ChatGPT web chat
2. Paste style rules from `Sprite_Context_Short.md`
3. Paste reference: `https://raw.github.../player_p1.png`
4. Paste enemy_chaser template from `SPRITE_PROMPTS.md`
5. Download the image

### Minute 6–15: Post-process (Phase 3)

1. Upload to remove.bg
2. Download clean PNG
3. Verify no halos, crisp edges
4. Already 128×128, no resize needed
5. Save to Downloads folder

### Minute 16–18: Godot Test (Phase 4)

1. Copy to `assets/sprites/enemies/`
2. Create test Sprite2D scene
3. Load texture, verify transparency
4. Scale 1x and 2x, verify readability
5. Delete test scene

### Minute 19–20: Approve and Log (Phase 5)

1. Add to `Sprite_Approval_Log.md`: status approved
2. Check off `Sprite_Backlog.md`

### Later: Integration (Phase 6)

1. Open `Enemy.gd` or enemy sprite loader
2. Update texture reference to `res://assets/sprites/enemies/enemy_chaser.png`
3. Test in gameplay
4. Commit

Done. Move to next sprite.

---

## Summary

1. **ChatGPT**: Request and download
2. **Post-process**: Remove background, resize, verify
3. **Godot test**: Load and check
4. **Approve**: Log approval and update backlog
5. **Integrate**: Update code, test, commit

Repeat for each sprite. Total time: ~20 minutes per sprite.
