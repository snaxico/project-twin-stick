# Game Feel & Neon Identity Patch — plan

> Status: **implemented (2026-06-22): Phases 1-4 landed; Phase 5 received the scoped room-entry /
> room-clear transition polish, with deeper transition work deferred.** On `v3/structure-rework`. Goal:
> remove the "prototype feeling" with **pure in-engine work** — no external art/audio assets. Route locked
> to **refine the procedural/neon style**. Lead = game feel/juice; all four prototype tells + audio in scope.

## Framing (what the audit found)

The presentation *infrastructure already exists* — `ScreenShake`, `ParticleFactory` (weight-scaled
muzzle/impact/explosion, bloom-tinted), `HitStopManager`, `FloatingText`, `ScreenEffects` (vignette +
low-health pulse + combat tint + paper-grain shader), and an audio stack (`SfxEngine`, `MusicEngine`,
`AudioBusConfig`), wired at ~70 call sites. So this patch is **cohesion + tuning + the shapes/arena**, not
new systems. Phases are ordered by perceived-quality-per-hour; each is an independent slice
(plan → implement → review).

## Phase 1 — Arena & background identity *(biggest cheap win)*

The arena is the loudest prototype tell. **Ownership note:** the grid and walls are **built at runtime in
code**, not left empty in the scene — refine the existing paths, do **not** add a second grid:
- `Floor` is a flat muddy-beige `Color(0.28, 0.3, 0.25)` rectangle ([GameWorld.tscn](scenes/game/GameWorld.tscn))
  that clashes with the neon palette.
- The empty `FloorGrid` node is **populated at runtime** by `_rebuild_floor_grid()`
  ([CoopManager.gd:885](scripts/game/CoopManager.gd:885)); wall visuals by `_add_arena_wall_visuals()`
  ([CoopManager.gd:914](scripts/game/CoopManager.gd:914)).
- The "Prototype Debug HUD" scene nodes are **already hidden** every run by `_hide_legacy_ui()`
  ([CoopManager.gd:294](scripts/game/CoopManager.gd:294)).

**Work:**
1. **Dark neon base + animated grid.** Recolor the `Floor` to a dark base and **refine `_rebuild_floor_grid()`**
   (don't add a parallel grid) into a glowing grid — subtle scroll/pulse, brighter near the players, fading
   at edges so the vignette reads. Keep it cheap (the existing `_draw`/Line2D path, or one shader quad). If
   the grid logic grows, consider extracting it to a dedicated `FloorGrid` script that CoopManager drives.
2. **Frame the arena.** Refine `_add_arena_wall_visuals()` into a glowing neon border on the bounds so the
   space feels intentional, not a void.
3. **Tune the glow.** Raise `WorldEnvironment` glow (`glow_bloom 0.08` → higher, revisit
   `glow_hdr_threshold`/`scale`) so neon elements actually bloom. One global knob, big payoff.
4. **Per-room identity via `ModifierTint`** (concrete rule). Drive the `CanvasModulate` from
   `_active_modifiers` (set in `_apply_active_modifiers`, [CoopManager.gd:1137](scripts/game/CoopManager.gd:1137)),
   which holds *both* passive minors (`enemy_speed`, `swarm`, `shielded`, …) and major hazards
   (`fire_floor`, `ice_zone`, `mine_field`, `shrinking_arena`). Rule: **reset tint to white at room start**;
   if a **major visual hazard** is present, wash the room with that hazard's signature color (single winner
   by a fixed priority order if more than one); **passive-only rooms stay neutral white**. Keep the wash subtle.
5. **Debug HUD — remove or keep hidden, don't re-gate.** It's already hidden by `_hide_legacy_ui()`. Either
   delete the legacy scene nodes outright or leave the existing unconditional hide. **Do NOT** gate on
   `OS.is_debug_build()` — normal editor play *is* a debug build, so that would re-show them.

**Open:** grid style (lines vs dot-field vs faint gradient) — default to a thin glowing line grid; tune in
play. Major-hazard tint priority order when two majors co-occur (rare) — pick a fixed list.

**Implemented:** existing runtime grid/wall builders now produce a dark neon arena with pulsing Line2D grid
metadata, player-proximity line highlights, and layered glowing border lines. `ModifierTint` stays neutral
unless a major hazard is active, then applies one fixed-priority subtle wash. Global bloom is raised in the
scene; the legacy debug HUD remains unconditionally hidden.

## Phase 2 — Enemy/player shape identity + motion

Every enemy renders the **same 8-point octagon** (`Enemy.get_base_visual_polygon`), separated only by
color/scale, and enemy bodies have little motion. (The **player** already has squash/dash-scale/glow/
body-root rotation — see the Player note below; it needs *tuning*, not new motion systems.)

**Work:**
1. **Per-type silhouettes.** Extend `Enemy.get_visual_profile` to return a **distinct polygon per type**
   (chaser = darty arrow, charger = heavy wedge, spitter = ranged/eye, splitter = cluster, bomber = round
   w/ spikes, champions = bigger ornate variants). Because the encyclopedia already renders *through*
   `get_visual_profile`, the codex entries update for free — single source of truth holds.
2. **Procedural motion / life.** Add squash/stretch + wobble for **enemies** (no new art): spawn pop-in,
   hit recoil, death squash-then-burst, idle breathing, lean/bank in the movement direction, telegraph
   swell before charger/bomber commits — driven from their per-frame visual update, not free-running tweens.
   **Player:** the body already squashes/scales every frame in `_apply_visual_state()` /  `_turn_squash`
   ([Player.gd:955](scripts/player/Player.gd:955), which writes `visual.scale` directly at ~971) and has
   dash-scale + glow + body-root rotation. **Tune that existing path** (and add states like hit-recoil/
   spawn there) — do **not** add independent tweens that fight the per-frame `visual.scale` assignment.
3. **Projectile life.** Light spin/pulse on projectiles + the existing trail styles dialed in.

**Open:** how distinct to push silhouettes vs keeping readability at small size — keep bold, low-vertex shapes.

**Implemented:** enemy visual profiles now use distinct per-type silhouettes and procedural motion on the
existing enemy visual update path. Projectiles have render-time spawn pop, pulse, and shape-specific spin /
wobble through the MultiMesh renderer.

## Phase 3 — Impact / juice tuning + coverage

Particles/shake/hit-stop exist; this is making every key moment *land* and be consistent.

**Work:** audit the ~70 juice call sites and ensure each beat is covered + tuned:
- **Enemy death** — squash→burst + impact sparks + small shake (scaled by enemy weight/size).
- **Player hit** — strong flash + shake + brief hit-stop + the low-health vignette ramp.
- **Weapon fire** — muzzle flash per shot (exists; verify per-weapon weight).
- **Champion spawn / death** — big telegraph, screen punch, distinct burst.
- **Room clear / transition** — a satisfying flourish (see Phase 5).
- Tune shake trauma / hit-stop durations / particle counts so it reads as punchy, not noisy.

**Implemented:** key combat beats now have stronger, consistent VFX/SFX coverage: player hit feedback,
weapon fire, projectile impacts, ability activations, champion entrance/death, enemy death, and room clear.
Combat VFX still respect the existing load-suppression path.

## Phase 4 — Audio pass

Audit `SfxEngine` / `MusicEngine` / `AudioBusConfig`: confirm fire/hit/death/champion/UI/pickup all
trigger, and that the procedural SFX feel satisfying (punchy transients, variation to avoid machine-gun
sameness). Verify music is present and ducks/intensifies with combat. Balance bus levels. (Procedural /
synthesized — no external audio assets.)

**Implemented:** existing procedural audio is wired for fire/hit/damage/death/champion/pickup/level-up/
room-clear beats, dash now triggers its dash SFX, startup and dynamically rebuilt UI buttons route through
`play_ui_click` including reward reroll/skip actions, and music contexts are set for menu/map/combat/boss.
Deep musical composition remains deferred; this pass confirms presence, reactivity, and coverage.

## Phase 5 *(optional)* — Transitions & framing

Room enter/exit transitions, camera punch on big events, score/momentum gain feedback, a clean
victory/defeat flourish. Polish layer once 1–4 land.

**Implemented scope:** room start receives a fade-in flash, room clear now plays a centered flourish
(SFX, flash, shake, ring, debris), and momentum tier-ups get a subtle pickup chirp / screen pulse. Larger
victory/defeat framing remains later polish.

## Build order

1. **Phase 1** (arena + glow + legacy debug HUD cleanup) — loudest tell, cheapest fix.
2. **Phase 2** (silhouettes + motion) — biggest "alive" gain; encyclopedia benefits free.
3. **Phase 3** (impact tuning) — make it hit.
4. **Phase 4** (audio) — the other half of "not a prototype".
5. **Phase 5** (transitions) — optional polish.

Each slice: `git diff --check` + headless parse, and a manual look in-play (this patch is felt, not unit-tested).
