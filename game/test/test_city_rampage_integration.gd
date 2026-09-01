extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"


func test_prop_destruction_updates_score_and_momentum_without_kill_combo() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.car.current_health = 1.0
	city.streetlamp.current_health = 0.05
	city.robot.stomp_radius = 500.0
	city.robot.stomp_damage = 200.0
	city.trigger_test_stomp()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(city.score, 450)
	assert_eq(city.rampage_session.current_multiplier(), 1)
	assert_almost_eq(city.rampage_session.momentum_value(), 12.0, 0.01)
	var score_label: Label = city.get_node(^"HUD/ScoreLabel") as Label
	var combo_label: Label = city.get_node(^"HUD/ComboLabel") as Label
	var combo_ring: ComboDecayRing = city.get_node(
		^"HUD/ComboDecayRing"
	) as ComboDecayRing
	assert_eq(score_label.text, "00000450")
	assert_false(combo_label.visible)
	assert_false(combo_ring.visible)
	assert_null(city.get_node_or_null(^"HUD/StatusLabel"))
	assert_null(city.get_node_or_null(^"HUD/MomentumLabel"))
	assert_null(city.get_node_or_null(^"HUD/MomentumTrack"))
	assert_null(city.get_node_or_null(^"HUD/MomentumFill"))
	_record_test_execution()


func test_motion_gain_and_heavy_hostile_hit_loss_reach_live_session() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.set_process(false)
	city.robot.velocity.x = city.robot.max_speed * 0.8
	city._process(1.0)
	assert_almost_eq(city.rampage_session.momentum_value(), 12.0, 0.001)
	var heavy_event: DamageEvent = DamageEvent.new(
		6199,
		city.tank,
		40.0,
		&"shell"
	)
	assert_true(city.robot.receive_damage(heavy_event))
	assert_almost_eq(city.rampage_session.momentum_value(), 0.0, 0.001)
	_record_test_execution()


func test_physical_enemy_copies_normalize_score_and_combo_until_player_damage() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var targets: Array[EnemyActor2D] = [city.soldier, city.tank, city.helicopter]
	for index: int in range(targets.size()):
		assert_true(city.rampage_events.enemy_defeated(
			targets[index],
			DamageEvent.new(7000 + index, city.robot, 999.0, &"test_kill"),
			100,
			city.robot
		))
	assert_eq(city.score, 200)
	assert_eq(city.rampage_session.current_multiplier(), 2)
	assert_eq(city.gameplay_hud.combo_label.text, "x2 KILL COMBO")
	assert_true(city.gameplay_hud.combo_label.visible)
	var herald: ComboHerald = city.gameplay_hud.combo_herald
	assert_eq(herald.last_tier, 2)
	assert_eq(herald.last_title_key, "hud.combo_herald.double")
	assert_eq(herald.title_label.text, "DOUBLE KILL")
	assert_eq(herald.presentation_count, 1)
	assert_eq(herald.audio_play_count, 1)
	assert_eq(herald.voice_player.bus, GameAudioBus.VOICE)
	assert_true(herald.is_presenting())
	assert_true(city.robot.receive_damage(DamageEvent.new(
		7100,
		city.soldier,
		1.0,
		&"rifle"
	)))
	assert_eq(city.rampage_session.current_multiplier(), 1)
	assert_eq(city.rampage_session.combo_tracker.current_chain_count, 0)
	assert_false(city.gameplay_hud.combo_label.visible)
	assert_false(herald.is_presenting())
	assert_false(herald.voice_player.playing)
	assert_null(herald.voice_player.stream)
	assert_eq(city.rampage_session.heavy_hit_count, 0)
	_record_test_execution()


func test_density_scaled_combo_ring_coexists_with_rear_barrier_vignette() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.gameplay_hud.set_combo(2, ComboTracker.GRACE_SECONDS)
	assert_almost_eq(city.gameplay_hud.combo_ring.ratio, 1.0, 0.0001)
	city.gameplay_hud.show_rear_barrier_warning()
	assert_true(city.gameplay_hud.rear_barrier_warning.visible)
	var warning_material: ShaderMaterial = (
		city.gameplay_hud.rear_barrier_warning.material as ShaderMaterial
	)
	assert_almost_eq(
		float(warning_material.get_shader_parameter(&"intensity")),
		1.0,
		0.0001
	)
	city.gameplay_hud._process(GameplayHud.REAR_BARRIER_WARNING_DURATION + 0.01)
	assert_false(city.gameplay_hud.rear_barrier_warning.visible)
	assert_almost_eq(city.gameplay_hud.combo_ring.ratio, 1.0, 0.0001)
	_record_test_execution()


func test_approved_event_values_and_surge_acceleration_reach_live_scene() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.soldier.set_physics_process(false)
	var soldier_event: DamageEvent = DamageEvent.new(
		6201,
		city.robot,
		999.0,
		&"impact",
		city.soldier.global_position,
		Vector2.RIGHT,
		320.0
	)
	assert_true(city.soldier.receive_damage(soldier_event))
	assert_eq(city.score, 250)
	assert_eq(city.rampage_session.current_multiplier(), 1)
	assert_eq(city.rampage_session.momentum_value(), 8.0)
	var cell: Destructible2D = city.building.get_cell(0, 1)
	var cell_event: DamageEvent = DamageEvent.new(
		6202,
		city.robot,
		cell.max_health + 1.0,
		&"structural",
		cell.global_position,
		Vector2.RIGHT,
		320.0
	)
	assert_true(cell.receive_damage(cell_event))
	assert_eq(city.rampage_session.current_multiplier(), 1)
	assert_eq(city.rampage_session.momentum_value(), 20.0)
	city.rampage_session.publish(GameplayEvent.new(
		&"surge_seed",
		0,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		&"",
		0,
		20.0
	))
	assert_eq(city.rampage_session.momentum_meter.band(), MomentumMeter.Band.SURGE)
	assert_almost_eq(city.robot.acceleration_multiplier, 1.08, 0.001)
	_record_test_execution()


func test_chain_collapse_bonus_uses_approved_tag_score_and_momentum() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var published: Array[GameplayEvent] = []
	city.rampage_session.event_hub.event_published.connect(
		func(event: GameplayEvent) -> void: published.append(event)
	)
	var chain_event: DamageEvent = DamageEvent.new(771, city.robot, 120.0, &"ground_smash")
	assert_true(
		city.rampage_events.chain_started(
			&"floor_chain",
			chain_event,
			city.building,
			city.robot
		)
	)
	assert_eq(city.score, 600)
	assert_eq(city.rampage_session.current_multiplier(), 1)
	assert_eq(city.rampage_session.momentum_value(), 24.0)
	assert_eq(published.size(), 1)
	assert_eq(published[0].action_tag, GameplayEvent.CHAIN_COLLAPSE)
	_record_test_execution()


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
