class_name RuntimeBudget
extends RefCounted

const SOLDIERS: int = 24
const TANKS: int = 4
const HELICOPTERS: int = 2
const PROCEDURAL_INFANTRY: int = 24
const PROCEDURAL_LIGHT: int = 6
const PROCEDURAL_HEAVY: int = 8
const PROCEDURAL_AIR: int = 8
const PROCEDURAL_SIEGE: int = 4
const PROCEDURAL_ENEMIES: int = (
	PROCEDURAL_INFANTRY
	+ PROCEDURAL_LIGHT
	+ PROCEDURAL_HEAVY
	+ PROCEDURAL_AIR
	+ PROCEDURAL_SIEGE
)
const BULLETS: int = 16
const SHELLS: int = 4
const ROCKETS: int = 4
const PLAYER_BULLETS: int = 8
const STRUCTURAL_DEBRIS: int = 24
const BUILDING_SECTION_BURST_SLOTS: int = 12
const STREAMED_BUILDINGS: int = CityWorldStream.CHUNK_CAPACITY
const STREAMED_PROPS: int = CityWorldStream.CHUNK_CAPACITY * 2
const WORLD_MUTATION_LEDGERS: int = 1
const BUILDING_DAMAGE_PATTERNS: int = (
	STREAMED_BUILDINGS * StructuralBuilding2D.CELL_COUNT
)
const STRUCTURAL_RUBBLE_SPRITES: int = (
	STREAMED_BUILDINGS
	* StructuralBuilding2D.COLUMNS
	* BuildingDamagePattern2D.RUIN_RUBBLE_SPRITE_COUNT
)
const PROP_RUBBLE_SPRITES: int = (
	STREAMED_PROPS * DestructibleProp2D.TERMINAL_RUBBLE_PIECE_COUNT
)
const ENEMY_SCRAP: int = 32
const SOLDIER_DEFEATS: int = 8
const WRECKS: int = 4
const PARTICLE_SLOTS: int = 8
const AUDIO_VOICES: int = 8
const ROBOT_AUDIO_VOICES: int = 7
const AIR_TARGET_VOICES: int = 1
const AIR_TARGET_RETICLES: int = 1
const RARE_TAG_ROWS: int = 3
const TELEGRAPH_RECORDS: int = 12
const CATALYST_SLOTS: int = 2
const CATALYST_RUBBLE_SPRITES: int = (
	CATALYST_SLOTS * DestructibleProp2D.TERMINAL_RUBBLE_PIECE_COUNT
)
const ACTIVE_CATALYSTS: int = 2
const REPAIR_PICKUP_SLOTS: int = CatalystRuntime.REPAIR_PICKUP_CAPACITY
const ACTOR_RESERVATIONS: int = 18
const PENDING_BEAT_RECORDS: int = 48
const CATALYST_QUERY_RESULTS: int = 12
const DIRECTIVE_SESSIONS: int = 1
const DIRECTIVE_CARDS: int = 1
const DIRECTIVE_OVERLAYS: int = 1
const PAUSE_COORDINATORS: int = 1
const ROLE_BADGES: int = SOLDIERS + TANKS + HELICOPTERS + PROCEDURAL_ENEMIES
const TRAIT_RUNTIMES: int = 1
const BOSS_SESSIONS: int = 1
const BOSS_RIGS: int = 1
const BOSS_ARENA_BARRIERS: int = 1
const BOSS_DEFEAT_SPECTACLES: int = 1
const BOSS_DEFEAT_VISUAL_SLOTS: int = (
	BossDefeatSpectacle2D.EXPLOSION_SLOT_CAPACITY
	+ BossDefeatSpectacle2D.FIREWORK_SLOT_CAPACITY
)
const BOSS_DEFEAT_PARTICLE_EMITTERS: int = (
	BossDefeatSpectacle2D.EXPLOSION_EMITTER_CAPACITY
	+ BossDefeatSpectacle2D.FIREWORK_EMITTER_CAPACITY
)
const BOSS_DEFEAT_PARTICLE_CAPACITY: int = (
	BossDefeatSpectacle2D.EXPLOSION_EMITTER_CAPACITY
	* BossDefeatSpectacle2D.EXPLOSION_PARTICLES_PER_EMITTER
	+ BossDefeatSpectacle2D.FIREWORK_EMITTER_CAPACITY
	* BossDefeatSpectacle2D.FIREWORK_PARTICLES_PER_EMITTER
)
const BOSS_DEFEAT_AUDIO_PLAYERS: int = 1
const BOSS_CONTROLLERS: int = 1
const BOSS_ARENA_ADAPTERS: int = 1
const BOSS_PYLON_PRESENTATIONS: int = BossUtilityPool.PYLON_PRESENTATION_CAPACITY
const BOSS_PROJECTION_SLOTS: int = BossUtilityPool.PROJECTION_SLOT_CAPACITY
const BOSS_MARKERS: int = BossUtilityPool.MARKER_CAPACITY
const BOSS_LANE_DAMAGE_AREAS: int = BossUtilityPool.LANE_DAMAGE_AREA_CAPACITY
const BOSS_LINE_AREAS: int = BossUtilityPool.LINE_AREA_CAPACITY
const BOSS_RADIAL_SHOCKWAVES: int = BossUtilityPool.RADIAL_SHOCKWAVE_CAPACITY
const BOSS_COLLAPSE_LISTENERS: int = BossUtilityPool.COLLAPSE_LISTENER_CAPACITY
const BOSS_POD_VISUALS: int = BossUtilityPool.POD_VISUAL_CAPACITY
const BOSS_RECLAMATION_ANCHORS: int = BossUtilityPool.RECLAMATION_ANCHOR_CAPACITY
const BOSS_WRECK_RECEIVERS: int = BossUtilityPool.WRECK_RECEIVER_CAPACITY
const BOSS_RUBBLE_PRESENTATIONS: int = 1
const CAUSAL_RECORDS: int = CausalChainTracker.MAX_RECORDS
const DISTRICT_RECIPES: int = 3
const RUN_CONTRACTS: int = 3
const TERMINAL_CHOICE_OVERLAYS: int = 1
const UPGRADE_SESSIONS: int = 1
const UPGRADE_OVERLAYS: int = 1
const UPGRADE_CARDS: int = 2
const WEAPON_STATUS_STRIPS: int = 1
const WEAPON_SHOP_SESSIONS: int = 1
const WEAPON_SHOP_OVERLAYS: int = 1
const WEAPON_SHOP_CARDS: int = WeaponShopCatalog.PRODUCTS_PER_DISTRICT
const WEAPON_SHOP_DIALOGUES: int = 1
const WEAPON_SHOP_CONFIRMATIONS: int = 1
const WEAPON_SHOP_STAT_PREVIEWS: int = 1
const WEAPON_SHOP_WARNING_OVERLAYS: int = 1
const WEAPON_SHOP_TRANSACTION_PARTICLES: int = 2
const WEAPON_SHOP_EFFECT_RUNTIMES: int = 1
const COSMETIC_DEBRIS_INSTANCES: int = 64
const SHOCKWAVE_RING_SLOTS: int = 10
const DIRECTIONAL_SHOCKWAVE_SLOTS: int = DirectionalPunchShockwaveRuntime.CAPACITY
const SIEGE_DRILL_HITBOX_SLOTS: int = SiegeDrillRuntime.HITBOX_CAPACITY
const GRAVITY_CRUCIBLE_SLOTS: int = GravityCrucibleRuntime.CAPACITY
const GRAVITY_CRUCIBLE_EXPLOSION_SLOTS: int = (
	GravityCrucibleRuntime.EXPLOSION_VISUAL_CAPACITY
)
const TESLA_TOWER_SLOTS: int = TeslaTowerRuntime.TOWER_CAPACITY
const TESLA_ARC_SLOTS: int = TeslaTowerRuntime.ARC_CAPACITY
const PLAYER_ARSENALS: int = 1
const WEAPON_DRONES: int = 19
const MACHINE_GUN_IMPACT_SLOTS: int = ProjectilePool.MACHINE_GUN_IMPACT_CAPACITY
const HOSTILE_IMPACT_SLOTS: int = ProjectilePool.HOSTILE_IMPACT_CAPACITY
const LASER_BEAM_SLOTS: int = 2
const ANTI_AIR_IMPACT_SLOTS: int = PlayerLaserWeapon.IMPACT_CAPACITY
const FLAME_VISUAL_SLOTS: int = 6
const SCORCH_VISUAL_SLOTS: int = 8
const FLAMETHROWER_LOOP_VOICES: int = 1
const PLAYER_MISSILES: int = 4
const MISSILE_EXPLOSION_VISUAL_SLOTS: int = MissileWeapon.EXPLOSION_VISUAL_CAPACITY
const MISSILE_EXPLOSION_QUEUE: int = 8
const PLAYER_ATTACK_REACTION_RUNTIMES: int = 1
const DODGE_AFTERIMAGE_SLOTS: int = 8
const DODGE_DUST_SLOTS: int = DodgeDustPool2D.CAPACITY
const CRITICAL_SMOKE_EMITTERS: int = 1
const MELEE_CHARGE_EMITTERS: int = 1
const MELEE_CHARGE_PARTICLES: int = RobotAnimationPresenter.CHARGE_PARTICLE_CAPACITY
const MELEE_CHARGE_VISUALS: int = 4
const ELITE_SPAWN_EFFECT_SLOTS: int = 6
const HAZARD_ACTORS: int = 12
const HAZARD_VFX_SLOTS: int = 16
const HAZARD_AUDIO_VOICES: int = 6
const ACTIVE_HAZARDS: int = 6
const PENDING_HAZARDS: int = 3
const HAZARD_PRESSURE: int = 10
const STREET_CHUNKS: int = 6
const FLOATING_ORIGIN_RUNTIMES: int = 1
const WEATHER_RUNTIMES: int = 1
const WEATHER_SURFACES: int = 1
const WEATHER_PARTICLE_CAPACITY: int = DistrictWeatherSurface.PARTICLE_CAPACITY
const SKY_LIFE_RUNTIMES: int = 1
const SKY_LIFE_BANDS: int = 1
const SKY_LIFE_SPRITES: int = 2
const NARRATIVE_DIRECTORS: int = 1
const TRANSMISSION_TOASTS: int = 1
const REAR_BARRIER_WARNING_OVERLAYS: int = 1
const REAR_BARRIER_WARNING_VOICES: int = 1
const MAX_WEB_PCK_BYTES: int = 16 * 1024 * 1024


static func snapshot(city: CitySlice) -> Dictionary:
	return {
		"node_count": _count_nodes(city),
		"enemy_total": city.encounter_runtime.total_count(),
		"enemy_active": city.encounter_runtime.active_count(),
		"enemy_post_warm_creations": city.encounter_runtime.post_warm_creation_count,
		"projectile_total": city.projectile_root.total_count(),
		"projectile_active": city.projectile_root.active_count(),
		"hostile_projectile_total": (
			city.projectile_root.bullet_capacity
			+ city.projectile_root.shell_capacity
			+ city.projectile_root.rocket_capacity
		),
		"player_bullet_total": city.projectile_root.player_bullet_capacity,
		"player_bullet_active": city.projectile_root.active_count(&"player_bullet"),
		"structural_debris_total": (
			city.debris_pool.active_count() + city.debris_pool.available_count()
		),
		"structural_debris_peak": city.debris_pool.peak_active_count,
		"building_section_burst_slots": city.building_section_burst_pool.slot_count(),
		"building_section_burst_peak": city.building_section_burst_pool.peak_active_count,
		"building_damage_patterns": _building_damage_pattern_count(city),
		"building_severe_damage_fx": _building_severe_damage_fx_count(city),
		"structural_rubble_sprites": _structural_rubble_sprite_count(city),
		"prop_rubble_sprites": _prop_rubble_sprite_count(city),
		"catalyst_rubble_sprites": _catalyst_rubble_sprite_count(city),
		"enemy_scrap_total": (
			city.enemy_scrap_pool.active_count() + city.enemy_scrap_pool.available_count()
		),
		"enemy_scrap_peak": city.enemy_scrap_pool.peak_active_count,
		"soldier_defeat_total": city.soldier_defeat_pool.total_count(),
		"soldier_defeat_peak": city.soldier_defeat_pool.peak_active_count,
		"wreck_total": city.enemy_remains_factory.total_count(),
		"wreck_peak": city.enemy_remains_factory.peak_active_count,
		"particle_slots": city.impact_feedback_pool.particle_child_count(),
		"audio_voices": city.impact_feedback_pool.audio_child_count(),
		"robot_audio_voices": _robot_audio_voice_count(city),
		"air_target_voices": city.air_target_lock_runtime.voice_player_count(),
		"air_target_reticles": city.air_target_lock_runtime.reticle_count(),
		"dodge_afterimage_slots": _robot_afterimage_slot_count(city),
		"dodge_dust_slots": _robot_dust_slot_count(city),
		"critical_smoke_emitters": _robot_smoke_emitter_count(city),
		"melee_charge_emitters": _robot_charge_emitter_count(city),
		"melee_charge_particles": _robot_charge_particle_capacity(city),
		"melee_charge_visuals": _robot_charge_visual_count(city),
		"elite_spawn_effect_slots": city.encounter_runtime.elite_spawn_effect_pool.slot_count(),
		"hazard_total": city.urban_siege.hazards.total_count(),
		"hazard_active": city.urban_siege.hazards.active_count(),
		"hazard_post_warm_creations": city.urban_siege.hazards.post_warm_creation_count,
		"hazard_activation_denials": city.urban_siege.hazards.activation_denial_count,
		"hazard_vfx_slots": city.urban_siege.hazards.vfx_pool.slot_count(),
		"hazard_audio_voices": city.urban_siege.hazards.audio_pool.voice_count(),
		"hazard_pending_peak": city.urban_siege.director.peak_hazard_pending,
		"hazard_pressure_peak": city.urban_siege.hazard_pressure.peak_used_budget,
		"district_pressure_peak_tier": city.urban_siege.director.progression_peak_tier,
		"district_pressure_peak_threat": city.urban_siege.director.progression_peak_threat,
		"district_copy_degradations": (
			city.urban_siege.director.progression_degradation_count
		),
			"street_chunks": city.world_stream.active_chunk_count(),
			"street_post_warm_creations": city.world_stream.post_warm_creation_count,
			"floating_origin_runtimes": 1 if city.world_stream.floating_origin != null else 0,
			"weather_runtimes": _weather_runtime_count(city),
			"weather_surfaces": _weather_surface_count(city),
			"weather_particle_capacity": WEATHER_PARTICLE_CAPACITY,
			"weather_post_warm_creations": _weather_post_warm_creations(city),
			"sky_life_runtimes": _sky_life_runtime_count(city),
			"sky_life_bands": _sky_life_band_count(city),
			"sky_life_sprites": _sky_life_sprite_count(city),
			"sky_life_post_warm_creations": _sky_life_post_warm_creations(city),
			"narrative_directors": 1 if city.project_choir_runtime.director != null else 0,
			"transmission_toasts": 1 if city.gameplay_hud.transmission_toast != null else 0,
			"rear_barrier_warning_overlays": (
				1 if city.gameplay_hud.rear_barrier_warning != null else 0
			),
			"rear_barrier_warning_voices": (
				1 if city.gameplay_hud.rear_barrier_warning_audio != null else 0
			),
			"streamed_buildings": city.streamed_destructibles.active_building_count(),
		"streamed_props": city.streamed_destructibles.active_prop_count(),
		"streamed_post_warm_creations": city.streamed_destructibles.post_warm_creation_count,
		"world_mutation_ledgers": 1 if city.streamed_destructibles.ledger != null else 0,
		"telegraph_active": city.telegraph_presenter.active_count(),
		"telegraph_peak": city.telegraph_presenter.peak_active_count,
		"rare_rows": city.gameplay_hud.rare_labels.size(),
		"catalyst_total": (
			city.urban_siege.catalysts.total_count() if city.urban_siege != null else 0
		),
		"catalyst_active": (
			city.urban_siege.catalysts.active_count() if city.urban_siege != null else 0
		),
		"repair_pickup_slots": (
			city.urban_siege.catalysts.repair_pickup_count()
			if city.urban_siege != null
			else 0
		),
		"actor_reservation_peak": (
			city.urban_siege.director.ledger.peak_pending if city.urban_siege != null else 0
		),
		"pending_beat_peak": (
			city.urban_siege.director.peak_pending_records if city.urban_siege != null else 0
		),
		"directive_sessions": 1 if city.urban_siege.directives != null else 0,
		"directive_cards": 1 if city.gameplay_hud.directive_card != null else 0,
		"directive_overlays": (
			1 if city.gameplay_hud.directive_choice_overlay != null else 0
		),
		"pause_coordinators": (
			1 if city.urban_siege.pause_coordinator != null else 0
		),
		"role_badges": city.encounter_runtime.total_count(),
		"trait_runtimes": 1 if city.urban_siege.trait_runtime != null else 0,
		"boss_sessions": 1 if city.urban_siege.boss_session != null else 0,
		"boss_rigs": _boss_utility_count(city, &"rig"),
		"boss_arena_barriers": _boss_arena_barrier_count(city),
		"boss_defeat_spectacles": _boss_utility_count(city, &"defeat_spectacle"),
		"boss_defeat_visual_slots": _boss_utility_count(city, &"defeat_visual_slots"),
		"boss_defeat_particle_emitters": _boss_utility_count(
			city,
			&"defeat_particle_emitters"
		),
		"boss_defeat_particle_capacity": _boss_utility_count(
			city,
			&"defeat_particle_capacity"
		),
		"boss_defeat_audio_players": _boss_utility_count(
			city,
			&"defeat_audio_players"
		),
		"boss_controllers": _boss_utility_count(city, &"controller"),
		"boss_rubble_presentations": _boss_utility_count(city, &"boss_rubble"),
		"boss_arena_adapters": _boss_utility_count(city, &"arena_adapter"),
		"boss_pylon_presentations": _boss_utility_count(city, &"pylons"),
		"boss_projection_slots": _boss_utility_count(city, &"projections"),
		"boss_markers": _boss_utility_count(city, &"markers"),
		"boss_lane_damage_areas": _boss_utility_count(city, &"lane_areas"),
			"boss_line_areas": _boss_utility_count(city, &"line_areas"),
			"boss_radial_shockwaves": _boss_utility_count(city, &"radial_shockwaves"),
		"boss_collapse_listeners": _boss_utility_count(city, &"collapse_listeners"),
		"boss_pod_visuals": _boss_utility_count(city, &"pod_visuals"),
		"boss_reclamation_anchors": _boss_utility_count(city, &"anchors"),
		"boss_wreck_receivers": _boss_utility_count(city, &"wreck_receivers"),
		"boss_post_warm_creations": _boss_utility_count(city, &"post_warm_creations"),
		"boss_reservations": _boss_utility_count(city, &"reservations"),
		"causal_records": city.rampage_session.causal_chain_tracker.active_count(),
		"district_recipes": city.urban_siege.DISTRICT_DECK.recipes.size(),
		"run_contracts": city.urban_siege.RUN_CONTRACTS.size(),
		"terminal_choice_overlays": 1 if city.gameplay_hud.extract_button != null else 0,
		"upgrade_sessions": (
			1 if city.upgrade_assembler.session != null else 0
		),
		"upgrade_overlays": 1 if city.gameplay_hud.upgrade_choice_overlay != null else 0,
		"upgrade_cards": city.gameplay_hud.upgrade_choice_overlay.cards.size(),
		"weapon_status_strips": 1 if city.gameplay_hud.weapon_status_strip != null else 0,
		"weapon_shop_sessions": 1 if city.weapon_shop_assembler.session != null else 0,
		"weapon_shop_overlays": 1 if city.weapon_shop_assembler.overlay != null else 0,
		"weapon_shop_cards": city.weapon_shop_assembler.overlay.cards.size(),
		"weapon_shop_dialogues": (
			1 if city.weapon_shop_assembler.overlay.dialogue_panel != null else 0
		),
		"weapon_shop_confirmations": (
			1 if city.weapon_shop_assembler.overlay.confirmation_panel != null else 0
		),
		"weapon_shop_stat_previews": (
			1 if city.weapon_shop_assembler.overlay.preview_panel != null else 0
		),
		"weapon_shop_warning_overlays": (
			1 if city.weapon_shop_assembler.overlay.insufficient_flash != null else 0
		),
		"weapon_shop_transaction_particles": (
			int(city.weapon_shop_assembler.overlay.upgrade_particles != null)
			+ int(city.weapon_shop_assembler.overlay.repair_particles != null)
		),
		"weapon_shop_effect_runtimes": (
			1 if city.weapon_shop_assembler.effects != null else 0
		),
			"cosmetic_debris_instances": CosmeticDebrisField2D.CAPACITY,
			"shockwave_ring_slots": ShockwaveUpgradeRuntime.CAPACITY,
			"directional_shockwave_slots": DirectionalPunchShockwaveRuntime.CAPACITY,
			"siege_drill_hitbox_slots": _siege_drill_hitbox_slots(city),
			"gravity_crucible_slots": _gravity_crucible_slots(city),
			"gravity_crucible_explosion_slots": (
				_gravity_crucible_explosion_slots(city)
			),
			"tesla_tower_slots": _tesla_tower_slots(city),
			"tesla_arc_slots": _tesla_arc_slots(city),
			"player_arsenals": (
			1
			if city.upgrade_assembler.get_node_or_null(^"PlayerArsenalRuntime") != null
			else 0
		),
			"weapon_drones": _weapon_drone_count(city),
			"machine_gun_impact_slots": city.projectile_root.machine_gun_impacts.size(),
			"hostile_impact_slots": city.projectile_root.hostile_impacts.size(),
			"laser_beam_slots": PlayerLaserWeapon.BEAM_CAPACITY,
		"anti_air_impact_slots": _anti_air_impact_slot_count(city),
		"flame_visual_slots": FlamethrowerRuntime.FLAME_CAPACITY,
		"scorch_visual_slots": FlamethrowerRuntime.SCORCH_CAPACITY,
		"flamethrower_loop_voices": FlamethrowerRuntime.LOOP_AUDIO_VOICES,
		"player_missiles": MissileProjectilePool.CAPACITY,
		"missile_explosion_visual_slots": _missile_explosion_visual_slot_count(city),
		"missile_explosion_queue": MissileWeapon.EXPLOSION_QUEUE_CAPACITY,
		"player_attack_reaction_runtimes": (
			1
			if city.upgrade_assembler.get_node_or_null(^"PlayerAttackReactionRuntime") != null
			else 0
		),
	}


static func validation_errors(city: CitySlice) -> PackedStringArray:
	var data: Dictionary = snapshot(city)
	var errors: PackedStringArray = []
	_check_equal(
		errors,
		data,
		"enemy_total",
		SOLDIERS + TANKS + HELICOPTERS + PROCEDURAL_ENEMIES
	)
	_check_equal(
		errors,
		data,
		"projectile_total",
		BULLETS + SHELLS + ROCKETS + PLAYER_BULLETS
	)
	_check_equal(errors, data, "hostile_projectile_total", BULLETS + SHELLS + ROCKETS)
	_check_equal(errors, data, "player_bullet_total", PLAYER_BULLETS)
	_check_equal(
		errors,
		data,
		"building_severe_damage_fx",
		BUILDING_DAMAGE_PATTERNS
	)
	_check_equal(errors, data, "structural_debris_total", STRUCTURAL_DEBRIS)
	_check_equal(errors, data, "building_damage_patterns", BUILDING_DAMAGE_PATTERNS)
	_check_equal(errors, data, "structural_rubble_sprites", STRUCTURAL_RUBBLE_SPRITES)
	_check_equal(errors, data, "prop_rubble_sprites", PROP_RUBBLE_SPRITES)
	_check_equal(errors, data, "catalyst_rubble_sprites", CATALYST_RUBBLE_SPRITES)
	_check_equal(errors, data, "enemy_scrap_total", ENEMY_SCRAP)
	_check_equal(errors, data, "soldier_defeat_total", SOLDIER_DEFEATS)
	_check_equal(errors, data, "wreck_total", WRECKS)
	_check_equal(errors, data, "particle_slots", PARTICLE_SLOTS)
	_check_equal(errors, data, "audio_voices", AUDIO_VOICES)
	_check_equal(errors, data, "robot_audio_voices", ROBOT_AUDIO_VOICES)
	_check_equal(errors, data, "air_target_voices", AIR_TARGET_VOICES)
	_check_equal(errors, data, "air_target_reticles", AIR_TARGET_RETICLES)
	_check_equal(errors, data, "dodge_afterimage_slots", DODGE_AFTERIMAGE_SLOTS)
	_check_equal(errors, data, "dodge_dust_slots", DODGE_DUST_SLOTS)
	_check_equal(errors, data, "critical_smoke_emitters", CRITICAL_SMOKE_EMITTERS)
	_check_equal(errors, data, "melee_charge_emitters", MELEE_CHARGE_EMITTERS)
	_check_equal(errors, data, "melee_charge_particles", MELEE_CHARGE_PARTICLES)
	_check_equal(errors, data, "melee_charge_visuals", MELEE_CHARGE_VISUALS)
	_check_equal(
		errors,
		data,
		"elite_spawn_effect_slots",
		ELITE_SPAWN_EFFECT_SLOTS
	)
	_check_equal(errors, data, "hazard_total", HAZARD_ACTORS)
	_check_equal(errors, data, "hazard_vfx_slots", HAZARD_VFX_SLOTS)
	_check_equal(errors, data, "hazard_audio_voices", HAZARD_AUDIO_VOICES)
	_check_equal(errors, data, "hazard_post_warm_creations", 0)
	_check_equal(errors, data, "street_chunks", STREET_CHUNKS)
	_check_equal(errors, data, "street_post_warm_creations", 0)
	_check_equal(errors, data, "floating_origin_runtimes", FLOATING_ORIGIN_RUNTIMES)
	_check_equal(errors, data, "weather_runtimes", WEATHER_RUNTIMES)
	_check_equal(errors, data, "weather_surfaces", WEATHER_SURFACES)
	_check_equal(
		errors,
		data,
		"weather_particle_capacity",
		WEATHER_PARTICLE_CAPACITY
	)
	_check_equal(errors, data, "weather_post_warm_creations", 0)
	_check_equal(errors, data, "sky_life_runtimes", SKY_LIFE_RUNTIMES)
	_check_equal(errors, data, "sky_life_bands", SKY_LIFE_BANDS)
	_check_equal(errors, data, "sky_life_sprites", SKY_LIFE_SPRITES)
	_check_equal(errors, data, "sky_life_post_warm_creations", 0)
	_check_equal(errors, data, "narrative_directors", NARRATIVE_DIRECTORS)
	_check_equal(errors, data, "transmission_toasts", TRANSMISSION_TOASTS)
	_check_equal(
		errors,
		data,
		"rear_barrier_warning_overlays",
		REAR_BARRIER_WARNING_OVERLAYS
	)
	_check_equal(
		errors,
		data,
		"rear_barrier_warning_voices",
		REAR_BARRIER_WARNING_VOICES
	)
	_check_equal(errors, data, "streamed_buildings", STREAMED_BUILDINGS)
	_check_equal(errors, data, "streamed_props", STREAMED_PROPS)
	_check_equal(errors, data, "streamed_post_warm_creations", 0)
	_check_equal(errors, data, "world_mutation_ledgers", WORLD_MUTATION_LEDGERS)
	_check_equal(errors, data, "rare_rows", RARE_TAG_ROWS)
	_check_equal(errors, data, "enemy_post_warm_creations", 0)
	_check_equal(errors, data, "catalyst_total", CATALYST_SLOTS)
	_check_equal(errors, data, "repair_pickup_slots", REPAIR_PICKUP_SLOTS)
	_check_equal(errors, data, "directive_sessions", DIRECTIVE_SESSIONS)
	_check_equal(errors, data, "directive_cards", DIRECTIVE_CARDS)
	_check_equal(errors, data, "directive_overlays", DIRECTIVE_OVERLAYS)
	_check_equal(errors, data, "pause_coordinators", PAUSE_COORDINATORS)
	_check_equal(errors, data, "role_badges", ROLE_BADGES)
	_check_equal(errors, data, "trait_runtimes", TRAIT_RUNTIMES)
	_check_equal(errors, data, "boss_sessions", BOSS_SESSIONS)
	_check_equal(errors, data, "boss_rigs", BOSS_RIGS)
	_check_equal(errors, data, "boss_arena_barriers", BOSS_ARENA_BARRIERS)
	_check_equal(errors, data, "boss_defeat_spectacles", BOSS_DEFEAT_SPECTACLES)
	_check_equal(errors, data, "boss_defeat_visual_slots", BOSS_DEFEAT_VISUAL_SLOTS)
	_check_equal(
		errors,
		data,
		"boss_defeat_particle_emitters",
		BOSS_DEFEAT_PARTICLE_EMITTERS
	)
	_check_equal(
		errors,
		data,
		"boss_defeat_particle_capacity",
		BOSS_DEFEAT_PARTICLE_CAPACITY
	)
	_check_equal(
		errors,
		data,
		"boss_defeat_audio_players",
		BOSS_DEFEAT_AUDIO_PLAYERS
	)
	_check_equal(errors, data, "boss_controllers", BOSS_CONTROLLERS)
	_check_equal(errors, data, "boss_arena_adapters", BOSS_ARENA_ADAPTERS)
	_check_equal(errors, data, "boss_pylon_presentations", BOSS_PYLON_PRESENTATIONS)
	_check_equal(errors, data, "boss_projection_slots", BOSS_PROJECTION_SLOTS)
	_check_equal(errors, data, "boss_markers", BOSS_MARKERS)
	_check_equal(errors, data, "boss_lane_damage_areas", BOSS_LANE_DAMAGE_AREAS)
	_check_equal(errors, data, "boss_line_areas", BOSS_LINE_AREAS)
	_check_equal(errors, data, "boss_radial_shockwaves", BOSS_RADIAL_SHOCKWAVES)
	_check_equal(errors, data, "boss_collapse_listeners", BOSS_COLLAPSE_LISTENERS)
	_check_equal(errors, data, "boss_pod_visuals", BOSS_POD_VISUALS)
	_check_equal(errors, data, "boss_reclamation_anchors", BOSS_RECLAMATION_ANCHORS)
	_check_equal(errors, data, "boss_wreck_receivers", BOSS_WRECK_RECEIVERS)
	_check_equal(
		errors,
		data,
		"boss_rubble_presentations",
		BOSS_RUBBLE_PRESENTATIONS
	)
	_check_equal(errors, data, "boss_post_warm_creations", 0)
	_check_equal(errors, data, "boss_reservations", 0)
	_check_equal(errors, data, "district_recipes", DISTRICT_RECIPES)
	_check_equal(errors, data, "run_contracts", RUN_CONTRACTS)
	_check_equal(
		errors,
		data,
		"terminal_choice_overlays",
		TERMINAL_CHOICE_OVERLAYS
	)
	_check_equal(errors, data, "upgrade_sessions", UPGRADE_SESSIONS)
	_check_equal(errors, data, "upgrade_overlays", UPGRADE_OVERLAYS)
	_check_equal(errors, data, "upgrade_cards", UPGRADE_CARDS)
	_check_equal(errors, data, "weapon_status_strips", WEAPON_STATUS_STRIPS)
	_check_equal(errors, data, "weapon_shop_sessions", WEAPON_SHOP_SESSIONS)
	_check_equal(errors, data, "weapon_shop_overlays", WEAPON_SHOP_OVERLAYS)
	_check_equal(errors, data, "weapon_shop_cards", WEAPON_SHOP_CARDS)
	_check_equal(errors, data, "weapon_shop_dialogues", WEAPON_SHOP_DIALOGUES)
	_check_equal(errors, data, "weapon_shop_confirmations", WEAPON_SHOP_CONFIRMATIONS)
	_check_equal(errors, data, "weapon_shop_stat_previews", WEAPON_SHOP_STAT_PREVIEWS)
	_check_equal(
		errors,
		data,
		"weapon_shop_warning_overlays",
		WEAPON_SHOP_WARNING_OVERLAYS
	)
	_check_equal(
		errors,
		data,
		"weapon_shop_transaction_particles",
		WEAPON_SHOP_TRANSACTION_PARTICLES
	)
	_check_equal(
		errors,
		data,
		"weapon_shop_effect_runtimes",
		WEAPON_SHOP_EFFECT_RUNTIMES
	)
	_check_equal(errors, data, "cosmetic_debris_instances", COSMETIC_DEBRIS_INSTANCES)
	_check_equal(errors, data, "shockwave_ring_slots", SHOCKWAVE_RING_SLOTS)
	_check_equal(errors, data, "directional_shockwave_slots", DIRECTIONAL_SHOCKWAVE_SLOTS)
	_check_equal(errors, data, "siege_drill_hitbox_slots", SIEGE_DRILL_HITBOX_SLOTS)
	_check_equal(errors, data, "gravity_crucible_slots", GRAVITY_CRUCIBLE_SLOTS)
	_check_equal(
		errors,
		data,
		"gravity_crucible_explosion_slots",
		GRAVITY_CRUCIBLE_EXPLOSION_SLOTS
	)
	_check_equal(errors, data, "tesla_tower_slots", TESLA_TOWER_SLOTS)
	_check_equal(errors, data, "tesla_arc_slots", TESLA_ARC_SLOTS)
	_check_equal(errors, data, "player_arsenals", PLAYER_ARSENALS)
	_check_equal(errors, data, "weapon_drones", WEAPON_DRONES)
	_check_equal(
		errors,
		data,
		"machine_gun_impact_slots",
		MACHINE_GUN_IMPACT_SLOTS
	)
	_check_equal(errors, data, "hostile_impact_slots", HOSTILE_IMPACT_SLOTS)
	_check_equal(errors, data, "laser_beam_slots", LASER_BEAM_SLOTS)
	_check_equal(errors, data, "anti_air_impact_slots", ANTI_AIR_IMPACT_SLOTS)
	_check_equal(errors, data, "flame_visual_slots", FLAME_VISUAL_SLOTS)
	_check_equal(errors, data, "scorch_visual_slots", SCORCH_VISUAL_SLOTS)
	_check_equal(errors, data, "flamethrower_loop_voices", FLAMETHROWER_LOOP_VOICES)
	_check_equal(errors, data, "player_missiles", PLAYER_MISSILES)
	_check_equal(
		errors,
		data,
		"missile_explosion_visual_slots",
		MISSILE_EXPLOSION_VISUAL_SLOTS
	)
	_check_equal(errors, data, "missile_explosion_queue", MISSILE_EXPLOSION_QUEUE)
	_check_equal(
		errors,
		data,
		"player_attack_reaction_runtimes",
		PLAYER_ATTACK_REACTION_RUNTIMES
	)
	if int(data.causal_records) > CAUSAL_RECORDS:
		errors.append(
			"causal_records=%d cap=%d" % [data.causal_records, CAUSAL_RECORDS]
		)
	if int(data.catalyst_active) > ACTIVE_CATALYSTS:
		errors.append("catalyst_active=%d cap=%d" % [data.catalyst_active, ACTIVE_CATALYSTS])
	if int(data.actor_reservation_peak) > ACTOR_RESERVATIONS:
		errors.append(
			"actor_reservation_peak=%d cap=%d"
			% [data.actor_reservation_peak, ACTOR_RESERVATIONS]
		)
	if int(data.pending_beat_peak) > PENDING_BEAT_RECORDS:
		errors.append(
			"pending_beat_peak=%d cap=%d"
			% [data.pending_beat_peak, PENDING_BEAT_RECORDS]
		)
	if int(data.hazard_active) > ACTIVE_HAZARDS:
		errors.append("hazard_active=%d cap=%d" % [data.hazard_active, ACTIVE_HAZARDS])
	if int(data.hazard_pending_peak) > PENDING_HAZARDS:
		errors.append(
			"hazard_pending_peak=%d cap=%d"
			% [data.hazard_pending_peak, PENDING_HAZARDS]
		)
	if int(data.hazard_pressure_peak) > HAZARD_PRESSURE:
		errors.append(
			"hazard_pressure_peak=%d cap=%d"
			% [data.hazard_pressure_peak, HAZARD_PRESSURE]
		)
	if int(data.district_pressure_peak_tier) > CityWorldStream.MAX_PROGRESSION_TIER:
		errors.append(
			"district_pressure_peak_tier=%d cap=%d"
			% [data.district_pressure_peak_tier, CityWorldStream.MAX_PROGRESSION_TIER]
		)
	if int(data.district_pressure_peak_threat) > DistrictPressureCatalog.MAX_LIVE_THREAT:
		errors.append(
			"district_pressure_peak_threat=%d cap=%d"
			% [data.district_pressure_peak_threat, DistrictPressureCatalog.MAX_LIVE_THREAT]
		)
	if int(data.telegraph_peak) > TELEGRAPH_RECORDS:
		errors.append("telegraph_peak=%d cap=%d" % [data.telegraph_peak, TELEGRAPH_RECORDS])
	return errors


static func _check_equal(
	errors: PackedStringArray,
	data: Dictionary,
	key: String,
	expected: int
) -> void:
	var actual: int = int(data[key])
	if actual != expected:
		errors.append("%s=%d expected=%d" % [key, actual, expected])


static func _siege_drill_hitbox_slots(city: CitySlice) -> int:
	if city.upgrade_assembler == null:
		return 0
	var runtime: SiegeDrillRuntime = (
		city.upgrade_assembler.runtimes.get(&"SIEGE_DRILL") as SiegeDrillRuntime
	)
	return runtime.HITBOX_CAPACITY if runtime != null else 0


static func _gravity_crucible_slots(city: CitySlice) -> int:
	if city.upgrade_assembler == null:
		return 0
	var runtime: GravityCrucibleRuntime = (
		city.upgrade_assembler.runtimes.get(
			&"GRAVITY_CRUCIBLE"
		) as GravityCrucibleRuntime
	)
	return runtime.CAPACITY if runtime != null else 0


static func _gravity_crucible_explosion_slots(city: CitySlice) -> int:
	if city.upgrade_assembler == null:
		return 0
	var runtime: GravityCrucibleRuntime = (
		city.upgrade_assembler.runtimes.get(
			&"GRAVITY_CRUCIBLE"
		) as GravityCrucibleRuntime
	)
	return runtime.explosion_visuals.size() if runtime != null else 0


static func _tesla_tower_slots(city: CitySlice) -> int:
	if city.upgrade_assembler == null:
		return 0
	var runtime: TeslaTowerRuntime = (
		city.upgrade_assembler.runtimes.get(&"TESLA_TOWER") as TeslaTowerRuntime
	)
	return runtime.TOWER_CAPACITY if runtime != null and runtime.tower != null else 0


static func _tesla_arc_slots(city: CitySlice) -> int:
	if city.upgrade_assembler == null:
		return 0
	var runtime: TeslaTowerRuntime = (
		city.upgrade_assembler.runtimes.get(&"TESLA_TOWER") as TeslaTowerRuntime
	)
	return runtime.tower.arcs.size() if runtime != null and runtime.tower != null else 0


static func _weather_runtime(city: CitySlice) -> DistrictWeatherRuntime:
	return city.get_node_or_null(^"DistrictWeather") as DistrictWeatherRuntime


static func _weather_runtime_count(city: CitySlice) -> int:
	return 1 if _weather_runtime(city) != null else 0


static func _weather_surface_count(city: CitySlice) -> int:
	var weather: DistrictWeatherRuntime = _weather_runtime(city)
	return weather.surface_count() if weather != null else 0


static func _weather_post_warm_creations(city: CitySlice) -> int:
	var weather: DistrictWeatherRuntime = _weather_runtime(city)
	return weather.post_warm_creation_count if weather != null else 0


static func _sky_life_runtime(city: CitySlice) -> DistrictSkyLifeRuntime:
	var parallax: DistrictParallaxRuntime = city.get_node_or_null(
		^"ParallaxCity"
	) as DistrictParallaxRuntime
	return parallax.sky_life_runtime() if parallax != null else null


static func _sky_life_runtime_count(city: CitySlice) -> int:
	return 1 if _sky_life_runtime(city) != null else 0


static func _sky_life_band_count(city: CitySlice) -> int:
	var life: DistrictSkyLifeRuntime = _sky_life_runtime(city)
	return life.band_count() if life != null else 0


static func _sky_life_sprite_count(city: CitySlice) -> int:
	var life: DistrictSkyLifeRuntime = _sky_life_runtime(city)
	return life.sprite_count() if life != null else 0


static func _sky_life_post_warm_creations(city: CitySlice) -> int:
	var life: DistrictSkyLifeRuntime = _sky_life_runtime(city)
	return life.post_warm_creation_count if life != null else 0


static func _count_nodes(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _count_nodes(child)
	return count


static func _building_damage_pattern_count(city: CitySlice) -> int:
	var count: int = 0
	for building: StructuralBuilding2D in city.streamed_destructibles.buildings:
		for row: int in range(StructuralBuilding2D.ROWS):
			for column: int in range(StructuralBuilding2D.COLUMNS):
				var cell: Destructible2D = building.get_cell(column, row)
				if cell.get_node_or_null(^"DamagedVisual") is BuildingDamagePattern2D:
					count += 1
	return count


static func _building_severe_damage_fx_count(city: CitySlice) -> int:
	var count: int = 0
	for building: StructuralBuilding2D in city.streamed_destructibles.buildings:
		for row: int in range(StructuralBuilding2D.ROWS):
			for column: int in range(StructuralBuilding2D.COLUMNS):
				var cell: Destructible2D = building.get_cell(column, row)
				var pattern: BuildingDamagePattern2D = cell.get_node_or_null(
					^"DamagedVisual"
				) as BuildingDamagePattern2D
				if pattern != null and pattern.get_node_or_null(
					^"SevereDamageFx"
				) is BuildingSevereDamageFx2D:
					count += 1
	return count


static func _structural_rubble_sprite_count(city: CitySlice) -> int:
	var count: int = 0
	for building: StructuralBuilding2D in city.streamed_destructibles.buildings:
		for row: int in range(StructuralBuilding2D.ROWS):
			for column: int in range(StructuralBuilding2D.COLUMNS):
				var pattern: BuildingDamagePattern2D = building.get_cell(
					column, row
				).get_node_or_null(^"DamagedVisual") as BuildingDamagePattern2D
				if pattern != null and pattern._ruin_rubble_bed() != null:
					count += pattern._ruin_rubble_bed().total_piece_count()
	return count


static func _prop_rubble_sprite_count(city: CitySlice) -> int:
	var count: int = 0
	for prop: DestructibleProp2D in city.streamed_destructibles.props:
		if prop.terminal_rubble != null:
			count += prop.terminal_rubble.total_piece_count()
	return count


static func _catalyst_rubble_sprite_count(city: CitySlice) -> int:
	var count: int = 0
	for catalyst: Catalyst2D in city.urban_siege.catalysts.slots:
		if catalyst.terminal_rubble != null:
			count += catalyst.terminal_rubble.total_piece_count()
	return count


static func _robot_audio_voice_count(city: CitySlice) -> int:
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node_or_null(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	return presenter.audio_voice_count() if presenter != null else 0


static func _robot_afterimage_slot_count(city: CitySlice) -> int:
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node_or_null(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	return presenter.afterimage_slot_count() if presenter != null else 0


static func _robot_dust_slot_count(city: CitySlice) -> int:
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node_or_null(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	return presenter.dust_slot_count() if presenter != null else 0


static func _robot_smoke_emitter_count(city: CitySlice) -> int:
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node_or_null(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	return presenter.critical_smoke_emitter_count() if presenter != null else 0


static func _robot_charge_emitter_count(city: CitySlice) -> int:
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node_or_null(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	return presenter.charge_particle_emitter_count() if presenter != null else 0


static func _robot_charge_particle_capacity(city: CitySlice) -> int:
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node_or_null(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	return presenter.charge_particle_capacity() if presenter != null else 0


static func _robot_charge_visual_count(city: CitySlice) -> int:
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node_or_null(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	return presenter.charge_visual_count() if presenter != null else 0


static func _weapon_drone_count(city: CitySlice) -> int:
	var orbit: WeaponDroneOrbit2D = city.robot.get_node_or_null(
		^"WeaponDroneOrbit"
	) as WeaponDroneOrbit2D
	return orbit.drones.size() if orbit != null else 0


static func _anti_air_impact_slot_count(city: CitySlice) -> int:
	var runtime: PlayerLaserWeapon = (
		city.upgrade_assembler.runtimes.get(&"LASER") as PlayerLaserWeapon
	)
	return runtime.impacts.size() if runtime != null else 0


static func _missile_explosion_visual_slot_count(city: CitySlice) -> int:
	var runtime: MissileWeapon = (
		city.upgrade_assembler.runtimes.get(&"MISSILE") as MissileWeapon
	)
	return runtime.explosion_visuals.size() if runtime != null else 0


static func _boss_utility_count(city: CitySlice, kind: StringName) -> int:
	if city.urban_siege == null or city.urban_siege.boss_session == null:
		return 0
	var pool: BossUtilityPool = city.urban_siege.boss_session.utility_pool
	if pool == null:
		return 0
	match kind:
		&"rig":
			return pool.rig_count()
		&"defeat_spectacle":
			return pool.defeat_spectacle_count()
		&"defeat_visual_slots":
			return pool.defeat_visual_slot_count()
		&"defeat_particle_emitters":
			return pool.defeat_particle_emitter_count()
		&"defeat_particle_capacity":
			return pool.defeat_particle_capacity()
		&"defeat_audio_players":
			return pool.defeat_audio_player_count()
		&"controller":
			return pool.controller_count()
		&"arena_adapter":
			return pool.arena_adapter_count()
		&"pylons":
			return pool.pylon_count()
		&"projections":
			return pool.projection_count()
		&"markers":
			return pool.marker_count()
		&"lane_areas":
			return pool.lane_damage_areas.size()
		&"line_areas":
			return pool.line_areas.size()
		&"radial_shockwaves":
			return 1 if pool.radial_shockwave != null else 0
		&"collapse_listeners":
			return pool.collapse_listener_count()
		&"pod_visuals":
			return pool.pod_visual_count()
		&"anchors":
			return pool.reclamation_anchor_count()
		&"wreck_receivers":
			return pool.wreck_receiver_count()
		&"boss_rubble":
			return pool.boss_rubble_count()
		&"post_warm_creations":
			return pool.post_warm_creation_count
		&"reservations":
			return pool.reservation_count()
	return 0


static func _boss_arena_barrier_count(city: CitySlice) -> int:
	if city.urban_siege == null or city.urban_siege.boss_campaign == null:
		return 0
	return 1 if city.urban_siege.boss_campaign.arena_barrier != null else 0
