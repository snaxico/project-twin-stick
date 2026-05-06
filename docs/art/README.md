# Art & Sprite Documentation

This folder contains all sprite generation rules, workflows, and tracking for the Project Twin Stick prototype.

## Quick Start

**First time?** Read in this order:

1. **[Sprite_Ruleset.md](Sprite_Ruleset.md)** — What sprites look like (visual language, sizes, names)
2. **[Sprite_Context_Short.md](Sprite_Context_Short.md)** — What to paste into ChatGPT to start generating
3. **[Sprite_Generation_Workflow.md](Sprite_Generation_Workflow.md)** — Complete step-by-step process (6 phases)

**Returning?** Check:

- **[Sprite_Backlog.md](Sprite_Backlog.md)** — What sprite to generate next
- **[Sprite_Approval_Log.md](Sprite_Approval_Log.md)** — What's been approved
- **[SPRITE_PROMPTS.md](SPRITE_PROMPTS.md)** — Templates to request sprites

## Workflow Overview

```
1. Pick a sprite from Sprite_Backlog.md
2. Paste rules from Sprite_Context_Short.md into ChatGPT web chat
3. Use template from SPRITE_PROMPTS.md
4. Download image from ChatGPT
5. Follow Sprite_Generation_Workflow.md (phases 1–6)
   a. Post-process: remove background, resize
   b. Test in Godot
   c. Approve in Sprite_Approval_Log.md
   d. Integrate into gameplay code
   e. Commit
```

Total time per sprite: ~20 minutes.

## Files

| File | Purpose |
|------|---------|
| **README.md** | This file — quick reference |
| **Sprite_Ruleset.md** | Visual style, sizes, naming, approval criteria |
| **SPRITE_PROMPTS.md** | ChatGPT prompt templates for each sprite type |
| **Sprite_Context_Short.md** | Paste-into-ChatGPT setup (rules + reference image) |
| **Sprite_Generation_Workflow.md** | Detailed 6-phase process (request → post-process → test → approve → integrate) |
| **Sprite_Backlog.md** | Checklist of sprites to generate |
| **Sprite_Approval_Log.md** | Status of all generated sprites (approved/rejected/review) |
| **FOLDER_STRUCTURE.md** | Complete folder organization and file locations |

## Key Rules

- **Visual language**: Rubberhose-inspired 2D cartoon, thick black outline, flat colors, readable first
- **One sprite per file**: No weapons on player bodies, no backgrounds
- **Transparent PNG**: All sprites must have clean transparent backgrounds (no white halos)
- **Specific sizes**: Player 128×128, Weapon 64×64, Enemy 128×128, etc.
- **Post-processing required**: ChatGPT outputs on white/grey backgrounds; you must remove the background manually

## Roles

- **ChatGPT (DALL-E 3)**: Generates sprite images based on prompts
- **You**: Post-processes (remove background, resize), tests in Godot, approves
- **Godot**: Loads and displays approved sprites in gameplay

## Current Status

- **Total sprites needed**: 20
- **Approved**: 1 (player_p1.png)
- **In progress**: 0
- **Not started**: 19

See [Sprite_Backlog.md](Sprite_Backlog.md) for the full list.

## Next Steps

1. Open [Sprite_Context_Short.md](Sprite_Context_Short.md)
2. Open a new ChatGPT web chat
3. Paste the setup (rules + reference image)
4. Pick the first sprite from [Sprite_Backlog.md](Sprite_Backlog.md) — start with **projectile_bullet.png**
5. Use the template from [SPRITE_PROMPTS.md](SPRITE_PROMPTS.md)
6. Follow [Sprite_Generation_Workflow.md](Sprite_Generation_Workflow.md)

## Questions?

- **"What should a sprite look like?"** → [Sprite_Ruleset.md](Sprite_Ruleset.md)
- **"How do I request one from ChatGPT?"** → [Sprite_Context_Short.md](Sprite_Context_Short.md)
- **"What do I do after ChatGPT generates it?"** → [Sprite_Generation_Workflow.md](Sprite_Generation_Workflow.md) Phases 3–6
- **"Where do approved sprites go?"** → [FOLDER_STRUCTURE.md](FOLDER_STRUCTURE.md)
- **"What sprite is next?"** → [Sprite_Backlog.md](Sprite_Backlog.md)
