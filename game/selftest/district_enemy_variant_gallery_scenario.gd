extends SceneTree

const ARTIFACT_DIR: String = "res://artifacts/district_enemy_variants"
const DISTRICT_ORDER: Array[StringName] = [
	&"BUSINESS", &"RESIDENTIAL",
]
const DISTRICT_COLORS: Dictionary[StringName, Color] = {
	&"BUSINESS": Color("68dbe0"),
	&"RESIDENTIAL": Color("78d2a9"),
}

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
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	_check(
		"catalog_eight_variants",
		EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS.size() == 8,
		"count=%d" % EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS.size()
	)
	_check(
		"eight_cards",
		_count_cards(gallery) == 8,
		"count=%d" % _count_cards(gallery)
	)
	_check(
		"vfx_catalog_covers_retained_variants",
		EnemyAttackVfxCatalog.SPECS.size() == 8,
		"count=%d" % EnemyAttackVfxCatalog.SPECS.size()
	)
	_check(
		"vfx_delivery_split",
		EnemyAttackVfxCatalog.RANGED_IDS.size() == 3,
		"ranged=3 actor=5"
	)
	_check(
		"two_district_groups",
		_district_card_counts(gallery) == {
			&"BUSINESS": 4,
			&"RESIDENTIAL": 4,
		},
		"counts=%s" % _district_card_counts(gallery)
	)
	_check(
		"cards_inside_viewport",
		_cards_inside_viewport(gallery, target_size),
		"size=%s" % target_size
	)
	var orientation: String = "portrait" if portrait else "landscape"
	var shot_path: String = ""
	var shot_status: String = "SKIP"
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(ARTIFACT_DIR)
		)
		shot_path = "%s/variant-gallery-%s.png" % [ARTIFACT_DIR, orientation]
		var image: Image = root.get_texture().get_image()
		var error: Error = image.save_png(ProjectSettings.globalize_path(shot_path))
		_check("shot_saved", error == OK, "error=%s" % error)
		_check(
			"shot_geometry",
			image.get_size() == target_size,
			"size=%s" % image.get_size()
		)
		shot_status = "PASS" if error == OK else "FAIL"
	var report: Dictionary = {
		"done": true,
		"result": "PASS" if _all_passed() else "FAIL",
		"orientation": orientation,
		"variant_count": EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS.size(),
		"variants": _variant_records(),
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
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
	gallery.name = "DistrictEnemyVariantGallery"
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("071018")
	gallery.add_child(backdrop)
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.position = Vector2(18.0, 14.0)
	content.size = Vector2(target_size) - Vector2(36.0, 28.0)
	content.add_theme_constant_override("separation", 6)
	gallery.add_child(content)
	var title: Label = Label.new()
	title.text = "PROJECT CHOIR // DISTRICT DERIVATIVE INDEX"
	title.add_theme_color_override("font_color", Color("b8ffff"))
	title.add_theme_font_size_override("font_size", 22 if portrait else 25)
	content.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "8 CONCRETE VARIANTS // 2 DISTRICTS // FIXED-POOL RUNTIME"
	subtitle.add_theme_color_override("font_color", Color("7896a8"))
	subtitle.add_theme_font_size_override("font_size", 12)
	content.add_child(subtitle)
	var grid: GridContainer = GridContainer.new()
	grid.name = "VariantGrid"
	grid.columns = 2 if portrait else 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	content.add_child(grid)
	for district_id: StringName in DISTRICT_ORDER:
		for variant_id: StringName in EnemyArchetypeCatalog.variants_for_district(district_id):
			grid.add_child(_variant_card(variant_id, district_id, portrait))
	return gallery


func _variant_card(
	variant_id: StringName,
	district_id: StringName,
	portrait: bool
) -> PanelContainer:
	var profile: Dictionary = EnemyArchetypeCatalog.profile(variant_id)
	var canonical_id: StringName = EnemyArchetypeCatalog.canonical_id(variant_id)
	var vfx_spec: Dictionary = EnemyAttackVfxCatalog.spec(variant_id)
	var texture: Texture2D = load(String(profile.get("texture", ""))) as Texture2D
	_check("%s_profile" % variant_id, not profile.is_empty(), "base=%s" % canonical_id)
	_check("%s_texture" % variant_id, texture != null, "path=%s" % profile.get("texture", ""))
	_check(
		"%s_attack_vfx" % variant_id,
		not vfx_spec.is_empty(),
		"delivery=%s" % vfx_spec.get("delivery", &"")
	)
	_check(
		"%s_family" % variant_id,
		EnemyArchetypeCatalog.family_for(variant_id) == EnemyArchetypeCatalog.family_for(canonical_id),
		"family=%s base=%s" % [profile.get("family", ""), canonical_id]
	)
	var card: PanelContainer = PanelContainer.new()
	card.set_meta(&"district_id", district_id)
	card.set_meta(&"variant_id", variant_id)
	card.custom_minimum_size = Vector2(330.0, 104.0) if portrait else Vector2(300.0, 110.0)
	card.add_theme_stylebox_override("panel", _card_style(DISTRICT_COLORS[district_id]))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var sprite: TextureRect = TextureRect.new()
	sprite.texture = texture
	sprite.custom_minimum_size = Vector2(106.0, 82.0) if portrait else Vector2(92.0, 82.0)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(sprite)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 1)
	row.add_child(stack)
	var district_label: Label = Label.new()
	district_label.text = String(district_id)
	district_label.add_theme_color_override("font_color", DISTRICT_COLORS[district_id])
	district_label.add_theme_font_size_override("font_size", 10)
	stack.add_child(district_label)
	var name_label: Label = Label.new()
	name_label.text = String(profile.display_name)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color", Color("e4f8f5"))
	name_label.add_theme_font_size_override("font_size", 13 if portrait else 12)
	stack.add_child(name_label)
	var identity_label: Label = Label.new()
	identity_label.text = "%s → %s" % [variant_id, canonical_id]
	identity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity_label.add_theme_color_override("font_color", Color("8ca6b3"))
	identity_label.add_theme_font_size_override("font_size", 9)
	stack.add_child(identity_label)
	var family_label: Label = Label.new()
	family_label.text = "%s // THREAT %02d // %s" % [
		String(profile.family).to_upper(),
		int(profile.threat),
		"SHOT" if EnemyAttackVfxCatalog.is_projectile_delivery(variant_id) else "ACTOR",
	]
	family_label.add_theme_color_override("font_color", Color("70c9c8"))
	family_label.add_theme_font_size_override("font_size", 10)
	stack.add_child(family_label)
	return card


func _card_style(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.075, 0.96)
	style.border_color = accent.darkened(0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6.0)
	return style


func _count_cards(gallery: Control) -> int:
	var grid: GridContainer = gallery.get_node("Content/VariantGrid") as GridContainer
	return grid.get_child_count()


func _district_card_counts(gallery: Control) -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	var grid: GridContainer = gallery.get_node("Content/VariantGrid") as GridContainer
	for child: Control in grid.get_children():
		var district_id: StringName = StringName(child.get_meta(&"district_id", &""))
		counts[district_id] = int(counts.get(district_id, 0)) + 1
	return counts


func _cards_inside_viewport(gallery: Control, target_size: Vector2i) -> bool:
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(target_size))
	var grid: GridContainer = gallery.get_node("Content/VariantGrid") as GridContainer
	for child: Control in grid.get_children():
		if not viewport_rect.encloses(child.get_global_rect()):
			return false
	return true


func _variant_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for variant_id: StringName in EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(variant_id)
		var attack_phase: Dictionary = EnemyAttackVfxCatalog.phase_spec(
			variant_id,
			&"attack"
		)
		var impact_phase: Dictionary = EnemyAttackVfxCatalog.phase_spec(
			variant_id,
			&"impact"
		)
		var payload_phase: Dictionary = EnemyAttackVfxCatalog.phase_spec(
			variant_id,
			&"projectile"
		)
		records.append({
			"id": String(variant_id),
			"canonical_id": String(EnemyArchetypeCatalog.canonical_id(variant_id)),
			"district_id": String(EnemyArchetypeCatalog.district_for_variant(variant_id)),
			"family": String(profile.family),
			"texture": String(profile.texture),
			"faces_right": bool(profile.get("faces_right", false)),
			"display": profile.display,
			"collision": profile.collision,
			"attack_vfx_id": String(profile.attack_vfx_id),
			"delivery": (
				"projectile"
				if EnemyAttackVfxCatalog.is_projectile_delivery(variant_id)
				else "actor"
			),
			"projectile_key": String(EnemyAttackVfxCatalog.projectile_key(variant_id)),
			"impact_key": String(EnemyAttackVfxCatalog.impact_key(variant_id)),
			"payload_region": payload_phase.region,
			"impact_region": impact_phase.region,
			"attack_region": attack_phase.region,
		})
	return records


func _check(check_name: String, passed: bool, detail: String) -> void:
	checks.append({"name": check_name, "passed": passed, "detail": detail})
	print("[CHECK] %s %s — %s" % ["PASS" if passed else "FAIL", check_name, detail])


func _all_passed() -> bool:
	for check: Dictionary in checks:
		if not bool(check.passed):
			return false
	return true
