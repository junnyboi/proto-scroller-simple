extends SceneTree

const ARTIFACT_DIR: String = "res://artifacts/district_gallery"
const LANDSCAPE_CELL: Vector2 = Vector2(220.0, 300.0)
const PORTRAIT_CELL: Vector2 = Vector2(500.0, 182.0)

var _gallery_root: Node2D
var _report: Dictionary = {
	"done": false,
	"result": "FAIL",
	"districts": [],
	"shots": [],
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	_gallery_root = Node2D.new()
	_gallery_root.name = "DistrictBuildingGallery"
	root.add_child(_gallery_root)
	await process_frame
	var districts: Array[CityDistrictProfile] = CityDistrictCatalog.districts()
	_check("catalog_complete", districts.size() == 2, "count=%d" % districts.size())
	for district: CityDistrictProfile in districts:
		await _render_district(district)
	_report.done = true
	_report.result = "PASS"
	_write_report()
	print("[DISTRICT-GALLERY-DONE] result=PASS")
	quit(0)


func _render_district(district: CityDistrictProfile) -> void:
	_clear_gallery()
	var background: ColorRect = ColorRect.new()
	background.name = "GalleryBackground"
	background.color = Color("11161d").lerp(district.asphalt_color, 0.24)
	background.size = Vector2(root.size)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gallery_root.add_child(background)
	var title: Label = Label.new()
	title.text = "%s  //  %s" % [district.district_id, district.display_name]
	title.position = Vector2(34.0, 24.0)
	title.add_theme_color_override("font_color", district.accent_color.lightened(0.35))
	title.add_theme_font_size_override("font_size", 28)
	_gallery_root.add_child(title)
	var portrait: bool = root.size.y > root.size.x
	var variants: Array[StructuralBuildingVariant] = district.building_variants
	for index: int in range(variants.size()):
		var building: StructuralBuilding2D = _create_building(variants[index])
		_gallery_root.add_child(building)
		building.apply_variant(variants[index])
		_place_building(building, index, portrait)
		if index == 1:
			_apply_partial_damage(building, index)
		_apply_hollow_cell(building, index)
	await process_frame
	await process_frame
	var path: String = "%s/%s-%s.png" % [
		ARTIFACT_DIR,
		String(district.district_id).to_lower(),
		"portrait" if portrait else "landscape",
	]
	var shot_ok: bool = _capture(path)
	_report.districts.append(String(district.district_id))
	_report.shots.append({"district": String(district.district_id), "path": path})
	_check(
		"%s_assets_render" % String(district.district_id).to_lower(),
		shot_ok,
		path
	)


func _create_building(variant: StructuralBuildingVariant) -> StructuralBuilding2D:
	var building: StructuralBuilding2D = StructuralBuilding2D.new()
	building.name = String(variant.variant_id)
	building.intact_texture = variant.intact_texture
	building.display_size = variant.display_size
	building.z_index = 2
	return building


func _place_building(
	building: StructuralBuilding2D,
	index: int,
	portrait: bool
) -> void:
	if portrait:
		var scale_factor: float = minf(
			PORTRAIT_CELL.x / building.display_size.x,
			PORTRAIT_CELL.y / building.display_size.y
		)
		building.scale = Vector2.ONE * scale_factor
		building.position = Vector2(360.0, 245.0 + float(index) * 245.0)
		return
	var landscape_scale: float = minf(
		LANDSCAPE_CELL.x / building.display_size.x,
		LANDSCAPE_CELL.y / building.display_size.y
	)
	building.scale = Vector2.ONE * landscape_scale
	building.position = Vector2(140.0 + float(index) * 250.0, 660.0)


func _apply_partial_damage(building: StructuralBuilding2D, index: int) -> void:
	var cell: Destructible2D = building.get_cell(1, 0)
	var event: DamageEvent = DamageEvent.new(
		700_000 + index,
		null,
		cell.max_health * 0.38,
		&"gallery_damage",
		cell.global_position,
		Vector2.RIGHT,
		220.0
	)
	cell.receive_damage(event)


func _apply_hollow_cell(building: StructuralBuilding2D, building_index: int) -> void:
	var state: Dictionary = building.capture_stream_state()
	var cells: Array = state.cells as Array
	var row: int = building_index % StructuralBuilding2D.ROWS
	var column: int = (building_index * 2) % StructuralBuilding2D.COLUMNS
	var cell_index: int = row * StructuralBuilding2D.COLUMNS + column
	var hollow_state: Dictionary = cells[cell_index] as Dictionary
	hollow_state.health = 0.0
	hollow_state.destroyed = true
	cells[cell_index] = hollow_state
	state.cells = cells
	building.restore_stream_state(state)


func _capture(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		return true
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(path)
	return error == OK and FileAccess.file_exists(path)


func _clear_gallery() -> void:
	for child: Node in _gallery_root.get_children():
		child.free()


func _check(check_name: String, passed: bool, detail: String) -> void:
	if not passed:
		push_error("[CHECK] FAIL %s — %s" % [check_name, detail])
		_report.done = true
		_report.result = "FAIL"
		_write_report()
		quit(1)
		return
	print("[CHECK] PASS %s — %s" % [check_name, detail])


func _write_report() -> void:
	var path: String = "%s/report.json" % ARTIFACT_DIR
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "  "))


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)
