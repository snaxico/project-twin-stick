# Playtest Round 5 - Combined Round-4 + Round-5 Validation Checklist

Manual validation for the current stable `v3/main` build. The round-4 patch and the
round-5 patch are both part of the runtime state for this checklist.

This checklist supersedes `playtest-round-4-validation.md` for the current stable build.
Use the round-4 checklist only as historical reference for the earlier patch scope.

Headless parse: **passing** after the round-5 implementation and Hive shield safeguard.

Suggested runs: **1P structured**, **2P structured**, **1P endless deep**, and a
boss-focused/debug pass if convenient. Tick each item and note any behavior that feels unfair,
too weak, too slow, or too expensive at high entity counts.

---

## Baseline Flow
- [ ] 1P structured run starts cleanly from the main menu.
- [ ] 2P structured run starts cleanly and shared XP/pick flow still works.
- [ ] Room-end mutation picks appear for pending picks and clear correctly.
- [ ] Health reset between rooms still works as expected.
- [ ] Structured map readability is acceptable after several rooms.
- [ ] Endless can run past wave 20 without obvious progression or spawn failures.

## Main Menu, Pause, And Controller UX
- [ ] Main-menu Settings key rebinding works.
- [ ] Main-menu controller rebinding works and persists correctly.
- [ ] Pause menu has no in-run Settings button or Settings panel.
- [ ] Pause focus cycles cleanly through Resume, Restart, and Main Menu.
- [ ] Pause build summary remains visible and readable.
- [ ] Ability select remains usable with controller focus/navigation.
- [ ] Aim mode remains playable at the current default behavior.

## Round-4 Regression Checks
- [ ] Leveling up produces no screen flash/ring/burst VFX.
- [ ] Blink teleports in movement direction, not aim direction.
- [ ] Standing still + Blink uses last-faced direction instead of failing.
- [ ] Blink arrival invulnerability prevents instant death on arrival.
- [ ] Blink detonation happens at the arrival point with visible damage/knockback.
- [ ] Objective HUD panel shows icon/title/progress and hides when no objective exists.
- [ ] Kill Streak resets only on real damage, not absorbed hits or invulnerability.
- [ ] Enemy projectiles are visibly red enough to separate from player projectiles.
- [ ] Fire Floor uses the current 280px radius and 7s duration values.
- [ ] Minefield/Turret room modifiers still spawn and clean up correctly.
- [ ] Projectile/enemy pooling has no ghost hits or stale visuals between rooms.

## Fire Bullets
- [ ] Mutation appears as Fire Bullets, not Fire Trail, in player-facing UI.
- [ ] Description matches the effect: projectiles ignite a burning pool where they hit.
- [ ] Projectiles no longer create burning zones along the flight path.
- [ ] Impact pools appear only on hit/death and feel readable at 50px radius.
- [ ] 2s pool lifetime feels useful but not dominant.
- [ ] Fire Bullets does not reintroduce the prior projectile/enemy performance problem.

## Overcharge
- [ ] Cooldown is effectively 22s.
- [ ] Burst is 30% faster firing without extra projectiles.
- [ ] Overcharge feels noticeable but not mandatory.
- [ ] Overcharge stacking with split shot / Fire Bullets does not dominate rooms.

## Elites
- [ ] Elites still spawn away from player start positions.
- [ ] Act 1 elites remain beatable without becoming trivial.
- [ ] Act 2 elites feel meaningfully stronger through HP/damage/cooldown scaling.
- [ ] Elite add waves spawn 2-3 regular enemies during the fight.
- [ ] Add waves stop after the elite dies.
- [ ] Add waves increase pressure without turning elite rooms into unavoidable swarms.

## Warden
- [ ] Leap telegraph is readable before the Warden relocates/slams.
- [ ] Leap catches excessive kiting without feeling instant or unavoidable.
- [ ] Multi-charge sequence is readable in phase 2 and phase 3.
- [ ] Ground-pound shockwaves add pressure at range.
- [ ] Fight is no longer trivial for a player who only kites backward.

## Hydra
- [ ] Aimed snipe shots force movement between larger patterns.
- [ ] Arm sweep is readable and dodgeable.
- [ ] Phase-transition minions spawn correctly at 67% and 33%.
- [ ] Slow homing orbs track visibly without becoming impossible to parse.
- [ ] Overall Hydra pressure feels like bullet hell rather than a passive turret.

## Hive
- [ ] Protective shield spawns exactly 4 shield minions.
- [ ] Hive is immune while shield minions are alive.
- [ ] Shield minions can be killed and immunity clears reliably.
- [ ] Phase transition does not spawn a new shield while the old shield is still alive.
- [ ] Poison cloud area is readable and avoidable.
- [ ] Burrow/relocate is understandable and does not break targeting.
- [ ] Minion escalation increases pressure without making the fight a slog.
- [ ] Hive cannot leave persistent shield/minion state after death or room cleanup.

## Pulsar
- [ ] Teleport repositioning is visible and does not feel like an invisible hitbox jump.
- [ ] EMP telegraph is readable before the lockout applies.
- [ ] EMP delays Dash and non-Dash ability cooldowns additively.
- [ ] EMP does not permanently break ability cooldown state.
- [ ] Beam telegraph is readable before damage starts.
- [ ] Beam sweep is dangerous but avoidable in the current arena layout.
- [ ] Beam currently has no line-of-sight raycast; note if walls/cover make that unfair.
- [ ] Phase-3 pressure feels higher without becoming unreadable.

## Performance And Entity Load
- [ ] 100+ active enemies/projectiles does not cause severe frame drops.
- [ ] 150+ active enemies/projectiles remains playable or degrades gracefully.
- [ ] Boss fights with homing orbs/minions/add waves do not create severe stalls.
- [ ] Fire Bullets impact-only pools keep node counts bounded.
- [ ] Deep endless does not show stale pooled projectiles, lingering damage zones, or ghost hits.
- [ ] Note approximate enemy/projectile counts when performance issues appear.

## Watch Items
- [ ] Pulsar beam line-of-sight: acceptable as designed, or needs a raycast/blocking rule.
- [ ] Hive shield + minion pressure: challenging, or too slow/sloggy.
- [ ] Boss entity load: acceptable, or too expensive with homing orbs/minions/add waves.
- [ ] Fire Bullets balance: useful, too weak, too strong, or still too expensive.
- [ ] Overcharge balance: noticeable enough, or nerfed below usefulness.
- [ ] Main-menu binding editor: no regression from removing in-run pause Settings.

## Notes
- Run:
- Player count:
- Mode:
- Wave/room reached:
- Bosses encountered:
- Performance notes:
- Balance notes:
- Bugs:
