extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func after_each() -> void:
	Engine.time_scale = 1.0


func test_hit_stop_clamps_and_deduplicates_without_changing_time_scale() -> void:
	var prior_scale: float = 0.75
	Engine.time_scale = prior_scale
	var lease: HitStopLease = HitStopLease.new()
	add_child_autofree(lease)
	await get_tree().process_frame
	assert_true(lease.request(5, 71))
	assert_eq(lease.last_duration_ms, 25)
	assert_almost_eq(Engine.time_scale, prior_scale, 0.001)
	assert_true(lease.is_active())
	assert_false(lease.request(100, 71))
	assert_eq(lease.ignored_request_count, 1)
	lease.cancel_and_restore()
	assert_almost_eq(Engine.time_scale, prior_scale, 0.001)


func test_camera_impact_spring_is_bounded_and_settles_exactly() -> void:
	var rig: CameraRig = CameraRig.new()
	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	rig.add_child(camera)
	add_child_autofree(rig)
	await get_tree().process_frame
	rig.add_impact_impulse(Vector2(500.0, -300.0))
	for step: int in range(420):
		rig._physics_process(1.0 / 60.0)
		assert_lte(rig.impact_offset.length(), rig.maximum_impact_offset + 0.001)
	assert_eq(rig.impact_offset, Vector2.ZERO)
	assert_eq(rig.impact_velocity, Vector2.ZERO)
	assert_eq(camera.offset, Vector2.ZERO)


func test_boss_path_reveal_pans_right_holds_then_returns_on_player_movement() -> void:
	var robot: GiantRobotController = GiantRobotController.new()
	robot.global_position = Vector2(1000.0, 460.0)
	add_child_autofree(robot)
	var rig: CameraRig = CameraRig.new()
	rig.target = robot
	rig.global_position = Vector2(1180.0, 360.0)
	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	rig.add_child(camera)
	add_child_autofree(rig)
	await get_tree().process_frame
	robot.set_physics_process(false)
	rig.set_physics_process(false)
	assert_true(rig.begin_path_clear_reveal(1520.0))
	var reveal_start_x: float = rig.global_position.x
	for _step: int in range(12):
		rig._physics_process(0.1)
	assert_true(rig.path_clear_reveal_active())
	assert_false(rig.path_clear_reveal_returning())
	assert_gt(rig.global_position.x, reveal_start_x)
	assert_lte(
		rig.global_position.x,
		robot.global_position.x + rig.look_ahead + rig.path_clear_max_distance + 0.001
	)
	robot.global_position.x += rig.path_clear_movement_threshold + 1.0
	rig._physics_process(0.1)
	assert_true(rig.path_clear_reveal_returning())
	for _step: int in range(60):
		rig._physics_process(0.1)
	assert_false(rig.path_clear_reveal_active())
	assert_false(rig.path_clear_reveal_returning())
	assert_almost_eq(
		rig.global_position.x,
		robot.global_position.x + rig.look_ahead,
		1.0
	)
	assert_true(rig.begin_path_clear_reveal(1800.0))
	var focus_before_rebase: float = rig.path_clear_focus_world_x()
	rig.reset_after_origin_shift(Vector2(-640.0, 0.0))
	assert_almost_eq(
		rig.path_clear_focus_world_x(),
		focus_before_rebase - 640.0,
		0.001
	)
	assert_true(rig.path_clear_reveal_active())
	rig.reset_presentation()
	assert_false(rig.path_clear_reveal_active())


func test_pool_stays_at_eight_and_tracks_drop_and_recycle() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var audio_root: Node2D = Node2D.new()
	root.add_child(audio_root)
	var pool: ImpactFeedbackPool = ImpactFeedbackPool.new()
	pool.setup(root, audio_root)
	root.add_child(pool)
	await get_tree().process_frame
	var profile: StructuralMaterialProfile = StructuralMaterialProfile.concrete()
	var oldest_audio: AudioStreamPlayer2D
	for request_index: int in range(8):
		assert_not_null(pool.spawn_particles(
			Vector2.ZERO,
			Vector2.RIGHT,
			300.0,
			profile,
			AudioVoicePriority.DEFEAT
		))
		var audio: AudioStreamPlayer2D = pool.play_audio(
			profile,
			Vector2.ZERO,
			300.0,
			true,
			AudioVoicePriority.DEFEAT
		)
		assert_not_null(audio)
		if request_index == 0:
			oldest_audio = audio
	assert_null(pool.spawn_particles(
		Vector2.ZERO,
		Vector2.RIGHT,
		300.0,
		profile,
		AudioVoicePriority.ORDINARY
	))
	assert_null(pool.play_audio(
		profile,
		Vector2.ZERO,
		300.0,
		true,
		AudioVoicePriority.ORDINARY
	))
	var normalized_spark: CPUParticles2D = pool.spawn_particles(
		Vector2.ZERO,
		Vector2.RIGHT,
		300.0,
		profile,
		AudioVoicePriority.MAJOR
	)
	assert_not_null(normalized_spark)
	assert_lte(normalized_spark.scale_amount_max, 0.5)
	var priority_audio: AudioStreamPlayer2D = pool.play_audio(
		profile,
		Vector2.ZERO,
		300.0,
		true,
		AudioVoicePriority.SIGNATURE
	)
	assert_same(priority_audio, oldest_audio)
	assert_eq(
		AudioVoicePriority.priority_of(priority_audio),
		AudioVoicePriority.SIGNATURE
	)
	assert_eq(pool.particle_child_count(), 8)
	assert_eq(pool.audio_child_count(), 8)
	assert_eq(pool.particle_drop_count, 1)
	assert_eq(pool.audio_drop_count, 1)
	assert_eq(pool.particle_recycle_count, 1)
	assert_eq(pool.audio_recycle_count, 1)
	assert_eq(pool.audio_preemption_count, 1)
	assert_eq(pool.last_preempted_priority, AudioVoicePriority.DEFEAT)


func test_accepted_events_coalesce_to_one_strongest_feedback_transaction() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	for enemy: EnemyActor2D in [city.soldier, city.tank, city.helicopter]:
		enemy.set_physics_process(false)
	var damage_event: GameplayEvent = GameplayEvent.new(
		&"feedback_damage",
		9001,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK,
		150,
		6.0,
		true,
		city.building.global_position,
		&"concrete"
	)
	var breach_event: GameplayEvent = GameplayEvent.new(
		&"feedback_breach",
		9001,
		GameplayEvent.Kind.CELL_DESTROYED,
		GameplayEvent.CELL_BREACH,
		300,
		12.0,
		true,
		city.building.global_position,
		&"concrete"
	)
	assert_true(city.rampage_session.publish(damage_event))
	assert_true(city.rampage_session.publish(breach_event))
	await get_tree().process_frame
	assert_eq(city.impact_feedback_director.flush_count, 1)
	assert_eq(city.impact_feedback_director.coalesced_count, 1)
	assert_eq(city.impact_feedback_director.last_priority, 4)
	assert_eq(city.hit_stop.request_count, 1)
	assert_eq(city.hit_stop.last_duration_ms, 70)
	assert_eq(city.haptics_adapter.request_count, 1)
	assert_eq(city.haptics_adapter.last_duration_ms, 52)
	assert_gt(city.camera_rig.impact_velocity.length(), 0.0)
	city.impact_feedback_director.cancel_all()
	assert_false(city.hit_stop.is_active())
	assert_eq(city.camera_rig.impact_offset, Vector2.ZERO)


func test_player_frame_11_dispatches_shake_enemy_recoil_and_knockback_without_flash() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.deactivate()
	city.robot.global_position = Vector2(900.0, 460.0)
	city.robot.facing = 1
	city.robot.velocity.x = city.robot.max_speed
	city.tank.activate(city.robot.global_position + Vector2(120.0, 60.0), city.robot)
	city.tank.set_physics_process(false)
	var reactions: PlayerAttackReactionRuntime = (
		city.get_node(^"PlayerAttackReactionRuntime")
		as PlayerAttackReactionRuntime
	)
	var attack_id: int = city.robot.request_attack()
	var spec: AttackSpec = city.contextual_attacks.current_spec
	assert_gt(attack_id, 0)
	assert_true(spec.is_jab_cross())
	assert_eq(reactions.last_anticipated_attack_id, attack_id)
	assert_eq(city.tank.last_player_reaction_attack_id, attack_id)
	assert_eq(city.tank.player_anticipation_count, 1)
	assert_eq(city.impact_feedback_director.player_strike_feedback_count, 0)
	await get_tree().create_timer(spec.anticipation_seconds + 0.03).timeout
	await get_tree().process_frame
	assert_eq(city.impact_feedback_director.player_strike_feedback_count, 1)
	assert_eq(city.impact_feedback_director.last_player_attack_id, attack_id)
	assert_eq(
		city.impact_feedback_director.last_player_strike_frame,
		RobotAnimationPresenter.ATTACK_EVENT_FRAME
	)
	assert_null(
		city.impact_feedback_director.get_node_or_null(^"PlayerStrikeFlashLayer")
	)
	assert_gt(city.camera_rig.impact_velocity.length(), 0.0)
	assert_eq(reactions.last_strike_attack_id, attack_id)
	assert_eq(city.tank.player_strike_reaction_count, 1)
	assert_eq(city.tank.last_player_knockback_attack_id, attack_id)
	assert_lt(city.tank.current_health, city.tank.max_health)
	assert_gt(city.tank.velocity.x, 250.0)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_confirmed_full_charge_enemy_hit_triggers_maximum_feedback_transaction() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.deactivate()
	city.robot.global_position = Vector2(900.0, 460.0)
	city.robot.facing = 1
	city.robot.velocity.x = city.robot.max_speed
	city.tank.max_health = 5000.0
	city.tank.activate(city.robot.global_position + Vector2(120.0, 60.0), city.robot)
	city.tank.set_physics_process(false)
	await get_tree().physics_frame
	city.hit_stop.enabled = true
	city.contextual_attacks.resolver.jab_cross_anticipation_seconds = 0.0
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	var prior_health: float = city.tank.current_health
	var attack_id: int = city.contextual_attacks.begin_charge()
	city.contextual_attacks._process(ContextualAttackController.MAX_CHARGE_SECONDS)
	assert_true(city.contextual_attacks.release_charge())
	assert_gt(attack_id, 0)
	assert_lt(city.tank.current_health, prior_health)
	assert_eq(city.impact_feedback_director.full_charge_hit_feedback_count, 1)
	assert_eq(city.impact_feedback_director.last_full_charge_enemy_count, 1)
	assert_true(city.hit_stop.is_active())
	assert_eq(city.hit_stop.last_duration_ms, ImpactFeedbackDirector.FULL_CHARGE_HIT_STOP_MS)
	assert_eq(city.haptics_adapter.last_duration_ms, ImpactFeedbackDirector.FULL_CHARGE_HAPTIC_MS)
	assert_gt(city.camera_rig.impact_velocity.length(), 0.0)
	assert_eq(presenter.full_charge_hit_sfx_play_count, 1)
	var photon_hit_voice_found: bool = false
	for player: AudioStreamPlayer2D in presenter._audio_players:
		photon_hit_voice_found = (
			photon_hit_voice_found
			or player.stream == RobotAnimationPresenter.PHOTON_FULL_HIT_SFX
		)
	assert_true(photon_hit_voice_found)
	assert_true(presenter.full_charge_hit_flash_visible())
	city.hit_stop.cancel_and_restore()
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_fully_charged_ground_smash_enemy_hit_uses_same_signature_feedback() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.deactivate()
	city.robot.global_position = Vector2(900.0, 460.0)
	city.robot.velocity = Vector2.ZERO
	city.soldier.max_health = 5000.0
	city.soldier.activate(city.robot.global_position + Vector2(80.0, 0.0), city.robot)
	city.soldier.set_physics_process(false)
	await get_tree().physics_frame
	city.contextual_attacks.resolver.ground_anticipation_seconds = 0.0
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	var prior_health: float = city.soldier.current_health
	assert_gt(city.contextual_attacks.begin_charge(), 0)
	city.contextual_attacks._process(ContextualAttackController.MAX_CHARGE_SECONDS)
	assert_true(city.contextual_attacks.release_charge())
	await get_tree().physics_frame
	assert_lt(city.soldier.current_health, prior_health)
	assert_eq(city.impact_feedback_director.full_charge_hit_feedback_count, 1)
	assert_eq(city.impact_feedback_director.last_full_charge_enemy_count, 1)
	assert_gt(city.hit_stop.request_count, 0)
	assert_eq(presenter.full_charge_hit_sfx_play_count, 1)
	assert_true(presenter.full_charge_hit_flash_visible())
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_surviving_melee_hit_applies_fivefold_knockback() -> void:
	var enemy: EnemyActor2D = EnemyActor2D.new()
	enemy.max_health = 1000.0
	add_child_autofree(enemy)
	await get_tree().process_frame
	var impulse: float = 100.0
	assert_true(enemy.receive_damage(DamageEvent.new(
		77_001,
		null,
		10.0,
		&"jab_cross",
		Vector2.ZERO,
		Vector2.RIGHT,
		impulse
	)))
	assert_almost_eq(
		enemy.velocity.x,
		impulse * 0.28 * EnemyActor2D.SURVIVING_MELEE_KNOCKBACK_MULTIPLIER,
		0.001
	)
	var non_melee: EnemyActor2D = EnemyActor2D.new()
	non_melee.max_health = 1000.0
	add_child_autofree(non_melee)
	await get_tree().process_frame
	assert_true(non_melee.receive_damage(DamageEvent.new(
		77_002,
		null,
		10.0,
		&"projectile",
		Vector2.ZERO,
		Vector2.RIGHT,
		impulse
	)))
	assert_almost_eq(non_melee.velocity.x, impulse * 0.18, 0.001)


func test_dodge_through_light_enemies_triggers_one_non_damaging_wheel_slip() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.deactivate()
	city.robot.global_position = Vector2(500.0, 460.0)
	city.robot.facing = 1
	city.soldier.activate(city.robot.global_position + Vector2(150.0, 0.0), city.robot)
	city.soldier.set_physics_process(false)
	var jackal: EnemyActor2D = city.encounter_runtime.acquire(
		&"jackal",
		city.robot.global_position + Vector2(55.0, 0.0)
	)
	assert_not_null(jackal)
	if jackal == null:
		return
	jackal.set_physics_process(false)
	city.tank.activate(city.robot.global_position + Vector2(55.0, 0.0), city.robot)
	city.tank.set_physics_process(false)
	var reactions: PlayerAttackReactionRuntime = (
		city.get_node(^"PlayerAttackReactionRuntime")
		as PlayerAttackReactionRuntime
	)
	var soldier_health: float = city.soldier.current_health
	var jackal_health: float = jackal.current_health
	assert_true(city.robot._start_dodge(1))
	assert_eq(jackal.dodge_wheel_slip_count, 1)
	assert_eq(city.soldier.dodge_wheel_slip_count, 0)
	assert_eq(city.tank.dodge_wheel_slip_count, 0)
	city.robot.global_position.x += 100.0
	reactions._physics_process(0.0)
	assert_eq(city.soldier.dodge_wheel_slip_count, 1)
	assert_eq(jackal.dodge_wheel_slip_count, 1)
	assert_eq(city.tank.dodge_wheel_slip_count, 0)
	assert_eq(reactions.dodge_slip_dispatch_count, 2)
	assert_eq(city.soldier.last_dodge_wheel_slip_direction, 1)
	assert_eq(city.soldier.current_health, soldier_health)
	assert_eq(jackal.current_health, jackal_health)
	assert_eq(city.soldier.visual.modulate, Color.WHITE)
	assert_ne(city.soldier.visual.skew, 0.0)
	reactions._physics_process(0.0)
	assert_eq(city.soldier.dodge_wheel_slip_count, 1)
	assert_eq(jackal.dodge_wheel_slip_count, 1)
	await get_tree().create_timer(0.17).timeout
	assert_almost_eq(city.soldier.visual.skew, 0.0, 0.001)
	assert_almost_eq(jackal.visual.skew, 0.0, 0.001)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_rampage_cues_are_48k_pcm16_and_share_the_eight_voice_pool() -> void:
	var overdrive_stream: AudioStreamWAV = (
		AudioCueRegistry.OVERDRIVE_ACTIVATION_SFX as AudioStreamWAV
	)
	var combo_stream: AudioStreamWAV = AudioCueRegistry.COMBO_BREAK_SFX as AudioStreamWAV
	assert_eq(
		int(AudioCueRegistry.profile(AudioCueRegistry.Cue.OVERDRIVE_ACTIVATION).priority),
		AudioVoicePriority.SIGNATURE
	)
	assert_eq(
		int(AudioCueRegistry.profile(AudioCueRegistry.Cue.COMBO_BREAK).priority),
		AudioVoicePriority.MAJOR
	)
	assert_eq(overdrive_stream.mix_rate, 48000)
	assert_eq(combo_stream.mix_rate, 48000)
	assert_eq(overdrive_stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(combo_stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_false(overdrive_stream.stereo)
	assert_false(combo_stream.stereo)
	assert_between(overdrive_stream.get_length(), 0.65, 1.0)
	assert_between(combo_stream.get_length(), 0.18, 0.35)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.rampage_session.momentum_meter.apply_event(GameplayEvent.new(
		&"audio_ready",
		0,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		&"",
		0,
		100.0
	))
	assert_gt(city.contextual_attacks.request_attack(), 0)
	assert_eq(
		city.impact_feedback_pool.last_cue,
		AudioCueRegistry.Cue.OVERDRIVE_ACTIVATION
	)
	city.rampage_session.combo_tracker.register_event(GameplayEvent.new(
		&"audio_combo",
		0,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK,
		0,
		0.0,
		true
	))
	city.rampage_session.combo_tracker.advance(4.0)
	assert_eq(city.impact_feedback_pool.last_cue, AudioCueRegistry.Cue.COMBO_BREAK)
	assert_eq(city.impact_feedback_pool.cue_play_count, 2)
	assert_eq(city.impact_feedback_pool.audio_child_count(), 8)
	var invalid_count: int = city.impact_feedback_pool.invalid_cue_count
	assert_null(city.impact_feedback_pool.play_cue(
		AudioCueRegistry.Cue.INVALID,
		city.robot.global_position
	))
	assert_eq(city.impact_feedback_pool.invalid_cue_count, invalid_count + 1)
	assert_eq(city.impact_feedback_pool.cue_play_count, 2)
	assert_eq(city.impact_feedback_pool.last_cue, AudioCueRegistry.Cue.COMBO_BREAK)
