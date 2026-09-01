extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const EXPECTED_ANIMATIONS: Array[StringName] = [
	&"attack_e",
	&"attack_se",
	&"attack_sw",
	&"attack_w",
	&"idle_s",
	&"walk_e",
	&"walk_w",
]
const FORBIDDEN_SCROLLER_ANIMATIONS: Array[StringName] = [
	&"walk_n",
	&"walk_ne",
	&"walk_nw",
	&"attack_n",
	&"attack_ne",
	&"attack_nw",
	&"idle_n",
]


func test_library_excludes_all_northward_walk_and_attack_directions() -> void:
	var city: CitySlice = await _spawn_city()
	var sprite: AnimatedSprite2D = _sprite(city)
	var visual_root: Node2D = sprite.get_parent() as Node2D
	assert_almost_eq(
		visual_root.position.y,
		CityWorldBuilder.ROBOT_ROAD_CENTER_VISUAL_OFFSET_Y,
		0.001
	)
	var body_collision: CollisionShape2D = city.robot.get_node(^"BodyCollision") as CollisionShape2D
	assert_eq(body_collision.position, Vector2(0.0, 21.0))
	var gameplay_ground: Marker2D = city.robot.get_node(^"GroundImpactOrigin") as Marker2D
	var visual_ground: Marker2D = city.robot.get_node(
		^"VisualRoot/VisualGroundOrigin"
	) as Marker2D
	assert_eq(gameplay_ground.position, Vector2(0.0, 126.0))
	assert_eq(visual_ground.position, Vector2(0.0, 126.0))
	assert_almost_eq(
		visual_ground.global_position.y - gameplay_ground.global_position.y,
		CityWorldBuilder.ROBOT_ROAD_CENTER_VISUAL_OFFSET_Y,
		0.001
	)
	# The body can settle during the deferred physics tick before this test disables it.
	assert_almost_eq(
		CityWorldBuilder.LAND_VISUAL_BASELINE_Y - visual_ground.global_position.y,
		CityWorldBuilder.ROBOT_ROAD_CLEARANCE_PIXELS,
		3.0
	)
	assert_eq(CityWorldBuilder.ROBOT_ROAD_CLEARANCE_PIXELS, 35.0)
	var names: PackedStringArray = sprite.sprite_frames.get_animation_names()
	names.sort()
	assert_eq(names, PackedStringArray(EXPECTED_ANIMATIONS))
	for animation: StringName in EXPECTED_ANIMATIONS:
		var expected_frames: int = 1 if animation == &"idle_s" else 25
		assert_eq(sprite.sprite_frames.get_frame_count(animation), expected_frames)
	for forbidden_animation: StringName in FORBIDDEN_SCROLLER_ANIMATIONS:
		assert_false(sprite.sprite_frames.has_animation(forbidden_animation))
	assert_false(sprite.flip_h)
	assert_almost_eq(sprite.scale.x, 1.246, 0.001)
	assert_almost_eq(sprite.position.y, 72.0, 0.001)


func test_idle_always_faces_south_while_walk_uses_east_and_west() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var visual_root: Node2D = robot.get_node(^"VisualRoot") as Node2D
	var emitter: Node2D = visual_root.get_node(^"LaserEmitter") as Node2D
	assert_eq(sprite.animation, &"idle_s")
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())
	robot.locomotion_state = GiantRobotController.LocomotionState.WALK
	robot.locomotion_changed.emit(robot.locomotion_state)
	assert_eq(sprite.animation, &"walk_e")
	assert_true(sprite.is_playing())
	robot.facing = -1
	robot.facing_changed.emit(robot.facing)
	assert_eq(sprite.animation, &"walk_w")
	assert_gt(visual_root.scale.x, 0.0)
	assert_lt(emitter.position.x, 0.0)
	robot.locomotion_state = GiantRobotController.LocomotionState.IDLE
	robot.locomotion_changed.emit(robot.locomotion_state)
	assert_eq(sprite.animation, &"idle_s")
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())


func test_attacks_map_cardinal_punches_and_diagonal_slams_with_frame_11_commit() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	var sprite: AnimatedSprite2D = _sprite(city)
	_assert_attack(presenter, robot, sprite, AttackSpec.Mode.GROUND_SMASH, 1, &"attack_se")
	_assert_attack(presenter, robot, sprite, AttackSpec.Mode.GROUND_SMASH, -1, &"attack_sw")
	_assert_attack(presenter, robot, sprite, AttackSpec.Mode.JAB_CROSS, 1, &"attack_e")
	_assert_attack(presenter, robot, sprite, AttackSpec.Mode.JAB_CROSS, -1, &"attack_w")


func test_contextual_attack_flow_drives_real_slam_and_punch_clips() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	robot.global_position = Vector2(80.0, 460.0)
	robot.stomp_damage = 0.0
	robot.stomp_radius = 1.0
	assert_gt(robot.request_attack(), 0)
	var ground_spec: AttackSpec = city.contextual_attacks.current_spec
	assert_true(ground_spec.is_ground_smash())
	assert_eq(sprite.animation, &"attack_se")
	await get_tree().create_timer(ground_spec.anticipation_seconds + 0.04).timeout
	assert_gte(sprite.frame, RobotAnimationPresenter.ATTACK_EVENT_FRAME)
	assert_true(sprite.is_playing())
	await _wait_for_attack(city.contextual_attacks)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	assert_eq(presenter.last_completed_attack_frame, 24)
	assert_eq(sprite.animation, &"idle_s")
	robot.velocity.x = robot.max_speed
	assert_gt(robot.request_attack(), 0)
	var jab_spec: AttackSpec = city.contextual_attacks.current_spec
	assert_not_null(jab_spec)
	if jab_spec == null:
		return
	assert_true(jab_spec.is_jab_cross())
	assert_eq(sprite.animation, &"attack_e")
	await get_tree().create_timer(jab_spec.anticipation_seconds + 0.04).timeout
	assert_gte(sprite.frame, RobotAnimationPresenter.ATTACK_EVENT_FRAME)
	assert_true(sprite.is_playing())
	await _wait_for_attack(city.contextual_attacks)
	assert_eq(presenter.last_completed_attack_frame, 24)
	assert_eq(presenter.completed_full_attack_count, 2)
	assert_eq(sprite.animation, &"idle_s")


func test_charge_holds_melee_pose_draws_particles_and_locks_locomotion() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var attacks: ContextualAttackController = city.contextual_attacks
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	var particles: CPUParticles2D = robot.get_node(
		^"VisualRoot/MeleeChargeParticles"
	) as CPUParticles2D
	var meter: Node2D = robot.get_node(^"VisualRoot/PhotonChargeMeter") as Node2D
	var meter_frame: Sprite2D = meter.get_node(^"Frame") as Sprite2D
	var core: Sprite2D = robot.get_node(^"VisualRoot/PhotonChestCore") as Sprite2D
	var baseline_nodes: int = int(RuntimeBudget.snapshot(city).node_count)
	assert_gt(attacks.begin_charge(), 0)
	assert_eq(sprite.animation, &"attack_se")
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())
	attacks.cancel_attack()
	assert_eq(sprite.animation, &"idle_s")
	robot.velocity.x = robot.max_speed
	assert_gt(attacks.begin_charge(), 0)
	assert_true(presenter.attacking)
	assert_true(presenter.charging)
	assert_eq(robot.locomotion_state, GiantRobotController.LocomotionState.ATTACK_LOCKED)
	assert_eq(sprite.animation, &"attack_e")
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())
	assert_eq(presenter.charge_particle_emitter_count(), 1)
	assert_eq(presenter.charge_particle_capacity(), RobotAnimationPresenter.CHARGE_PARTICLE_CAPACITY)
	assert_false(presenter.charge_particles_emitting())
	assert_eq(particles.color, RobotAnimationPresenter.CHARGE_PARTICLE_COLOR)
	assert_same(particles.texture, RobotAnimationPresenter.PHOTON_CORE_TEXTURE)
	assert_lt(particles.radial_accel_max, 0.0)
	assert_true(presenter.charge_meter_visible())
	assert_true(presenter.charge_core_visible())
	assert_same(meter_frame.texture, RobotAnimationPresenter.CHARGE_METER_FRAME_TEXTURE)
	assert_same(core.texture, RobotAnimationPresenter.PHOTON_CORE_TEXTURE)
	assert_eq(presenter.charge_sfx_play_count, 2)
	assert_same(presenter._charge_sfx_player.stream, RobotAnimationPresenter.PHOTON_CHARGE_SFX)
	assert_eq(presenter._charge_sfx_player.bus, GameAudioBus.MECHANICS)
	attacks._process(RobotAnimationPresenter.CHARGE_PARTICLE_DELAY_SECONDS - 0.001)
	assert_false(presenter.charge_particles_emitting())
	attacks._process(0.001)
	assert_true(presenter.charge_particles_emitting())
	attacks._process(0.4)
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())
	assert_almost_eq(presenter.last_charge_progress, 0.5, 0.0001)
	assert_eq(presenter.charge_particle_capacity(), RobotAnimationPresenter.CHARGE_PARTICLE_CAPACITY)
	assert_almost_eq(presenter.charge_meter_fill_ratio(), 0.5, 0.0001)
	assert_almost_eq(
		core.scale.x,
		lerpf(
			RobotAnimationPresenter.CHARGE_CORE_MIN_SCALE,
			RobotAnimationPresenter.CHARGE_CORE_MAX_SCALE,
			0.5
		),
		0.0001
	)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), baseline_nodes)
	assert_true(attacks.release_charge())
	assert_false(presenter.charging)
	assert_false(presenter.charge_particles_emitting())
	assert_false(presenter.charge_meter_visible())
	assert_false(presenter.charge_core_visible())
	assert_false(presenter.release_shockwave_visible())
	assert_false(presenter._charge_sfx_player.playing)
	assert_true(sprite.is_playing())
	var spec: AttackSpec = attacks.current_spec
	await get_tree().create_timer(spec.anticipation_seconds + 0.04).timeout
	assert_gte(sprite.frame, RobotAnimationPresenter.ATTACK_EVENT_FRAME)
	assert_almost_eq(spec.actor_damage, 217.5, 0.001)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_pause_preserves_full_charge_and_allows_release() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var attacks: ContextualAttackController = city.contextual_attacks
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	assert_gt(attacks.begin_charge(), 0)
	attacks._process(ContextualAttackController.MAX_CHARGE_SECONDS)
	assert_false(presenter.charge_particles_emitting())
	assert_true(presenter._charge_voice_player.playing)
	var pause_token: int = city.urban_siege.pause_coordinator.acquire(&"pause_menu")
	assert_true(attacks.is_busy())
	assert_true(attacks.is_charging())
	assert_true(presenter.attacking)
	assert_true(presenter.charging)
	assert_false(presenter.charge_particles_emitting())
	assert_false(presenter.release_shockwave_visible())
	assert_true(presenter._charge_voice_player.playing)
	assert_eq(sprite.animation, &"attack_se")
	assert_false(sprite.is_playing())
	assert_true(attacks.release_charge())
	assert_true(presenter.release_shockwave_visible())
	assert_true(city.urban_siege.pause_coordinator.release(pause_token))


func test_full_charge_stops_particles_at_two_seconds_but_keeps_first_frame_frozen() -> void:
	var city: CitySlice = await _spawn_city()
	var attacks: ContextualAttackController = city.contextual_attacks
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	assert_gt(attacks.begin_charge(), 0)
	attacks._process(2.5)
	assert_true(attacks.is_charging())
	assert_almost_eq(attacks.charge_duration(), 2.0, 0.0001)
	assert_almost_eq(presenter.last_charge_progress, 1.0, 0.0001)
	assert_almost_eq(presenter.charge_meter_fill_ratio(), 1.0, 0.0001)
	assert_true(presenter.charge_meter_visible())
	assert_true(presenter.charge_core_visible())
	assert_eq(presenter.full_charge_voice_play_count, 1)
	assert_same(
		presenter._charge_voice_player.stream,
		RobotAnimationPresenter.FULLY_CHARGED_VOICE
	)
	assert_eq(presenter._charge_voice_player.bus, GameAudioBus.VOICE)
	assert_false(presenter.charge_particles_emitting())
	assert_true(presenter.charge_core_max_shifted())
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())
	presenter._process(0.25)
	attacks._process(1.0)
	assert_eq(presenter.full_charge_voice_play_count, 1)
	assert_true(attacks.release_charge())
	assert_almost_eq(attacks.current_spec.actor_damage, 720.0, 0.001)
	assert_true(presenter._charge_voice_player.playing)
	assert_false(presenter.charge_meter_visible())
	assert_false(presenter.charge_core_visible())
	assert_true(presenter.release_shockwave_visible())
	assert_almost_eq(
		presenter.release_shockwave_scale(),
		RobotAnimationPresenter.RELEASE_SHOCKWAVE_START_SCALE,
		0.0001
	)
	assert_true(sprite.is_playing())
	presenter._process(RobotAnimationPresenter.RELEASE_SHOCKWAVE_SECONDS * 0.5)
	assert_true(presenter.release_shockwave_visible())
	assert_gt(
		presenter.release_shockwave_scale(),
		RobotAnimationPresenter.RELEASE_SHOCKWAVE_START_SCALE
	)
	presenter._process(RobotAnimationPresenter.RELEASE_SHOCKWAVE_SECONDS * 0.51)
	assert_false(presenter.release_shockwave_visible())
	attacks.cancel_attack()
	assert_false(presenter._charge_voice_player.playing)


func test_near_cap_release_snaps_to_full_charge_and_announces_once() -> void:
	var city: CitySlice = await _spawn_city()
	var attacks: ContextualAttackController = city.contextual_attacks
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	assert_gt(attacks.begin_charge(), 0)
	attacks._process(
		ContextualAttackController.MAX_CHARGE_SECONDS
		- ContextualAttackController.FULL_CHARGE_RELEASE_GRACE_SECONDS * 0.5
	)
	assert_lt(attacks.charge_progress(), 1.0)
	assert_eq(presenter.full_charge_voice_play_count, 0)
	assert_true(attacks.release_charge())
	assert_true(attacks.current_spec.is_fully_charged())
	assert_almost_eq(attacks.charge_progress(), 1.0, 0.0001)
	assert_eq(presenter.full_charge_voice_play_count, 1)
	assert_eq(presenter.last_audio_cue, &"fully_charged")
	assert_true(presenter._charge_voice_player.playing)


func test_confirmed_full_charge_enemy_hit_plays_signature_cue_and_world_flash_once() -> void:
	var city: CitySlice = await _spawn_city()
	var attacks: ContextualAttackController = city.contextual_attacks
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	var hit_position: Vector2 = city.robot.global_position + Vector2(150.0, -28.0)
	var attack_id: int = attacks.begin_charge()
	attacks._process(ContextualAttackController.MAX_CHARGE_SECONDS)
	assert_true(attacks.release_charge())
	assert_true(attacks.current_spec.is_fully_charged())
	assert_true(attacks.report_enemy_hit(attack_id, hit_position, 2))
	assert_eq(presenter.full_charge_hit_sfx_play_count, 1)
	assert_eq(presenter.last_audio_cue, &"photon_full_hit")
	assert_eq(presenter.last_full_charge_hit_position, hit_position)
	assert_true(presenter.full_charge_hit_flash_visible())
	assert_false(attacks.report_enemy_hit(attack_id, hit_position, 2))
	assert_eq(presenter.full_charge_hit_sfx_play_count, 1)
	presenter._process(RobotAnimationPresenter.FULL_CHARGE_HIT_FLASH_SECONDS + 0.01)
	assert_false(presenter.full_charge_hit_flash_visible())


func test_pause_preserves_melee_and_attack_lock() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	robot.collision_mask = 0
	robot.gravity = 0.0
	robot.velocity.x = robot.max_speed
	var terminal_specs: Array[AttackSpec] = []
	city.contextual_attacks.attack_finished.connect(
		func(spec: AttackSpec) -> void:
			terminal_specs.append(spec)
	)
	assert_gt(robot.request_attack(), 0)
	assert_true(city.contextual_attacks.is_busy())
	assert_true(presenter.attacking)
	assert_eq(sprite.animation, &"attack_e")
	var pause_token: int = city.urban_siege.pause_coordinator.acquire(&"pause_menu")
	assert_true(city.contextual_attacks.is_busy())
	assert_eq(terminal_specs.size(), 0)
	var pause_x: float = robot.global_position.x
	robot.physics_step(1.0, 0.10)
	assert_almost_eq(robot.global_position.x, pause_x, 0.001)
	city.contextual_attacks.cancel_attack()
	assert_eq(terminal_specs.size(), 1)
	assert_false(presenter.attacking)
	assert_eq(sprite.animation, &"idle_s")
	assert_false(sprite.is_playing())
	assert_true(city.urban_siege.pause_coordinator.release(pause_token))
	robot.physics_step(1.0, 0.10)
	assert_eq(robot.locomotion_state, GiantRobotController.LocomotionState.WALK)
	assert_eq(sprite.animation, &"walk_e")
	assert_true(sprite.is_playing())
	robot.facing = -1
	robot.facing_changed.emit(robot.facing)
	assert_eq(sprite.animation, &"walk_w")
	assert_true(sprite.is_playing())


func test_pause_preserves_dodge_and_player_locomotion() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	robot.collision_mask = 0
	robot.gravity = 0.0
	assert_true(robot._start_dodge(-1))
	assert_true(presenter.dodging)
	assert_eq(robot.locomotion_state, GiantRobotController.LocomotionState.DODGE)
	assert_gt(sprite.skew, 0.0)
	var pause_token: int = city.urban_siege.pause_coordinator.acquire(&"pause_menu")
	assert_true(presenter.dodging)
	assert_eq(robot.locomotion_state, GiantRobotController.LocomotionState.DODGE)
	var start_x: float = robot.global_position.x
	robot.physics_step(-1.0, 0.10)
	assert_lt(robot.global_position.x, start_x)
	assert_true(city.urban_siege.pause_coordinator.release(pause_token))


func test_defeat_cancels_melee_but_preserves_free_locomotion() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	var terminal_specs: Array[AttackSpec] = []
	city.contextual_attacks.attack_finished.connect(
		func(spec: AttackSpec) -> void:
			terminal_specs.append(spec)
	)
	robot.velocity.x = robot.max_speed
	assert_gt(robot.request_attack(), 0)
	assert_true(presenter.attacking)
	assert_true(robot.receive_damage(DamageEvent.new(99_001, null, robot.max_health + 1.0)))
	assert_false(city.contextual_attacks.is_busy())
	assert_false(presenter.attacking)
	assert_eq(terminal_specs.size(), 1)
	assert_eq(sprite.animation, &"idle_s")
	assert_false(sprite.is_playing())
	var defeated_x: float = robot.global_position.x
	robot.physics_step(-1.0, 0.10)
	robot.physics_step(-1.0, 0.10)
	assert_lt(robot.global_position.x, defeated_x)


func test_directive_pause_preserves_melee_and_attack_lock() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	robot.collision_mask = 0
	robot.gravity = 0.0
	robot.velocity.x = robot.max_speed
	assert_gt(robot.request_attack(), 0)
	assert_true(presenter.attacking)
	var profile: DirectiveProfile = city.urban_siege.directives.offer(781)
	assert_not_null(profile)
	assert_true(city.urban_siege.pause_coordinator.is_paused())
	assert_true(city.contextual_attacks.is_busy())
	assert_true(presenter.attacking)
	var paused_x: float = robot.global_position.x
	robot.physics_step(1.0, 0.10)
	assert_almost_eq(robot.global_position.x, paused_x, 0.001)
	assert_true(city.urban_siege.directives.select(profile))
	assert_false(city.urban_siege.pause_coordinator.is_paused())
	city.contextual_attacks.cancel_attack()
	city.urban_siege.directives.stop()


func test_critical_health_smoke_emits_at_or_below_twenty_five_percent() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	var smoke: CPUParticles2D = (
		robot.get_node(^"VisualRoot/CriticalHealthSmoke") as CPUParticles2D
	)
	assert_eq(presenter.critical_smoke_emitter_count(), 1)
	assert_not_null(smoke.texture)
	assert_false(presenter.critical_smoke_emitting())
	robot.current_health = robot.max_health * 0.26
	robot.health_changed.emit(robot.current_health, robot.max_health)
	assert_false(presenter.critical_smoke_emitting())
	robot.current_health = robot.max_health * 0.25
	robot.health_changed.emit(robot.current_health, robot.max_health)
	assert_true(presenter.critical_smoke_emitting())
	assert_gt(smoke.position.x, 0.0)
	robot.facing = -1
	robot.facing_changed.emit(-1)
	assert_lt(smoke.position.x, 0.0)
	robot.current_health = 0.0
	robot.health_changed.emit(robot.current_health, robot.max_health)
	assert_false(presenter.critical_smoke_emitting())
	robot.current_health = robot.max_health * 0.5
	robot.health_changed.emit(robot.current_health, robot.max_health)
	assert_false(presenter.critical_smoke_emitting())
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_robot_mechanics_audio_is_pcm_fixed_and_frame_synchronized() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	_assert_pcm_cue(RobotAnimationPresenter.FOOTSTEP_SFX)
	_assert_pcm_cue(RobotAnimationPresenter.SERVO_SFX)
	_assert_compressed_runtime_cue(RobotAnimationPresenter.DASH_WARP_SFX)
	assert_almost_eq(RobotAnimationPresenter.DASH_WARP_SFX.get_length(), 1.70, 0.01)
	_assert_pcm_cue(RobotAnimationPresenter.DODGE_RECHARGED_SFX)
	_assert_compressed_runtime_cue(RobotAnimationPresenter.GROUND_SLAM_IMPACT_SFX)
	_assert_compressed_runtime_cue(RobotAnimationPresenter.DOUBLE_PUNCH_IMPACT_SFX, 0.45)
	assert_eq(
		RobotAnimationPresenter.PUNCH_CONTACT_FRAMES,
		[RobotAnimationPresenter.ATTACK_EVENT_FRAME, 14]
	)
	assert_almost_eq(
		RobotAnimationPresenter.PUNCH_CONTACT_INTERVAL_SECONDS,
		0.25,
		0.0001
	)
	assert_almost_eq(
		RobotAnimationPresenter.DOUBLE_PUNCH_IMPACT_SFX.get_length(),
		0.47,
		0.01
	)
	_assert_compressed_runtime_cue(RobotAnimationPresenter.PHOTON_CHARGE_SFX)
	_assert_compressed_runtime_cue(RobotAnimationPresenter.PHOTON_FULL_HIT_SFX)
	_assert_compact_voice_cue(RobotAnimationPresenter.FULLY_CHARGED_VOICE)
	assert_almost_eq(
		db_to_linear(RobotAnimationPresenter.ATTACK_IMPACT_GAIN_DB),
		3.0,
		0.0001
	)
	assert_almost_eq(
		db_to_linear(RobotAnimationPresenter.ATTACK_IMPACT_REDUCTION_DB),
		0.75,
		0.0001
	)
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)
	for audio_node: Node in presenter.find_children("RobotMechanicsAudio*", "AudioStreamPlayer2D"):
		assert_eq((audio_node as AudioStreamPlayer2D).bus, GameAudioBus.MECHANICS)
	assert_eq(
		(presenter.get_node(^"RobotStatusRechargeSfx") as AudioStreamPlayer).bus,
		GameAudioBus.MECHANICS
	)
	assert_eq(presenter._charge_sfx_player.bus, GameAudioBus.MECHANICS)
	assert_eq(presenter._charge_voice_player.bus, GameAudioBus.VOICE)
	var frame_callable: Callable = presenter._on_sprite_frame_changed
	sprite.frame_changed.disconnect(frame_callable)
	robot.locomotion_state = GiantRobotController.LocomotionState.WALK
	sprite.play(&"walk_e")
	sprite.pause()
	var impact_positions: Array[Vector2] = []
	robot.footstep_impact.connect(
		func(position: Vector2, _strength: float) -> void:
			impact_positions.append(position)
	)
	_set_walk_audio_frame(presenter, sprite, 1)
	assert_eq(presenter.audio_play_count, 0)
	_set_walk_audio_frame(presenter, sprite, 2)
	assert_eq(presenter.servo_play_count, 1)
	assert_eq(presenter.last_audio_cue, &"walk_servo")
	_set_walk_audio_frame(presenter, sprite, 5)
	assert_eq(presenter.footstep_play_count, 1)
	assert_eq(impact_positions.size(), 1)
	_set_walk_audio_frame(presenter, sprite, 15)
	_set_walk_audio_frame(presenter, sprite, 18)
	assert_eq(presenter.servo_play_count, 2)
	assert_eq(presenter.footstep_play_count, 2)
	assert_eq(impact_positions.size(), 2)
	presenter._on_attack_selected(AttackSpec.Mode.GROUND_SMASH, 501)
	assert_eq(presenter.servo_play_count, 3)
	assert_eq(presenter.last_audio_cue, &"attack_windup")
	presenter._on_attack_committed(AttackSpec.Mode.GROUND_SMASH, 501)
	assert_eq(presenter.attack_impact_play_count, 1)
	assert_eq(presenter.last_audio_cue, &"ground_slam_impact")
	_assert_cue_volume(
		presenter,
		RobotAnimationPresenter.GROUND_SLAM_IMPACT_SFX,
		RobotAnimationPresenter.ATTACK_IMPACT_VOLUME_DB,
		RobotAnimationPresenter.MELEE_IMPACT_VOLUME_VARIATION_DB
	)
	assert_eq(sprite.frame, RobotAnimationPresenter.ATTACK_EVENT_FRAME)
	presenter._on_attack_committed(AttackSpec.Mode.JAB_CROSS, 501)
	assert_eq(presenter.attack_impact_play_count, 2)
	assert_eq(presenter.last_audio_cue, &"double_punch_impact")
	_assert_cue_volume(
		presenter,
		RobotAnimationPresenter.DOUBLE_PUNCH_IMPACT_SFX,
		RobotAnimationPresenter.ATTACK_IMPACT_VOLUME_DB,
		RobotAnimationPresenter.MELEE_IMPACT_VOLUME_VARIATION_DB
	)
	assert_almost_eq(
		RobotAnimationPresenter.volume_delta_for_sample(
			0.0, RobotAnimationPresenter.MELEE_IMPACT_VOLUME_VARIATION_DB
		),
		-0.55,
		0.0001
	)
	assert_almost_eq(
		RobotAnimationPresenter.volume_delta_for_sample(
			0.5, RobotAnimationPresenter.MELEE_IMPACT_VOLUME_VARIATION_DB
		),
		0.0,
		0.0001
	)
	assert_almost_eq(
		RobotAnimationPresenter.volume_delta_for_sample(
			1.0, RobotAnimationPresenter.MELEE_IMPACT_VOLUME_VARIATION_DB
		),
		0.55,
		0.0001
	)
	assert_almost_eq(
		RobotAnimationPresenter.volume_delta_for_sample(1.0, 20.0),
		RobotAnimationPresenter.MAX_MECHANICS_VOLUME_VARIATION_DB,
		0.0001
	)
	for cycle_index: int in range(8):
		presenter.attacking = false
		_set_walk_audio_frame(presenter, sprite, 2 if cycle_index % 2 == 0 else 5)
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)
	assert_gt(presenter.audio_recycle_count, 0)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_robot_mechanics_priority_stealing_protects_signature_cues() -> void:
	var city: CitySlice = await _spawn_city()
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	for index: int in range(RobotAnimationPresenter.AUDIO_VOICE_CAPACITY):
		presenter._play_mechanics(
			RobotAnimationPresenter.SERVO_SFX,
			&"walk_servo",
			-7.0,
			1.0
		)
	for player: AudioStreamPlayer2D in presenter._audio_players:
		assert_eq(
			AudioVoicePriority.priority_of(player),
			AudioVoicePriority.LOCOMOTION
		)
	for index: int in range(RobotAnimationPresenter.AUDIO_VOICE_CAPACITY):
		presenter._play_mechanics(
			RobotAnimationPresenter.DOUBLE_PUNCH_IMPACT_SFX,
			&"double_punch_impact",
			2.0,
			1.0
		)
	assert_eq(
		presenter.audio_preemption_count,
		RobotAnimationPresenter.AUDIO_VOICE_CAPACITY
	)
	assert_eq(presenter.last_preempted_priority, AudioVoicePriority.LOCOMOTION)
	for player: AudioStreamPlayer2D in presenter._audio_players:
		assert_eq(
			AudioVoicePriority.priority_of(player),
			AudioVoicePriority.SIGNATURE
		)
	var accepted_count: int = presenter.audio_play_count
	presenter._play_mechanics(
		RobotAnimationPresenter.SERVO_SFX,
		&"walk_servo",
		-7.0,
		1.0
	)
	assert_eq(presenter.audio_play_count, accepted_count)
	assert_eq(presenter.audio_drop_count, 1)
	assert_eq(presenter.last_audio_cue, &"double_punch_impact")
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)


func test_robot_mechanics_audio_recovers_after_pause() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	robot.global_position = Vector2(2800.0, 466.5)
	var pause_token: int = city.urban_siege.pause_coordinator.acquire(&"pause_menu")
	assert_true(city.urban_siege.pause_coordinator.release(pause_token))
	var cues: Array = [
		[RobotAnimationPresenter.FOOTSTEP_SFX, &"walk_footstep"],
		[RobotAnimationPresenter.SERVO_SFX, &"attack_windup"],
		[RobotAnimationPresenter.DASH_WARP_SFX, &"dash_warp"],
		[RobotAnimationPresenter.GROUND_SLAM_IMPACT_SFX, &"ground_slam_impact"],
		[RobotAnimationPresenter.DOUBLE_PUNCH_IMPACT_SFX, &"double_punch_impact"],
	]
	for cue_data: Array in cues:
		var stream: AudioStream = cue_data[0] as AudioStream
		presenter._play_mechanics(stream, cue_data[1] as StringName, 0.0, 1.0)
		var voice: AudioStreamPlayer2D = _voice_for_stream(presenter, stream)
		assert_not_null(voice)
		assert_eq(voice.global_position, robot.global_position)
		assert_lt(voice.global_position.distance_to(robot.global_position), voice.max_distance)
		voice.stop()
	assert_eq(presenter.audio_drop_count, 0)
	assert_eq(presenter.audio_play_count, cues.size())
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_dodge_recharge_sfx_plays_once_when_cooldown_completes() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	robot.collision_mask = 0
	robot.gravity = 0.0
	assert_eq(presenter.dodge_recharged_sfx_play_count, 0)
	assert_eq(presenter._status_sfx_player.bus, GameAudioBus.MECHANICS)
	assert_same(
		RobotAnimationPresenter.DODGE_RECHARGED_SFX,
		load("res://audio/sfx/robot/dodge_energy_recharged.wav")
	)
	assert_true(robot._start_dodge())
	robot.physics_step(0.0, 0.60)
	assert_eq(presenter.dodge_recharged_sfx_play_count, 0)
	robot.physics_step(0.0, 0.60)
	assert_eq(presenter.dodge_recharged_sfx_play_count, 1)
	assert_eq(presenter.last_audio_cue, &"dodge_recharged")
	assert_same(presenter._status_sfx_player.stream, presenter.DODGE_RECHARGED_SFX)
	robot.physics_step(0.0, 0.20)
	assert_eq(presenter.dodge_recharged_sfx_play_count, 1)
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_dodge_uses_facing_lean_and_restores_clean_sprite_state() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	presenter.set_process(false)
	robot.collision_mask = 0
	robot.gravity = 0.0
	robot.global_position = Vector2(600.0, 460.0)
	var baseline_nodes: int = int(RuntimeBudget.snapshot(city).node_count)
	robot.facing = -1
	robot.facing_changed.emit(-1)
	assert_true(robot._start_dodge())
	assert_eq(presenter.dash_warp_sfx_play_count, 1)
	assert_eq(presenter.last_audio_cue, &"dash_warp")
	assert_same(
		presenter._audio_players[0].stream,
		RobotAnimationPresenter.DASH_WARP_SFX
	)
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)
	assert_true(presenter.dodging)
	assert_gt(sprite.skew, 0.0)
	assert_lt(sprite.modulate.a, 1.0)
	assert_eq(presenter.afterimage_slot_count(), RuntimeBudget.DODGE_AFTERIMAGE_SLOTS)
	assert_eq(presenter.active_afterimage_count(), 1)
	assert_eq(presenter.dust_slot_count(), RuntimeBudget.DODGE_DUST_SLOTS)
	assert_eq(presenter.active_dust_slot_count(), 1)
	assert_gt(presenter._dust_pool.last_direction.x, 0.0)
	assert_lt(presenter._dust_pool.last_direction.y, 0.0)
	for step_index: int in range(4):
		robot.physics_step(0.0, 0.04)
		presenter._process(0.04)
	assert_gte(presenter.active_afterimage_count(), 4)
	assert_gte(presenter.active_dust_slot_count(), 3)
	var minimum_x: float = INF
	var maximum_x: float = -INF
	for ghost: Sprite2D in presenter._afterimages:
		if ghost.visible:
			minimum_x = minf(minimum_x, ghost.global_position.x)
			maximum_x = maxf(maximum_x, ghost.global_position.x)
	assert_gt(maximum_x - minimum_x, 30.0)
	for saturation_index: int in range(16):
		presenter._spawn_afterimage()
		presenter._spawn_dodge_dust(1.0)
	assert_eq(presenter.active_afterimage_count(), RuntimeBudget.DODGE_AFTERIMAGE_SLOTS)
	assert_eq(presenter.active_dust_slot_count(), RuntimeBudget.DODGE_DUST_SLOTS)
	assert_gt(presenter._dust_pool.recycle_count, 0)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), baseline_nodes)
	robot.physics_step(0.0, 0.03)
	presenter._process(0.03)
	assert_false(presenter.dodging)
	assert_eq(sprite.skew, 0.0)
	assert_eq(sprite.modulate, Color.WHITE)
	presenter._process(RobotAnimationPresenter.AFTERIMAGE_LIFETIME + 0.01)
	assert_eq(presenter.active_afterimage_count(), 0)
	presenter._dust_pool.stop_all()
	assert_eq(presenter.active_dust_slot_count(), 0)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func _assert_attack(
	presenter: RobotAnimationPresenter,
	robot: GiantRobotController,
	sprite: AnimatedSprite2D,
	mode: int,
	facing: int,
	expected: StringName
) -> void:
	robot.facing = facing
	robot.facing_changed.emit(facing)
	var attack_id: int = 100 + mode * 10 + (1 if facing > 0 else 2)
	presenter._on_attack_selected(mode, attack_id)
	assert_eq(sprite.animation, expected)
	assert_true(sprite.is_playing())
	presenter._on_attack_committed(mode, attack_id)
	assert_eq(sprite.frame, 11)
	assert_true(sprite.is_playing())
	sprite.pause()
	sprite.set_frame_and_progress(24, 0.0)
	var spec: AttackSpec = AttackSpec.new(
		mode,
		attack_id,
		facing,
		0.0,
		0.0,
		0.0,
		0.0,
		1.0,
		1.0,
		1.0,
		Vector2.ONE,
		Vector2.ZERO
	)
	presenter._on_attack_finished(spec)
	assert_eq(presenter.last_completed_attack_frame, 24)
	assert_eq(sprite.animation, &"idle_s")


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _wait_for_attack(controller: ContextualAttackController) -> void:
	var spec: AttackSpec = controller.current_spec
	if spec != null:
		await get_tree().create_timer(
			spec.anticipation_seconds
			+ spec.active_seconds
			+ spec.recovery_seconds
			+ 0.10
		).timeout
	assert_false(controller.is_busy())


func _assert_pcm_cue(stream: AudioStream) -> void:
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	assert_not_null(wav)
	if wav == null:
		return
	assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(wav.mix_rate, 48000)
	assert_false(wav.stereo)


func _assert_compressed_runtime_cue(stream: AudioStream, minimum_length: float = 1.0) -> void:
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	assert_not_null(wav)
	if wav == null:
		return
	assert_eq(wav.format, AudioStreamWAV.FORMAT_QOA)
	assert_eq(wav.mix_rate, 48000)
	assert_false(wav.stereo)
	assert_gt(wav.get_length(), minimum_length)
	assert_lt(wav.get_length(), 2.1)


func _assert_cue_volume(
	presenter: RobotAnimationPresenter,
	stream: AudioStream,
	expected_volume_db: float,
	variation_db: float = 0.0
) -> void:
	var matching_voices: int = 0
	for player: AudioStreamPlayer2D in presenter._audio_players:
		if player.stream != stream:
			continue
		matching_voices += 1
		assert_between(
			player.volume_db,
			expected_volume_db - variation_db,
			expected_volume_db + variation_db
		)
	assert_eq(matching_voices, 1)


func _voice_for_stream(
	presenter: RobotAnimationPresenter,
	stream: AudioStream
) -> AudioStreamPlayer2D:
	for player: AudioStreamPlayer2D in presenter._audio_players:
		if player.stream == stream:
			return player
	return null


func _assert_compact_voice_cue(stream: AudioStream) -> void:
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	assert_not_null(wav)
	if wav == null:
		return
	assert_eq(wav.format, AudioStreamWAV.FORMAT_QOA)
	assert_eq(wav.mix_rate, 24000)
	assert_false(wav.stereo)


func _set_walk_audio_frame(
	presenter: RobotAnimationPresenter,
	sprite: AnimatedSprite2D,
	frame: int
) -> void:
	sprite.set_frame_and_progress(frame, 0.0)
	presenter._on_sprite_frame_changed()


func _sprite(city: CitySlice) -> AnimatedSprite2D:
	return city.robot.get_node(^"VisualRoot/RobotAnimatedSprite") as AnimatedSprite2D
