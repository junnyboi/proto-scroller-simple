extends SceneTree

const MAX_FRAMES: int = 180
const REPORT_PATH: String = "res://artifacts/match_debrief/report.json"
const PROFILE_PATH: String = "user://match_debrief_visual_profile.json"

var elapsed_frames: int = 0
var completed: bool = false


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred(&"_run")


func _on_process_frame() -> void:
	if completed:
		return
	elapsed_frames += 1
	if elapsed_frames > MAX_FRAMES:
		_finish(false, "frame watchdog")


func _run() -> void:
	var requested_locale: String = OS.get_environment(
		"PROTO_SCROLLER_DEBRIEF_LOCALE"
	)
	L10n.set_locale(requested_locale if requested_locale in L10n.SUPPORTED_LOCALES else "en")
	_clear_profile()
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	root.add_child(store)
	store.setup(PROFILE_PATH)
	store.set_callsign("ECHO-7")
	var game_over: bool = OS.get_environment("PROTO_SCROLLER_DEBRIEF_GAME_OVER") == "1"
	var skill_affinity: bool = (
		OS.get_environment("PROTO_SCROLLER_DEBRIEF_SKILL_AFFINITY") == "1"
	)
	var summary: RunSummarySnapshot = _build_history(store, game_over, skill_affinity)
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	if scene == null:
		_finish(false, "city scene missing")
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	city.combat_profile = store
	root.add_child(city)
	await process_frame
	city.gameplay_hud.first_run_tutorial._finish_tutorial(true)
	city.encounter_runtime.release_all()
	city.encounter_director.process_mode = Node.PROCESS_MODE_DISABLED
	city.gameplay_hud._set_campaign_summary(25, 2)
	if game_over:
		city.gameplay_hud.show_game_over(summary)
	else:
		city.gameplay_hud.show_district_complete(summary)
	for _frame: int in range(4):
		await process_frame
	var panel: MatchDebriefPanel = city.gameplay_hud.match_debrief
	var page_name: String = OS.get_environment("PROTO_SCROLLER_DEBRIEF_PAGE").to_lower()
	if page_name == "global":
		panel.set_page(MatchDebriefPanel.Page.GLOBAL)
		panel.set_global_state(&"online", _global_rows(), {
			"rank": 4,
			"callsign": "ECHO-7",
		})
	else:
		page_name = "overview"
		panel.set_page(MatchDebriefPanel.Page.AFTER_ACTION)
	for _frame: int in range(2):
		await process_frame
	var snapshot: Dictionary = panel.debug_snapshot()
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(target_size))
	var valid: bool = (
		panel.is_visible_in_tree()
		and viewport_rect.encloses(snapshot.panel_rect as Rect2)
		and viewport_rect.encloses(snapshot.retry_rect as Rect2)
		and viewport_rect.encloses(snapshot.title_rect as Rect2)
		and _page_valid(page_name, snapshot, game_over, skill_affinity)
	)
	if not valid:
		_finish(false, JSON.stringify(_json_safe_snapshot(snapshot)))
		return
	if DisplayServer.get_name() == "headless":
		_finish(true, "headless geometry pass")
		await _cleanup(panel, city, store)
		quit(0)
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/match_debrief")
	)
	var shot_name: String = (
		"skill-affinity"
		if skill_affinity
		else ("game-over-killer" if game_over else page_name)
	)
	if target_size.y > target_size.x:
		shot_name += "-portrait"
	if L10n.current_locale() != "en":
		shot_name += "-%s" % L10n.current_locale().to_lower()
	var shot_path: String = "res://artifacts/match_debrief/match-debrief-%s.png" % shot_name
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(shot_path))
	if save_error != OK or image.get_size() != target_size:
		_finish(false, "shot error=%s size=%s" % [save_error, image.get_size()])
		return
	var report: Dictionary = {
		"result": "PASS",
		"page": page_name,
		"viewport": {"width": target_size.x, "height": target_size.y},
		"summary": {
			"score": summary.score,
			"highest_combo_tier": summary.highest_combo_tier,
			"total_enemy_kills": summary.total_enemies_defeated,
			"unique_enemy_types": summary.unique_enemy_types,
			"preferred_weapon": String(summary.preferred_weapon),
			"defeat_source_id": String(summary.defeat_source_id),
		},
		"layout": _json_safe_snapshot(snapshot),
		"shot": shot_path,
	}
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file == null:
		_finish(false, "report open failed")
		return
	report_file.store_string(JSON.stringify(report, "  "))
	report_file.close()
	_finish(true, shot_path)
	await _cleanup(panel, city, store)
	quit(0)


func _build_history(
	store: PlayerCombatProfileStore,
	game_over: bool,
	skill_affinity: bool
) -> RunSummarySnapshot:
	var latest: RunSummarySnapshot
	for index: int in range(8):
		var score: int = 84_000 + index * 112_000
		if index == 7:
			score = 874_200
		var weapon_kills: Dictionary = {
			&"GROUND_SMASH": 12 + index * 4,
			&"MISSILE": 18 + (7 - index) * 2,
			&"LASER": 5 + index * 3,
		}
		var preferred_weapon: StringName = &"GROUND_SMASH" if index >= 4 else &"MISSILE"
		var preferred_weapon_kills: int = 42 if index == 7 else 18 + index * 4
		if skill_affinity and index == 7:
			weapon_kills = {
				&"SIEGE_DRILL": 32,
				&"GRAVITY_CRUCIBLE": 26,
				&"JAB_CROSS": 20,
			}
			preferred_weapon = &"SIEGE_DRILL"
			preferred_weapon_kills = 32
		latest = RunSummarySnapshot.new(
			score,
			mini(index + 1, 5),
			10 + index * 2,
			6 if index == 7 else 2 + index % 4,
			index,
			{&"SKYBREAKER": index},
			{
				"completed": false if game_over and index == 7 else index % 2 == 1,
				"defeat_source_id": (
					&"covenant_warden"
					if game_over and index == 7
					else DefeatSourceResolver.UNKNOWN
				),
				"grade": (
					&"D"
					if game_over and index == 7
					else (&"S" if index == 7 else &"B")
				),
				"mastery_points": 982 if index == 7 else 200 + index * 40,
				"objective": "summary.retry.reach_next_act",
				"cycle_count": 2 if index == 7 else 1,
				"highest_combo_tier": 12 if index == 7 else 3 + index,
				"total_enemies_defeated": 78 if index == 7 else 22 + index * 5,
				"unique_enemy_types": 14 if index == 7 else 5 + index,
				"enemy_kills": {
					&"covenant_warden": 12 + index,
					&"needle": 4 + index,
					&"reclaimed_breacher": index,
				},
				"weapon_kills": weapon_kills,
				"preferred_weapon": preferred_weapon,
				"preferred_weapon_kills": preferred_weapon_kills,
			}
		)
		latest = store.enrich_and_submit(latest)
	return latest


func _global_rows() -> Array[Dictionary]:
	var callsigns: Array[String] = [
		"CROWN-BREAKER", "MERCY ZERO", "ASH PILOT", "ECHO-7", "PALE SIGNAL",
		"NIGHT ENGINE", "GLASS SAINT", "IRON WITNESS", "VANTA FOX", "CHOIRLESS",
	]
	var rows: Array[Dictionary] = []
	for index: int in range(callsigns.size()):
		rows.append({
			"rank": index + 1,
			"callsign": callsigns[index],
			"highest_combo_tier": 24 - index,
			"best_score": 9_500_000 - index * 640_000,
			"preferred_weapon": "GROUND_SMASH" if index % 2 == 0 else "MISSILE",
		})
	return rows


func _page_valid(
	page_name: String,
	snapshot: Dictionary,
	game_over: bool,
	skill_affinity: bool
) -> bool:
	if page_name == "global":
		return (
			String(snapshot.page) == "GLOBAL"
			and String(snapshot.global_state) == "online"
			and (snapshot.global_rows as PackedStringArray).size() == 10
		)
	var weapon_rows_text: String = "\n".join(snapshot.weapon_rows as PackedStringArray)
	return (
		String(snapshot.page) == "AFTER_ACTION"
		and String(snapshot.result) == ("GAME OVER" if game_over else "DISTRICT CLEARED")
		and String(snapshot.killed_by) == (
			"KILLED BY 'COVENANT WARDEN'" if game_over else ""
		)
		and String(snapshot.combo).contains("EXTINCTION EVENT")
		and bool(snapshot.personal_best)
		and (snapshot.weapon_rows as PackedStringArray).size() == 3
		and (
			not skill_affinity
			or (
				weapon_rows_text.contains("SIEGE DRILL")
				and weapon_rows_text.contains("GRAVITY CRUCIBLE")
			)
		)
		and (snapshot.enemy_rows as PackedStringArray).size() == 3
	)


func _cleanup(
	panel: MatchDebriefPanel,
	city: CitySlice,
	store: PlayerCombatProfileStore
) -> void:
	panel.hide_panel()
	city.queue_free()
	store.queue_free()
	await process_frame
	await process_frame
	_clear_profile()


func _clear_profile() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = PROFILE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish(success: bool, detail: String) -> void:
	if completed:
		return
	completed = true
	print("[MATCH-DEBRIEF-VISUAL-%s] %s" % ["PASS" if success else "FAIL", detail])
	if not success:
		quit(1)


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)


func _json_safe_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"visible": bool(snapshot.visible),
		"page": String(snapshot.page),
		"result": String(snapshot.result),
		"killed_by": String(snapshot.killed_by),
		"combo": String(snapshot.combo),
		"personal_best": bool(snapshot.personal_best),
		"global_state": String(snapshot.global_state),
		"weapon_rows": Array(snapshot.weapon_rows as PackedStringArray),
		"enemy_rows": Array(snapshot.enemy_rows as PackedStringArray),
		"global_rows": Array(snapshot.global_rows as PackedStringArray),
		"panel_rect": _rect_dictionary(snapshot.panel_rect as Rect2),
		"retry_rect": _rect_dictionary(snapshot.retry_rect as Rect2),
		"title_rect": _rect_dictionary(snapshot.title_rect as Rect2),
	}


func _rect_dictionary(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
	}
