extends SceneTree

const MAX_FRAMES: int = 420
const TRANSFORMER: CatalystProfile = preload(
	"res://resources/catalysts/transformer.tres"
)

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
		_check("frame_watchdog", false, "frames=%d" % elapsed_frames)
		_finish("SKIP", "")


func _run() -> void:
	var portrait: bool = OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1"
	var expected_size: Vector2i = Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	root.get_window().content_scale_size = expected_size
	root.size = expected_size
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	_check("city_scene_loads", scene != null, "loaded=%s" % [scene != null])
	if scene == null:
		_finish("SKIP", "")
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	city.urban_siege.stop_run()
	city.encounter_runtime.release_all()
	city.gameplay_hud.first_run_tutorial.visible = false
	city.robot.current_health = 600.0
	city.robot.health_changed.emit(city.robot.current_health, city.robot.max_health)
	city.robot.global_position.x = 760.0
	city.camera_rig.global_position.x = 900.0
	var catalysts: CatalystRuntime = city.urban_siege.catalysts
	var transformer: Catalyst2D = catalysts.activate(
		0,
		TRANSFORMER,
		Vector2(1040.0, CitySlice.LAND_VISUAL_BASELINE_Y)
	)
	_check("transformer_activates", transformer != null, "active=%s" % [transformer != null])
	if transformer == null:
		_finish("SKIP", "")
		return
	_check(
		"transformer_is_power_box",
		transformer.get_meta(&"street_destructible_kind") == &"power_box",
		"kind=%s" % transformer.get_meta(&"street_destructible_kind")
	)
	var event: DamageEvent = DamageEvent.new(
		7001,
		city.robot,
		100.0,
		&"ground_smash",
		transformer.global_position,
		Vector2.RIGHT,
		520.0
	)
	_check(
		"power_box_accepts_damage",
		transformer.receive_damage(event),
		"spent=%s" % transformer.spent
	)
	_check("power_box_is_destroyed", transformer.spent, "health=%.1f" % transformer.current_health)
	_check(
		"one_repair_pickup_spawns",
		catalysts.active_repair_pickup_count() == 1,
		"active=%d" % catalysts.active_repair_pickup_count()
	)
	var pickup: ChassisRepairPickup2D = catalysts.repair_pickups[0]
	_check("repair_pickup_is_visible", pickup.active and pickup.visible, "active=%s" % pickup.active)
	for frame_index: int in range(8):
		await process_frame
	var mode_name: String = "portrait" if portrait else "landscape"
	var shot_path: String = "res://artifacts/power_box_repair/power-box-%s.png" % mode_name
	var report_path: String = "res://artifacts/power_box_repair/report-%s.json" % mode_name
	var shot_status: String = "SKIP"
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
	else:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			"res://artifacts/power_box_repair"
		))
		var error: Error = image.save_png(ProjectSettings.globalize_path(shot_path))
		_check("shot_saved", error == OK, "error=%s" % error)
		_check("shot_geometry", image.get_size() == expected_size, "size=%s" % image.get_size())
		shot_status = "PASS" if error == OK else "FAIL"
	var finishing_event: DamageEvent = DamageEvent.new(
		7002,
		city.robot,
		1.0,
		&"ground_smash",
		transformer.global_position,
		Vector2.RIGHT,
		520.0
	)
	var score_before_finish: int = city.rampage_session.current_score()
	var debris_before_finish: int = city.debris_pool.active_count()
	_check(
		"second_hit_starts_electrical_discharge",
		transformer.receive_damage(finishing_event),
		"discharging=%s" % transformer.discharging
	)
	_check(
		"spent_shell_holds_during_discharge",
		transformer.discharging and transformer.visual.visible,
		"visible=%s" % transformer.visual.visible
	)
	await create_timer(Catalyst2D.OBLITERATION_DELAY_SECONDS + 0.02).timeout
	_check(
		"spent_shell_is_removed",
		transformer.is_fully_destroyed and not transformer.visual.visible,
		"visible=%s layer=%d" % [transformer.visual.visible, transformer.collision_layer]
	)
	_check(
		"heavy_scrap_burst_uses_six_pooled_pieces",
		city.debris_pool.active_count() - debris_before_finish
		== CatalystRuntime.POWER_BOX_SCRAP_PIECES,
		"pieces=%d" % catalysts.power_box_scrap_piece_count
	)
	_check(
		"second_hit_awards_small_score_bonus",
		catalysts.power_box_finish_score_count == CatalystRuntime.POWER_BOX_FINISH_POINTS
		and city.rampage_session.current_score() - score_before_finish
		>= CatalystRuntime.POWER_BOX_FINISH_POINTS,
		"awarded=%d" % catalysts.power_box_finish_score_count
	)
	_check(
		"repair_pickup_survives_second_hit",
		catalysts.active_repair_pickup_count() == 1,
		"active=%d" % catalysts.active_repair_pickup_count()
	)
	_check(
		"pickup_collects",
		pickup.try_collect(city.robot),
		"health=%.1f" % city.robot.current_health
	)
	_check(
		"pickup_repairs_five_percent",
		is_equal_approx(city.robot.current_health, 640.0),
		"health=%.1f" % city.robot.current_health
	)
	_check(
		"pickup_returns_to_pool",
		catalysts.active_repair_pickup_count() == 0,
		"active=%d" % catalysts.active_repair_pickup_count()
	)
	var cap_errors: PackedStringArray = RuntimeBudget.validation_errors(city)
	_check("runtime_caps_hold", cap_errors.is_empty(), "errors=%s" % cap_errors)
	_check("frame_budget", elapsed_frames <= MAX_FRAMES, "frames=%d" % elapsed_frames)
	city.queue_free()
	await process_frame
	OS.delay_msec(100)
	_finish(shot_status, shot_path, report_path, mode_name)


func _check(check_name: String, passed: bool, detail: String) -> void:
	checks.append({"name": check_name, "passed": passed, "detail": detail})
	print("[CHECK] %s %s — %s" % ["PASS" if passed else "FAIL", check_name, detail])


func _finish(
	shot_status: String,
	shot_path: String,
	report_path: String = "res://artifacts/power_box_repair/report-landscape.json",
	mode_name: String = "landscape"
) -> void:
	completed = true
	var all_passed: bool = true
	for item: Dictionary in checks:
		if not bool(item.passed):
			all_passed = false
	var report: Dictionary = {
		"scenario": "power_box_repair",
		"mode": mode_name,
		"result": "PASS" if all_passed else "FAIL",
		"done": completed,
		"headless": DisplayServer.get_name() == "headless",
		"elapsed_frames": elapsed_frames,
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
		"res://artifacts/power_box_repair"
	))
	var report_file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("[POWER-BOX-REPAIR-DONE] result=%s mode=%s" % [report.result, mode_name])
	quit(0 if all_passed else 1)
