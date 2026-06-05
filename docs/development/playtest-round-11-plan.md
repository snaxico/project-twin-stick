# Playtest Round 11 — Plan & Implementation (for Codex)

Single self-contained build doc for Round 11. Built collaboratively, point by point. Work on
`v3/main` in `D:\GameDev\Project_Twin_stick` (main checkout, no new worktrees). Do not commit unless
asked. **Round 10 (`b8ae383`) is committed/pushed and is the baseline.**

> STATUS: **DESIGN COMPLETE.** Clusters: arena shrink + 2P camera, map-gen differentiation,
> Encounter Builder HUD, boss telegraph verify + off-screen indicator, UI text-trim, and the
> **performance cluster** (MultiMesh projectiles + drop trails + caps, Perf Runner-driven).
> **9 build slices.** Ready to implement as a Codex build spec. (VFX-throttle readability tuning →
> playtest; MultiMesh-enemies → only if the projectile pass doesn't clear the ceiling.)

## Findings

**From the Round-10 review (completion gaps):**
- Boss telegraphs — **verify** the Round-10 delayed-effect scheduling (Round 10 added
  `_scheduled_enemy_hazards` / `_scheduled_pulsar_emps` / `_scheduled_enemy_shockwaves`); find any
  boss attack that still fires same-frame and fix only those by reusing the existing scheduler.
- Verify the map generator differentiation (route options must actually differ by
  type/elite/modifier, not just render as cards).

**From the playtest:**
- 2P camera too close / awkward (`zoom_max 1.0` overshot; 2P swings empty↔close).
- Arena too big — 4800×2700 (2.5× viewport each axis); large dead space; root of the camera problem.
- Encounter Builder HUD — overlapping text boxes; missing weapons + missing enemies in the lists.
- Pulsar / entity-count perf — projectile-heavy moments still spike (the deferred ceiling).
- Boss off-screen indicator — edge arrow toward an off-screen boss.
- "Too much on screen" — split into (a) **in-combat clutter** (mainly addressed by dropping
  projectile trails + the arena/camera changes; any further VFX-throttle tuning deferred to playtest)
  and (b) **loadout + reward text density** (UI text-trim track).

---

## Decisions (locked)

### Arena shrink + 2P camera retune (linked)
- **Shrink the arena to ~`3000 × 1700`** (≈1.5× the 1920×1080 viewport) — `CoopManager.ARENA_SIZE`
  `(4800,2700) → (3000,1700)`. Cuts dead space, denser combat, and collapses the 2P fit-zoom range.
- **2P camera: retune the shared fit-camera** (no split-screen — stays the deferred fallback if this
  isn't enough). `ZoomCamera`: `zoom_min 0.35 → 0.60`, `zoom_max 1.0 → 0.80`; **leave `padding` at
  (160,140) unchanged** (the problem was zoom, not padding — any padding feel-tuning is a playtest
  note, not an implementation step). Result: ~0.6 fits the whole arena when players are far (no empty void), ~0.8 keeps
  awareness when close (no more 1.0 over-zoom).
- **Dependent constants — first pass changes ONLY `ARENA_SIZE`; do not pre-scale anything else.**
  Most logic reads `ARENA_RECT`/`ARENA_SIZE` and cascades. The absolute-distance constants are
  gameplay sizes (not arena-proportional) and are likely still fine at 3000×1700, so **do not scale
  them blindly** (no-assumptions rule). After the shrink, **measure in play**; change a specific
  constant **only with approval**. Watch-list to evaluate (don't change without sign-off): enemy
  edge-spawn margins, Scanline `EDGE_PADDING`/gaps, Fire-Floor radius/zone count, mine `spread_radius`,
  hazard radii, boss leap/charge distances, `MIN_PLAYER_SEPARATION`, `arena_margin`.

### Encounter Builder / Debug HUD fixes
- **Complete the in-room spawn list** (`CoopManager` `_debug_spawn_option` ~503) — currently a
  hardcoded 6-entry subset. Include **all** types: basics (chaser, charger, spitter, splitter,
  splitter_mini, bomber), elites (elite_charger, elite_spitter, elite_support), bosses (boss_warden,
  boss_hydra, boss_hive, boss_pulsar). Source from a **single shared enemy-type list** (a static
  const/catalog) so the spawn list can't drift from the real roster. (Launcher enemy-mix presets
  left as-is.)
- **In-room weapon selector** — the in-room debug overlay only has a *"Give P1 Weapon Level"* button
  (no way to choose a weapon). Add a **weapon selector** (OptionButton from
  `RunState.get_weapon_catalog()`) + a "Set weapon" action so the active weapon can be switched live
  for testing. (The pre-game starting-weapon picker already uses the catalog — leave it.)
- **Layout overlap** — fix the Encounter Builder panel (the **runtime-created debug rows in
  `Bootstrap.gd`**; touch `Bootstrap.tscn` scene nodes only if actually needed) and the in-room debug
  overlay to use proper containers (VBox/Grid with min sizes + separation) so labels no longer overlap.

### Boss telegraph — VERIFY (do NOT add a second scheduler)
Round 10 already implemented delayed boss effects via `CoopManager._scheduled_enemy_hazards`,
`_scheduled_pulsar_emps`, and `_scheduled_enemy_shockwaves` — so Hive poison clouds and Pulsar
EMP/hazard **already fire after a delay**, not same-frame. This slice is therefore a **verification +
gap-fill**, not a rebuild:
- **Verify** each boss heavy attack telegraphs ≥~0.8s before the effect lands (Warden charge/leap/
  ground-pound, Hydra radial burst/sweep, Hive poison cloud, Pulsar EMP/shockwave/hazard).
- **Identify any attack still firing same-frame** as its tell ring; fix **only those** by routing
  them through the **existing** scheduled queues. Do not introduce a second scheduling mechanism.
- Correction: the `spawn_enemy_homing_orbs` "spore volley" is a **Hydra** attack, not Hive — don't
  attribute it to Hive.
- **Classification — which attacks need a ~0.8s tell vs not:**
  - **Heavy (require the delayed tell; verify they have it):** Warden charge / leap / ground-pound,
    Hydra radial burst + arm sweep, Hive poison cloud, Pulsar EMP / shockwave / hazard.
  - **Light (regular firing — NO 0.8s tell):** Hydra aimed snipes, Hydra homing orbs, Pulsar aimed
    fire, all minion spawns. Do **not** add tells to these; they're inherently telegraphed by travel.
  - Fix only a *heavy* attack found firing same-frame; leave light attacks as-is.

### Boss off-screen indicator
HUD **edge arrow** (on the UI layer / screen frame) pointing toward the active boss whenever it's
outside the camera view; hidden when on-screen. Compute the camera→boss direction, clamp the marker
to the viewport edge. Optional small distance tick. Helps track the boss after the arena shrink /
when kiting.

### Readability ("too much on screen") — addressed indirectly; throttle deferred to playtest
The main clutter sources are handled by other slices: **dropping the per-projectile particle trails**
(perf slice) + the **arena shrink** + **camera retune** substantially declutter the screen. The extra
**VFX-throttle tuning is deferred to playtest** (not a build slice) — re-evaluate after seeing the
post-trail-drop result; if still cluttered, tune the throttle thresholds then with approved numbers.
(Keeps the Codex build a clean linear run with no mid-build approval pause.)

### UI text-trim (loadout + reward screens)
**No focused detail panel exists** (round 10 added a *selected-ability summary label* in `Bootstrap`;
`MutationPickUI` has none) — so this is **hard-truncation + reuse the existing summary**, NOT new panels:
- **Reward card** (`MutationPickUI.gd`): **hard-truncate** the description to **one line** (ellipsis).
  Card = tag line + name + 1-line effect + (commons) `Lv X→Y`. No new panel.
- **Loadout setup** (`Bootstrap.gd`): keep the round-10 **ability summary label** as the full-text
  surface (already shows the selected OFF/DEF descriptions); trim the per-card/row text + redundant
  help labels to name-only.
- *Acceptance:* reward cards + the loadout screen read at a glance, no walls of text; full text stays
  reachable via the summary label (loadout) / the concise card line (reward) — not hover-only.

### Map generator differentiation (verify)
Confirm the Round-10 route-card options actually **differ** per step (room type / elite / modifier
load), per the Round-10 generator rules. If `RunState._build_branching_row` / `_assign_modifiers_to_map`
weren't updated, add the differentiation now. *Acceptance:* a route step's options are not all
identical Combat rooms.

### Performance — MultiMesh projectiles + drop particle trails + caps
(Folded in from the deferred perf round, since Round 11 is otherwise light.) Bottleneck per the Perf
Runner: ~200 enemies+projectiles → ~62 FPS / ~662 draw calls; each projectile = 2 `Polygon2D`
(Visual + Outline) **+ a `GPUParticles2D` trail**.
**MultiMesh renderer contract (concrete — no assumptions):**
- **Reusable renderer keyed by `projectile_shape`:** a standalone **`ProjectileRenderer`** (its own
  class/node, NOT CoopManager-private) holding one `MultiMeshInstance2D` **per distinct
  `projectile_shape`** (`orb`, `small_orb`, `large_orb`, `lance`, `diamond`, `shard`, `blob`,
  `bomb`/`ember_orb`, …) → ~one draw call per shape (≈8–9 total, vs ~400+). **Key on
  `projectile_shape`, NOT `projectile_kind`** — shape is set by weapons AND effect mutations
  (ricochet `diamond`, fire `ember_orb`, freeze `shard`, poison `blob`…); keying on `projectile_kind`
  would collapse those shapes (regression).
- **Meshes match current shapes + explicit render API (do this; don't choose):** the renderer must
  **not** call private `Projectile` methods. Refactor the projectile render helpers into a public API:
  make the shape→polygon builder a **static** `Projectile.build_shape_polygon(shape) ->
  PackedVector2Array` (pure — the renderer builds one mesh per shape from it, pixel-identical to
  today's `_build_shape_polygon`); add per-instance public getters **`get_render_scale() -> Vector2`**
  (the current `_get_shape_scale` logic) and **`get_render_color() -> Color`** (final team tint ×
  over-bright bloom). The renderer reads each active projectile's `projectile_shape`, `global_position`,
  `direction`, and those two getters. No shape regresses.
- **Ownership + reuse:** `CoopManager` owns a `ProjectileRenderer` over its `projectiles` container,
  **AND `ProfilingHarness` instantiates one over its `_projectiles_container`** — so both the real
  game and the `entity_ramp` harness exercise it (without this, harness projectiles would be
  invisible/unmeasured once they stop self-drawing; see Validation).
- **Update lifecycle:** each `_physics_process` the renderer rebuilds instance data from its source's
  active projectiles: group by `projectile_shape`; per shape set `multimesh.instance_count` = active
  count and per instance `instance_transform_2d` (origin = `global_position`, rotation =
  `direction.angle()`, scale from the `_get_shape_scale` logic × `collision_half_width`/`area`) +
  `instance_color`. **Pooled-inactive projectiles excluded.** `multimesh.use_colors = true`.
- **Color/bloom:** `instance_color` = the projectile's final render color (player tint / enemy red ×
  the round-8 render-local over-bright ×1.45). HDR/`WorldEnvironment` glow still applies to MultiMesh output.
- **Projectile scene:** hide/remove the per-projectile `Visual` **and `Outline`** `Polygon2D` (drop the
  outline — body color + bloom is enough; one mesh per kind, not two). **Keep `CollisionShape2D`**
  (Area2D physics). Projectiles become collision + state; visuals come entirely from the MultiMesh.
- **z-index:** all projectile MultiMeshInstance2D share the projectiles' existing z band (above
  floor/enemies, below UI) — same as today.
- **Drop per-projectile particle trails** — remove the `GPUParticles2D` trail (the ~200-particle-
  systems cost); body-only by default, with an optional cheap batched streak later. This **converges
  with the readability finding** (fewer/shorter trails) — so trails are owned here, not in slice 7.
- **Caps — measure/report-only (no blind changes):** after MultiMesh, re-measure and **report**.
  Leave `MAX_ACTIVE_PROJECTILES` + Fire-Bullets pool (`FireTrailZone`) + enemy hazard-zone counts
  **unchanged** unless the measure shows the ceiling isn't cleared — then **propose** specific caps
  for approval, don't apply blindly. (Boss add-wave cap of 25 already exists.) MultiMesh likely makes
  extra caps unnecessary.
- **Validation (Perf Runner, before + after):** `entity_ramp` is the controlled 50→200 draw-call
  check — valid **because `ProfilingHarness` instantiates the same `ProjectileRenderer`** (above);
  `boss:pulsar --players=2 --build=heavy` is the real-room check through `CoopManager`. *Target:*
  draw calls ≈ #shapes regardless of projectile count; ~60+ FPS at realistic counts.
- **Enemies stay per-node** (round-6 already reduced them to 1 polygon each). MultiMesh enemies only
  if projectiles alone don't clear the ceiling — **deferred** to a follow-up.

---

## Build Order & Acceptance (for Codex)

Conventions: headless parse after each slice; line numbers above are **indicative — re-confirm
against live code**. Build in this order:

1. **Arena shrink** — `CoopManager.ARENA_SIZE (4800,2700) → (3000,1700)`; change **only** that, do
   not pre-scale dependent constants (measure after; see the caveat above). *Accept:* arena plays;
   spawns + modifiers cover the smaller space; kiting still works.
2. **2P camera retune** — `ZoomCamera` `zoom_min 0.35→0.60`, `zoom_max 1.0→0.80`; **leave `padding`
   (160,140) unchanged**. *Accept:* 1P readable; 2P framing steady — no empty void when apart, no
   over-zoom when close; both players visible.
3. **Map-generator differentiation** (gameplay, before polish) — verify/implement that route-step
   options genuinely differ (type/elite/modifier load) in `RunState._build_branching_row` /
   `_assign_modifiers_to_map`. *Accept:* a step's options are not all identical Combat rooms.
4. **Encounter Builder / Debug HUD** — complete the in-room spawn list (shared enemy-type list: all
   basics + elites + bosses); add an **in-room weapon selector** (OptionButton from
   `get_weapon_catalog()`) + "Set weapon"; fix the panel layout overlap. *Accept:* every
   enemy/elite/boss spawnable; active weapon switchable live; no overlapping text.
5. **Boss telegraph VERIFY + gap-fill** — confirm Round-10's scheduled delays (`_scheduled_enemy_hazards`
   / `_scheduled_pulsar_emps` / `_scheduled_enemy_shockwaves`) cover every boss heavy attack; fix
   **only** any remaining same-frame attack via the existing scheduler (no second scheduler).
   *Accept:* each boss heavy attack telegraphs ~0.8s before it lands.
6. **Boss off-screen indicator** — HUD edge arrow toward an off-screen boss. *Accept:* arrow appears
   when the boss is off-camera, points correctly, hides when on-screen.
7. **UI text-trim** — reward card description hard-truncated to one line; loadout cards name-only with
   the existing summary label as the full-text surface. *Accept:* loadout + reward read at a glance, no walls of text.
8. **MultiMesh projectiles + drop trails** — one `MultiMeshInstance2D` **per `projectile_shape`**
   (reusable `ProjectileRenderer`; per-instance transform + color; pooled-inactive excluded);
   projectiles stop self-drawing (drop Visual+Outline, keep collision); remove the `GPUParticles2D`
   trails. Follow the renderer contract above. *Accept:* Perf Runner shows draw calls ≈ **#shapes**
   regardless of projectile count; player-tint + bloom preserved; no ghost/missing projectiles.
9. **Re-measure + caps report (measure/report-only — no blind value changes)** — re-run
   `entity_ramp` + `boss:pulsar --players=2 --build=heavy` after slice 8 and **report** FPS/draw/nodes.
   Leave `MAX_ACTIVE_PROJECTILES` and pool/hazard counts **unchanged**; only **if** the measure shows
   the ceiling isn't cleared, report the current values + **propose** specific caps for approval (don't
   change them in this slice). *Accept:* a before/after report exists; ~60+ FPS at realistic counts;
   any cap change is explicitly approved, not assumed.

> Deferred to playtest (not a build slice): the VFX-throttle readability tuning — re-evaluate after
> the trail-drop + arena/camera changes.

**Deferred:** MultiMesh **enemies** — only if projectiles alone don't clear the ceiling. Round 10
(`b8ae383`) is the committed baseline; all Round-11 work above is unbuilt spec.
