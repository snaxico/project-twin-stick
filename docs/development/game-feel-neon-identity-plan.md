# Game Feel & Neon Identity Patch — plan

> Status: **design shaped with the user (2026-06-22), not implemented.** On `v3/structure-rework`. Goal:
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

The arena is the loudest prototype tell. In [GameWorld.tscn](scenes/game/GameWorld.tscn):
- `Floor` is a flat muddy-beige `Color(0.28, 0.3, 0.25)` rectangle that clashes with the neon palette.
- `FloorGrid` is an **empty** `Node2D` (no grid drawn).
- Wall visuals are `visible = false`; the play space has no framing.
- A literal **"Prototype Debug HUD"** (raw `P1`/`P2` labels, "Cycle Aim Mode" buttons, "Room status" /
  "Modifier status" text) lives in the scene's `UI` layer.

**Work:**
1. **Dark neon base + animated grid.** Replace the beige floor with a dark base; draw a glowing grid in
   `FloorGrid` (code `_draw` or a shader) — subtle scroll/pulse, brighter near the players, fading at
   edges so the vignette reads. Keep it cheap (one `_draw`, or a single shader quad).
2. **Frame the arena.** A glowing neon border on the bounds (the walls exist as colliders) so the space
   feels intentional, not a void.
3. **Tune the glow.** Raise `WorldEnvironment` glow (`glow_bloom 0.08` → higher, revisit
   `glow_hdr_threshold`/`scale`) so neon elements actually bloom. One global knob, big payoff.
4. **Per-room identity via `ModifierTint`.** Use the existing `CanvasModulate` to wash the room with the
   active modifier's color (subtle), so rooms feel distinct.
5. **Hide the debug HUD in normal play.** Verify the real combat HUD (HealthBarHUD/inventory HUDs) is the
   live one, then gate the `Prototype Debug HUD` labels/buttons behind a debug flag (off by default).

**Open:** grid style (lines vs dot-field vs faint gradient) — default to a thin glowing line grid; tune in play.

## Phase 2 — Enemy/player shape identity + motion

Every enemy renders the **same 8-point octagon** (`Enemy.get_base_visual_polygon`), separated only by
color/scale — and the player/most shapes are static (no squash/stretch).

**Work:**
1. **Per-type silhouettes.** Extend `Enemy.get_visual_profile` to return a **distinct polygon per type**
   (chaser = darty arrow, charger = heavy wedge, spitter = ranged/eye, splitter = cluster, bomber = round
   w/ spikes, champions = bigger ornate variants). Because the encyclopedia already renders *through*
   `get_visual_profile`, the codex entries update for free — single source of truth holds.
2. **Procedural motion / life.** Add squash/stretch + wobble via `visual.scale`/rotation tweens, no new
   art: spawn pop-in, hit recoil, death squash-then-burst, idle breathing, lean/bank in the movement
   direction, telegraph swell before charger/bomber commits. Same treatment for the player body.
3. **Projectile life.** Light spin/pulse on projectiles + the existing trail styles dialed in.

**Open:** how distinct to push silhouettes vs keeping readability at small size — keep bold, low-vertex shapes.

## Phase 3 — Impact / juice tuning + coverage

Particles/shake/hit-stop exist; this is making every key moment *land* and be consistent.

**Work:** audit the ~70 juice call sites and ensure each beat is covered + tuned:
- **Enemy death** — squash→burst + impact sparks + small shake (scaled by enemy weight/size).
- **Player hit** — strong flash + shake + brief hit-stop + the low-health vignette ramp.
- **Weapon fire** — muzzle flash per shot (exists; verify per-weapon weight).
- **Champion spawn / death** — big telegraph, screen punch, distinct burst.
- **Room clear / transition** — a satisfying flourish (see Phase 5).
- Tune shake trauma / hit-stop durations / particle counts so it reads as punchy, not noisy.

## Phase 4 — Audio pass

Audit `SfxEngine` / `MusicEngine` / `AudioBusConfig`: confirm fire/hit/death/champion/UI/pickup all
trigger, and that the procedural SFX feel satisfying (punchy transients, variation to avoid machine-gun
sameness). Verify music is present and ducks/intensifies with combat. Balance bus levels. (Procedural /
synthesized — no external audio assets.)

**Open:** how much music to invest now vs a later dedicated pass — default to "ensure present + reactive",
deep musical design deferred.

## Phase 5 *(optional)* — Transitions & framing

Room enter/exit transitions, camera punch on big events, score/momentum gain feedback, a clean
victory/defeat flourish. Polish layer once 1–4 land.

## Build order

1. **Phase 1** (arena + glow + hide debug HUD) — loudest tell, cheapest fix.
2. **Phase 2** (silhouettes + motion) — biggest "alive" gain; encyclopedia benefits free.
3. **Phase 3** (impact tuning) — make it hit.
4. **Phase 4** (audio) — the other half of "not a prototype".
5. **Phase 5** (transitions) — optional polish.

Each slice: `git diff --check` + headless parse, and a manual look in-play (this patch is felt, not unit-tested).
