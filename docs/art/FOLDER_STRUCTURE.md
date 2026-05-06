# Folder Structure

Complete sprite and documentation folder organization.

## Documentation Structure

All art documentation lives in `docs/art/`:

```
docs/
  └─ art/
      ├─ Sprite_Ruleset.md              (visual style rules)
      ├─ SPRITE_PROMPTS.md              (ChatGPT prompt templates)
      ├─ Sprite_Context_Short.md        (paste-into-ChatGPT rules)
      ├─ Sprite_Generation_Workflow.md  (complete process, 6 phases)
      ├─ Sprite_Backlog.md              (what needs generation)
      ├─ Sprite_Approval_Log.md         (what's approved/rejected)
      └─ FOLDER_STRUCTURE.md            (this file)
```

### File Purposes

| File | Purpose | Who Uses | When |
|------|---------|----------|------|
| Sprite_Ruleset.md | Visual language and approval criteria | Approver (user) | Before approving any sprite |
| SPRITE_PROMPTS.md | ChatGPT prompt templates for each sprite type | Generator (ChatGPT) | When requesting each sprite |
| Sprite_Context_Short.md | Short rules to paste into ChatGPT | Generator (ChatGPT) | At start of every new chat |
| Sprite_Generation_Workflow.md | Step-by-step process for full lifecycle | Everyone | Reference during any phase |
| Sprite_Backlog.md | What sprites need to be generated | Tracker | Daily, to pick next sprite |
| Sprite_Approval_Log.md | What's approved, rejected, in review | Approver | After generating each sprite |
| FOLDER_STRUCTURE.md | This file, folder organization | Reference | Onboarding only |

---

## Runtime Sprite Structure

All runtime sprites live in `assets/sprites/` and are organized by category:

```
assets/
  └─ sprites/
      ├─ player/
      │   ├─ player_p1.png
      │   ├─ player_p2.png
      │   ├─ player_p3.png
      │   └─ player_p4.png
      ├─ enemies/
      │   ├─ enemy_chaser.png
      │   ├─ enemy_spitter.png
      │   ├─ enemy_charger.png
      │   └─ boss_main.png
      ├─ weapons/
      │   ├─ weapon_rifle.png
      │   ├─ weapon_scatter.png
      │   └─ weapon_slug.png
      ├─ secondaries/
      │   ├─ grenade_standard.png
      │   ├─ grenade_cluster.png
      │   ├─ grenade_siege.png
      │   ├─ mine_standard.png
      │   ├─ mine_shrapnel.png
      │   └─ mine_heavy.png
      ├─ pickups/
      │   ├─ pickup_gold.png
      │   └─ pickup_food.png
      ├─ objectives/
      │   └─ objective_generator.png
      └─ projectiles/
          └─ projectile_bullet.png
```

### Folder Organization

| Folder | Contains | Loaded at | Notes |
|--------|----------|-----------|-------|
| `player/` | Player body sprites (P1, P2, P3, P4) | Bootstrap/RunFlow | One per player, no weapon |
| `enemies/` | Enemy silhouettes | CoopManager/Enemy.gd | Boss is separate but same folder |
| `weapons/` | Primary weapon visuals | Player/Weapon attachment | Rifle, Scatter, Slug |
| `secondaries/` | Grenade and mine visuals | Grenade/Mine scenes | 6 total (3 grenades, 3 mines) |
| `pickups/` | Gold, food, and reward pickups | CoopManager/Pickup.gd | Dropped by enemies and generators |
| `objectives/` | Destructible objectives | CoopManager/Generator.gd | Generators for gauntlet rooms |
| `projectiles/` | In-flight bullet and projectile visuals | Bullet/Projectile scenes | Used by guns and enemies |

---

## Naming Convention

All sprite filenames follow the pattern:

```
<category>_<name>.png
```

Examples:

```
player_p1.png
enemy_chaser.png
weapon_rifle.png
grenade_standard.png
mine_heavy.png
pickup_gold.png
objective_generator.png
projectile_bullet.png
```

### Naming Rules

- All lowercase
- Use underscore to separate category and name
- No spaces
- No special characters
- Descriptive but concise
- Match the backlog exactly

---

## Deprecated Folders

The old `sprites/guidelines/` folder (if it exists) is now deprecated. All sprite generation documentation has been moved to `docs/art/`.

**If you have old files in `sprites/guidelines/`:**

1. Copy any custom prompts to `SPRITE_PROMPTS.md`
2. Delete `sprites/guidelines/`
3. Commit the cleanup

---

## Adding a New Sprite

### Step 1: Add to Backlog

Open `Sprite_Backlog.md`, find the right category, and add:

```
- [ ] new_sprite_name.png — description of the sprite
```

### Step 2: Create Prompt

Add a template to `SPRITE_PROMPTS.md` if not already there.

### Step 3: Generate and Process

Follow `Sprite_Generation_Workflow.md` phases 1–5.

### Step 4: Save to Correct Folder

Place the approved sprite in the appropriate `assets/sprites/<category>/` folder.

### Step 5: Integrate

Update Godot code or JSON to reference the new sprite (see `Sprite_Generation_Workflow.md` Phase 6).

### Step 6: Commit

```bash
git add assets/sprites/<category>/<filename>
git commit -m "Add <filename> sprite"
```

---

## Godot Import Settings

All sprites in `assets/sprites/` should have these Godot import settings:

- **Texture Type**: 2D Texture (default)
- **Filter**: Nearest (to preserve crisp edges)
- **Mipmaps**: Off
- **Compression**: VRAM Compressed (default)

Check `.godot/imported/<path>.texture` if import settings are wrong.

---

## Quick Reference: File Checklist

When starting sprite work:

- [ ] Read `Sprite_Ruleset.md` to understand visual language
- [ ] Check `Sprite_Backlog.md` for next sprite
- [ ] Find template in `SPRITE_PROMPTS.md`
- [ ] Follow phases in `Sprite_Generation_Workflow.md`
- [ ] Log approval in `Sprite_Approval_Log.md`
- [ ] Save sprite to `assets/sprites/<category>/`
- [ ] Update Godot code to use new sprite
- [ ] Test in gameplay
- [ ] Commit

---

## GitHub Integration

When committing sprites to GitHub:

- Always add `.png` files with `git add assets/sprites/...`
- PNG files are stored as-is (not compressed by git)
- Large batch commits are fine (e.g., "Add enemy sprites")
- Reference the approval log in commit messages if helpful

Example:

```bash
git add assets/sprites/enemies/
git commit -m "Add enemy silhouettes (chaser, spitter, charger, boss)"
```

---

## Contact & Questions

- **Visual language questions**: Check `Sprite_Ruleset.md`
- **Prompt template questions**: Check `SPRITE_PROMPTS.md`
- **Process questions**: Check `Sprite_Generation_Workflow.md`
- **ChatGPT setup**: Check `Sprite_Context_Short.md`
