extends SceneTree

const MAX_FRAMES: int = 1200
const REPORT_PATH: String = "res://artifacts/enemy_variety/report.json"
const SHOT_PATH: String = "res://artifacts/enemy_variety/enemy-variety.png"

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
	var exercised: int = 0
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var actor: ProceduralEnemy = city.encounter_runtime.acquire(
			archetype_id,
			Vector2(1320.0, float(profile.spawn_y))
		) as ProceduralEnemy
		var acquired: bool = actor != null
		_check("%s_acquires" % archetype_id, acquired, "family=%s" % profile.family)
		if not acquired:
			continue
		actor.set_physics_process(false)
		var authored_right: bool = bool(profile.get("faces_right", false))
		city.robot.global_position.x = actor.global_position.x + 200.0
		actor._update_facing()
		_check(
			"%s_faces_east" % archetype_id,
			actor.facing == 1 and actor.visual.flip_h == (not authored_right),
			"facing=%d flip=%s authored_right=%s"
			% [actor.facing, actor.visual.flip_h, authored_right]
		)
		city.robot.global_position.x = actor.global_position.x - 200.0
		actor._update_facing()
		_check(
			"%s_faces_west" % archetype_id,
			actor.facing == -1 and actor.visual.flip_h == authored_right,
			"facing=%d flip=%s authored_right=%s"
			% [actor.facing, actor.visual.flip_h, authored_right]
		)
		var before_position: Vector2 = actor.visual.position
		var before_scale: Vector2 = actor.visual.scale
		actor.velocity = Vector2(actor.move_speed, 0.0)
		actor._begin_attack()
		actor._animate_visual(0.17)
		var animated: bool = (
			actor.visual.position != before_position
			or actor.visual.scale != before_scale
			or not is_zero_approx(actor.visual.rotation)
		)
		_check("%s_animates" % archetype_id, animated, "style=%s" % actor.movement_style)
		_check(
			"%s_telegraphs" % archetype_id,
			actor.is_telegraphing(),
			"attack=%s" % actor.attack_style
		)
		actor.cancel_telegraph()
		city.encounter_runtime.release(actor)
		exercised += 1
	_check("all_eight_exercised", exercised == 8, "count=%d" % exercised)
	_check(
		"reservations_clean",
		city.projectile_root.reservation_count() == 0
		and city.telegraph_presenter.active_count() == 0,
		"projectiles=%d telegraphs=%d"
		% [
			city.projectile_root.reservation_count(),
			city.telegraph_presenter.active_count(),
		]
		)
	await _run_balanced_mixed_wave(city)
	city.robot.global_position.x = 1300.0
	city.camera_rig.global_position.x = 1300.0
	city.gameplay_hud.first_run_tutorial.visible = false
	var showcase: Array[Dictionary] = [
		{"id": &"reclaimed_breacher", "trait": &"BRUTAL", "position": Vector2(860.0, 540.0)},
		{"id": &"graft_runner", "trait": &"BLITZ", "position": Vector2(1040.0, 554.0)},
		{"id": &"needle", "trait": &"PHASED", "position": Vector2(1260.0, 175.0)},
		{"id": &"bulwark", "trait": &"PHASED", "position": Vector2(1010.0, 540.0)},
		{"id": &"jackal", "trait": &"BRUTAL", "position": Vector2(1540.0, 554.0)},
		{"id": &"lobber", "trait": &"BLITZ", "position": Vector2(1730.0, 541.0)},
		{"id": &"sapper", "trait": &"PHASED", "position": Vector2(620.0, 541.0)},
		{"id": &"hound", "trait": &"BRUTAL", "position": Vector2(1960.0, 230.0)},
	]
	var showcase_count: int = 0
	for item: Dictionary in showcase:
		var actor: ProceduralEnemy = city.encounter_runtime.acquire(
			item.id,
			item.position,
			&"",
			item.trait
		) as ProceduralEnemy
		if actor != null:
			actor.set_physics_process(false)
			showcase_count += 1
	_check("chaos_showcase_acquires", showcase_count == 8, "count=%d" % showcase_count)
	_check(
		"elite_spawn_impacts_active",
		city.encounter_runtime.elite_spawn_effect_pool.active_count() > 0,
		"active=%d" % city.encounter_runtime.elite_spawn_effect_pool.active_count()
	)
	await process_frame
	await physics_frame
	var shot_status: String = "SKIP"
	var shot_path: String = ""
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
	else:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://artifacts/enemy_variety")
		)
		var error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check("shot_saved", error == OK, "error=%s" % error)
		_check("shot_geometry", image.get_size() == Vector2i(1280, 720), "size=%s" % image.get_size())
		shot_status = "PASS" if error == OK else "FAIL"
		shot_path = SHOT_PATH
	var cap_errors: PackedStringArray = RuntimeBudget.validation_errors(city)
	_check("runtime_caps_hold", cap_errors.is_empty(), "errors=%s" % cap_errors)
	_check("frame_budget", elapsed_frames <= MAX_FRAMES, "frames=%d" % elapsed_frames)
	city.queue_free()
	await process_frame
	# Work around godotengine/godot#76745 in fixed-FPS command-line runs.
	OS.delay_msec(100)
	_finish(shot_status, shot_path)


func _run_balanced_mixed_wave(city: CitySlice) -> void:
	city.encounter_runtime.release_all()
	city.robot.global_position.x = 820.0
	city.robot.set_durability_bonus(400.0)
	city.robot.current_health = city.robot.max_health
	var loadout_health: float = city.robot.max_health
	var wave: Array[Dictionary] = [
		{"id": &"jackal", "trait": &"BLITZ", "position": Vector2(1320.0, 554.0)},
		{"id": &"needle", "trait": &"BRUTAL", "position": Vector2(1250.0, 175.0)},
		{"id": &"bulwark", "trait": &"PHASED", "position": Vector2(450.0, 540.0)},
		{"id": &"lobber", "trait": &"BLITZ", "position": Vector2(540.0, 541.0)},
		{"id": &"sapper", "trait": &"BRUTAL", "position": Vector2(1060.0, 541.0)},
		{"id": &"sapper", "trait": &"PHASED", "position": Vector2(1150.0, 541.0)},
	]
	var actors: Array[ProceduralEnemy] = []
	var families: Dictionary[StringName, bool] = {}
	for item: Dictionary in wave:
		var actor: ProceduralEnemy = city.encounter_runtime.acquire(
			item.id,
			item.position,
			&"",
			item.trait
		) as ProceduralEnemy
		if actor != null:
			actors.append(actor)
			families[actor.family] = true
	_check("mixed_wave_acquires", actors.size() == 6, "count=%d" % actors.size())
	_check("mixed_wave_has_three_families", families.size() == 3, "count=%d" % families.size())
	_check("late_loadout_has_max_armor", loadout_health == 1200.0, "health=%.1f" % loadout_health)
	for frame_index: int in range(360):
		if frame_index == 24:
			_check("late_loadout_dodge_starts", city.robot._start_dodge(), "frame=%d" % frame_index)
		await physics_frame
	var completed_attacks: int = 0
	for actor: ProceduralEnemy in actors:
		completed_attacks += 1 if actor._attack_sequence > 0 else 0
	_check(
		"mixed_wave_all_attack",
		completed_attacks == actors.size(),
		"completed=%d count=%d" % [completed_attacks, actors.size()]
	)
	_check(
		"mixed_wave_pressures_max_loadout_without_burst_defeat",
		city.robot.current_health > 0.0 and city.robot.current_health <= loadout_health - 100.0,
		"health=%.1f lost=%.1f" % [
			city.robot.current_health,
			loadout_health - city.robot.current_health,
		]
	)
	city.encounter_runtime.release_all()
	city.projectile_root.release_all()
	_check(
		"mixed_wave_releases_cleanly",
		city.projectile_root.reservation_count() == 0
		and city.telegraph_presenter.active_count() == 0,
		"projectiles=%d telegraphs=%d"
		% [
			city.projectile_root.reservation_count(),
			city.telegraph_presenter.active_count(),
		]
	)


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
		"scenario": "enemy_variety",
		"result": "PASS" if all_passed else "FAIL",
		"done": completed,
		"headless": DisplayServer.get_name() == "headless",
		"elapsed_frames": elapsed_frames,
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
	}
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/enemy_variety")
	)
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("[ENEMY-VARIETY-DONE] result=%s" % report.result)
	quit(0 if all_passed else 1)
