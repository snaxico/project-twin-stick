# Sprite Prompts

Reusable AI prompts for generating prototype sprites.

Use together with `Sprite_ruleset.md`.

Core assumptions:
- rubberhose-inspired 2D cartoon
- shallow 3/4 top-down gameplay view
- thick black outlines
- flat colors
- readable silhouettes
- characters and weapons are separate sprites
- weapons float near the character hand
- one asset per prompt
- one sprite per file, PNG with transparent background

---

## 1. Base Player Character

Create a single 2D game sprite for the base player character of a local co-op action roguelite.

Canvas: 128x128 px, character fills ~80% of canvas height, centered, transparent background.

The character must NOT include any weapon. The character is designed as a reusable body that will have a separate floating weapon sprite attached near the forward hand later.

Style: rubberhose-inspired cartoon, thick black outer outline, rounded tubular limbs, simple shapes, flat colors, minimal detail, friendly playful tone.

View: shallow 3/4 top-down gameplay view.

Pose: neutral combat-ready pose with one clearly visible forward arm and empty hand pointing toward a nearby floating weapon position. The hand should not grip or hold anything. Slight asymmetry so a simple scale-bounce reads as idle animation.

Character design: large head, compact body, simple expressive face, gloves, big shoes, readable silhouette. Use neutral gray or white accent color — player tint is applied in-engine.

Output: single centered sprite, transparent background, no text, no environment.

Avoid: weapon, gun, sword, staff, realistic rendering, painterly texture, complex clothing, tiny details, horror tone, side view, pure top-down view, anime style.

---

## 2. Player Recolor Variant

Create a recolor variant of the existing base player character sprite.

Canvas: 128x128 px, transparent background.

Keep the exact same body shape, pose, silhouette, proportions, outline thickness, and art style.

Only change the player accent/tint color to: [COLOR].

The character must NOT include any weapon.

Style: rubberhose-inspired cartoon, thick black outline, flat colors, minimal detail.

Output: single centered sprite, transparent background, no text, no environment.

Avoid: changing the silhouette, changing the pose, adding weapons, adding class-specific armor, adding complex details.

---

## 3. Standalone Primary Weapon (Generic Template)

Create a single standalone 2D weapon sprite for a local co-op action roguelite.

Canvas: 64x64 px, weapon fills ~70% of canvas width, transparent background.

The weapon must be separate from the character and designed to float slightly near the character's forward hand in-game.

Weapon type: [WEAPON TYPE]

Gameplay identity: [SHORT DESCRIPTION OF HOW IT SHOULD FEEL]

Style: rubberhose-inspired cartoon, thick black outer outline, simple exaggerated shape, flat colors, minimal detail, readable at small size.

View: shallow 3/4 top-down gameplay view matching the player character perspective.

Orientation: right-facing. The front/muzzle points to the right. The rear/handle sits near the left-center of the canvas as the rotation pivot area.

Output: single centered weapon sprite, transparent background, no hand, no character, no text, no environment.

Avoid: realistic gun details, military realism, excessive mechanical parts, thin outlines, tiny details, muzzle flash, projectile effects, UI frame.

---

## 4. Rifle

Create a single standalone 2D rifle sprite for a local co-op action roguelite.

Canvas: 64x64 px, transparent background.

The rifle must be separate from the character and designed to float near the character's forward hand.

Style: rubberhose-inspired cartoon, thick black outline, simple exaggerated shape, flat colors, minimal detail.

View: shallow 3/4 top-down gameplay view.

Orientation: right-facing. The barrel points to the right. The rear/stock area is on the left and should work as the rotation/pivot area.

Design: medium-length, balanced silhouette that reads as a reliable accurate weapon. Not too long, not too short.

Output: single centered sprite, transparent background, no hand, no character, no text.

Avoid realistic firearm detail, military realism, tiny mechanical parts, muzzle flash, projectile effects.

---

## 5. Scatter (Shotgun)

Create a single standalone 2D shotgun sprite for a local co-op action roguelite.

Canvas: 64x64 px, transparent background.

The shotgun must be separate from the character and designed to float near the character's forward hand.

Style: rubberhose-inspired cartoon, thick black outline, simple exaggerated shape, flat colors, minimal detail.

View: shallow 3/4 top-down gameplay view.

Orientation: right-facing. The barrel points to the right. The rear/handle area is on the left and should work as the rotation/pivot area.

Design: short, wide, chunky silhouette that clearly reads as a close-range burst weapon.

Output: single centered sprite, transparent background, no hand, no character, no text.

Avoid realistic firearm detail, military realism, thin outlines, tiny mechanical parts, muzzle flash, projectile effects.

---

## 6. Slug (Launcher)

Create a single standalone 2D launcher sprite for a local co-op action roguelite.

Canvas: 64x64 px, transparent background.

The launcher must be separate from the character and designed to float near the character's forward hand.

Style: rubberhose-inspired cartoon, thick black outline, simple exaggerated shape, flat colors, minimal detail.

View: shallow 3/4 top-down gameplay view.

Orientation: right-facing. The front tube points to the right. The rear/handle area is on the left and should work as the rotation/pivot area.

Design: chunky tube silhouette, heavy but playful, clearly readable as a slow powerful weapon that fires big projectiles.

Output: single centered sprite, transparent background, no hand, no character, no text.

Avoid realistic military rocket launcher detail, tiny mechanical parts, muzzle flash, projectile effects.

---

## 7. Player Projectile

Create a single 2D projectile sprite for a local co-op action roguelite.

Canvas: 32x32 px, projectile fills ~60-70% of canvas, transparent background.

Projectile type: standard player bullet

Style: rubberhose-inspired cartoon, thick black outline, simple diamond/oval shape, bright saturated color, readable at small size.

View: shallow 3/4 top-down gameplay view.

Orientation: right-facing.

Design: bright, punchy, clearly visible against a medium-dark floor. Should read as friendly/player-owned.

Color: neutral bright warm white or yellow — player tint is applied in-engine.

Output: single centered sprite, transparent background, no weapon, no character, no text, no environment.

Avoid tiny size, realistic ballistics, excessive particle trails, detailed background.

---

## 8. Enemy Projectile

Create a single 2D projectile sprite for a local co-op action roguelite.

Canvas: 32x32 px, projectile fills ~65-75% of canvas, transparent background.

Projectile type: enemy ranged attack

Style: rubberhose-inspired cartoon, thick black outline, simple shape, readable at small size.

View: shallow 3/4 top-down gameplay view.

Orientation: right-facing.

Design: slightly larger than player projectile. Bright magenta or hot pink accent. Should immediately read as a threat/enemy shot. Distinct silhouette from player bullets.

Output: single centered sprite, transparent background, no weapon, no character, no text, no environment.

Avoid tiny size, realistic ballistics, excessive particle trails, detailed background.

---

## 9. Chaser Enemy

Create a single 2D enemy sprite for a local co-op action roguelite.

Canvas: 128x128 px, enemy fills ~75% of canvas, transparent background.

Enemy role: fast melee chaser. Small, aggressive, runs at players.

Style: rubberhose-inspired cartoon, thick black outline, rounded simplified shapes, flat colors, minimal detail, friendly-but-hostile cartoon tone.

View: shallow 3/4 top-down gameplay view.

Design: small, squat, round silhouette, leaning forward aggressively. It should clearly read as an enemy that runs directly at the player. Pose should work for a simple scale-bounce idle.

Color direction: red accent — RGB approximately (1.0, 0.2, 0.15). Bake this color into the sprite.

Output: single centered sprite, transparent background, no text, no environment.

Avoid realistic rendering, horror tone, tiny details, complex clothing, side view, pure top-down view.

---

## 10. Spitter Enemy

Create a single 2D enemy sprite for a local co-op action roguelite.

Canvas: 128x128 px, enemy fills ~75% of canvas, transparent background.

Enemy role: ranged shooter. Fires projectiles from a distance.

Style: rubberhose-inspired cartoon, thick black outline, rounded simplified shapes, flat colors, minimal detail, friendly-but-hostile cartoon tone.

View: shallow 3/4 top-down gameplay view.

Design: more upright than the chaser, with a clear ranged attack tool or built-in blaster shape. It should immediately read as an enemy that attacks from distance. Medium size.

Color direction: magenta/purple accent — RGB approximately (0.82, 0.18, 0.88). Bake this color into the sprite.

Output: single centered sprite, transparent background, no text, no environment.

Avoid realistic weapons, military realism, horror tone, tiny details, complex clothing.

---

## 11. Charger Enemy

Create a single 2D enemy sprite for a local co-op action roguelite.

Canvas: 128x128 px, enemy fills ~80% of canvas, transparent background.

Enemy role: slow durable tank. Charges at players, takes many hits.

Style: rubberhose-inspired cartoon, thick black outline, rounded simplified shapes, flat colors, minimal detail, friendly-but-hostile cartoon tone.

View: shallow 3/4 top-down gameplay view.

Design: large, heavy, blocky silhouette with strong mass. Wedge-shaped or broad-shouldered. It should clearly read as a tough enemy that takes more damage before dying. Noticeably bigger than the chaser and spitter.

Color direction: orange-brown accent — RGB approximately (0.88, 0.44, 0.08). Bake this color into the sprite.

Output: single centered sprite, transparent background, no text, no environment.

Avoid realistic armor detail, horror tone, tiny details, visual clutter.

---

## 12. Boss

Create a single 2D boss sprite for a local co-op action roguelite.

Canvas: 256x256 px, boss fills ~85% of canvas, transparent background.

Boss role: final arena boss. Crown-shaped silhouette, menacing but cartoonish.

Style: rubberhose-inspired cartoon, thick black outline, rounded exaggerated shapes, flat colors, minimal detail, friendly-but-threatening cartoon tone.

View: shallow 3/4 top-down gameplay view.

Design: much larger than normal enemies, with a crown-like head shape and a readable silhouette. The boss should be memorable but not visually cluttered. Oversized compared to everything else on screen.

Color direction: deep crimson — RGB approximately (0.72, 0.06, 0.06). Bake this color into the sprite.

Output: single centered sprite, transparent background, no text, no environment.

Avoid excessive detail, horror realism, complex armor, tiny parts, painterly rendering, background scene.

---

## 13. Grenade (Secondary — World Object)

Create a single 2D grenade sprite for a local co-op action roguelite.

Canvas: 48x48 px, object fills ~65% of canvas, transparent background.

This is the grenade as it appears on the ground after being thrown — a world object, not a UI icon.

Style: rubberhose-inspired cartoon, thick black outline, simple exaggerated round shape, flat colors, minimal detail, readable at small size.

View: shallow 3/4 top-down gameplay view.

Design: classic cartoon round bomb shape. Clear fuse or pin detail. Should read instantly as "grenade on the floor" during fast combat.

Color: neutral gray/green body — player tint is applied in-engine.

Output: single centered sprite, transparent background, no hand, no character, no text, no environment.

Avoid realistic military grenade detail, tiny parts, active explosion effects, UI frame.

---

## 14. Mine (Secondary — World Object)

Create a single 2D proximity mine sprite for a local co-op action roguelite.

Canvas: 48x48 px, object fills ~65% of canvas, transparent background.

This is the mine as it sits on the ground waiting for enemies to approach.

Style: rubberhose-inspired cartoon, thick black outline, simple flat shape, flat colors, minimal detail, readable at small size.

View: shallow 3/4 top-down gameplay view.

Design: flat disc or puck shape with a visible trigger indicator on top. Should read instantly as "mine on the floor" and be visually distinct from the grenade. Lower profile than the grenade.

Color: neutral gray/dark body — player tint is applied in-engine.

Output: single centered sprite, transparent background, no hand, no character, no text, no environment.

Avoid realistic military mine detail, tiny parts, active explosion effects, UI frame.

---

## 15. Gold Pickup

Create a single 2D gold pickup sprite for a local co-op action roguelite.

Canvas: 48x48 px, icon fills ~70% of canvas, transparent background.

Style: rubberhose-inspired cartoon, thick black outline, simple exaggerated shape, flat colors, minimal detail, readable at small size.

View: shallow 3/4 top-down gameplay view or clean icon-like game sprite view.

Design: bright yellow coin or gem shape. Instantly readable as currency/gold during chaotic co-op combat. Should pop against a medium-dark olive floor.

Output: single centered sprite, transparent background, no text, no environment.

Avoid tiny details, realistic rendering, UI frame, complex background.

---

## 16. Food Pickup (Health)

Create a single 2D food/health pickup sprite for a local co-op action roguelite.

Canvas: 48x48 px, icon fills ~70% of canvas, transparent background.

Style: rubberhose-inspired cartoon, thick black outline, simple exaggerated shape, flat colors, minimal detail, readable at small size.

View: shallow 3/4 top-down gameplay view or clean icon-like game sprite view.

Design: simple cartoon food item (apple, drumstick, or similar). Green accent to signal healing. Instantly readable as "pick up to heal" during fast combat.

Output: single centered sprite, transparent background, no text, no environment.

Avoid tiny details, realistic rendering, UI frame, complex background.

---

## 17. Generator (Gauntlet Objective)

Create a single 2D generator/spawner objective sprite for a local co-op action roguelite.

Canvas: 96x96 px, object fills ~80% of canvas, transparent background.

This is a destructible objective that players must destroy to clear a room. It spawns enemies while alive.

Style: rubberhose-inspired cartoon, thick black outline, simple exaggerated shape, flat colors, minimal detail.

View: shallow 3/4 top-down gameplay view.

Design: mechanical or magical device shape — a glowing core or pulsing orb on a stand. Should clearly read as "destroy this thing" and look distinct from enemies and pickups. Slightly menacing but clearly an object, not a creature.

Color: neutral dark gray body with a bright red or orange glowing core.

Output: single centered sprite, transparent background, no text, no environment.

Avoid realistic mechanical detail, tiny parts, horror tone, excessive glow effects, background scene.

---

## 18. Universal Negative Block

Use this at the end of any prompt when outputs drift off-style:

Avoid realistic rendering, painterly texture, horror tone, gritty dark fantasy, anime style, pixel art, thin outlines, tiny decorative details, overly complex clothing, detailed backgrounds, text, UI frames, side view, pure top-down view, realistic military gear, baked-in player weapons, hands attached to standalone weapons.
