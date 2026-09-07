class_name MatchDebriefPanel
extends Control

signal retry_pressed
signal title_pressed
signal global_refresh_requested
signal callsign_saved(callsign: String)

enum Page { AFTER_ACTION, CAREER, GLOBAL }

const CREST: Texture2D = preload("res://assets/ui/match_debrief/dossier_crest.png")
const BACKGROUND: Color = Color(0.012, 0.025, 0.034, 0.985)
const CARD: Color = Color(0.022, 0.052, 0.064, 0.96)
const CARD_ALT: Color = Color(0.025, 0.042, 0.055, 0.96)
const CYAN: Color = Color("7ae4ff")
const MUTED: Color = Color("a9bdc4")
const AMBER: Color = Color("f1b36f")
const RED: Color = Color("ff695c")
const PERSONAL_ROW_HIGHLIGHT: Color = Color(0.12, 0.52, 0.62, 0.28)
const AFTER_ACTION_HEADER_BOTTOM_PADDING: float = 12.0
const KILLER_INLINE_GAP: float = 18.0
const LANDSCAPE_SIZE: Vector2 = Vector2(
	1160.0,
	636.0 + AFTER_ACTION_HEADER_BOTTOM_PADDING
)
const PORTRAIT_SIZE: Vector2 = Vector2(
	672.0,
	1120.0 + AFTER_ACTION_HEADER_BOTTOM_PADDING
)
const WEAPON_ROW_COUNT: int = 3
const ENEMY_ROW_COUNT: int = 4
const LOCAL_ROW_COUNT: int = 5
const GLOBAL_ROW_COUNT: int = 10
const CONTROL_GROUP_MARGIN: float = 24.0

var global_navigation_enabled: bool = false
var content_root: Control
var scrim: ColorRect
var main_panel: ColorRect
var tab_buttons: Array[Button] = []
var combo_panel: ColorRect
var career_panel: ColorRect
var weapon_panel: ColorRect
var enemy_panel: ColorRect
var result_label: Label
var grade_label: Label
var score_label: Label
var killer_label: Label
var run_meta_label: Label
var crest: TextureRect
var combo_header_label: Label
var combo_value_label: Label
var combo_detail_label: Label
var personal_best_label: Label
var career_header_label: Label
var career_value_label: Label
var weapon_header_label: Label
var weapon_preferred_label: Label
var weapon_rows: Array[Label] = []
var enemy_header_label: Label
var enemy_total_label: Label
var enemy_rows: Array[Label] = []
var recommendation_label: Label
var retry_button: Button
var title_button: Button

var career_profile_panel: ColorRect
var callsign_header_label: Label
var callsign_edit: LineEdit
var callsign_save_button: Button
var callsign_status_label: Label
var chart_panel: ColorRect
var chart_header_label: Label
var chart_kills_button: Button
var chart_share_button: Button
var weapon_history_chart: CareerWeaponHistoryChart
var local_board_panel: ColorRect
var local_board_header_label: Label
var local_board_rows: Array[Label] = []

var global_panel: ColorRect
var global_header_label: Label
var global_status_label: Label
var global_refresh_button: Button
var global_callsign_header_label: Label
var global_callsign_edit: LineEdit
var global_callsign_save_button: Button
var global_callsign_status_label: Label
var personal_rank_label: Label
var global_row_highlights: Array[ColorRect] = []
var global_rows: Array[Label] = []

var presented_summary: RunSummarySnapshot
var profile_store: PlayerCombatProfileStore
var current_page: Page = Page.AFTER_ACTION
var global_state: StringName = &"native_local"
var callsign_uplink_state: StringName = &"idle"
var _global_entries: Array[Dictionary] = []
var _personal_rank: Dictionary = {}
var _after_action_controls: Array[Control] = []
var _career_controls: Array[Control] = []
var _global_controls: Array[Control] = []


func _ready() -> void:
	name = "MatchDebriefPanel"
	z_index = 30
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_controls()


func configure_profile(store: PlayerCombatProfileStore) -> void:
	profile_store = store
	if store != null:
		_sync_callsign_edits(store.callsign())


func present(
	summary: RunSummarySnapshot,
	result_text: String,
	dossier_count: int,
	continuity_generation: int
) -> void:
	if summary == null:
		hide_panel()
		return
	presented_summary = summary
	result_label.text = result_text
	grade_label.text = L10n.t("debrief.grade", {"grade": summary.grade})
	score_label.text = L10n.t("debrief.score", {"score": "%08d" % summary.score})
	if summary.completed:
		killer_label.text = ""
		killer_label.tooltip_text = ""
	else:
		var killer_name: String = _killer_name(summary.defeat_source_id)
		killer_label.text = L10n.t("debrief.killed_by", {"killer": killer_name})
		killer_label.tooltip_text = killer_label.text
	run_meta_label.text = L10n.t("debrief.run_meta", {
		"acts": summary.waves_cleared,
		"cycle": summary.cycle_count,
		"dossiers": dossier_count,
		"total": CityDistrictCatalog.BUILDING_VARIANT_COUNT,
		"generation": continuity_generation,
	})
	var compact_hash: String = (
		summary.tuning_configuration_hash.left(10)
		if not summary.tuning_configuration_hash.is_empty()
		else "DEFAULT"
	)
	run_meta_label.text += L10n.t("debrief.tuning_meta", {
		"status": L10n.t(
			"tuning.status.%s" % String(summary.tuning_status).to_lower()
		),
		"hash": compact_hash,
	})
	run_meta_label.tooltip_text = "%s\n%s" % [
		summary.tuning_configuration_hash,
		", ".join(summary.tuning_reasons),
	]
	run_meta_label.modulate = MUTED if summary.tuning_ranked_eligible else AMBER
	var combo_title: String = _combo_title(summary.highest_combo_tier)
	combo_value_label.text = "%s\n%s" % [
		combo_title,
		L10n.t("debrief.combo.tier", {"tier": summary.highest_combo_tier}),
	]
	combo_detail_label.text = L10n.t("debrief.combo.detail", {
		"chain": summary.best_chain,
		"multiplier": summary.peak_combo,
	})
	personal_best_label.visible = summary.new_combo_record or summary.new_score_record
	personal_best_label.text = L10n.t(
		"debrief.personal_best.both"
		if summary.new_combo_record and summary.new_score_record
		else (
			"debrief.personal_best.combo"
			if summary.new_combo_record
			else "debrief.personal_best.score"
		)
	)
	_update_career(summary.career_snapshot)
	_update_weapons(summary)
	_update_enemies(summary)
	_update_career_page(summary.career_snapshot)
	_update_global_page()
	recommendation_label.text = L10n.t("debrief.recommendation", {
		"objective": L10n.t(summary.retry_objective),
	})
	visible = true
	set_page(Page.AFTER_ACTION)
	apply_responsive_layout(get_viewport_rect().size)
	retry_button.grab_focus()


func hide_panel() -> void:
	presented_summary = null
	visible = false


func set_page(page: Page) -> void:
	tab_buttons[Page.GLOBAL].visible = global_navigation_enabled
	if page == Page.GLOBAL and not global_navigation_enabled:
		page = Page.CAREER
	current_page = page
	_set_controls_visible(_after_action_controls, page == Page.AFTER_ACTION)
	_set_controls_visible(_career_controls, page == Page.CAREER)
	_set_controls_visible(_global_controls, page == Page.GLOBAL)
	for index: int in range(tab_buttons.size()):
		tab_buttons[index].button_pressed = index == page
	if page == Page.AFTER_ACTION and presented_summary != null:
		killer_label.visible = not presented_summary.completed
		personal_best_label.visible = (
			presented_summary.new_combo_record or presented_summary.new_score_record
		)
		_update_weapons(presented_summary)
		_update_enemies(presented_summary)
	elif page == Page.CAREER and presented_summary != null:
		_update_career_page(presented_summary.career_snapshot)
	elif page == Page.GLOBAL:
		if profile_store != null:
			_sync_callsign_edits(profile_store.callsign())
		_update_global_page()
	apply_responsive_layout(get_viewport_rect().size)
	if page == Page.GLOBAL:
		global_refresh_requested.emit()


func set_global_state(
	state: StringName,
	entries: Array[Dictionary] = [],
	personal_rank: Dictionary = {}
) -> void:
	global_state = state
	_global_entries.clear()
	for entry: Dictionary in entries:
		_global_entries.append(entry.duplicate(true))
	_personal_rank = personal_rank.duplicate(true)
	_update_global_page()


func set_callsign_uplink_state(new_state: StringName) -> void:
	callsign_uplink_state = new_state
	if global_callsign_status_label == null:
		return
	var key: String = "debrief.callsign.uplink.%s" % String(new_state)
	var message: String = L10n.t(key)
	var color: Color = MUTED
	if new_state == &"success":
		color = CYAN
	elif new_state in [&"failure", &"rejected"]:
		color = RED
	_sync_callsign_status(message, color)


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if content_root == null:
		return
	if viewport_size.y > viewport_size.x:
		_apply_portrait_layout(viewport_size)
	else:
		_apply_landscape_layout(viewport_size)


func debug_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"page": Page.keys()[current_page],
		"result": result_label.text if result_label != null else "",
		"killed_by": killer_label.text if killer_label != null and killer_label.visible else "",
		"combo": combo_value_label.text if combo_value_label != null else "",
		"personal_best": personal_best_label.visible if personal_best_label != null else false,
		"weapon_rows": _visible_row_text(weapon_rows),
		"enemy_rows": _visible_row_text(enemy_rows),
		"local_rows": _visible_row_text(local_board_rows),
		"global_rows": _visible_row_text(global_rows),
		"global_state": String(global_state),
		"callsign": callsign_edit.text if callsign_edit != null else "",
		"global_callsign": (
			global_callsign_edit.text if global_callsign_edit != null else ""
		),
		"global_callsign_status": (
			global_callsign_status_label.text
			if global_callsign_status_label != null
			else ""
		),
		"callsign_uplink_state": String(callsign_uplink_state),
		"highlighted_global_rows": _highlighted_global_row_indexes(),
		"chart": weapon_history_chart.debug_snapshot() if weapon_history_chart != null else {},
		"panel_rect": Rect2(
			content_root.position,
			main_panel.size * content_root.scale
		) if content_root != null and main_panel != null else Rect2(),
		"tabs_rect": _controls_union_rect(tab_buttons),
		"page_content_rect": _page_content_rect(),
		"bottom_content_rect": _bottom_content_rect(),
		"retry_rect": _scaled_rect(retry_button),
		"title_rect": _scaled_rect(title_button),
		"callsign_rect": _scaled_rect(callsign_edit),
		"global_callsign_rect": _scaled_rect(global_callsign_edit),
		"global_callsign_save_rect": _scaled_rect(global_callsign_save_button),
		"refresh_rect": _scaled_rect(global_refresh_button),
	}


func _build_controls() -> void:
	scrim = ColorRect.new()
	scrim.name = "DebriefScrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.004, 0.009, 0.015, 0.985)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	content_root = Control.new()
	content_root.name = "Content"
	add_child(content_root)
	main_panel = _panel("DossierBackground", BACKGROUND)
	for index: int in range(3):
		var key: String = [
			"debrief.tab.after_action",
			"debrief.tab.career",
			"debrief.tab.global",
		][index]
		var tab: Button = _button("DebriefTab%d" % index, key)
		tab.toggle_mode = true
		tab.pressed.connect(set_page.bind(index as Page))
		tab_buttons.append(tab)
	_build_after_action_controls()
	_build_career_controls()
	_build_global_controls()
	retry_button = _button("DebriefRetryButton", "hud.retry")
	retry_button.pressed.connect(retry_pressed.emit)
	title_button = _button("DebriefTitleButton", "hud.title_screen")
	title_button.pressed.connect(title_pressed.emit)


func _build_after_action_controls() -> void:
	combo_panel = _panel("ComboCard", CARD)
	career_panel = _panel("CareerCard", CARD_ALT)
	weapon_panel = _panel("WeaponCard", CARD_ALT)
	enemy_panel = _panel("EnemyCard", CARD)
	result_label = _label("Result", 42, MUTED)
	grade_label = _label("Grade", 34, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	score_label = _label("Score", 34, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	killer_label = _label("KilledBy", 18, RED)
	killer_label.clip_text = true
	run_meta_label = _label("RunMeta", 16, MUTED)
	combo_header_label = _section_label("ComboHeader", "debrief.highest_combo")
	combo_value_label = _label("ComboValue", 28, AMBER)
	combo_detail_label = _label("ComboDetail", 16, MUTED)
	personal_best_label = _label("PersonalBest", 16, RED)
	crest = TextureRect.new()
	crest.name = "DossierCrest"
	crest.texture = CREST
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(crest)
	career_header_label = _section_label("CareerHeader", "debrief.career_record")
	career_value_label = _label("CareerValues", 17, MUTED)
	weapon_header_label = _section_label("WeaponHeader", "debrief.weapon_affinity")
	weapon_preferred_label = _label("PreferredWeapon", 20, AMBER)
	for index: int in range(WEAPON_ROW_COUNT):
		var row: Label = _label("WeaponRow%d" % index, 16, MUTED)
		row.clip_text = true
		weapon_rows.append(row)
	enemy_header_label = _section_label("EnemyHeader", "debrief.enemy_matrix")
	enemy_total_label = _label("EnemyTotals", 16, AMBER)
	for index: int in range(ENEMY_ROW_COUNT):
		var row: Label = _label("EnemyRow%d" % index, 16, MUTED)
		row.clip_text = true
		enemy_rows.append(row)
	recommendation_label = _label("Recommendation", 14, MUTED)
	recommendation_label.clip_text = true
	_after_action_controls.assign([
		combo_panel, career_panel, weapon_panel, enemy_panel, result_label, grade_label,
		score_label, killer_label, run_meta_label, combo_header_label, combo_value_label,
		combo_detail_label, personal_best_label, crest, career_header_label,
		career_value_label, weapon_header_label, weapon_preferred_label,
		enemy_header_label, enemy_total_label, recommendation_label,
	])
	_after_action_controls.append_array(weapon_rows)
	_after_action_controls.append_array(enemy_rows)


func _build_career_controls() -> void:
	career_profile_panel = _panel("OperatorProfileCard", CARD)
	callsign_header_label = _section_label("CallsignHeader", "debrief.callsign.header")
	callsign_edit = LineEdit.new()
	callsign_edit.name = "CallsignEdit"
	callsign_edit.placeholder_text = L10n.t("debrief.callsign.placeholder")
	callsign_edit.max_length = PlayerCombatProfileStore.MAX_CALLSIGN_LENGTH
	callsign_edit.add_theme_font_size_override(&"font_size", 19)
	content_root.add_child(callsign_edit)
	callsign_save_button = _button("CallsignSaveButton", "debrief.callsign.save")
	callsign_save_button.pressed.connect(_save_callsign)
	callsign_edit.text_submitted.connect(func(_value: String) -> void: _save_callsign())
	callsign_status_label = _label("CallsignStatus", 14, MUTED)
	chart_panel = _panel("WeaponHistoryCard", CARD_ALT)
	chart_header_label = _section_label("ChartHeader", "debrief.history.header")
	chart_kills_button = _button("ChartKillsButton", "debrief.history.kills")
	chart_kills_button.toggle_mode = true
	chart_kills_button.button_pressed = true
	chart_kills_button.pressed.connect(
		_set_chart_mode.bind(CareerWeaponHistoryChart.DisplayMode.KILLS)
	)
	chart_share_button = _button("ChartShareButton", "debrief.history.share")
	chart_share_button.toggle_mode = true
	chart_share_button.pressed.connect(
		_set_chart_mode.bind(CareerWeaponHistoryChart.DisplayMode.SHARE)
	)
	weapon_history_chart = CareerWeaponHistoryChart.new()
	content_root.add_child(weapon_history_chart)
	local_board_panel = _panel("LocalBoardCard", CARD)
	local_board_header_label = _section_label("LocalBoardHeader", "debrief.local.header")
	for index: int in range(LOCAL_ROW_COUNT):
		var row: Label = _label("LocalBoardRow%d" % index, 14, MUTED)
		row.clip_text = true
		local_board_rows.append(row)
	_career_controls.assign([
		career_profile_panel, callsign_header_label, callsign_edit, callsign_save_button,
		callsign_status_label, chart_panel, chart_header_label, chart_kills_button,
		chart_share_button, weapon_history_chart, local_board_panel, local_board_header_label,
	])
	_career_controls.append_array(local_board_rows)


func _build_global_controls() -> void:
	global_panel = _panel("GlobalNetworkCard", CARD_ALT)
	global_header_label = _section_label("GlobalHeader", "debrief.global.header")
	global_status_label = _label("GlobalStatus", 16, MUTED)
	global_refresh_button = _button("GlobalRefreshButton", "debrief.global.refresh")
	global_refresh_button.pressed.connect(global_refresh_requested.emit)
	global_callsign_header_label = _section_label(
		"GlobalCallsignHeader",
		"debrief.callsign.header"
	)
	global_callsign_edit = LineEdit.new()
	global_callsign_edit.name = "GlobalCallsignEdit"
	global_callsign_edit.placeholder_text = L10n.t("debrief.callsign.placeholder")
	global_callsign_edit.max_length = PlayerCombatProfileStore.MAX_CALLSIGN_LENGTH
	global_callsign_edit.add_theme_font_size_override(&"font_size", 19)
	content_root.add_child(global_callsign_edit)
	global_callsign_save_button = _button(
		"GlobalCallsignSaveButton",
		"debrief.callsign.save"
	)
	global_callsign_save_button.pressed.connect(
		func() -> void:
			_save_callsign(global_callsign_edit, global_callsign_status_label)
	)
	global_callsign_edit.text_submitted.connect(
		func(_value: String) -> void:
			_save_callsign(global_callsign_edit, global_callsign_status_label)
	)
	global_callsign_status_label = _label("GlobalCallsignStatus", 14, MUTED)
	personal_rank_label = _label("PersonalRank", 18, AMBER)
	for index: int in range(GLOBAL_ROW_COUNT):
		var highlight: ColorRect = _panel(
			"GlobalRowHighlight%d" % index,
			PERSONAL_ROW_HIGHLIGHT
		)
		highlight.visible = false
		global_row_highlights.append(highlight)
		var row: Label = _label("GlobalRow%d" % index, 15, MUTED)
		row.clip_text = true
		global_rows.append(row)
	_global_controls.assign([
		global_panel, global_header_label, global_status_label, global_refresh_button,
		global_callsign_header_label, global_callsign_edit, global_callsign_save_button,
		global_callsign_status_label, personal_rank_label,
	])
	_global_controls.append_array(global_row_highlights)
	_global_controls.append_array(global_rows)


func _panel(panel_name: String, color: Color) -> ColorRect:
	var panel: ColorRect = ColorRect.new()
	panel.name = panel_name
	panel.color = color
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(panel)
	return panel


func _section_label(label_name: String, key: String) -> Label:
	var label: Label = _label(label_name, 17, CYAN)
	label.text = L10n.t(key)
	return label


func _label(
	label_name: String,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.add_theme_font_size_override(&"font_size", font_size)
	label.modulate = color
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(label)
	return label


func _button(button_name: String, key: String) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.text = L10n.t(key)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override(&"font_size", 20)
	content_root.add_child(button)
	return button


func _save_callsign(
	source_edit: LineEdit = null,
	status_label: Label = null
) -> void:
	var active_edit: LineEdit = source_edit if source_edit != null else callsign_edit
	var active_status: Label = status_label if status_label != null else callsign_status_label
	callsign_uplink_state = &"idle"
	if profile_store == null:
		active_status.text = L10n.t("debrief.callsign.unavailable")
		active_status.modulate = RED
		return
	var result: StringName = profile_store.set_callsign(active_edit.text)
	if result != &"ok":
		active_status.text = L10n.t("debrief.callsign.%s" % String(result))
		active_status.modulate = RED
		return
	var saved_callsign: String = profile_store.callsign()
	_sync_callsign_edits(saved_callsign)
	if OS.has_feature("web"):
		set_callsign_uplink_state(&"pending")
	else:
		_sync_callsign_status(L10n.t("debrief.callsign.saved"), CYAN)
	_update_global_callsign(saved_callsign)
	_update_career_page(profile_store.snapshot())
	_update_global_page()
	callsign_saved.emit(saved_callsign)


func _sync_callsign_edits(value: String) -> void:
	if callsign_edit != null:
		callsign_edit.text = value
	if global_callsign_edit != null:
		global_callsign_edit.text = value


func _sync_callsign_status(message: String, color: Color) -> void:
	var labels: Array[Label] = [callsign_status_label, global_callsign_status_label]
	for label: Label in labels:
		if label != null:
			label.text = message
			label.modulate = color


func _update_global_callsign(saved_callsign: String) -> void:
	var personal_rank: int = int(_personal_rank.get("rank", 0))
	if not _personal_rank.is_empty():
		_personal_rank["callsign"] = saved_callsign
	if personal_rank <= 0:
		return
	for entry: Dictionary in _global_entries:
		if int(entry.get("rank", 0)) == personal_rank:
			entry["callsign"] = saved_callsign
			return


func _set_chart_mode(mode: CareerWeaponHistoryChart.DisplayMode) -> void:
	chart_kills_button.button_pressed = mode == CareerWeaponHistoryChart.DisplayMode.KILLS
	chart_share_button.button_pressed = mode == CareerWeaponHistoryChart.DisplayMode.SHARE
	weapon_history_chart.set_display_mode(mode)


func _update_career(career: Dictionary) -> void:
	if career.is_empty():
		career_value_label.text = L10n.t("debrief.career.local_record_unavailable")
		return
	career_value_label.text = L10n.t("debrief.career.values", {
		"score": "%08d" % int(career.get("best_score", 0)),
		"tier": int(career.get("highest_combo_tier", 0)),
		"kills": int(career.get("total_enemy_kills", 0)),
		"runs": int(career.get("total_runs", 0)),
		"victories": int(career.get("victories", 0)),
	})


func _update_career_page(career: Dictionary) -> void:
	var history: Array[Dictionary] = []
	var local_rows: Array[Dictionary] = []
	if profile_store != null:
		_sync_callsign_edits(profile_store.callsign())
		history = profile_store.chart_history()
		local_rows = profile_store.local_leaderboard(LOCAL_ROW_COUNT)
	else:
		_sync_callsign_edits(String(career.get("callsign", "")))
		var raw_history: Array = career.get("run_history", []) as Array
		for entry: Variant in raw_history:
			if entry is Dictionary:
				history.append((entry as Dictionary).duplicate(true))
		local_rows = _rank_history_locally(history, LOCAL_ROW_COUNT)
	weapon_history_chart.set_history(history)
	for index: int in range(local_board_rows.size()):
		var row: Label = local_board_rows[index]
		row.visible = index < local_rows.size()
		row.text = _ranking_row(local_rows[index], true) if row.visible else ""
	if local_rows.is_empty():
		local_board_rows[0].visible = true
		local_board_rows[0].text = L10n.t("debrief.local.empty")


func _update_global_page() -> void:
	if global_status_label == null:
		return
	global_status_label.text = L10n.t("debrief.global.state.%s" % String(global_state))
	global_status_label.modulate = RED if global_state == &"local_fallback" else MUTED
	var display_entries: Array[Dictionary] = _global_entries
	if display_entries.is_empty() and profile_store != null:
		display_entries = profile_store.local_leaderboard(GLOBAL_ROW_COUNT)
	var show_rows: bool = current_page == Page.GLOBAL
	for index: int in range(global_rows.size()):
		var row: Label = global_rows[index]
		row.visible = show_rows and index < display_entries.size()
		row.text = _ranking_row(display_entries[index]) if row.visible else ""
		var is_personal: bool = (
			row.visible and _is_personal_global_entry(display_entries[index])
		)
		row.modulate = AMBER if is_personal else MUTED
		global_row_highlights[index].visible = is_personal
	if display_entries.is_empty() and show_rows:
		global_rows[0].visible = true
		global_rows[0].text = L10n.t("debrief.global.empty")
		global_row_highlights[0].visible = false
	personal_rank_label.text = (
		L10n.t("debrief.global.personal_rank", {
			"rank": int(_personal_rank.get("rank", 0)),
			"callsign": String(_personal_rank.get(
				"callsign",
				profile_store.callsign() if profile_store != null else ""
			)),
		})
		if not _personal_rank.is_empty()
		else L10n.t("debrief.global.unranked")
	)


func _is_personal_global_entry(entry: Dictionary) -> bool:
	var personal_rank: int = int(_personal_rank.get("rank", 0))
	return personal_rank > 0 and int(entry.get("rank", 0)) == personal_rank


func _highlighted_global_row_indexes() -> PackedInt32Array:
	var indexes: PackedInt32Array = []
	for index: int in range(global_row_highlights.size()):
		if global_row_highlights[index].visible:
			indexes.append(index)
	return indexes


func _update_weapons(summary: RunSummarySnapshot) -> void:
	var ranked: Array[Dictionary] = CombatRunTelemetry.ranked_entries(
		summary.weapon_kills,
		WEAPON_ROW_COUNT
	)
	weapon_preferred_label.text = L10n.t("debrief.preferred_weapon", {
		"weapon": _weapon_name(summary.preferred_weapon),
	})
	for index: int in range(weapon_rows.size()):
		var row: Label = weapon_rows[index]
		row.visible = index < ranked.size()
		if not row.visible:
			row.text = ""
			continue
		var entry: Dictionary = ranked[index]
		var count: int = int(entry.count)
		var percent: int = roundi(
			float(count) * 100.0 / float(maxi(summary.total_enemies_defeated, 1))
		)
		row.text = L10n.t("debrief.weapon_row", {
			"weapon": _weapon_name(entry.id as StringName),
			"kills": count,
			"percent": percent,
		})
	if ranked.is_empty():
		weapon_rows[0].visible = true
		weapon_rows[0].text = L10n.t("debrief.no_weapon_data")


func _update_enemies(summary: RunSummarySnapshot) -> void:
	enemy_total_label.text = L10n.t("debrief.enemy_totals", {
		"kills": summary.total_enemies_defeated,
		"types": summary.unique_enemy_types,
	})
	var ranked: Array[Dictionary] = CombatRunTelemetry.ranked_entries(
		summary.enemy_kills,
		ENEMY_ROW_COUNT
	)
	for index: int in range(enemy_rows.size()):
		var row: Label = enemy_rows[index]
		row.visible = index < ranked.size()
		if not row.visible:
			row.text = ""
			continue
		var entry: Dictionary = ranked[index]
		row.text = L10n.t("debrief.enemy_row", {
			"enemy": _enemy_name(entry.id as StringName),
			"kills": int(entry.count),
		})
	if ranked.is_empty():
		enemy_rows[0].visible = true
		enemy_rows[0].text = L10n.t("debrief.no_enemy_data")


func _combo_title(tier: int) -> String:
	if tier <= 0:
		return L10n.t("debrief.combo.none")
	var selected_tier: int = 0
	for milestone: int in ComboHeraldCatalog.milestone_counts():
		if milestone <= tier:
			selected_tier = milestone
	var profile: Dictionary = ComboHeraldCatalog.profile_for(selected_tier)
	if profile.is_empty():
		return L10n.t("debrief.combo.single")
	return L10n.t(String(profile.get(&"title_key", "debrief.combo.single")))


func _ranking_row(entry: Dictionary, compact: bool = false) -> String:
	return L10n.t(
		"debrief.ranking_row_compact" if compact else "debrief.ranking_row",
		{
		"rank": int(entry.get("rank", 0)),
		"callsign": String(entry.get("callsign", "UNKNOWN")),
		"tier": int(entry.get("highest_combo_tier", 0)),
		"score": "%08d" % int(entry.get("best_score", entry.get("score", 0))),
		"weapon": _weapon_name(StringName(entry.get("preferred_weapon", "UNKNOWN"))),
		}
	)


func _rank_history_locally(history: Array[Dictionary], limit: int) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for entry: Dictionary in history:
		ranked.append(entry.duplicate(true))
	ranked.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_tier: int = int(first.get("highest_combo_tier", 0))
		var second_tier: int = int(second.get("highest_combo_tier", 0))
		if first_tier != second_tier:
			return first_tier > second_tier
		return int(first.get("score", 0)) > int(second.get("score", 0))
	)
	if ranked.size() > limit:
		ranked.resize(limit)
	for index: int in range(ranked.size()):
		ranked[index]["rank"] = index + 1
		ranked[index]["callsign"] = callsign_edit.text
	return ranked


func _weapon_name(weapon_id: StringName) -> String:
	var key: String = "debrief.weapon.%s" % String(weapon_id).to_lower()
	var translated: String = L10n.t(key)
	return _prettify_identifier(weapon_id) if translated == key else translated


func _enemy_name(enemy_id: StringName) -> String:
	var raw: String = String(enemy_id)
	if raw.begins_with("boss:"):
		var boss_id: String = raw.trim_prefix("boss:")
		var boss_key: String = "boss.%s.name" % boss_id
		var boss_name: String = L10n.t(boss_key)
		return _prettify_identifier(StringName(boss_id)) if boss_name == boss_key else boss_name
	if enemy_id in [&"soldier", &"tank", &"helicopter"]:
		return L10n.t("debrief.enemy.%s" % raw)
	var profile: Dictionary = EnemyArchetypeCatalog.profile(enemy_id)
	if not profile.is_empty():
		return String(profile.get("display_name", _prettify_identifier(enemy_id)))
	return _prettify_identifier(enemy_id)


func _killer_name(source_id: StringName) -> String:
	if source_id == DefeatSourceResolver.ENVIRONMENT:
		return L10n.t("debrief.killer.environment")
	if source_id.is_empty() or source_id == DefeatSourceResolver.UNKNOWN:
		return L10n.t("debrief.killer.unknown")
	return _enemy_name(source_id)


func _prettify_identifier(identifier: StringName) -> String:
	return String(identifier).replace("_", " ").replace(":", " ").to_upper()


func _apply_landscape_layout(viewport_size: Vector2) -> void:
	_place_content(viewport_size, LANDSCAPE_SIZE, 40.0)
	main_panel.position = Vector2.ZERO
	main_panel.size = LANDSCAPE_SIZE
	_layout_tabs(20.0, 10.0, 1120.0, 42.0)
	var body_offset: float = _tabs_bottom() + CONTROL_GROUP_MARGIN - 58.0
	result_label.position = Vector2(30.0, 58.0 + body_offset)
	result_label.size = Vector2(590.0, 44.0)
	result_label.add_theme_font_size_override(&"font_size", 34)
	grade_label.position = Vector2(655.0, 56.0 + body_offset)
	grade_label.size = Vector2(180.0, 48.0)
	grade_label.add_theme_font_size_override(&"font_size", 28)
	score_label.position = Vector2(845.0, 56.0 + body_offset)
	score_label.size = Vector2(285.0, 48.0)
	score_label.add_theme_font_size_override(&"font_size", 28)
	_place_killer_inline(grade_label.position.x - 20.0)
	run_meta_label.position = Vector2(30.0, 100.0 + body_offset)
	run_meta_label.size = Vector2(1100.0, 24.0)
	combo_panel.position = Vector2(20.0, 130.0 + body_offset)
	combo_panel.size = Vector2(535.0, 190.0)
	crest.position = Vector2(36.0, 153.0 + body_offset)
	crest.size = Vector2(140.0, 140.0)
	combo_header_label.position = Vector2(194.0, 140.0 + body_offset)
	combo_header_label.size = Vector2(335.0, 24.0)
	combo_value_label.position = Vector2(194.0, 166.0 + body_offset)
	combo_value_label.size = Vector2(325.0, 74.0)
	combo_value_label.add_theme_font_size_override(&"font_size", 25)
	combo_detail_label.position = Vector2(194.0, 242.0 + body_offset)
	combo_detail_label.size = Vector2(325.0, 26.0)
	personal_best_label.position = Vector2(194.0, 272.0 + body_offset)
	personal_best_label.size = Vector2(325.0, 30.0)
	career_panel.position = Vector2(20.0, 330.0 + body_offset)
	career_panel.size = Vector2(535.0, 174.0)
	career_header_label.position = Vector2(40.0, 340.0 + body_offset)
	career_header_label.size = Vector2(495.0, 28.0)
	career_value_label.position = Vector2(40.0, 372.0 + body_offset)
	career_value_label.size = Vector2(495.0, 116.0)
	weapon_panel.position = Vector2(565.0, 130.0 + body_offset)
	weapon_panel.size = Vector2(575.0, 180.0)
	weapon_header_label.position = Vector2(585.0, 140.0 + body_offset)
	weapon_header_label.size = Vector2(535.0, 24.0)
	weapon_preferred_label.position = Vector2(585.0, 167.0 + body_offset)
	weapon_preferred_label.size = Vector2(535.0, 28.0)
	for index: int in range(weapon_rows.size()):
		weapon_rows[index].position = Vector2(
			585.0, 199.0 + body_offset + float(index) * 31.0
		)
		weapon_rows[index].size = Vector2(535.0, 28.0)
	enemy_panel.position = Vector2(565.0, 320.0 + body_offset)
	enemy_panel.size = Vector2(575.0, 184.0)
	enemy_header_label.position = Vector2(585.0, 330.0 + body_offset)
	enemy_header_label.size = Vector2(310.0, 24.0)
	enemy_total_label.position = Vector2(895.0, 330.0 + body_offset)
	enemy_total_label.size = Vector2(225.0, 24.0)
	enemy_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for index: int in range(enemy_rows.size()):
		enemy_rows[index].position = Vector2(
			585.0, 358.0 + body_offset + float(index) * 34.0
		)
		enemy_rows[index].size = Vector2(535.0, 30.0)
	_layout_career_landscape()
	_layout_global_landscape()
	recommendation_label.position = Vector2(30.0, 526.0)
	recommendation_label.size = Vector2(1100.0, 24.0)
	_apply_after_action_header_bottom_padding()
	retry_button.position = Vector2(190.0, 574.0 + AFTER_ACTION_HEADER_BOTTOM_PADDING)
	retry_button.size = Vector2(350.0, 60.0)
	title_button.position = Vector2(620.0, 574.0 + AFTER_ACTION_HEADER_BOTTOM_PADDING)
	title_button.size = Vector2(350.0, 60.0)


func _layout_career_landscape() -> void:
	career_profile_panel.position = Vector2(20.0, 89.0)
	career_profile_panel.size = Vector2(330.0, 186.0)
	callsign_header_label.position = Vector2(38.0, 101.0)
	callsign_header_label.size = Vector2(294.0, 26.0)
	callsign_edit.position = Vector2(38.0, 135.0)
	callsign_edit.size = Vector2(294.0, 44.0)
	callsign_save_button.position = Vector2(38.0, 187.0)
	callsign_save_button.size = Vector2(142.0, 48.0)
	callsign_status_label.position = Vector2(188.0, 187.0)
	callsign_status_label.size = Vector2(144.0, 48.0)
	local_board_panel.position = Vector2(20.0, 285.0)
	local_board_panel.size = Vector2(
		330.0,
		265.0 + AFTER_ACTION_HEADER_BOTTOM_PADDING
	)
	local_board_header_label.position = Vector2(38.0, 295.0)
	local_board_header_label.size = Vector2(294.0, 26.0)
	for index: int in range(local_board_rows.size()):
		local_board_rows[index].position = Vector2(38.0, 327.0 + float(index) * 43.0)
		local_board_rows[index].size = Vector2(294.0, 38.0)
		local_board_rows[index].add_theme_font_size_override(&"font_size", 12)
	chart_panel.position = Vector2(360.0, 89.0)
	chart_panel.size = Vector2(780.0, 461.0)
	chart_header_label.position = Vector2(378.0, 99.0)
	chart_header_label.size = Vector2(380.0, 26.0)
	chart_kills_button.position = Vector2(900.0, 97.0)
	chart_kills_button.size = Vector2(104.0, 36.0)
	chart_share_button.position = Vector2(1012.0, 97.0)
	chart_share_button.size = Vector2(104.0, 36.0)
	weapon_history_chart.position = Vector2(378.0, 141.0)
	weapon_history_chart.size = Vector2(744.0, 404.0)


func _layout_global_landscape() -> void:
	global_panel.position = Vector2(20.0, 89.0)
	global_panel.size = Vector2(
		1120.0,
		461.0 + AFTER_ACTION_HEADER_BOTTOM_PADDING
	)
	global_header_label.position = Vector2(40.0, 101.0)
	global_header_label.size = Vector2(360.0, 28.0)
	global_status_label.position = Vector2(410.0, 101.0)
	global_status_label.size = Vector2(420.0, 28.0)
	global_refresh_button.position = Vector2(930.0, 97.0)
	global_refresh_button.size = Vector2(190.0, 42.0)
	global_callsign_header_label.position = Vector2(40.0, 140.0)
	global_callsign_header_label.size = Vector2(260.0, 26.0)
	global_callsign_edit.position = Vector2(310.0, 137.0)
	global_callsign_edit.size = Vector2(360.0, 48.0)
	global_callsign_save_button.position = Vector2(682.0, 137.0)
	global_callsign_save_button.size = Vector2(218.0, 48.0)
	global_callsign_status_label.position = Vector2(912.0, 137.0)
	global_callsign_status_label.size = Vector2(208.0, 48.0)
	personal_rank_label.position = Vector2(40.0, 191.0)
	personal_rank_label.size = Vector2(1080.0, 32.0)
	for index: int in range(global_rows.size()):
		global_row_highlights[index].position = Vector2(
			32.0, 223.0 + float(index) * 31.0
		)
		global_row_highlights[index].size = Vector2(1096.0, 31.0)
		global_rows[index].position = Vector2(40.0, 226.0 + float(index) * 31.0)
		global_rows[index].size = Vector2(1080.0, 29.0)
		global_rows[index].add_theme_font_size_override(&"font_size", 13)


func _apply_portrait_layout(viewport_size: Vector2) -> void:
	_place_content(viewport_size, PORTRAIT_SIZE, 24.0)
	main_panel.position = Vector2.ZERO
	main_panel.size = PORTRAIT_SIZE
	_layout_tabs(16.0, 12.0, 640.0, 50.0)
	var body_offset: float = _tabs_bottom() + CONTROL_GROUP_MARGIN - 70.0
	result_label.position = Vector2(20.0, 70.0 + body_offset)
	result_label.size = Vector2(632.0, 44.0)
	result_label.add_theme_font_size_override(&"font_size", 32)
	grade_label.position = Vector2(20.0, 116.0 + body_offset)
	grade_label.size = Vector2(190.0, 42.0)
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	grade_label.add_theme_font_size_override(&"font_size", 26)
	score_label.position = Vector2(220.0, 116.0 + body_offset)
	score_label.size = Vector2(432.0, 42.0)
	score_label.add_theme_font_size_override(&"font_size", 26)
	_place_killer_inline(652.0)
	run_meta_label.position = Vector2(20.0, 160.0 + body_offset)
	run_meta_label.size = Vector2(632.0, 24.0)
	combo_panel.position = Vector2(16.0, 192.0 + body_offset)
	combo_panel.size = Vector2(640.0, 180.0)
	crest.position = Vector2(30.0, 220.0 + body_offset)
	crest.size = Vector2(124.0, 124.0)
	combo_header_label.position = Vector2(174.0, 204.0 + body_offset)
	combo_header_label.size = Vector2(458.0, 24.0)
	combo_value_label.position = Vector2(174.0, 232.0 + body_offset)
	combo_value_label.size = Vector2(458.0, 70.0)
	combo_value_label.add_theme_font_size_override(&"font_size", 23)
	combo_detail_label.position = Vector2(174.0, 304.0 + body_offset)
	combo_detail_label.size = Vector2(458.0, 24.0)
	personal_best_label.position = Vector2(174.0, 332.0 + body_offset)
	personal_best_label.size = Vector2(458.0, 28.0)
	weapon_panel.position = Vector2(16.0, 382.0 + body_offset)
	weapon_panel.size = Vector2(640.0, 174.0)
	weapon_header_label.position = Vector2(32.0, 392.0 + body_offset)
	weapon_header_label.size = Vector2(608.0, 24.0)
	weapon_preferred_label.position = Vector2(32.0, 420.0 + body_offset)
	weapon_preferred_label.size = Vector2(608.0, 28.0)
	for index: int in range(weapon_rows.size()):
		weapon_rows[index].position = Vector2(
			32.0, 450.0 + body_offset + float(index) * 30.0
		)
		weapon_rows[index].size = Vector2(608.0, 28.0)
		weapon_rows[index].add_theme_font_size_override(&"font_size", 14)
	enemy_panel.position = Vector2(16.0, 566.0 + body_offset)
	enemy_panel.size = Vector2(640.0, 190.0)
	enemy_header_label.position = Vector2(32.0, 576.0 + body_offset)
	enemy_header_label.size = Vector2(340.0, 24.0)
	enemy_total_label.position = Vector2(372.0, 576.0 + body_offset)
	enemy_total_label.size = Vector2(268.0, 24.0)
	enemy_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for index: int in range(enemy_rows.size()):
		enemy_rows[index].position = Vector2(
			32.0, 606.0 + body_offset + float(index) * 34.0
		)
		enemy_rows[index].size = Vector2(608.0, 30.0)
		enemy_rows[index].add_theme_font_size_override(&"font_size", 14)
	career_panel.position = Vector2(16.0, 766.0 + body_offset)
	career_panel.size = Vector2(640.0, 162.0)
	career_header_label.position = Vector2(32.0, 776.0 + body_offset)
	career_header_label.size = Vector2(608.0, 24.0)
	career_value_label.position = Vector2(32.0, 804.0 + body_offset)
	career_value_label.size = Vector2(608.0, 110.0)
	career_value_label.add_theme_font_size_override(&"font_size", 15)
	_layout_career_portrait()
	_layout_global_portrait()
	recommendation_label.position = Vector2(24.0, 986.0)
	recommendation_label.size = Vector2(624.0, 28.0)
	_apply_after_action_header_bottom_padding()
	retry_button.position = Vector2(24.0, 1038.0 + AFTER_ACTION_HEADER_BOTTOM_PADDING)
	retry_button.size = Vector2(296.0, 66.0)
	title_button.position = Vector2(352.0, 1038.0 + AFTER_ACTION_HEADER_BOTTOM_PADDING)
	title_button.size = Vector2(296.0, 66.0)


func _layout_career_portrait() -> void:
	career_profile_panel.position = Vector2(16.0, 91.0)
	career_profile_panel.size = Vector2(640.0, 150.0)
	callsign_header_label.position = Vector2(32.0, 101.0)
	callsign_header_label.size = Vector2(608.0, 26.0)
	callsign_edit.position = Vector2(32.0, 133.0)
	callsign_edit.size = Vector2(392.0, 50.0)
	callsign_save_button.position = Vector2(438.0, 133.0)
	callsign_save_button.size = Vector2(202.0, 50.0)
	callsign_status_label.position = Vector2(32.0, 189.0)
	callsign_status_label.size = Vector2(608.0, 34.0)
	chart_panel.position = Vector2(16.0, 251.0)
	chart_panel.size = Vector2(640.0, 430.0)
	chart_header_label.position = Vector2(32.0, 261.0)
	chart_header_label.size = Vector2(340.0, 26.0)
	chart_kills_button.position = Vector2(408.0, 257.0)
	chart_kills_button.size = Vector2(108.0, 42.0)
	chart_share_button.position = Vector2(524.0, 257.0)
	chart_share_button.size = Vector2(116.0, 42.0)
	weapon_history_chart.position = Vector2(32.0, 309.0)
	weapon_history_chart.size = Vector2(608.0, 354.0)
	local_board_panel.position = Vector2(16.0, 691.0)
	local_board_panel.size = Vector2(
		640.0,
		323.0 + AFTER_ACTION_HEADER_BOTTOM_PADDING
	)
	local_board_header_label.position = Vector2(32.0, 701.0)
	local_board_header_label.size = Vector2(608.0, 26.0)
	for index: int in range(local_board_rows.size()):
		local_board_rows[index].position = Vector2(32.0, 735.0 + float(index) * 54.0)
		local_board_rows[index].size = Vector2(608.0, 48.0)
		local_board_rows[index].add_theme_font_size_override(&"font_size", 13)


func _layout_global_portrait() -> void:
	global_panel.position = Vector2(16.0, 91.0)
	global_panel.size = Vector2(
		640.0,
		923.0 + AFTER_ACTION_HEADER_BOTTOM_PADDING
	)
	global_header_label.position = Vector2(32.0, 103.0)
	global_header_label.size = Vector2(360.0, 28.0)
	global_status_label.position = Vector2(32.0, 137.0)
	global_status_label.size = Vector2(380.0, 28.0)
	global_refresh_button.position = Vector2(438.0, 111.0)
	global_refresh_button.size = Vector2(202.0, 54.0)
	global_callsign_header_label.position = Vector2(32.0, 179.0)
	global_callsign_header_label.size = Vector2(608.0, 26.0)
	global_callsign_edit.position = Vector2(32.0, 211.0)
	global_callsign_edit.size = Vector2(392.0, 50.0)
	global_callsign_save_button.position = Vector2(438.0, 211.0)
	global_callsign_save_button.size = Vector2(202.0, 50.0)
	global_callsign_status_label.position = Vector2(32.0, 267.0)
	global_callsign_status_label.size = Vector2(608.0, 34.0)
	personal_rank_label.position = Vector2(32.0, 307.0)
	personal_rank_label.size = Vector2(608.0, 42.0)
	for index: int in range(global_rows.size()):
		global_row_highlights[index].position = Vector2(
			24.0, 351.0 + float(index) * 64.0
		)
		global_row_highlights[index].size = Vector2(624.0, 64.0)
		global_rows[index].position = Vector2(32.0, 355.0 + float(index) * 64.0)
		global_rows[index].size = Vector2(608.0, 56.0)
		global_rows[index].add_theme_font_size_override(&"font_size", 13)


func _apply_after_action_header_bottom_padding() -> void:
	for control: Control in _after_action_controls:
		if control in [result_label, grade_label, score_label, killer_label]:
			continue
		control.position.y += AFTER_ACTION_HEADER_BOTTOM_PADDING


func _place_killer_inline(max_right: float) -> void:
	var result_font: Font = result_label.get_theme_font(&"font")
	var result_font_size: int = result_label.get_theme_font_size(&"font_size")
	var result_width: float = result_font.get_string_size(
		result_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		result_font_size
	).x
	var killer_x: float = result_label.position.x + result_width + KILLER_INLINE_GAP
	killer_label.position = Vector2(killer_x, result_label.position.y)
	killer_label.size = Vector2(maxf(max_right - killer_x, 0.0), result_label.size.y)


func _layout_tabs(x: float, y: float, total_width: float, height: float) -> void:
	var gap: float = 8.0
	var tab_width: float = (total_width - gap * 2.0) / 3.0
	for index: int in range(tab_buttons.size()):
		tab_buttons[index].position = Vector2(x + float(index) * (tab_width + gap), y)
		tab_buttons[index].size = Vector2(tab_width, height)
		tab_buttons[index].add_theme_font_size_override(&"font_size", 16)


func _tabs_bottom() -> float:
	var bottom: float = 0.0
	for tab: Button in tab_buttons:
		bottom = maxf(bottom, tab.position.y + tab.size.y)
	return bottom


func _place_content(viewport_size: Vector2, design_size: Vector2, margin: float) -> void:
	var scale_factor: float = minf(
		minf(
			(viewport_size.x - margin * 2.0) / design_size.x,
			(viewport_size.y - margin * 2.0) / design_size.y
		),
		1.0
	)
	scale_factor = maxf(scale_factor, 0.45)
	content_root.scale = Vector2.ONE * scale_factor
	content_root.size = design_size
	content_root.position = (viewport_size - design_size * scale_factor) * 0.5


func _set_controls_visible(controls: Array[Control], show: bool) -> void:
	for control: Control in controls:
		control.visible = show


func _visible_row_text(rows: Array[Label]) -> PackedStringArray:
	var text: PackedStringArray = []
	for row: Label in rows:
		if row.visible:
			text.append(row.text)
	return text


func _controls_union_rect(controls: Array[Button]) -> Rect2:
	if controls.is_empty():
		return Rect2()
	var combined: Rect2 = _scaled_rect(controls[0])
	for index: int in range(1, controls.size()):
		combined = combined.merge(_scaled_rect(controls[index]))
	return combined


func _page_content_rect() -> Rect2:
	match current_page:
		Page.CAREER:
			return _scaled_rect(career_profile_panel)
		Page.GLOBAL:
			return _scaled_rect(global_panel)
	return _scaled_rect(result_label)


func _bottom_content_rect() -> Rect2:
	match current_page:
		Page.CAREER:
			return _scaled_rect(local_board_panel)
		Page.GLOBAL:
			return _scaled_rect(global_panel)
	return _scaled_rect(recommendation_label)


func _scaled_rect(control: Control) -> Rect2:
	if control == null or content_root == null:
		return Rect2()
	return Rect2(
		content_root.position + control.position * content_root.scale,
		control.size * content_root.scale
	)
