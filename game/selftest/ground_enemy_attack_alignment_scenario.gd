extends SceneTree

const REPORT_PATH: String = "res://artifacts/ground_enemy_attack_alignment/report.json"
const SHOT_PATH: String = "res://artifacts/ground_enemy_attack_alignment/alignment.png"
const HUMANOID_SHOT_PREFIX: String = (
	"res://artifacts/ground_enemy_attack_alignment/humanoid-page"
)
const HUMANOID_CASES_PER_PAGE: int = 4
const HUMANOID_PROJECTILE_CASES: Array[StringName] = [
	&"soldier", &"bulwark", &"lobber", &"covenant_warden",
]
const HUMANOID_AUDIT_CASES: Array[Dictionary] = [
	{"id": &"soldier"},
	{"id": &"bulwark"},
	{"id": &"lobber"},
	{"id": &"sapper"},
	{"id": &"covenant_warden"},
	{"id": &"intake_shepherd"},
	{"id": &"reclaimed_breacher"},
]

var checks: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_window().content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	_check("city_scene_loads", scene != null, "loaded=%s" % [scene != null])
	if scene == null:
		_finish("SKIP", "", [])
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	city.urban_siege.stop_run()
	city.encounter_runtime.release_all()
	city.projectile_root.release_all()
	city.robot.global_position.x = 1300.0
	city.camera_rig.global_position.x = 1300.0
	city.gameplay_hud.visible = false
	var attack_cases: Array[Dictionary] = [
		{"id": &"covenant_warden", "x": 800.0, "authored": true},
		{"id": &"reclaimed_breacher", "x": 1040.0, "authored": false},
		{"id": &"soldier", "x": 1280.0, "authored": false},
		{"id": &"lobber", "x": 1510.0, "authored": false},
		{"id": &"tank", "x": 1810.0, "authored": false},
	]
	for attack_case: Dictionary in attack_cases:
		var archetype_id: StringName = StringName(attack_case.id)
		var support_id: StringName = StringName(attack_case.get("support", &""))
		var check_id: StringName = support_id if not support_id.is_empty() else archetype_id
		var enemy: EnemyActor2D = city.encounter_runtime.acquire(
			archetype_id,
			Vector2(float(attack_case.x), 540.0)
		)
		_check("%s_acquires" % check_id, enemy != null, "id=%s" % archetype_id)
		if enemy == null:
			continue
		if not support_id.is_empty():
			_check(
				"%s_reskins" % check_id,
				enemy is ProceduralEnemy
				and (enemy as ProceduralEnemy).configure_boss_support(support_id),
				"shell=%s support=%s" % [archetype_id, support_id]
			)
		enemy.set_physics_process(false)
		_begin_attack(enemy)
		_check(
			"%s_telegraphs" % check_id,
			enemy.is_telegraphing(),
			"origin=%s" % enemy.telegraph_origin()
		)
		var procedural_visible: bool = city.telegraph_presenter.uses_procedural_rendering(
			enemy._telegraph_id
		)
		_check(
			"%s_presentation_route" % check_id,
			procedural_visible != bool(attack_case.authored),
			"authored=%s procedural=%s" % [attack_case.authored, procedural_visible]
		)
		if bool(attack_case.authored) and enemy is ProceduralEnemy:
			var procedural: ProceduralEnemy = enemy as ProceduralEnemy
			var attack_phase: Dictionary = procedural._authored_attack_phase()
			_check(
				"%s_sprite_matches_origin" % check_id,
				procedural._presentation_visible_center_world(
					procedural._presentation_sprites[0],
					attack_phase
				) == enemy.telegraph_origin(),
				"visible_center=%s origin=%s" % [
					procedural._presentation_visible_center_world(
						procedural._presentation_sprites[0],
						attack_phase
					),
					enemy.telegraph_origin(),
				]
			)
	await process_frame
	await physics_frame
	var shot_status: String = "SKIP"
	var shot_path: String = ""
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://artifacts/ground_enemy_attack_alignment")
		)
		var image: Image = root.get_texture().get_image()
		var error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check("shot_saved", error == OK, "error=%s" % error)
		_check("shot_geometry", image.get_size() == Vector2i(1280, 720), "size=%s" % image.get_size())
		shot_status = "PASS" if error == OK else "FAIL"
		shot_path = SHOT_PATH
	var humanoid_shots: Array[Dictionary] = await _capture_humanoid_audit(city)
	humanoid_shots.append(await _capture_humanoid_projectiles(city))
	city.queue_free()
	await process_frame
	OS.delay_msec(100)
	_finish(shot_status, shot_path, humanoid_shots)


func _begin_attack(enemy: EnemyActor2D) -> void:
	if enemy is SoldierEnemy:
		(enemy as SoldierEnemy)._begin_fire()
	elif enemy is TankEnemy:
		(enemy as TankEnemy)._begin_shell()
	elif enemy is ProceduralEnemy:
		(enemy as ProceduralEnemy)._begin_attack()


func _check(check_name: String, passed: bool, detail: String) -> void:
	checks.append({"name": check_name, "passed": passed, "detail": detail})
	print("[CHECK] %s %s — %s" % ["PASS" if passed else "FAIL", check_name, detail])


func _finish(
	shot_status: String,
	shot_path: String,
	humanoid_shots: Array[Dictionary]
) -> void:
	var all_passed: bool = true
	for item: Dictionary in checks:
		if not bool(item.passed):
			all_passed = false
	var report: Dictionary = {
		"scenario": "ground_enemy_attack_alignment",
		"result": "PASS" if all_passed else "FAIL",
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
		"humanoid_shots": humanoid_shots,
	}
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/ground_enemy_attack_alignment")
	)
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	print("[GROUND-ATTACK-ALIGNMENT-DONE] result=%s" % report.result)
	quit(0 if all_passed else 1)


func _capture_humanoid_audit(city: CitySlice) -> Array[Dictionary]:
	var shot_records: Array[Dictionary] = []
	_check(
		"humanoid_audit_roster",
		HUMANOID_AUDIT_CASES.size() == 7,
		"count=%d" % HUMANOID_AUDIT_CASES.size()
	)
	if DisplayServer.get_name() == "headless":
		return shot_records
	city.robot.visible = false
	city.camera_rig.set_process(false)
	city.camera_rig.set_physics_process(false)
	city.camera_rig.global_position.x = 1300.0
	city.robot.global_position = Vector2(260.0, 540.0)
	var page_count: int = ceili(
		float(HUMANOID_AUDIT_CASES.size()) / float(HUMANOID_CASES_PER_PAGE)
	)
	for page_index: int in range(page_count):
		city.encounter_runtime.release_all()
		city.projectile_root.release_all()
		city.telegraph_presenter.cancel_all()
		var audit_overlays: Array[Node] = []
		for slot_index: int in range(HUMANOID_CASES_PER_PAGE):
			var case_index: int = page_index * HUMANOID_CASES_PER_PAGE + slot_index
			if case_index >= HUMANOID_AUDIT_CASES.size():
				break
			var audit_case: Dictionary = HUMANOID_AUDIT_CASES[case_index]
			var archetype_id: StringName = StringName(audit_case.id)
			var enemy: EnemyActor2D = city.encounter_runtime.acquire(
				archetype_id,
				Vector2(805.0 + float(slot_index) * 315.0, 540.0)
			)
			_check(
				"audit_%s_acquires" % archetype_id,
				enemy != null,
				"page=%d slot=%d" % [page_index, slot_index]
			)
			if enemy == null:
				continue
			enemy.set_physics_process(false)
			enemy.target = city.robot
			enemy._update_facing()
			_begin_attack(enemy)
			_check(
				"audit_%s_telegraphs" % archetype_id,
				enemy.is_telegraphing(),
				"origin=%s" % enemy.telegraph_origin()
			)
			_check(
				"audit_%s_center_mass_y" % archetype_id,
				is_equal_approx(
					enemy.telegraph_origin().y,
					enemy.center_of_mass_world_position().y
				),
				"origin=%s center=%s" % [
					enemy.telegraph_origin(),
					enemy.center_of_mass_world_position(),
				]
			)
			if enemy is ProceduralEnemy:
				var procedural: ProceduralEnemy = enemy as ProceduralEnemy
				if (
					not procedural._presentation_sprites.is_empty()
					and procedural._presentation_sprites[0].visible
				):
					var visible_center: Vector2 = _presentation_visible_center(
						procedural._presentation_sprites[0]
					)
					_check(
						"audit_%s_authored_visible_center_y" % archetype_id,
						absf(visible_center.y - enemy.telegraph_origin().y) <= 2.0,
						"visible=%s origin=%s" % [
							visible_center,
							enemy.telegraph_origin(),
						]
					)
			audit_overlays.append(_add_attack_anchor_overlay(city, enemy, archetype_id))
		await process_frame
		await RenderingServer.frame_post_draw
		var shot_path: String = "%s-%02d.png" % [HUMANOID_SHOT_PREFIX, page_index + 1]
		var image: Image = root.get_texture().get_image()
		var save_error: Error = image.save_png(ProjectSettings.globalize_path(shot_path))
		_check(
			"humanoid_page_%02d_saved" % [page_index + 1],
			save_error == OK,
			"path=%s error=%s" % [shot_path, save_error]
		)
		shot_records.append({
			"status": "PASS" if save_error == OK else "FAIL",
			"path": shot_path,
		})
		for overlay: Node in audit_overlays:
			overlay.queue_free()
		await process_frame
	city.robot.visible = true
	return shot_records


func _capture_humanoid_projectiles(city: CitySlice) -> Dictionary:
	var shot_path: String = "%s-projectiles.png" % HUMANOID_SHOT_PREFIX
	if DisplayServer.get_name() == "headless":
		return {"status": "SKIP", "path": ""}
	city.encounter_runtime.release_all()
	city.projectile_root.release_all()
	city.telegraph_presenter.cancel_all()
	city.robot.visible = false
	city.camera_rig.set_process(false)
	city.camera_rig.set_physics_process(false)
	city.camera_rig.global_position.x = 1300.0
	city.robot.global_position = Vector2(260.0, 540.0)
	var audit_overlays: Array[Node] = []
	for case_index: int in range(HUMANOID_PROJECTILE_CASES.size()):
		var archetype_id: StringName = HUMANOID_PROJECTILE_CASES[case_index]
		var enemy: EnemyActor2D = city.encounter_runtime.acquire(
			archetype_id,
			Vector2(755.0 + float(case_index) * 265.0, 540.0)
		)
		_check(
			"projectile_audit_%s_acquires" % archetype_id,
			enemy != null,
			"slot=%d" % case_index
		)
		if enemy == null:
			continue
		enemy.set_physics_process(false)
		enemy.target = city.robot
		enemy._update_facing()
		_begin_attack(enemy)
		var committed_origin: Vector2 = enemy.telegraph_origin()
		if enemy is SoldierEnemy:
			(enemy as SoldierEnemy)._fire_snapshot()
		else:
			(enemy as ProceduralEnemy)._complete_attack()
		var projectile: Projectile2D = city.projectile_root.last_acquired
		_check(
			"projectile_audit_%s_spawns" % archetype_id,
			projectile != null and projectile.global_position == committed_origin,
			"projectile=%s origin=%s" % [
				projectile.global_position if projectile != null else Vector2.ZERO,
				committed_origin,
			]
		)
		if projectile != null:
			projectile.set_physics_process(false)
		audit_overlays.append(_add_attack_anchor_overlay(city, enemy, archetype_id))
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(shot_path))
	_check(
		"humanoid_projectile_page_saved",
		save_error == OK,
		"path=%s error=%s" % [shot_path, save_error]
	)
	for overlay: Node in audit_overlays:
		overlay.queue_free()
	city.robot.visible = true
	return {
		"status": "PASS" if save_error == OK else "FAIL",
		"path": shot_path,
	}


func _add_attack_anchor_overlay(
	city: CitySlice,
	enemy: EnemyActor2D,
	archetype_id: StringName
) -> Node2D:
	var overlay: Node2D = Node2D.new()
	overlay.name = "AuditOverlay_%s" % archetype_id
	overlay.z_index = 120
	city.add_child(overlay)
	var center: Vector2 = enemy.center_of_mass_world_position()
	var origin: Vector2 = enemy.telegraph_origin()
	var guide: Line2D = Line2D.new()
	guide.width = 2.0
	guide.default_color = Color("53f4e6")
	guide.points = PackedVector2Array([center, origin])
	overlay.add_child(guide)
	for marker_position: Vector2 in [center, origin]:
		var horizontal: Line2D = Line2D.new()
		horizontal.width = 2.0
		horizontal.default_color = Color("ff4d9e")
		horizontal.points = PackedVector2Array([
			marker_position + Vector2(-7.0, 0.0),
			marker_position + Vector2(7.0, 0.0),
		])
		overlay.add_child(horizontal)
		var vertical: Line2D = Line2D.new()
		vertical.width = 2.0
		vertical.default_color = Color("ff4d9e")
		vertical.points = PackedVector2Array([
			marker_position + Vector2(0.0, -7.0),
			marker_position + Vector2(0.0, 7.0),
		])
		overlay.add_child(vertical)
	var label: Label = Label.new()
	label.text = String(archetype_id).to_upper().replace("_", " ")
	label.position = center + Vector2(-115.0, -112.0)
	label.size = Vector2(230.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("b8ffff"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 15)
	overlay.add_child(label)
	return overlay


func _presentation_visible_center(sprite: Sprite2D) -> Vector2:
	var texture: Texture2D = sprite.texture
	if texture == null:
		return sprite.global_position
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return sprite.global_position
	var region: Rect2i = (
		Rect2i(sprite.region_rect)
		if sprite.region_enabled
		else Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))
	)
	var minimum: Vector2i = region.end
	var maximum: Vector2i = region.position - Vector2i.ONE
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a <= 0.03:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return sprite.global_position
	var source_center: Vector2 = (
		Vector2(minimum + maximum + Vector2i.ONE) * 0.5
		- Vector2(region.position)
	)
	var local_center: Vector2 = source_center - Vector2(region.size) * 0.5
	if sprite.flip_h:
		local_center.x = -local_center.x
	if sprite.flip_v:
		local_center.y = -local_center.y
	return sprite.to_global(local_center)
