extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_required_experience_is_ten_percent_below_the_tripled_curve() -> void:
	assert_almost_eq(RunExperience.REQUIREMENT_REDUCTION, 0.10, 0.0001)
	assert_eq(RunExperience.required_for_level(1), 8100)
	assert_eq(RunExperience.required_for_level(2), 10935)
	assert_eq(RunExperience.required_for_level(3), 14758)
	assert_eq(RunExperience.required_for_level(4), 19926)
	assert_gt(
		RunExperience.required_for_level(12),
		RunExperience.required_for_level(11)
	)


func test_experience_levels_repeatedly_and_preserves_overflow() -> void:
	var experience: RunExperience = RunExperience.new()
	add_child_autofree(experience)
	var emitted_levels: Array[Vector2i] = []
	experience.level_gained.connect(
		func(level: int, event_id: int) -> void:
			emitted_levels.append(Vector2i(level, event_id))
	)
	assert_eq(experience.add_experience(26550), 2)
	assert_eq(experience.level, 3)
	assert_eq(experience.current_experience, 7515)
	assert_eq(experience.total_experience, 26550)
	assert_eq(experience.experience_required(), 14758)
	assert_almost_eq(experience.progress_ratio(), 7515.0 / 14758.0, 0.0001)
	assert_eq(emitted_levels, [])


func test_accepted_event_crosses_levels_with_one_nonzero_identity() -> void:
	var session: RampageSession = RampageSession.new()
	add_child_autofree(session)
	var emitted_levels: Array[Vector2i] = []
	session.run_experience.level_gained.connect(
		func(level: int, event_id: int) -> void:
			emitted_levels.append(Vector2i(level, event_id))
	)
	var event: GameplayEvent = GameplayEvent.new(
		&"multi-level",
		77,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.SOLDIER_LAUNCH,
		26550
	)
	assert_true(session.publish(event))
	assert_gt(event.event_id, 0)
	assert_eq(
		emitted_levels,
		[Vector2i(2, event.event_id), Vector2i(3, event.event_id)]
	)
	assert_false(session.publish(event))
	assert_eq(emitted_levels.size(), 2)
	assert_eq(session.run_experience.total_experience, 26550)


func test_session_grants_base_xp_once_and_reset_returns_to_level_one() -> void:
	var session: RampageSession = RampageSession.new()
	add_child_autofree(session)
	var event: GameplayEvent = GameplayEvent.new(
		&"xp-event",
		1,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.SOLDIER_LAUNCH,
		8100
	)
	assert_true(session.publish(event))
	assert_eq(session.run_experience.level, 2)
	assert_eq(session.run_experience.current_experience, 0)
	assert_false(session.publish(event))
	assert_eq(session.run_experience.total_experience, 8100)
	session.reset_run()
	assert_eq(session.run_experience.level, 1)
	assert_eq(session.run_experience.current_experience, 0)
	assert_eq(session.run_experience.total_experience, 0)


func test_adapter_copies_causal_metadata_and_keys_enemy_generation() -> void:
	var session: RampageSession = RampageSession.new()
	add_child_autofree(session)
	var adapter: RampageEventAdapter = RampageEventAdapter.new(session)
	var robot: GiantRobotController = GiantRobotController.new()
	var enemy: EnemyActor2D = EnemyActor2D.new()
	add_child_autofree(robot)
	add_child_autofree(enemy)
	enemy.activation_generation = 3
	var published: Array[GameplayEvent] = []
	session.event_hub.event_published.connect(
		func(gameplay_event: GameplayEvent) -> void:
			published.append(gameplay_event)
	)
	var damage: DamageEvent = DamageEvent.new(
		91,
		robot,
		100.0,
		&"machine_gun",
		Vector2(3.0, 4.0),
		Vector2.RIGHT,
		40.0,
		77,
		2
	)
	assert_true(adapter.enemy_defeated(enemy, damage, 500, robot))
	assert_eq(published.size(), 1)
	assert_eq(published[0].dedupe_key, StringName("enemy:%d:3" % enemy.get_instance_id()))
	assert_eq(published[0].attack_id, 91)
	assert_eq(published[0].root_attack_id, 77)
	assert_eq(published[0].causal_depth, 2)
	assert_eq(published[0].source_id, robot.get_instance_id())
	assert_eq(published[0].target_id, enemy.get_instance_id())
	assert_eq(published[0].cause, &"machine_gun")
	assert_false(adapter.enemy_defeated(enemy, damage, 500, robot))
	enemy.activation_generation = 4
	assert_true(adapter.enemy_defeated(enemy, damage, 500, robot))
	assert_eq(published.size(), 2)


func test_hud_shows_level_and_preserves_exp_ratio_across_orientation() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	assert_eq(city.gameplay_hud.experience_label.text, "LEVEL 01  EXP 0 / 8100")
	city.rampage_session.run_experience.add_experience(4050)
	assert_eq(city.gameplay_hud.experience_label.text, "LEVEL 01  EXP 4050 / 8100")
	assert_almost_eq(city.gameplay_hud.experience_fill.size.x, 127.0, 0.01)
	get_window().content_scale_size = Vector2i(720, 1280)
	get_tree().root.size = Vector2i(720, 1280)
	await get_tree().process_frame
	assert_almost_eq(
		city.gameplay_hud.experience_fill.size.x,
		(city.gameplay_hud.experience_track.size.x - 8.0) * 0.5,
		0.01
	)
	assert_true(
		Rect2(Vector2.ZERO, Vector2(720.0, 1280.0)).encloses(
			city.gameplay_hud.experience_track.get_global_rect()
		)
	)
	get_window().content_scale_size = Vector2i(1280, 720)
	get_tree().root.size = Vector2i(1280, 720)
