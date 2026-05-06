# Sprite Context (Paste into ChatGPT)

**Do this at the start of every new ChatGPT chat window before requesting sprites.**

---

## Step 1: Paste These Rules

```
Sprite generation rules:
- rubberhose-inspired 2D cartoon
- shallow 3/4 top-down gameplay view
- thick black outline on all shapes
- flat colors, no gradients or shading
- transparent background
- readable first, details second
- one sprite per file
- no text, no background, no realistic rendering
- no tiny details

Output format: PNG with transparent background

Dimensions by category:
- Player: 128×128
- Weapon: 64×64
- Enemy: 128×128
- Boss: 256×256
- Pickup/secondary: 48×48
- Objective: 96×96
```

## Step 2: Provide a Style Reference

Paste the URL of an already-approved sprite, for example:

```
Reference image (match this visual style):
[approved sprite URL, e.g., https://raw.githubusercontent.com/.../player_p1_base.png]
```

## Step 3: Say This

```
Use this reference image to match the visual style and cartoon language.
Generate sprites that follow these rules and match this reference style.
```

---

## Then Request Sprites One at a Time

Use the template below. Fill in the bracketed fields:

```
Create one sprite:
Category: [player | enemy | weapon | pickup | objective | secondary]
Filename: [exact filename]
Gameplay role: [what it does in the game]
Shape/silhouette: [visual form]
Color: [colors and description]
Must include: [required visual elements]
Must exclude: [what to avoid]
```

### Example

```
Create one sprite:
Category: enemy
Filename: enemy_chaser.png
Gameplay role: fast small homing enemy
Shape/silhouette: small dart shape, pointed forward
Color: bright red
Must include: pointed shape, small readable form, speed appearance
Must exclude: legs, wings, eyes, realistic features
```

---

## After You Get the Sprite

1. **Download it** from ChatGPT
2. **Remove the background** (it will have a white/grey background)
   - Use remove.bg, Photoshop, GIMP, or Affinity Photo
   - Ensure a clean transparent background with no halos
3. **Resize to target dimensions** if needed (e.g., 128×128)
   - Use nearest-neighbor scaling to preserve crisp edges
4. **Save as PNG** with transparency
5. **Verify in Godot** by loading it in the scene to check scale/pivot
6. **Approve or request changes** in the Approval Log

---

## Important Notes

- **One chat window = one batch** (~5–10 sprites before consistency drifts)
- **Always paste the style reference** — ChatGPT forgets style between sessions
- **Generate one sprite at a time** — don't batch requests
- **Background removal is manual** — ChatGPT doesn't output transparent PNGs
- **When this chat gets old**, start a new window and repeat steps 1–3

---

## Approved Sprites Reference

Check `Sprite_Approval_Log.md` for sprites already approved and ready to use.
Check `Sprite_Backlog.md` for what still needs to be generated.
