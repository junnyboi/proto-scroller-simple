extends SceneTree

const MAX_FRAMES: int = 3000
const REPORT_PATH: String = "res://artifacts/city_slice/report.json"
const SHOT_PATH: String = "res://artifacts/city_slice/city-slice.png"
const WRECK_SHOT_PATH: String = "res://artifacts/city_slice/city-slice-wrecked.png"
const RUBBLE_SHOT_PATH: String = "res://artifacts/city_slice/city-slice-rubble.png"

var checks: Array[Dictionary] = []
var completed: bool = false
var elapsed_frames: int = 0


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred("_run")


func _on_process_frame() -> void:
	if completed:
		return
	elapsed_frames += 1
	if elapsed_frames > MAX_FRAMES:
		_check("frame_watchdog", false, "frames=%s" % elapsed_frames)
		_finish("SKIP", "")


func _run() -> void:
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	_check("city_scene_loads", scene != null, "loaded=%s" % [scene != null])
	if scene == null:
		_finish("SKIP", "")
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	await physics_frame
	await physics_frame
	var parallax_count: int = city.get_node("ParallaxCity").get_child_count()
	_check("four_parallax_bands", parallax_count == 4, "bands=%s" % parallax_count)
	var enemies_ready: bool = (
		city.soldier != null and city.tank != null and city.helicopter != null
	)
	_check(
		"enemy_set",
		enemies_ready,
		"soldier=%s tank=%s helicopter=%s"
		% [city.soldier != null, city.tank != null, city.helicopter != null]
	)
	for pooled_enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		pooled_enemy.set_physics_process(false)
	city.robot.set_physics_process(false)
	var target_building: StructuralBuilding2D = city.building
	var target_car: DestructibleProp2D = city.car
	var target_lamp: DestructibleProp2D = city.streetlamp
	var initial_x: float = city.robot.position.x
	for frame_index: int in range(90):
		await physics_frame
		city.robot.physics_step(1.0, 1.0 / 60.0)
	_check(
		"robot_moves",
		city.robot.position.x > initial_x + 200.0,
		"start=%.2f end=%.2f" % [initial_x, city.robot.position.x]
	)
	for frame_index: int in range(8):
		await physics_frame
		city.robot.physics_step(-1.0, 1.0 / 60.0)
	_check("robot_turns", city.robot.facing == -1, "facing=%s" % city.robot.facing)
	target_car.current_health = 1.0
	target_lamp.current_health = 1.0
	city.robot.position = Vector2(1150.0, 460.0)
	city.robot.stomp_radius = 500.0
	city.robot.stomp_damage = 200.0
	city.trigger_test_stomp()
	await physics_frame
	await physics_frame
	await physics_frame
	_check(
		"ground_smash_damages_building",
		target_building.destroyed_cell_count() == 1,
		"cells=%d" % target_building.destroyed_cell_count()
	)
	_check(
		"ground_smash_blackens_car",
		target_car.is_broken and not target_car.is_fully_destroyed and target_car.visual.visible,
		"broken=%s fully_destroyed=%s visible=%s"
		% [target_car.is_broken, target_car.is_fully_destroyed, target_car.visual.visible]
	)
	_check(
		"ground_smash_blackens_lamp",
		target_lamp.is_broken and not target_lamp.is_fully_destroyed and target_lamp.visual.visible,
		"broken=%s fully_destroyed=%s visible=%s"
		% [target_lamp.is_broken, target_lamp.is_fully_destroyed, target_lamp.visual.visible]
	)
	await _save_state_shot(WRECK_SHOT_PATH)
	var debris_before_rubble: int = city.debris_pool.active_count()
	target_car.receive_damage(DamageEvent.new(
		76101,
		city.robot,
		1.0,
		&"jab_cross",
		target_car.global_position,
		Vector2.RIGHT,
		420.0
	))
	target_lamp.receive_damage(DamageEvent.new(
		76102,
		city.robot,
		1.0,
		&"jab_cross",
		target_lamp.global_position,
		Vector2.RIGHT,
		420.0
	))
	await physics_frame
	await physics_frame
	_check(
		"next_hit_reduces_props_to_rubble",
		target_car.is_fully_destroyed
		and target_lamp.is_fully_destroyed
		and city.debris_pool.active_count() == debris_before_rubble + 8,
		"car=%s lamp=%s debris=%d"
		% [
			target_car.is_fully_destroyed,
			target_lamp.is_fully_destroyed,
			city.debris_pool.active_count(),
		]
	)
	await _save_state_shot(RUBBLE_SHOT_PATH)
	var jab_cross_columns: Array[int] = [1, 1, 2, 2]
	for jab_cross_index: int in range(jab_cross_columns.size()):
		await _wait_for_contextual_attack(city)
		var column: int = jab_cross_columns[jab_cross_index]
		city.robot.position = Vector2(1100.0 + float(column) * 167.0, 460.0)
		city.robot.facing = 1
		city.robot.velocity.x = city.robot.max_speed * 0.8
		var attack_id: int = city.robot.request_attack()
		var spec: AttackSpec = city.contextual_attacks.current_spec
		_check(
			"jab_cross_%d_commits" % jab_cross_index,
			attack_id > 0 and spec != null and spec.is_jab_cross(),
			"attack_id=%d" % attack_id
		)
		if spec == null:
			continue
		await create_timer(spec.anticipation_seconds + 0.03).timeout
		await create_timer(spec.active_seconds + spec.recovery_seconds + 0.10).timeout
	for wait_frame: int in range(90):
		if target_building.is_destroyed():
			break
		await process_frame
	_check("car_breaks", target_car.is_broken, "broken=%s" % target_car.is_broken)
	_check("lamp_breaks", target_lamp.is_broken, "broken=%s" % target_lamp.is_broken)
	_check(
		"building_breaks",
		target_building.is_destroyed(),
		"destroyed=%s cells=%d"
		% [target_building.is_destroyed(), target_building.destroyed_cell_count()]
	)
	_check(
		"debris_activates",
		city.debris_pool.active_count() > 0,
		"active=%s" % city.debris_pool.active_count()
	)
	city.overdrive_session.end_overdrive()
	city.rampage_session.momentum_meter.reset_run()
	for pressure_tick: int in range(900):
		city.rampage_session.advance(0.75, 0.1)
	_check(
		"pressure_trace_reaches_ready",
		city.rampage_session.momentum_meter.is_ready(),
		"momentum=%.1f" % city.rampage_session.momentum_value()
	)
	await _wait_for_contextual_attack(city)
	city.robot.velocity.x = 0.0
	var overdrive_attack: int = city.robot.request_attack()
	_check(
		"overdrive_activates_from_smash",
		overdrive_attack > 0 and city.overdrive_session.active,
		"attack_id=%d active=%s" % [overdrive_attack, city.overdrive_session.active]
	)
	city.overdrive_session._process(4.0)
	_check(
		"overdrive_restores_modifiers",
		not city.overdrive_session.active
		and is_equal_approx(city.robot.acceleration_multiplier, 1.0),
		"active=%s acceleration=%.2f"
		% [city.overdrive_session.active, city.robot.acceleration_multiplier]
	)
	await _wait_for_contextual_attack(city)
	city.tank.activate(Vector2(1780.0, 600.0), city.robot)
	city.tank.set_physics_process(false)
	var warned: bool = city.tank.begin_telegraph(
		&"shell",
		0.75,
		city.tank.global_position,
		city.robot.global_position
	)
	_check(
		"heavy_warning_reserves",
		warned and city.projectile_root.reservation_count(&"shell") == 1,
		"warned=%s reservations=%d"
		% [warned, city.projectile_root.reservation_count(&"shell")]
	)
	city.tank.cancel_telegraph()
	_check(
		"warning_cancel_is_atomic",
		city.telegraph_presenter.active_count() == 0
		and city.projectile_root.reservation_count(&"shell") == 0,
		"warnings=%d reservations=%d"
		% [
			city.telegraph_presenter.active_count(),
			city.projectile_root.reservation_count(&"shell"),
		]
	)
	var cap_errors: PackedStringArray = RuntimeBudget.validation_errors(city)
	_check("runtime_caps_hold", cap_errors.is_empty(), "errors=%s" % cap_errors)
	var shot_status: String = "SKIP"
	var shot_path: String = ""
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
	else:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://artifacts/city_slice")
		)
		var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check("shot_saved", save_error == OK, "error=%s" % save_error)
		_check(
			"shot_geometry",
			image.get_size() == target_size,
			"size=%s" % image.get_size()
		)
		shot_status = "PASS" if save_error == OK else "FAIL"
		shot_path = SHOT_PATH
	city.robot.receive_damage(DamageEvent.new(
		99901,
		city.tank,
		city.robot.current_health + 1.0,
		&"shell",
		city.robot.global_position
	))
	await process_frame
	_check(
		"defeat_freezes_run",
		city.game_over_active and city.rampage_session.frozen_summary != null,
		"game_over=%s summary=%s"
		% [city.game_over_active, city.rampage_session.frozen_summary != null]
	)
	root.remove_child(city)
	city.queue_free()
	var retry_city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(retry_city)
	await process_frame
	await process_frame
	_check(
		"retry_is_fresh",
		retry_city.score == 0
		and is_zero_approx(retry_city.rampage_session.momentum_value())
		and RuntimeBudget.validation_errors(retry_city).is_empty(),
		"score=%d momentum=%.1f"
		% [retry_city.score, retry_city.rampage_session.momentum_value()]
	)
	_check(
		"frame_budget",
		elapsed_frames <= MAX_FRAMES,
		"frames=%s max=%s" % [elapsed_frames, MAX_FRAMES]
	)
	retry_city.queue_free()
	await process_frame
	# Work around godotengine/godot#76745 in fixed-FPS command-line runs.
	OS.delay_msec(100)
	_finish(shot_status, shot_path)


func _wait_for_contextual_attack(city: CitySlice) -> void:
	if not city.contextual_attacks.is_busy():
		return
	var spec: AttackSpec = city.contextual_attacks.current_spec
	if spec == null:
		return
	await create_timer(
		spec.anticipation_seconds
		+ spec.active_seconds
		+ spec.recovery_seconds
		+ 0.10
	).timeout


func _save_state_shot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/city_slice")
	)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(path))
	_check("shot_saved_%s" % path.get_file(), save_error == OK, "error=%s" % save_error)


func _check(check_name: String, passed: bool, detail: String) -> void:
	checks.append({"name": check_name, "passed": passed, "detail": detail})
	print("[CHECK] %s %s — %s" % ["PASS" if passed else "FAIL", check_name, detail])


func _finish(shot_status: String, shot_path: String) -> void:
	completed = true
	var all_passed: bool = true
	for item: Dictionary in checks:
		if not bool(item["passed"]):
			all_passed = false
	var report: Dictionary = {
		"scenario": "city_slice",
		"result": "PASS" if all_passed else "FAIL",
		"done": completed,
		"headless": DisplayServer.get_name() == "headless",
		"elapsed_frames": elapsed_frames,
		"max_frames": MAX_FRAMES,
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
		"engine": Engine.get_version_info().get("string", "unknown"),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/city_slice"))
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("[SCENARIO-DONE] result=%s" % report["result"])
	quit(0 if all_passed else 1)


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)
