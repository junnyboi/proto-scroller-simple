extends SceneTree

const ARTIFACT_DIR: String = "res://artifacts/project_choir_enemies"
const HYBRID_IDS: Array[StringName] = [
	&"reclaimed_breacher", &"graft_runner",
]

var checks: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var portrait: bool = OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1"
	var target_size: Vector2i = Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var gallery: Control = _build_gallery(target_size, portrait)
	root.add_child(gallery)
	await process_frame
	await RenderingServer.frame_post_draw
	var orientation: String = "portrait" if portrait else "landscape"
	var shot_path: String = "%s/hybrid-gallery-%s.png" % [ARTIFACT_DIR, orientation]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(shot_path))
	_check("shot_saved", error == OK, "error=%s" % error)
	_check("shot_geometry", image.get_size() == target_size, "size=%s" % image.get_size())
	_check("two_hybrid_cards", _count_cards(gallery) == 2, "count=%d" % _count_cards(gallery))
	var report: Dictionary = {
		"done": true,
		"result": "PASS" if _all_passed() else "FAIL",
		"orientation": orientation,
		"hybrids": HYBRID_IDS.map(func(id: StringName) -> String: return String(id)),
		"checks": checks,
		"shot": shot_path,
	}
	var report_path: String = "%s/report-%s.json" % [ARTIFACT_DIR, orientation]
	var report_file: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(report_path),
		FileAccess.WRITE
	)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "  "))
		report_file.close()
	gallery.queue_free()
	await process_frame
	OS.delay_msec(100)
	quit(0 if _all_passed() else 1)


func _build_gallery(target_size: Vector2i, portrait: bool) -> Control:
	var gallery: Control = Control.new()
	gallery.name = "ProjectChoirEnemyGallery"
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil: ColorRect = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.015, 0.025, 0.045, 0.88)
	gallery.add_child(veil)
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.position = Vector2(28.0, 24.0)
	content.size = Vector2(target_size) - Vector2(56.0, 48.0)
	content.add_theme_constant_override("separation", 16)
	gallery.add_child(content)
	var title: Label = Label.new()
	title.text = "PROJECT CHOIR // BIOLOGICAL THREAT INDEX"
	title.add_theme_color_override("font_color", Color("8df4f1"))
	title.add_theme_font_size_override("font_size", 28 if portrait else 32)
	content.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "RECOVERED SILHOUETTES // TWO ACTIVE WARFORMS"
	subtitle.add_theme_color_override("font_color", Color("a8b8c8"))
	subtitle.add_theme_font_size_override("font_size", 16)
	content.add_child(subtitle)
	var grid: GridContainer = GridContainer.new()
	grid.name = "HybridGrid"
	grid.columns = 2 if portrait else 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for hybrid_id: StringName in HYBRID_IDS:
		grid.add_child(_hybrid_card(hybrid_id, portrait))
	return gallery


func _hybrid_card(hybrid_id: StringName, portrait: bool) -> PanelContainer:
	var profile: Dictionary = EnemyArchetypeCatalog.profile(hybrid_id)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(320.0, 338.0) if portrait else Vector2(390.0, 260.0)
	card.add_theme_stylebox_override("panel", _card_style())
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	card.add_child(stack)
	var sprite: TextureRect = TextureRect.new()
	sprite.texture = load(String(profile.texture)) as Texture2D
	sprite.custom_minimum_size = Vector2(0.0, 260.0 if portrait else 180.0)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(sprite)
	var name_label: Label = Label.new()
	name_label.text = String(profile.display_name)
	name_label.add_theme_color_override("font_color", Color("d9fff9"))
	name_label.add_theme_font_size_override("font_size", 19 if portrait else 17)
	stack.add_child(name_label)
	var family_label: Label = Label.new()
	family_label.text = "%s FAMILY // THREAT %02d" % [
		String(profile.family).to_upper(),
		int(profile.threat),
	]
	family_label.add_theme_color_override("font_color", Color("7ec8ce"))
	family_label.add_theme_font_size_override("font_size", 13)
	stack.add_child(family_label)
	return card


func _card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.05, 0.075, 0.94)
	style.border_color = Color("28747a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10.0)
	return style


func _count_cards(gallery: Control) -> int:
	var grid: GridContainer = gallery.get_node("Content/HybridGrid") as GridContainer
	return grid.get_child_count()


func _check(name: String, passed: bool, detail: String) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	print("[CHECK] %s %s — %s" % ["PASS" if passed else "FAIL", name, detail])


func _all_passed() -> bool:
	for check: Dictionary in checks:
		if not bool(check.passed):
			return false
	return true
