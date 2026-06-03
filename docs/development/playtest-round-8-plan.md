# Round 8 Plan — Offense Power, Difficulty Curve, Bloom, Generated SFX

## Context

Playtest feedback on the round-7 build:
- **Difficulty curve is off** — first level too easy, then increases too fast. Player likes the
  *amount* of enemies but wants the **player to be stronger** and **offense to be fun**.
- **Looks boring** (round-7 bloom isn't landing).
- **SFX are bad** — improve them, but **generated/procedural** (no audio asset files available).
- **Projectiles should match the player color** — **already implemented** (see §5).

Decisions: **buff player power + flatten the curve**; **better procedural SFX** (not imported);
fix bloom by going over-bright. Plan only — no implementation in this doc.

---

## 1. Offense buff — stronger player, fun offense

**Why:** offense doesn't feel powerful; player wants to feel strong from level 1. (A8 fire-rate
was deferred in round 7 — pull it forward now.)

**Changes (`data/weapons.json` rifle, currently `fire_rate 5.0 / damage 16.0`):**
- `fire_rate` 5.0 → **~6.5** (A8, tune in play).
- `damage` 16.0 → **~20** (tune).
- Leave `projectile_speed 850` / `range 950` unless it still feels weak.

**No separate front-load mechanic** (avoids arbitrary, hard-to-tune starting power). L1 strength
comes from the global offense buff above (applies everywhere) + the gentler early rooms in §2 —
together those make L1 feel strong *and* keep the ramp smooth. If a dedicated starting bonus is
wanted later it must be fully specified before implementing (exact mutation id, per-player,
which modes — structured/endless/debug, and whether it consumes a level-up pick); out of scope
for this round.

**Feel multiplier:** §3 (over-bright bloom) + the round-7 hit-stop make the *same* numbers feel
far punchier — so tune fire-rate/damage *after* §3 lands; you may need less than it seems.

**Perf:** higher fire rate = more projectiles = pressure on the round-6 gate. Re-check with the
`DebugOverlay` (F3) after this.

## 2. Flatten the difficulty curve

**Why (root cause):** the curve is **flat within Act 1, then a hard step at Act 2**, not a smooth
ramp. Current (`CoopManager.gd`):
- `_get_room_duration()`: Act 1 = 35s, Act 2 = 45s (+10 elite, +10 endless≥20).
- `_get_spawn_interval()`: Act 1 = 0.7s, **Act 2 = 0.5s** (−0.1 elite, −0.05 at depth≥10/≥20).
- `_spawn_opening_burst()`: Act 1 = **6**, Act 2 = **8**.
- `_burst_interval`: 10s (Act 1) / 8s (Act 2).
- On top: Act 2 enemy pool is tougher, bosses ×2 HP, elites ×1.5.

So every Act 1 room is identical (trivial), then Act 2 spikes on *four* axes at once.

**Change to a progress-scaled ramp** (smooth climb, no Act-2 cliff). First define a single
normalized progress `t ∈ [0,1]` so randomized act lengths don't break it:
- Add `RunState.get_run_progress() -> float`:
  - **Structured:** `t = clamp(float(global_depth - 1) / float(max(total_combat_depth - 1, 1)), 0, 1)`
    where `total_combat_depth` = the run's last combat row's global depth (RunState builds the
    rows, so it knows this; compute once at generation and store).
  - **Endless:** `t = clamp(float(room_number - 1) / 20.0, 0, 1)` (soft horizon at room 20).
  - Bosses can reuse the room's own `t`; they're per-encounter, not part of the cadence ramp.
- Then interpolate each knob by `t` (replace the binary Act 1/2 branches), explicit endpoints:
  - `room_duration   = lerp(32, 45, t)` (+10 elite; +5 endless ≥ depth 20)
  - `spawn_interval  = lerp(0.80, 0.50, t)` (−0.07 elite; floor `max(…, 0.30)`)
  - `opening_burst   = round(lerp(4, 9, t))` (×2 swarm)
  - `_burst_interval = lerp(11.0, 7.0, t)`
- **Enemy-pool cliff:** keep boss ×2 HP and elite ×1.5 as-is (per-encounter, not the ramp). The
  remaining hard step is the binary Act-1/Act-2 enemy *pool*; **softening that is the one bigger
  change** — make the pool/mix escalate with `t` instead of swapping at the act boundary. If
  that's too much scope now, do the cadence interpolation first and leave the pool swap, noting
  the Act-2 pool jump as a known residual.
- **Keep enemy *amount* roughly the same** (player likes it) — these endpoints are tuned to
  flatten the *rate of increase*, not cut totals; tune in play.
- Functions: `_get_room_duration()`, `_get_spawn_interval()`, `_spawn_opening_burst()`, the
  `_burst_interval` assignment in `_start_room`, and the new `RunState.get_run_progress()`.

## 3. Over-bright bloom — fix "looks boring"

**Why:** glow is enabled (`GameWorld.tscn`: `glow_hdr_threshold 0.8`, `glow_hdr_scale 1.35`) and
HDR 2D is on, but **nothing is pushed over-bright**, so almost nothing crosses the threshold —
bloom is technically on but invisible. (The round-7 A1 "emissive target" step was skipped.)

**Change:** push key colors **over-bright (×~1.3-1.6)** so they actually bloom — player core,
player projectiles, enemy projectiles, hit/kill flashes, and ability VFX. Tune threshold/scale
alongside.
- **Render-local only — do NOT mutate gameplay/UI color sources.** `player_config.tint` also
  drives the HUD / loadout / readability, so over-bright must be applied at *draw time* (e.g.
  multiply the visual node's draw color, a `self_modulate`/material brightness, or a separate
  derived "glow color"), never by changing the persistent `player_config.tint`, enemy base
  feedback colors, or the global UI palette.
- Files: `Player.gd` / `Projectile.gd` `_apply_visual_state` / `Enemy.gd` visual /
  `ParticleFactory.gd` — apply the over-bright factor to the rendered color, leaving the
  source tints/palettes untouched.

## 4. Better generated SFX (procedural — no asset files)

**Why:** procedural SFX sound bad, but no audio files are available — so improve the *synthesis*,
don't import.

**Architecture (decided): keep the existing path.** `SfxEngine.gd` already uses a pool of 16
`AudioStreamPlayer` + `AudioStreamGenerator`, building frame buffers per trigger via the
`_build_*_frames()` functions. This quality pass **improves those `_build_*_frames` functions +
adds bus FX** — it does NOT refactor to pre-baked `AudioStreamWAV`s (that would be a different
playback model; note it only as a possible future perf optimization if per-trigger synth ever
shows cost).

**Change (within the generator path):**
- Richer `_build_*_frames`: layer tone + noise, pitch envelopes (attack/decay), slight detune /
  multiple partials instead of single bare blips.
- Distinct, recognizable profiles for: fire, hit, enemy death, level-up sting, pickup, ability
  cast, boss phase.
- Per-trigger **pitch variation** (±10-15%) so repetition doesn't fatigue.
- A **master-bus limiter + a touch of reverb** for cohesion/punch (AudioServer bus effects, no
  assets).

## 5. Projectile color = player — DONE

Already implemented + committed (`acf8672`, `Projectile.gd`): for `team == "player"`, the
accent/outline is forced to `tint_color.lightened(0.22)` (player green), overriding the
per-mutation accent — so player projectiles read as the player color.
**Consequence:** per-mutation **accent color no longer differentiates** player projectiles, so
build distinction now relies on **projectile shape / trail pattern / impact / SFX** (Track C),
not color. Keep that in mind when tuning Track C — lean on shape/trail/SFX, not accent hue.

---

## Suggested order
1. **§3 bloom over-bright** (makes everything look/feel better immediately, informs §1 tuning).
2. **§1 offense buff** (then re-check perf via DebugOverlay).
3. **§2 curve flatten** (the main complaint; tune against the buffed player).
4. **§4 procedural SFX quality pass.**

## Verification
1. Headless parse: `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\GameDev\Project_Twin_stick --quit`
2. Perf re-check (DebugOverlay F3, 1P + 2P) after §1 fire-rate + §3 bloom.
3. Manual feel: L1 feels strong and fun (offense satisfying); difficulty ramps smoothly with no
   Act-2 cliff; neon glow is clearly visible; SFX sound noticeably better and distinct per event;
   player projectiles read green.
