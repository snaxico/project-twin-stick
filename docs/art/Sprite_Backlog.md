# Sprite Backlog

Track sprites that need to be generated. Check off when moved to approval.

## Player Bodies

- [x] player_p1.png — approved, integrated
- [ ] player_p2.png — magenta/pink variant
- [ ] player_p3.png — yellow variant
- [ ] player_p4.png — orange variant

## Enemies

- [ ] enemy_chaser.png — small red dart
- [ ] enemy_spitter.png — medium magenta hex
- [ ] enemy_charger.png — large brown wedge
- [ ] boss_main.png — oversized crimson crown

## Primary Weapons

- [ ] weapon_rifle.png — linear, standard hitscan
- [ ] weapon_scatter.png — wide spread shotgun
- [ ] weapon_slug.png — heavy single-shot cannon

## Secondary Weapons (Grenades)

- [ ] grenade_standard.png — round spiky explosive
- [ ] grenade_cluster.png — bumpy cluster explosive
- [ ] grenade_siege.png — large armored explosive

## Secondary Weapons (Mines)

- [ ] mine_standard.png — dome proximity mine
- [ ] mine_shrapnel.png — spiky proximity mine
- [ ] mine_heavy.png — reinforced heavy mine

## Pickups

- [ ] pickup_gold.png — coin/treasure, bright gold
- [ ] pickup_food.png — apple/food, warm red tone

## Objectives

- [ ] objective_generator.png — machine with glowing core

## Projectiles

- [ ] projectile_bullet.png — small bright bullet shape

## Status Summary

- **Total sprites needed**: 20
- **Currently approved**: 1
- **In review**: 0
- **Not started**: 19

## Priority Order

Priority is bottom-up: get the smallest, most reusable sprites first.

1. **Projectile** (smallest, fastest to validate)
2. **Pickups** (small, clear shapes)
3. **Enemies** (core gameplay visual)
4. **Weapons** (support primary identity)
5. **Secondaries** (complexity and distinction)
6. **Objective** (fewer gameplay moments)
7. **Player bodies** (color variants, lower priority)

## Notes

- Each sprite is requested and approved individually
- Background removal is manual post-processing
- Resizing to target dimensions may be needed if ChatGPT outputs wrong size
- Load each approved sprite into Godot to verify scale/pivot before final approval
