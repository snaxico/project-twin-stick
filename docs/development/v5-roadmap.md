# V5 Roadmap — Prototype to Real Game (2026-07-19)

> Decided with the user on 2026-07-19. This is the phase-ordered path from the validated V4 prototype to a
> finished-feeling game. Branch `v4/class-system`, checkout `D:\GameDev\Project_Twin_stick`.

## Goal & Constraints (LOCKED)

- **Ambition: portfolio / for-us.** A finished-feeling game for the user and friends. No Steam/marketing
  work, no stranger-proof onboarding, **no external playtesting** (internal 1P/2P only).
- The core gameplay loop is validated and feels fine. What is missing: better visuals, SFX, and balance —
  the game currently reads as a proof of concept.
- **Run shape: short & replayable.** ~10–15 minute tight runs with heavy build variety driving replay.
  This shrinks the content bar and tilts content work toward upgrades/synergies over raw enemy volume.

## Phase Order (LOCKED: Feel → Run arc → Content → Audio & Art → Finishing)

Content is deliberately produced before the art change; the re-skin cost is accepted and contained because
all rendering is procedural (palette/shader/shape-language level, not per-asset artwork).

### Phase 1 — Feel & Fixes (active)

Detailed plan: `docs/development/v4-feel-polish-plan.md`. Summary: scoped perf pass, concrete playtest
fixes (sawblades, aimed-ability direction, Hazard Floor inversion), spawn-model A/B prototype
(trickle vs pulsed), balance pass, core impact juice pass.

### Phase 2 — Run Arc & Difficulty

- Design the real run: target length ~10–15 min, a proper ending moment replacing the placeholder
  room-10 milestone + endless continue, difficulty options.
- Commit the spawn-model decision from the Phase 1 A/B if not already committed.
- Cheap to build but decides how much content Phase 3 needs — done before content.

### Phase 3 — Content Depth

- Upgrades/synergies first (short-run replayability feeds on build variety), then enemies, champions,
  WHERE mechanics as needed.
- **Un-park the deferred design questions here:** Risk class rework-or-keep, flamethrower/cone, beam.
- Content is produced in placeholder style; keep shapes/silhouettes clean so the Phase 4 re-skin is systemic.

### Phase 4 — Audio & Art Identity

- Art: moodboard/reference session first → 2–3 style tests on one room → choose → systemic rollout.
  No pre-committed direction.
- Audio: **curated asset packs** (license + edit to fit), replacing/augmenting the procedural SFX.
  Designed music direction alongside.

### Phase 5 — Finishing

- Cross-cutting balance over the final roster, menu/UX polish, the "feels complete" pass.

## Parked Until Phase 3+ (LOCKED 2026-07-19)

- **Risk class: no Risk-specific work** (its mechanic, numbers, abilities' presentation). It is the
  simple accessible class for non-gamers; Mobile/Tank/Controller are the main/depth classes. Boundary
  (locked 2026-07-19): shared/global systems (juice tuning, spawn model, arena changes) still apply to
  Risk like every class — only work targeting Risk specifically is excluded.
- **Flamethrower/cone** — parked with Risk (it is Risk's weapon).
- **Beam** — sustained-channel mismatch acknowledged; decision (pulse rework / feel pass / cut) deferred.
- **Full artstyle change** — Phase 4. Juice/hitstop/shake/impact VFX are art-agnostic and land in Phase 1.

## Market Position (checked 2026-07-19)

- Closest comparables: **Brotato** (short wave-based arena runs, classes, builds — the loop comparable),
  **SYNTHETIK 2** (class-kit co-op twin-stick roguelite), **Assault Android Cactus** (local co-op arena
  twin-stick, choreographed spawns), Nuclear Throne / Enter the Gungeon (weapon-feel benchmarks),
  The Spell Brigade / Danger Scavenger / Section 13 (recent co-op arena roguelites).
- itch.io's twin-stick roguelite tags are busy, but few titles combine **couch co-op + class ability
  kits + room choice**; the combination is under-served and a good portfolio position.
- Key structural insight: successful arena games use **pulsed/scripted waves with lulls**, not uniform
  continuous trickle. Continuous spawning structurally favors sustained-DPS weapons and starves burst
  weapons of their moment — this is the suspected root of "some weapons feel strong, some weak".
  Phase 1 prototypes both models behind a debug toggle to test this.
