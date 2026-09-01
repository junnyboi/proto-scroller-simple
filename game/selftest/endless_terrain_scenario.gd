extends SceneTree

const MAX_FRAMES: int = 900
const REPORT_PATH: String = "res://artifacts/endless_terrain/report.json"
const SHOT_PATH: String = "res://artifacts/endless_terrain/endless-terrain.png"

var checks: Array[Dictionary] = []
var district_trace: Array[Dictionary] = []
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
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var packed: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	_check("city_scene_loads", packed != null, "loaded=%s" % [packed != null])
	if packed == null:
		_finish("SKIP", "")
		return
	var city: CitySlice = packed.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	await physics_frame
	city.urban_siege.stop_run()
	city.gameplay_hud.first_run_tutorial.visible = false
	city.encounter_runtime.release_all()
	var catalog_digest: String = _catalog_digest()
	var baseline_nodes: int = RuntimeBudget.snapshot(city).node_count
	var origin_cell: Destructible2D = city.building.get_cell(0, 1)
	origin_cell.receive_damage(_fatal_event(city, origin_cell, 51_001))
	city.car.current_health = 1.0
	city.car.receive_damage(_fatal_event(city, city.car, 51_002))
	for logical_index: int in range(0, 49):
		_move_to_logical_chunk(city, logical_index)
		if logical_index == 48 or _is_roster_sample(logical_index):
			var blueprint: CityChunkBlueprint = CityChunkBlueprint.generate(
				city.world_stream.run_seed,
				logical_index
			)
			var live_building: StructuralBuilding2D = city.building
			var live_sprite: Sprite2D = live_building.get_cell(0, 0).get_node(
				^"IntactVisual"
			) as Sprite2D
			district_trace.append({
				"chunk": logical_index,
				"district": blueprint.district_id,
				"variant": blueprint.building_variant_id,
				"expected_texture": blueprint.building_variant.intact_texture.resource_path,
				"live_variant": live_building.current_variant_id(),
				"live_texture": live_sprite.texture.resource_path,
				"roster_sample": _is_roster_sample(logical_index),
			})
	_check(
		"six_chunk_window",
		city.world_stream.active_chunk_count() == CityWorldStream.CHUNK_CAPACITY,
		"chunks=%d" % city.world_stream.active_chunk_count()
	)
	_check(
		"traversal_exceeds_fixed_map",
		city.world_stream.maximum_visited_chunk >= 48,
		"max_chunk=%d" % city.world_stream.maximum_visited_chunk
	)
	var culled_chunk_count: int = 0
	for chunk: CityStreetChunk in city.world_stream.chunks:
		if chunk.culled:
			culled_chunk_count += 1
	_check(
		"rear_frontier_culls_discarded_chunks",
		culled_chunk_count > 0
		and is_equal_approx(
			city.world_stream.rear_frontier_logical_x,
			city.world_stream.furthest_progress_logical_x
			- CityWorldStream.LEFT_RETENTION_DISTANCE
		),
		"culled=%d frontier=%.1f furthest=%.1f"
		% [
			culled_chunk_count,
			city.world_stream.rear_frontier_logical_x,
			city.world_stream.furthest_progress_logical_x,
		]
	)
	var traced_districts: Dictionary[StringName, bool] = {}
	var traced_variants: Dictionary[StringName, bool] = {}
	var district_rosters: Dictionary[StringName, Dictionary] = {}
	var live_facade_mapping_valid: bool = true
	for trace_item: Dictionary in district_trace:
		var district_id: StringName = StringName(trace_item.district)
		traced_districts[district_id] = true
		live_facade_mapping_valid = (
			live_facade_mapping_valid
			and trace_item.variant == trace_item.live_variant
			and trace_item.expected_texture == trace_item.live_texture
		)
		if bool(trace_item.roster_sample):
			var district_roster: Dictionary = district_rosters.get(district_id, {})
			district_roster[StringName(trace_item.variant)] = true
			district_rosters[district_id] = district_roster
			traced_variants[StringName(trace_item.variant)] = true
	_check(
		"all_spatial_districts_traced",
		traced_districts.size() == CityDistrictCatalog.DISTRICT_COUNT,
		"districts=%s digest=%s" % [traced_districts.keys(), catalog_digest]
	)
	var complete_district_rosters: bool = true
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		var district_roster: Dictionary = district_rosters.get(
			district.district_id,
			{}
		)
		complete_district_rosters = (
			complete_district_rosters
			and district_roster.size() == CityDistrictCatalog.VARIANTS_PER_DISTRICT
		)
	_check(
		"all_twenty_five_live_facades_mapped",
		complete_district_rosters
		and traced_variants.size() == CityDistrictCatalog.BUILDING_VARIANT_COUNT
		and live_facade_mapping_valid,
		"variants=%d districts=%d live_mapping=%s"
		% [
			traced_variants.size(),
			district_rosters.size(),
			live_facade_mapping_valid,
		]
	)
	_check(
		"floating_origin_applied",
		city.world_stream.floating_origin.shift_count > 0,
		"shifts=%d origin_chunk=%d"
		% [
			city.world_stream.floating_origin.shift_count,
			city.world_stream.floating_origin.origin_chunk,
		]
	)
	_check(
		"no_stream_growth",
		RuntimeBudget.snapshot(city).node_count == baseline_nodes
		and city.world_stream.post_warm_creation_count == 0
		and city.streamed_destructibles.post_warm_creation_count == 0,
		"nodes=%d baseline=%d terrain_creations=%d content_creations=%d"
		% [
			RuntimeBudget.snapshot(city).node_count,
			baseline_nodes,
			city.world_stream.post_warm_creation_count,
			city.streamed_destructibles.post_warm_creation_count,
		]
	)
	var origin_building_state: Dictionary = city.streamed_destructibles.ledger.restore(
		city.streamed_destructibles.ledger.make_object_id(0, &"building")
	)
	var origin_car_state: Dictionary = city.streamed_destructibles.ledger.restore(
		city.streamed_destructibles.ledger.make_object_id(0, &"car")
	)
	var origin_cells: Array = origin_building_state.get("cells", []) as Array
	var origin_cell_destroyed: bool = (
		not origin_cells.is_empty() and bool((origin_cells[3] as Dictionary).destroyed)
	)
	_check(
		"culled_destruction_state_persisted",
		origin_cell_destroyed and bool(origin_car_state.get("broken", false)),
		"cell=%s car=%s mutations=%d"
		% [
			origin_cell_destroyed,
			bool(origin_car_state.get("broken", false)),
			city.streamed_destructibles.mutation_count(),
		]
	)
	var residential_profile: DistrictPressureProfile = DistrictPressureCatalog.authored_profile(
		&"RESIDENTIAL"
	)
	_check(
		"residential_pressure_is_authored",
		city.world_stream.progression_tier() == CityWorldStream.MAX_PROGRESSION_TIER
		and residential_profile.district_id == &"RESIDENTIAL"
		and residential_profile.live_threat_ceiling == 11,
		"distance_tier=%d effective=%s threat_ceiling=%d max_chunk=%d"
		% [
			city.world_stream.progression_tier(),
			residential_profile.district_id,
			residential_profile.live_threat_ceiling,
			city.world_stream.maximum_visited_chunk,
		]
	)
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(40)
		+ CityWorldStream.CHUNK_WIDTH * 0.48
	)
	city.world_stream.advance_stream()
	city.camera_rig.global_position = Vector2(city.robot.global_position.x, 360.0)
	city.camera_rig.follow_speed = 10000.0
	city.camera_rig.reset_after_origin_shift()
	var enemy_kinds: Array[StringName] = [&"soldier", &"bulwark", &"lobber", &"helicopter"]
	var enemy_offsets: Array[Vector2] = [
		Vector2(-460.0, 542.5 - city.robot.global_position.y),
		Vector2(-280.0, 542.5 - city.robot.global_position.y),
		Vector2(330.0, 542.5 - city.robot.global_position.y),
		Vector2(500.0, 180.0 - city.robot.global_position.y),
	]
	for enemy_index: int in range(enemy_kinds.size()):
		var enemy: EnemyActor2D = city.encounter_runtime.acquire(
			enemy_kinds[enemy_index],
			city.robot.global_position + enemy_offsets[enemy_index]
		)
		if enemy != null:
			enemy.set_physics_process(false)
	for settle_frame: int in range(6):
		await physics_frame
		city.camera_rig._physics_process(1.0 / 60.0)
	var spawn_position: Vector2 = city.encounter_runtime.resolve_spawn_position(
		Vector2(0.0, 542.5),
		&"AHEAD"
	)
	_check(
		"camera_relative_spawns",
		spawn_position.x > city.robot.global_position.x,
		"robot_x=%.1f spawn_x=%.1f" % [city.robot.global_position.x, spawn_position.x]
	)
	_check(
		"origin_landmarks_culled",
		not city.landmark_root.visible
		and city.landmark_root.process_mode == Node.PROCESS_MODE_DISABLED,
		"visible=%s mode=%d" % [city.landmark_root.visible, city.landmark_root.process_mode]
	)
	_check(
		"runtime_caps_hold",
		RuntimeBudget.validation_errors(city).is_empty(),
		"errors=%s" % RuntimeBudget.validation_errors(city)
	)
	var shot_status: String = "SKIP"
	var shot_path: String = ""
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
	else:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://artifacts/endless_terrain")
		)
		var error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check("shot_saved", error == OK, "error=%d" % error)
		_check("shot_geometry", image.get_size() == target_size, "size=%s" % image.get_size())
		shot_status = "PASS" if error == OK else "FAIL"
		shot_path = SHOT_PATH
	city.queue_free()
	await process_frame
	# Work around godotengine/godot#76745 in fixed-FPS command-line runs.
	OS.delay_msec(100)
	_finish(shot_status, shot_path)


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)


func _move_to_logical_chunk(city: CitySlice, logical_index: int) -> void:
	_unlock_districts_through(city.world_stream, logical_index)
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(logical_index)
		+ CityWorldStream.CHUNK_WIDTH * 0.5
	)
	city.world_stream.advance_stream()


func _unlock_districts_through(stream: CityWorldStream, logical_index: int) -> void:
	var target_district_index: int = CityDistrictCatalog.district_index_for_chunk(
		logical_index
	)
	while stream.unlocked_district_index < target_district_index:
		var district: CityDistrictProfile = CityDistrictCatalog.districts()[
			stream.unlocked_district_index
		]
		stream.current_district_id = district.district_id
		for encounter_index: int in range(
			CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT
		):
			var encounter_chunk: int = district.start_chunk + encounter_index
			var variant: StructuralBuildingVariant = CityDistrictCatalog.variant_for_chunk(
				stream.run_seed,
				encounter_chunk
			)
			var building_value: StructuralBuilding2D = StructuralBuilding2D.new()
			building_value.set_meta(&"district_id", district.district_id)
			building_value.set_meta(&"district_index", district.district_index)
			building_value.set_meta(&"building_variant_id", variant.variant_id)
			building_value.set_meta(&"logical_chunk", encounter_chunk)
			stream.report_building_cleared(building_value)
			building_value.free()


func _is_roster_sample(logical_index: int) -> bool:
	if logical_index < 0:
		return false
	var district: CityDistrictProfile = CityDistrictCatalog.district_for_chunk(logical_index)
	return (
		logical_index >= district.start_chunk
		and logical_index
		< district.start_chunk + CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT
	)


func _fatal_event(city: CitySlice, target: Node2D, attack_id: int) -> DamageEvent:
	var event: DamageEvent = DamageEvent.new(
		attack_id,
		city.robot,
		10_000.0,
		&"jab_cross"
	)
	event.hit_position = target.global_position
	event.direction = Vector2.RIGHT
	event.impulse_per_mass = 900.0
	return event


func _catalog_digest() -> String:
	var entries: PackedStringArray = PackedStringArray()
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant: StructuralBuildingVariant in district.building_variants:
			entries.append(
				"%s:%s:%s"
				% [district.district_id, variant.variant_id, variant.intact_texture.resource_path]
			)
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update("|".join(entries).to_utf8_buffer())
	return context.finish().hex_encode()


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
		"scenario": "endless_terrain",
		"result": "PASS" if all_passed else "FAIL",
		"done": completed,
		"headless": DisplayServer.get_name() == "headless",
		"elapsed_frames": elapsed_frames,
		"max_frames": MAX_FRAMES,
		"catalog_digest": _catalog_digest(),
		"district_trace": district_trace,
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
		"engine": Engine.get_version_info().get("string", "unknown"),
	}
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/endless_terrain")
	)
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("[SCENARIO-DONE] result=%s" % report.result)
	quit(0 if all_passed else 1)
