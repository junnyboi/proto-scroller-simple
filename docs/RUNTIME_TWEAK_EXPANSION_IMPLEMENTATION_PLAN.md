# Runtime Tweak Expansion Implementation Plan

## Objective

Reorganize every existing runtime-tweak descriptor into the fixed order `UI`,
`GAMEPLAY`, `AUDIO`, `PLAYER`, `ENEMIES`, `ENVIRONMENT`; remove the legacy
category model; add an extensive set of controls backed by real runtime
consumers; and preserve boundary semantics, persistence, ranked-run integrity,
localization, responsive layouts, and sandbox safety.

The implementation excludes inert controls. Every added descriptor has a
runtime consumer and an automated observation point.

## Final category model and totals

1. `UI` — 12 controls
2. `GAMEPLAY` — 14 controls
3. `AUDIO` — 11 controls
4. `PLAYER` — 32 controls
5. `ENEMIES` — 30 controls
6. `ENVIRONMENT` — 24 controls
7. `SESSION` — synthetic sandbox tab, always last

The final catalog contains 123 controls: 52 existing controls, regrouped without
renaming their stable IDs, plus 71 additions.

## Existing controls regrouped (52)

### UI (4)

- `interface.hud.scale`
- `interface.hud.tint`
- `interface.leaderboard_timeout_seconds`
- `interface.title_transition_duration_scale`

### Gameplay (4)

- `progression.combo.base_grace_seconds`
- `progression.combo.max_multiplier`
- `progression.rewards.named_boss_multiplier`
- `progression.score.bank_base_seconds`

### Audio (1)

- `projectile.hostile_impact_pitch_jitter`

### Player (14)

- `feedback.full_charge_hit_stop_ms`
- `feedback.player_jab_camera_impulse`
- `feedback.player_slam_camera_impulse`
- `input.controller_vibration_enabled`
- `input.mobile_deadzone`
- `input.mobile_response_speed`
- `input.mobile_smash_cooldown`
- `player.melee.charge_duration`
- `player.melee.ground_smash_damage`
- `player.melee.ground_smash_radius`
- `player.move.ground_acceleration`
- `player.move.max_speed`
- `player.visual.scale`
- `player.visual.tint`

### Enemies (16)

- `boss.animation_moving_fps`
- `boss.exposed_health_multiplier`
- `boss.intro_screen_seconds`
- `boss.reinforcement_interval_multiplier`
- `boss.s04_release_camera_impulse`
- `boss.standard_projectile_damage_multiplier`
- `enemy.aegis_aura_radius`
- `enemy.aegis_damage_taken_multiplier`
- `enemy.outgoing_damage_multiplier`
- `enemy.static_attack_interval_multiplier`
- `enemy.target_mark_damage_multiplier`
- `enemy.visual.scale`
- `enemy.visual.tint`
- `projectile.hostile_lifetime`
- `spawn.interval_scale`
- `spawn.quantity_multiplier`

### Environment (13)

- `world.facade.chain_delay_multiplier`
- `world.facade.damaged_stage_ratio`
- `world.facade.health_multiplier`
- `world.facade.support_transfer_ratio`
- `world.parallax.motion_multiplier`
- `world.repair_drop.amount`
- `world.repair_drop.lifetime_seconds`
- `world.sky.day_night_cycle_seconds`
- `world.sky.traffic_speed_multiplier`
- `world.street_prop.health_multiplier`
- `world.weather.density_multiplier`
- `world.weather.motion_multiplier`
- `world.weather.opacity_multiplier`

## New controls (71)

### UI additions (8)

- `interface.hud.opacity`
- `interface.motion_scale`
- `interface.screen_shake_scale`
- `interface.flash_intensity`
- `interface.reticle.scale`
- `interface.reticle.opacity`
- `interface.combo_herald.duration_scale`
- `interface.district_banner.duration_scale`

### Gameplay additions (10)

- `progression.combo.units_per_tier`
- `gameplay.momentum.surge_threshold`
- `gameplay.momentum.critical_threshold`
- `gameplay.momentum.motion_gain_per_second`
- `gameplay.momentum.idle_loss_per_second`
- `gameplay.momentum.idle_grace_seconds`
- `gameplay.overdrive.duration_seconds`
- `gameplay.overdrive.force_multiplier`
- `gameplay.overdrive.structure_multiplier`
- `gameplay.overdrive.acceleration_multiplier`

### Audio additions (10)

- `audio.mechanics.gain_db`
- `audio.threat.gain_db`
- `audio.ui.gain_db`
- `audio.ambience.gain_db`
- `audio.music_duck.depth_db`
- `audio.music_duck.attack_seconds`
- `audio.music_duck.release_seconds`
- `audio.player.footstep_gain_db`
- `audio.player.combat_gain_db`
- `audio.enemy.impact_gain_db`

Bus controls are additive offsets over persistent user volume settings.

### Player additions (18)

- `player.move.ground_deceleration`
- `player.move.air_acceleration`
- `player.move.gravity`
- `player.health.max_health`
- `player.dodge.speed`
- `player.dodge.duration`
- `player.dodge.invulnerability_seconds`
- `player.dodge.recovery_seconds`
- `player.dodge.cooldown_seconds`
- `player.dodge.double_tap_window`
- `player.jab.speed_threshold`
- `player.jab.actor_damage`
- `player.jab.structural_damage`
- `player.melee.max_charge_multiplier`
- `player.visual.animation_speed`
- `player.visual.afterimage_alpha`
- `player.visual.dust_intensity`
- `player.visual.critical_health_ratio`

### Enemy additions (14)

- `enemy.health_multiplier`
- `enemy.movement_speed_multiplier`
- `enemy.acceleration_multiplier`
- `enemy.attack_interval_multiplier`
- `enemy.projectile_speed_multiplier`
- `enemy.anticipation_multiplier`
- `enemy.score_multiplier`
- `enemy.telegraph.duration_multiplier`
- `enemy.visual.bounce_height_multiplier`
- `enemy.visual.bounce_frequency_multiplier`
- `boss.armor_multiplier`
- `boss.health_multiplier`
- `boss.projectile_speed_multiplier`
- `boss.telegraph.duration_multiplier`

### Environment additions (11)

- `environment.parallax.sky_motion_multiplier`
- `environment.parallax.far_motion_multiplier`
- `environment.parallax.infrastructure_motion_multiplier`
- `environment.parallax.near_motion_multiplier`
- `environment.sky.start_phase`
- `environment.weather.transition_seconds`
- `environment.weather.portrait_density_scale`
- `environment.hazard.telegraph_multiplier`
- `environment.hazard.damage_multiplier`
- `environment.hazard.radius_multiplier`
- `environment.hazard.impulse_multiplier`

## Implementation phases

### Phase 1 — Catalog and panel foundation

1. Replace legacy categories with the six supported categories and explicit order.
2. Add bounded typed descriptors with labels, descriptions, tags, apply modes,
   and integrity classes.
3. Validate supported categories and the momentum surge/critical relationship.
4. Grow the row pool on demand while preserving responsive layout and focus.
5. Keep `SESSION` synthetic and last.

### Phase 2 — Runtime consumers

1. UI: HUD opacity, global motion, camera shake, flashes, reticle presentation,
   combo-herald timing, and district-banner timing.
2. Gameplay: combo progression, momentum flow, and frozen overdrive output.
3. Audio: non-compounding live bus offsets, music ducking, player cue gains, and
   hostile-impact gain.
4. Player: movement, health, dodge, jab/charge output, animation, afterimages,
   dust, and critical-health presentation at their declared boundaries.
5. Enemies: spawn durability/movement/cadence/score snapshots, attack
   projectile/anticipation/telegraph snapshots, live bounce presentation, and
   boss durability/projectile/telegraph snapshots.
6. Environment: per-layer parallax, district sky/weather snapshots, and
   spawn-snapshotted hazard profiles.

### Phase 3 — Settings, sandbox, and localization

1. Populate the sandbox from the validated current enemy roster.
2. Add matching English and Simplified Chinese strings for every descriptor.
3. Update repository documentation and catalog revision.

### Phase 4 — Verification

1. Validate catalog uniqueness, counts, category order, metadata, ranges, and
   bilingual key coverage.
2. Test dynamic row growth, persistence, boundary consumption, provenance, and
   spawn snapshots.
3. Run JSON validation, Godot import and parse checks, focused GUT suites,
   headless smoke, and the repository verification gate where the concurrent
   simplification asset state permits it.

## Safety and compatibility contract

- Existing parameter IDs are unchanged, so saved deltas remain readable.
- Apply boundaries remain `LIVE`, `NEXT_ATTACK`, `NEXT_SPAWN`, `NEXT_DISTRICT`,
  and `NEXT_RUN`; no active attack, actor, district, or run changes mid-boundary.
- Cosmetic controls never affect collision, damage, score, targeting, pool
  capacity, or spawn geometry.
- Gameplay and score-affecting values taint ranked eligibility only when their
  declared boundary consumes a nondefault value.
- Session commands remain allowlisted, bounded, pause-safe, and permanently mark
  the run `SANDBOX` after a successful mutation.
- Existing concurrent simplification changes are preserved.
