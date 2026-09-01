extends SceneTree

const ARTIFACT_DIR: String = "res://artifacts/district_ruin_layering"
const MAX_FRAMES: int = 1200
const DISTRICT_CHUNKS: Dictionary[StringName, int] = {
	&"RESIDENTIAL": 12,
	&"ENTERTAINMENT": 24,
	&"MILITARY": 36,
	&"ROYAL": 48,
}

var _elapsed_frames: int = 0
var _completed: bool = false
var _report: Dictionary = {
	"done": false,
	"result": "FAIL",
	"captures": [],
}


func _init() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred("_run")


func _on_process_frame() -> void:
	if _completed:
		return
	_elapsed_frames += 1
	if _elapsed_frames > MAX_FRAMES:
		_fail("District ruin layering scenario exceeded frame watchdog")


func _run() -> void:
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var packed: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	if packed == null:
		_fail("CitySlice failed to load")
		return
	var city: CitySlice = packed.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	await physics_frame
	city.urban_siege.stop_run()
	city.encounter_runtime.release_all()
	city.gameplay_hud.visible = false
	city.gameplay_hud.first_run_tutorial.visible = false
	city.urban_siege.pause_coordinator.release_all()
	paused = false
	city.robot.set_physics_process(false)
	city.camera_rig.set_physics_process(false)
	for district_id: StringName in DISTRICT_CHUNKS:
		print("[DISTRICT-RUIN-LAYERING] district=%s" % district_id)
		var captured: bool = await _capture_district(
			city,
			district_id,
			DISTRICT_CHUNKS[district_id]
		)
		if not captured:
			return
	city.queue_free()
	await process_frame
	_completed = true
	_report.done = true
	_report.result = "PASS"
	_report.elapsed_frames = _elapsed_frames
	_write_report()
	print("[DISTRICT-RUIN-LAYERING-DONE] result=PASS")
	quit(0)


func _capture_district(
	city: CitySlice,
	district_id: StringName,
	logical_chunk: int
) -> bool:
	var district: CityDistrictProfile = CityDistrictCatalog.district_for_chunk(logical_chunk)
	if district.district_id != district_id:
		_fail("District catalog mismatch for %s" % district_id)
		return false
	city.world_stream.current_district_id = district_id
	CityWorldBuilder.transition_environment(city, district_id)
	for building: StructuralBuilding2D in city.streamed_destructibles.buildings:
		building.visible = false
	var showcase: StructuralBuilding2D = city.streamed_destructibles.buildings[0]
	var variant: StructuralBuildingVariant = _smallest_variant(district)
	if not showcase.apply_variant(variant):
		_fail("Failed to apply %s" % variant.variant_id)
		return false
	showcase.set_meta(&"district_id", district_id)
	showcase.set_meta(&"district_index", district.district_index)
	showcase.set_meta(&"logical_chunk", logical_chunk)
	showcase.global_position = Vector2(
		city.robot.global_position.x - 100.0,
		CitySlice.LAND_VISUAL_BASELINE_Y
	)
	showcase.visible = true
	var upper_cell: Destructible2D = showcase.get_cell(2, 0)
	var ground_cell: Destructible2D = showcase.get_cell(0, 1)
	if (
		not _damage_cell(city, upper_cell, logical_chunk * 100 + 1)
		or not _damage_cell(city, ground_cell, logical_chunk * 100 + 2)
		or not upper_cell.is_destroyed()
		or not ground_cell.is_destroyed()
	):
		_fail("Failed to establish two ruin rows for %s" % district_id)
		return false
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	if DisplayServer.get_name() == "headless":
		_fail("Visual playtest requires a rendering display")
		return false
	var orientation: String = "portrait" if root.size.y > root.size.x else "landscape"
	var path: String = "%s/%s-%s.png" % [
		ARTIFACT_DIR,
		String(district_id).to_lower(),
		orientation,
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK or image.get_size() != _target_size():
		_fail("Failed to capture %s" % path)
		return false
	var variant_ids: PackedStringArray = PackedStringArray()
	for catalog_variant: StructuralBuildingVariant in district.building_variants:
		variant_ids.append(String(catalog_variant.variant_id))
	_report.captures.append({
		"district": district_id,
		"logical_chunk": logical_chunk,
		"variant": variant.variant_id,
		"catalog_variants": variant_ids,
		"orientation": orientation,
		"path": path,
	})
	return true


func _damage_cell(city: CitySlice, cell: Destructible2D, attack_id: int) -> bool:
	var event: DamageEvent = DamageEvent.new(
		attack_id,
		city.robot,
		10_000.0,
		&"ground_smash",
		cell.global_position,
		Vector2.RIGHT,
		900.0
	)
	return cell.receive_damage(event)


func _smallest_variant(district: CityDistrictProfile) -> StructuralBuildingVariant:
	var smallest: StructuralBuildingVariant = district.building_variants[0]
	var smallest_area: float = smallest.display_size.x * smallest.display_size.y
	for candidate: StructuralBuildingVariant in district.building_variants:
		var candidate_area: float = candidate.display_size.x * candidate.display_size.y
		if candidate_area < smallest_area:
			smallest = candidate
			smallest_area = candidate_area
	return smallest


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var file: FileAccess = FileAccess.open(
		"%s/report.json" % ARTIFACT_DIR,
		FileAccess.WRITE
	)
	if file != null:
		file.store_string(JSON.stringify(_report, "  "))


func _fail(message: String) -> void:
	push_error(message)
	_completed = true
	_report.done = true
	_report.result = "FAIL"
	_report.error = message
	_report.elapsed_frames = _elapsed_frames
	_write_report()
	quit(1)
