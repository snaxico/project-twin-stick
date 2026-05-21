# Patch 12 — Icon-First UI Pass

## Status Note

- This file is a historical implementation record for an earlier slice.
- It is not the current runtime source of truth.

Hard scope lock: no new gameplay systems, weapons, enemies, or progression mechanics. This patch replaces text-heavy UI with icon-driven presentation across the HUD, loot screen, shop, and weapon replacement flow.

---

## Goal

Make every UI surface readable at a glance with icons instead of text walls. Players should recognize items by shape and color, not by reading descriptions mid-combat.

---

## Patch 12A — Placeholder Icon Assets

### Goal

Create a procedural placeholder icon for every weapon and passive that does not already have a sprite. Also create small UI chrome icons (gold coin, heart). These are colored geometric shapes — not final art — but distinct enough to tell items apart.

### Rules

- Icons are generated in GDScript at startup using `Image` and saved to a static cache. No external image files needed for placeholders.
- Each icon should be a distinct colored shape on a transparent background, sized 64x64 pixels.
- Primary weapons, secondary weapons, and passives each get a different shape family so type is instantly recognizable.
- When a real sprite exists (Rifle, Scatter, Slug), it takes priority. The placeholder system is the fallback.

### Icon Design Language

#### Primary weapons — rounded rectangle silhouette

Each primary gets a unique accent color:

| Weapon ID | Color | Shape detail |
|-----------|-------|--------------|
| `rifle` | — | Has real sprite, skip |
| `scatter` | — | Has real sprite, skip |
| `slug` | — | Has real sprite, skip |
| `incinerator` | Orange `(0.96, 0.55, 0.15)` | Rounded rect + flame notch (triangle on top edge) |
| `beam_lance` | Cyan `(0.3, 0.85, 0.95)` | Rounded rect + horizontal line through center |
| `arc_caster` | Electric blue `(0.4, 0.5, 1.0)` | Rounded rect + zigzag line through center |

#### Secondary weapons — circle silhouette

| Weapon ID | Color | Shape detail |
|-----------|-------|--------------|
| `grenade` | Olive `(0.7, 0.75, 0.3)` | Circle + small cross on top |
| `cluster_grenade` | Dark olive `(0.6, 0.65, 0.25)` | Circle + three small dots inside |
| `siege_grenade` | Burnt orange `(0.85, 0.55, 0.2)` | Circle + larger, thicker cross on top |
| `mine` | Steel `(0.55, 0.6, 0.65)` | Circle + four short spikes outward |
| `shrapnel_mine` | Dark steel `(0.45, 0.5, 0.55)` | Circle + eight short spikes outward |
| `heavy_mine` | Copper `(0.7, 0.5, 0.35)` | Large circle + four short spikes + inner ring |

#### Passives — diamond silhouette

Each passive gets a color based on its effect category:

| Category | Color | Passive IDs |
|----------|-------|-------------|
| Fire rate | Yellow `(0.95, 0.85, 0.25)` | `overclocked_receiver`, `rapid_loader` |
| Damage | Red `(0.9, 0.35, 0.3)` | `tungsten_cores`, `charged_payload`, `chain_reaction`, `high_velocity_rounds` |
| Projectile speed | Light blue `(0.5, 0.75, 0.95)` | `velocity_rig` |
| Explosion radius | Magenta `(0.85, 0.4, 0.75)` | `blast_amplifier` |
| Cooldown | Green `(0.4, 0.85, 0.45)` | `quick_deploy`, `quick_release_valve` |
| Pierce | White `(0.85, 0.88, 0.92)` | `armor_piercing_rounds` |
| Trigger proc | Purple `(0.6, 0.4, 0.9)` | `ember_bloom`, `feedback_arc`, `culling_burst`, `detonation_web` |
| Health | Pink `(0.9, 0.55, 0.6)` | `ablative_coating`, `reinforced_plating` |
| Movement | Teal `(0.3, 0.8, 0.7)` | `sprint_servos` |

Within each category, differentiate passives by adding a small inner mark (dot, line, cross, ring) so no two passives look identical.

#### UI chrome icons — 32x32

| Icon | Shape | Color |
|------|-------|-------|
| Gold coin | Circle with inner ring | Gold `(1.0, 0.84, 0.24)` |
| Heart | Heart shape (two arcs + triangle) | Red `(0.9, 0.3, 0.35)` |

### Implementation

Create a new script `scripts/ui/IconFactory.gd` as an autoload or static class:

```
static func get_weapon_icon(weapon_id: String) -> Texture2D
static func get_passive_icon(passive_id: String) -> Texture2D
static func get_ui_icon(icon_name: String) -> Texture2D
```

- Check if a real sprite exists (from `WeaponSlotHUD.ICON_TEXTURE_PATHS`). If yes, return that.
- Otherwise, generate the placeholder `ImageTexture` on first request and cache it.
- All generation uses `Image.create()`, `Image.set_pixel()`, or simple shape drawing.

### Do NOT change

- Existing real sprite assets (Rifle, Scatter, Slug, bullet, player sprites).
- Any gameplay scripts.
- Any UI layout or behavior — this patch only creates the icon lookup system.

### Validation

1. Run headless parse.
2. Call `IconFactory.get_weapon_icon()` for every weapon ID. Confirm each returns a non-null texture.
3. Call `IconFactory.get_passive_icon()` for every passive ID. Confirm each returns a non-null texture.
4. Call `IconFactory.get_ui_icon("gold")` and `get_ui_icon("heart")`. Confirm both return textures.

---

## Patch 12B — HUD Icon Integration

### Goal

Replace text abbreviations in the in-combat HUD with icons from `IconFactory`.

### Changes

#### WeaponSlotHUD — `scripts/ui/WeaponSlotHUD.gd`

Replace the hardcoded `ICON_TEXTURE_PATHS` dictionary and `_get_icon_texture()` method with a call to `IconFactory.get_weapon_icon(weapon_id)`. This means every weapon gets an icon — real sprite where available, procedural placeholder otherwise.

```gdscript
# Old
func _get_icon_texture(weapon_id: String) -> Texture2D:
    ...check ICON_TEXTURE_PATHS...

# New
func _get_icon_texture(weapon_id: String) -> Texture2D:
    if weapon_id.is_empty():
        return null
    return IconFactory.get_weapon_icon(weapon_id)
```

Remove the `ICON_TEXTURE_PATHS` constant and `_icon_cache` variable — `IconFactory` owns the cache now.

The `_placeholder_panel` and `_placeholder_label` (text fallback) should remain as a last-resort fallback if `IconFactory` returns null, but in practice every weapon should now have an icon.

#### PlayerInventoryHUD passive chips — `scripts/ui/PlayerInventoryHUD.gd`

Replace `_build_passive_chip()` text abbreviations with passive icons.

Current flow (line 133):
```gdscript
_passive_row.add_child(_build_passive_chip(_build_passive_abbreviation(passive_name)))
```

New flow: `_update_passive_icons()` needs to receive passive IDs (not just names) from the HUD data. Then:

```gdscript
# Build chip with icon texture instead of text
func _build_passive_chip_icon(passive_id: String) -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(24.0, 20.0)
    # ... same style as current chip ...
    var icon := TextureRect.new()
    icon.texture = IconFactory.get_passive_icon(passive_id)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    panel.add_child(icon)
    return panel
```

**Data change required:** The HUD data dictionary currently passes `"passives": Array of passive_name_strings`. This needs to change to pass passive IDs alongside names. Check where `update_hud()` is called from in `CoopManager.gd` and ensure passive IDs are included in the data payload.

#### Gold label — `scripts/ui/PlayerInventoryHUD.gd`

Line 38: Replace `"$%d"` text with a gold icon + number.

Add a `TextureRect` for the coin icon next to `_gold_label` in the top row during `_build()`. Use `IconFactory.get_ui_icon("gold")`.

### Do NOT change

- Health bar (already visual).
- Cooldown bar (already visual).
- Level badge (number overlay is fine).
- HUD layout structure or sizing.

### Validation

1. Run headless parse.
2. Start a run. Confirm:
   - All weapon slots show icons (real sprites for Rifle/Scatter/Slug, placeholder shapes for everything else).
   - Passive chips show colored diamond icons instead of 2-letter text.
   - Gold label has a coin icon next to the number.
   - All icons are readable at gameplay scale.

---

## Patch 12C — Loot, Shop, and Replace UI Rework

### Goal

Replace text-heavy item presentation with icon + short label in the loot vote, shop, and weapon replacement screens.

### Changes

#### LootVoteUI — `scripts/ui/LootVoteUI.gd`

Current: `"Loot Vote: Rifle"` title + description text.

New layout:
- Large item icon (64x64) centered above the title, from `IconFactory`.
- Title: item name only (no "Loot Vote:" prefix) — e.g., `"Rifle"`.
- Item type badge below name: `"Primary"`, `"Secondary"`, or `"Passive"` in smaller text with type color.
- Description stays but moves below the type badge in smaller font.
- Vote rows stay as text (`P1: Take`).

Data requirement: `setup_for_item()` already receives `item.type` and `item.id` — use `item.id` to fetch the icon and `item.type` to pick the type badge color.

Type badge colors:
- `primary_weapon`: `(0.96, 0.54, 0.26)` (orange)
- `secondary_weapon`: `(0.82, 0.46, 1.0)` (purple)
- `passive`: `(0.56, 0.88, 1.0)` (cyan)

#### ShopUI — `scripts/ui/ShopUI.gd`

Current: Multi-line text blocks per offer (`"> Rifle\nDescription\nCost: 3 Gold"`).

New layout per offer:
- Item icon (48x48) on the left.
- Item name to the right of icon.
- Cost as gold icon + number below name (no "Cost:" text, no "Gold" word).
- Description hidden by default — show on hover/selection as a tooltip or subtitle line.
- Selection indicator: border highlight instead of `> ` text prefix.

Wallet line: replace `"Wallet: %d Gold"` with gold icon + number.

#### WeaponReplaceUI — `scripts/ui/WeaponReplaceUI.gd`

Current: `"New weapon: Rifle\nDescription"` + `"> Slot 1: Scatter Lv2"`.

New layout:
- Top: new weapon icon (48x48) + name + level.
- "Replace which slot?" label.
- Slot rows: each shows weapon icon (32x32) + name + level badge. Selection highlight via border, not `> ` prefix.
- Drop the full description text — the icon + name is enough for a replacement decision.

### Do NOT change

- Vote logic, shop purchase logic, or replacement logic.
- Timer bar in loot vote (already visual).
- Ready/leave flow in shop.
- Any data structures beyond what's needed for icon lookups.

### Validation

1. Run headless parse.
2. Complete a combat room. Confirm:
   - Loot vote shows item icon prominently with type badge.
   - Screen reads faster than the old text-only version.
3. Enter a shop room. Confirm:
   - Offers show icon + name + cost (with coin icon).
   - Selected offer highlights visually, not with `> `.
   - Description is secondary, not dominant.
4. Trigger a weapon replacement. Confirm:
   - New weapon and slot weapons both show icons.
   - Comparison is icon-to-icon, readable at a glance.

---

## Implementation Order

Execute 12A first. Validate. Then 12B. Validate. Then 12C. Validate.

- 12A creates the icon system. Nothing changes visually yet.
- 12B wires icons into the in-combat HUD. Players see the change immediately.
- 12C reworks the reward/shop/replace screens to use icons.

## Asset Note

All placeholder icons are procedurally generated in GDScript — no external image files are created or required. When real art lands later, add the sprite path to `IconFactory` and it will take priority over the procedural placeholder automatically.

## After Patch 12

Update:
- `docs/development/current-state.md` — note icon-first UI and `IconFactory`
- `docs/development/history/` entry for the session
- `docs/process/prototype-roadmap.md` — add Patch 12 row
- `docs/development/start-of-day.md` — update HUD and UI descriptions
