extends SceneTree

const MAX_FRAMES: int = 720
const REPORT_PATH: String = "res://artifacts/street_volatility/report.json"
const SHOT_PATH: String = "res://artifacts/street_volatility/street-volatility.png"

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
	root.get_window().content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
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
	city.robot.global_position.x = 1300.0
	city.camera_rig.global_position.x = 1300.0
	city.gameplay_hud.first_run_tutorial.visible = false
	city.robot.current_health = city.robot.max_health
	var enemies: Array[Dictionary] = [
		{"id": &"lobber", "position": Vector2(1040.0, 542.0)},
		{"id": &"sapper", "position": Vector2(1160.0, 541.0)},
		{"id": &"jackal", "position": Vector2(1490.0, 554.0)},
		{"id": &"hound", "position": Vector2(1660.0, 230.0)},
	]
	var enemy_count: int = 0
	for item: Dictionary in enemies:
		var enemy: ProceduralEnemy = city.encounter_runtime.acquire(
			item.id,
			item.position
		) as ProceduralEnemy
		if enemy != null:
			enemy.set_physics_process(false)
			enemy_count += 1
	_check("mixed_enemies_present", enemy_count == enemies.size(), "count=%d" % enemy_count)
	var placements: Array[Dictionary] = [
		{
			"id": &"skybridge",
			"position": Vector2(1070.0, CitySlice.LAND_VISUAL_BASELINE_Y),
			"facing": 1,
			"source": true,
		},
		{
			"id": &"flooded_lane",
			"position": Vector2(1230.0, CitySlice.LAND_VISUAL_BASELINE_Y),
			"facing": 1,
			"source": false,
		},
		{
			"id": &"metro_car",
			"position": Vector2(1510.0, CitySlice.LAND_VISUAL_BASELINE_Y),
			"facing": -1,
			"source": true,
		},
		{
			"id": &"ammo_convoy",
			"position": Vector2(1670.0, CitySlice.LAND_VISUAL_BASELINE_Y),
			"facing": -1,
			"source": false,
		},
	]
	var hazards: Array[EnvironmentalHazard2D] = []
	var sources: Array[EnvironmentalHazard2D] = []
	for item: Dictionary in placements:
		var hazard: EnvironmentalHazard2D = city.urban_siege.hazards.activate(
			item.id,
			item.position,
			item.facing,
			false
		)
		_check("%s_acquires" % item.id, hazard != null, "active=%s" % [hazard != null])
		if hazard == null:
			continue
		hazards.append(hazard)
		if bool(item.source):
			sources.append(hazard)
	for source_index: int in range(sources.size()):
		var source: EnvironmentalHazard2D = sources[source_index]
		source.receive_damage(DamageEvent.new(
			701 + source_index,
			city.robot,
			80.0,
			&"ground_smash",
			source.global_position,
			Vector2(float(source.facing), -0.2),
			520.0
		))
		source._process(float(source.profile.telegraph) + 0.01)
	for hazard: EnvironmentalHazard2D in hazards:
		if hazard.state == EnvironmentalHazard2D.STATE_TELEGRAPH:
			hazard._process(float(hazard.profile.telegraph) + 0.01)
	await physics_frame
	city.destruction_director._physics_process(0.016)
	for frame_index: int in range(12):
		await process_frame
	_check("apex_tier_active", hazards.size() == 4, "count=%d" % hazards.size())
	_check(
		"cross_hazard_chains_fire",
		city.urban_siege.hazards.chain_trigger_count == 2,
		"chains=%d" % city.urban_siege.hazards.chain_trigger_count
	)
	_check(
		"all_hazards_impact",
		city.urban_siege.hazards.impact_count >= 4,
		"impacts=%d" % city.urban_siege.hazards.impact_count
	)
	_check(
		"all_hazard_warnings_sound",
		city.urban_siege.hazards.audio_pool.warning_play_count == 4,
		"warnings=%d" % city.urban_siege.hazards.audio_pool.warning_play_count
	)
	_check(
		"all_primary_impacts_sound",
		city.urban_siege.hazards.audio_pool.impact_play_count >= 4,
		"impacts=%d" % city.urban_siege.hazards.audio_pool.impact_play_count
	)
	_check(
		"both_chain_stingers_sound",
		city.urban_siege.hazards.audio_pool.chain_play_count == 2,
		"chains=%d" % city.urban_siege.hazards.audio_pool.chain_play_count
	)
	_check(
		"hazard_audio_voice_cap_holds",
		city.urban_siege.hazards.audio_pool.active_voice_count()
		<= RuntimeBudget.HAZARD_AUDIO_VOICES,
		"active=%d cap=%d"
		% [
			city.urban_siege.hazards.audio_pool.active_voice_count(),
			RuntimeBudget.HAZARD_AUDIO_VOICES,
		]
	)
	_check(
		"custom_vfx_active",
		city.urban_siege.hazards.vfx_pool.active_count() >= 4,
		"active=%d" % city.urban_siege.hazards.vfx_pool.active_count()
	)
	_check(
		"camera_shake_requested",
		city.camera_rig.impact_velocity.length() > 0.0,
		"velocity=%.2f" % city.camera_rig.impact_velocity.length()
	)
	_check(
		"neutral_hazards_preserve_player",
		city.robot.current_health > 0.0,
		"health=%.1f" % city.robot.current_health
	)
	var shot_status: String = "SKIP"
	var shot_path: String = ""
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
	else:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			"res://artifacts/street_volatility"
		))
		var error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check("shot_saved", error == OK, "error=%s" % error)
		_check(
			"shot_geometry",
			image.get_size() == Vector2i(1280, 720),
			"size=%s" % image.get_size()
		)
		shot_status = "PASS" if error == OK else "FAIL"
		shot_path = SHOT_PATH
	city.urban_siege.hazards.release_all()
	_check(
		"hazards_release_cleanly",
		city.urban_siege.hazards.active_count() == 0
		and city.urban_siege.hazards.vfx_pool.active_count() == 0,
		"hazards=%d vfx=%d"
		% [
			city.urban_siege.hazards.active_count(),
			city.urban_siege.hazards.vfx_pool.active_count(),
		]
	)
	_check(
		"hazard_audio_releases_cleanly",
		city.urban_siege.hazards.audio_pool.active_voice_count() == 0,
		"active=%d" % city.urban_siege.hazards.audio_pool.active_voice_count()
	)
	var cap_errors: PackedStringArray = RuntimeBudget.validation_errors(city)
	_check("runtime_caps_hold", cap_errors.is_empty(), "errors=%s" % cap_errors)
	_check("frame_budget", elapsed_frames <= MAX_FRAMES, "frames=%d" % elapsed_frames)
	city.queue_free()
	await process_frame
	# Work around godotengine/godot#76745 in fixed-FPS command-line runs.
	OS.delay_msec(100)
	_finish(shot_status, shot_path)


func _check(check_name: String, passed: bool, detail: String) -> void:
	checks.append({"name": check_name, "passed": passed, "detail": detail})
	print("[CHECK] %s %s — %s" % ["PASS" if passed else "FAIL", check_name, detail])


func _finish(shot_status: String, shot_path: String) -> void:
	completed = true
	var all_passed: bool = true
	for item: Dictionary in checks:
		if not bool(item.passed):
			all_passed = false
	var report: Dictionary = {
		"scenario": "street_volatility",
		"result": "PASS" if all_passed else "FAIL",
		"done": completed,
		"headless": DisplayServer.get_name() == "headless",
		"elapsed_frames": elapsed_frames,
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
		"res://artifacts/street_volatility"
	))
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("[STREET-VOLATILITY-DONE] result=%s" % report.result)
	quit(0 if all_passed else 1)
