# Playtest Round 4 — Validation Checklist

Historical validation checklist for the round-4 patch (see `playtest-round-4-plan.md`).
The current stable `v3/main` baseline also includes the round-5 patch, so use
`playtest-round-5-validation.md` for the build that should be playtested now.

Issues found in the current build should feed the next iteration from the stable baseline.

Headless parse: **passing** for the round-4 state. This checklist is for historical
round-4 in-game behavior + feel.

Suggested runs: **1P structured**, **2P structured**, **1P endless (deep, for perf)**. Tick each item; jot a note on anything that feels off.

---

## F1 — Level-up VFX removed
- [ ] Leveling up produces **no** screen flash / ring / burst.
- [ ] Level-up still works mechanically (pending picks accrue, mutation pick UI appears).

## F2 — Blink rework
- [ ] Blink teleports in **movement** direction (not aim direction).
- [ ] Standing still + blink → goes in last-faced direction (no failed/zero blink).
- [ ] Range feels longer than before (~340).
- [ ] Brief invulnerability on arrival (~0.2s) — blinking into danger isn't instant death.
- [ ] Detonation fires **at arrival point** (damage + knockback + visible blast).
- [ ] Feels **distinct from Dash** — aggressive engage vs short dodge. (Key subjective check.)

## F3 — Objective HUD panel
- [ ] Secondary objective shows a styled panel (icon + title + progress bar), not just text.
- [ ] Progress bar advances correctly toward target.
- [ ] Panel hidden in rooms with no secondary objective.

## F4 — Kill streak = true streak
- [ ] Labeled "Kill Streak", target is a fixed number (18).
- [ ] Taking **real** damage resets progress to 0.
- [ ] Dash i-frames / shield / blink-arrival invuln absorbing a hit does **NOT** reset the streak.
- [ ] Completes at target and stays complete.

## F5 — Elite rework
- [ ] Player **never** spawns on top of an elite (elite spawns far from player spawns).
- [ ] Elite entrance has a telegraph (ring + light shake).
- [ ] **elite_charger:** long telegraphed charge that catches a kiting player + slam shockwave on arrival.
- [ ] **elite_spitter:** fires a 5-shot spread that **leads** the player; must actively dodge.
- [ ] **elite_support:** damaging pulse + minion spawns — can't be ignored.
- [ ] Overall: **kiting is no longer free**; elites pressure you. (Key subjective check.)
- [ ] Elites no longer feel like overlong damage sponges (HP lowered).

## F6 — Overcharge / baseline rebalance
- [ ] Baseline fire rate feels punchier than before (fire_rate 5.0).
- [ ] Overcharge still feels like a noticeable burst, but milder gap vs baseline (1.5× not 2×).
- [ ] Non-Overcharge builds no longer feel flat. (Key subjective check.)

## F7 — Fire trail mutation
- [ ] Trail zones are meaningfully sized (not tiny dots) and visible along flight path.
- [ ] A larger burning **pool** spawns where the projectile hits/expires.
- [ ] It catches enemies the projectile didn't directly kill (area-denial value).
- [ ] ⚠ **Balance watch:** does it trivialize rooms? Note if it feels OP — damage % may need lowering.

## F8 — Settings in pause
- [ ] Pause → **Settings** button opens the panel (no longer disabled).
- [ ] **Gamepad:** can navigate all settings controls + Back with the d-pad/stick. (Original pain point — test on controller.)
- [ ] Screen-effect **Off / Minimal / Full** changes shake/flash behavior live.
- [ ] Per-player **aim mode (Auto / Movement)** toggles and actually changes aiming in-game.
- [ ] Back returns to the pause menu with focus on the Settings button.
- [ ] Pressing pause while in Settings backs out to pause menu (not straight to resume).
- [ ] Resuming the game closes the settings panel.

## F9 — Boss rework
- [ ] **Hydra** is now appropriately tough (was the weakest — HP 600→1400). Not trivially easy, **not** an overcorrected slog.
- [ ] Each boss visibly **escalates** at HP thresholds (more/faster attacks).
- [ ] Phase transitions have a telegraph.
- [ ] Bosses summon **adds** during the fight.
- [ ] Heavy attacks are **telegraphed** with a dodge window (rings before the hit).
- [ ] Check all four: Warden, Hydra, Hive, Pulsar.

## F10 — Enemy projectiles red
- [ ] **All** enemy projectiles read as unmistakably red (no white/pale/pink shots).
- [ ] Clearly distinct from player projectiles at a glance.
- [ ] Check boss projectiles too (Hydra bursts, Pulsar, spitters).

## F11 — Fire zone modifier
- [ ] Zones are bigger (radius 280) and there can be more on screen (up to 7).
- [ ] Zones stay **inside** the arena (no clipping past walls — margin fix).
- [ ] Floor feels like meaningful area denial now.

## F13 — Turret + mines
- [ ] **Turret** hits harder + faster and lasts noticeably longer (9s).
- [ ] **Minefield** ability: more mines (7), bigger trigger range, more damage, lasts longer (14s).
- [ ] Both feel impactful, not throwaway.

## F14 — Performance (do this in 1P endless, deep room)
- [ ] Push to **150+** enemies + projectiles on screen.
- [ ] Frame rate holds acceptably (the goal: no obvious chugging).
- [ ] Projectile pooling: no stutter/hitch when firing rapidly (overcharge + split shot is a good stress test).
- [ ] If it **still** drops frames: that's the signal to escalate to MultiMesh rendering (deferred from Phase 5). Note the entity count + symptom.
- [ ] (No clean Phase-0 baseline was captured, so this is a "does it hold up?" check, not a before/after comparison.)

## F12 — (Deferred)
- Visual/asset upgrade intentionally not in this patch. No validation needed.

---

## Regression spot-checks (things round-4 touched indirectly)
- [ ] Projectiles still despawn correctly (pooling didn't leave ghost bullets or double-hits).
- [ ] Room transitions clean — no leftover projectiles/enemies/effects carrying into the next room.
- [ ] Shockwave ability still destroys enemy projectiles (pooled-projectile path).
- [ ] Pause freeze still stops everything (enemies, projectiles, modifiers).
- [ ] 2P: both players' HUD cards, LT/RT labels, and cooldown rings still correct.

---

## Notes / issues found
(Jot findings here during the run — feeds the next iteration from the stable baseline.)

-
