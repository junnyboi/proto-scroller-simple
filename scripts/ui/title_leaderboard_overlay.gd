class_name TitleLeaderboardOverlay
extends Control

signal global_refresh_requested
signal callsign_saved(callsign: String)
signal closed

enum Tab { LOCAL, GLOBAL }

const ROW_COUNT: int = 10
const BACKGROUND: Color = Color(0.002, 0.012, 0.022, 0.94)
const PANEL: Color = Color(0.004, 0.027, 0.050, 0.985)
const ROW_BACKGROUND: Color = Color(0.01, 0.044, 0.06, 0.82)
const CYAN: Color = Color("72e5ec")
const MUTED: Color = Color("a8bbc2")
const AMBER: Color = Color("f1b36f")
const RED: Color = Color("ff695c")

var global_navigation_enabled: bool = false
var profile_store: PlayerCombatProfileStore
var current_tab: Tab = Tab.LOCAL
var global_state: StringName = &"native_local"
var callsign_uplink_state: StringName = &"idle"
var _global_entries: Array[Dictionary] = []
var _personal_rank: Dictionary = {}
var _return_focus: Control
var _portrait_layout: bool = false
var _callsign_status_key: String = ""

var scrim: ColorRect
var backdrop: Button
var panel: Panel
var heading_label: Label
var local_tab_button: Button
var global_tab_button: Button
var callsign_header_label: Label
var callsign_edit: LineEdit
var callsign_save_button: Button
var callsign_status_label: Label
var board_heading_label: Label
var status_label: Label
var personal_rank_label: Label
var row_backgrounds: Array[ColorRect] = []
var row_labels: Array[Label] = []
var refresh_button: Button
var close_button: Button


func _ready() -> void:
	name = "TitleLeaderboardOverlay"
	z_index = 130
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	refresh_locale()
	apply_responsive_layout(get_viewport_rect().size)


func configure_profile(store: PlayerCombatProfileStore) -> void:
	if profile_store != null and profile_store.profile_changed.is_connected(
		_on_profile_changed
	):
		profile_store.profile_changed.disconnect(_on_profile_changed)
	profile_store = store
	if profile_store != null and not profile_store.profile_changed.is_connected(
		_on_profile_changed
	):
		profile_store.profile_changed.connect(_on_profile_changed)
	_sync_callsign_edit()
	_refresh_rows()


func open(return_focus: Control = null) -> void:
	_return_focus = return_focus
	refresh_locale()
	callsign_uplink_state = &"idle"
	_callsign_status_key = ""
	callsign_status_label.text = ""
	_sync_callsign_edit()
	set_tab(Tab.LOCAL)
	visible = true
	apply_responsive_layout(get_viewport_rect().size)
	local_tab_button.call_deferred("grab_focus")


func close(restore_focus: bool = true) -> bool:
	if not visible:
		return false
	visible = false
	if restore_focus and is_instance_valid(_return_focus):
		_return_focus.call_deferred("grab_focus")
	closed.emit()
	return true


func set_tab(tab: Tab) -> void:
	global_tab_button.visible = global_navigation_enabled
	if tab == Tab.GLOBAL and not global_navigation_enabled:
		tab = Tab.LOCAL
	current_tab = tab
	local_tab_button.set_pressed_no_signal(tab == Tab.LOCAL)
	global_tab_button.set_pressed_no_signal(tab == Tab.GLOBAL)
	_refresh_rows()
	if tab == Tab.GLOBAL:
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
	_refresh_rows()


func set_callsign_uplink_state(new_state: StringName) -> void:
	callsign_uplink_state = new_state
	if callsign_status_label == null:
		return
	if new_state == &"idle":
		_callsign_status_key = ""
		callsign_status_label.text = ""
		return
	var color: Color = MUTED
	if new_state == &"success":
		color = CYAN
	elif new_state in [&"failure", &"rejected"]:
		color = RED
	_show_callsign_status(
		"debrief.callsign.uplink.%s" % String(new_state),
		color
	)


func refresh_locale() -> void:
	if heading_label == null:
		return
	heading_label.text = L10n.t("title.leaderboard_heading")
	local_tab_button.text = L10n.t("title.leaderboard_local_tab")
	global_tab_button.text = L10n.t("title.leaderboard_global_tab")
	callsign_header_label.text = L10n.t("debrief.callsign.header")
	callsign_edit.placeholder_text = L10n.t("debrief.callsign.placeholder")
	callsign_save_button.text = L10n.t("debrief.callsign.save")
	if not _callsign_status_key.is_empty():
		callsign_status_label.text = L10n.t(_callsign_status_key)
	refresh_button.text = L10n.t("debrief.global.refresh")
	close_button.text = L10n.t("title.leaderboard_close")
	_refresh_rows()


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if panel == null:
		return
	_portrait_layout = viewport_size.y > viewport_size.x
	if _portrait_layout:
		_apply_portrait_layout(viewport_size)
	else:
		_apply_landscape_layout(viewport_size)
	_refresh_rows()


func _apply_landscape_layout(viewport_size: Vector2) -> void:
	var panel_size: Vector2 = Vector2(
		minf(viewport_size.x - 64.0, 1080.0),
		minf(viewport_size.y - 48.0, 648.0)
	)
	panel.position = (viewport_size - panel_size) * 0.5
	panel.size = panel_size
	var content_width: float = panel_size.x - 64.0
	_set_rect(heading_label, Rect2(32.0, 20.0, content_width, 42.0))
	var tab_width: float = (content_width - 12.0) * 0.5
	_set_rect(local_tab_button, Rect2(32.0, 70.0, tab_width, 52.0))
	_set_rect(global_tab_button, Rect2(44.0 + tab_width, 70.0, tab_width, 52.0))
	var callsign_header_width: float = minf(260.0, content_width * 0.26)
	var callsign_edit_width: float = minf(300.0, content_width * 0.30)
	var callsign_save_width: float = minf(220.0, content_width * 0.22)
	var callsign_x: float = 32.0
	_set_rect(
		callsign_header_label,
		Rect2(callsign_x, 130.0, callsign_header_width, 44.0)
	)
	callsign_x += callsign_header_width + 12.0
	_set_rect(callsign_edit, Rect2(callsign_x, 130.0, callsign_edit_width, 44.0))
	callsign_x += callsign_edit_width + 12.0
	_set_rect(
		callsign_save_button,
		Rect2(callsign_x, 130.0, callsign_save_width, 44.0)
	)
	_set_rect(
		callsign_status_label,
		Rect2(32.0 + content_width * 0.38, 178.0, content_width * 0.62, 32.0)
	)
	callsign_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_set_rect(board_heading_label, Rect2(32.0, 178.0, content_width * 0.38, 32.0))
	_set_rect(status_label, Rect2(32.0, 208.0, content_width * 0.58, 30.0))
	_set_rect(
		personal_rank_label,
		Rect2(32.0 + content_width * 0.58, 208.0, content_width * 0.42, 30.0)
	)
	var rows_top: float = 240.0
	var row_height: float = 34.0
	for index: int in range(ROW_COUNT):
		var row_rect: Rect2 = Rect2(
			32.0,
			rows_top + float(index) * row_height,
			content_width,
			row_height - 2.0
		)
		_set_rect(row_backgrounds[index], row_rect)
		_set_rect(row_labels[index], Rect2(
			row_rect.position + Vector2(10.0, 0.0),
			row_rect.size - Vector2(20.0, 0.0)
		))
	var action_y: float = panel_size.y - 62.0
	_set_rect(refresh_button, Rect2(32.0, action_y, 260.0, 44.0))
	_set_rect(close_button, Rect2((panel_size.x - 260.0) * 0.5 if not global_navigation_enabled else panel_size.x - 292.0, action_y, 260.0, 44.0))
	_set_font_sizes(30, 24, 24)


func _apply_portrait_layout(viewport_size: Vector2) -> void:
	var panel_size: Vector2 = Vector2(
		viewport_size.x - 40.0,
		minf(viewport_size.y - 56.0, 1176.0)
	)
	panel.position = (viewport_size - panel_size) * 0.5
	panel.size = panel_size
	var content_width: float = panel_size.x - 48.0
	_set_rect(heading_label, Rect2(24.0, 24.0, content_width, 48.0))
	var tab_width: float = (content_width - 12.0) * 0.5
	_set_rect(local_tab_button, Rect2(24.0, 82.0, tab_width, 58.0))
	_set_rect(global_tab_button, Rect2(36.0 + tab_width, 82.0, tab_width, 58.0))
	_set_rect(callsign_header_label, Rect2(24.0, 154.0, content_width, 36.0))
	var callsign_edit_width: float = maxf(content_width - 232.0, 220.0)
	_set_rect(callsign_edit, Rect2(24.0, 194.0, callsign_edit_width, 54.0))
	_set_rect(
		callsign_save_button,
		Rect2(36.0 + callsign_edit_width, 194.0, content_width - callsign_edit_width - 12.0, 54.0)
	)
	_set_rect(callsign_status_label, Rect2(24.0, 252.0, content_width, 36.0))
	callsign_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_set_rect(board_heading_label, Rect2(24.0, 296.0, content_width, 40.0))
	_set_rect(status_label, Rect2(24.0, 338.0, content_width, 36.0))
	_set_rect(personal_rank_label, Rect2(24.0, 374.0, content_width, 36.0))
	var rows_top: float = 418.0
	var row_height: float = 61.0
	for index: int in range(ROW_COUNT):
		var row_rect: Rect2 = Rect2(
			24.0,
			rows_top + float(index) * row_height,
			content_width,
			row_height - 5.0
		)
		_set_rect(row_backgrounds[index], row_rect)
		_set_rect(row_labels[index], Rect2(
			row_rect.position + Vector2(12.0, 0.0),
			row_rect.size - Vector2(24.0, 0.0)
		))
	var action_y: float = panel_size.y - 78.0
	_set_rect(refresh_button, Rect2(24.0, action_y, 252.0, 58.0))
	_set_rect(close_button, Rect2((panel_size.x - 252.0) * 0.5 if not global_navigation_enabled else panel_size.x - 276.0, action_y, 252.0, 58.0))
	_set_font_sizes(32, 24, 24)


func _refresh_rows() -> void:
	if board_heading_label == null:
		return
	var global_tab: bool = current_tab == Tab.GLOBAL
	board_heading_label.text = L10n.t(
		"debrief.global.header" if global_tab else "debrief.local.header"
	)
	status_label.visible = global_tab
	personal_rank_label.visible = global_tab
	refresh_button.visible = global_tab
	status_label.text = L10n.t("debrief.global.state.%s" % String(global_state))
	status_label.modulate = RED if global_state == &"local_fallback" else MUTED
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
	var entries: Array[Dictionary] = []
	if global_tab:
		for entry: Dictionary in _global_entries:
			entries.append(entry)
		if entries.is_empty() and profile_store != null and global_state != &"online":
			entries = profile_store.local_leaderboard(ROW_COUNT)
	elif profile_store != null:
		entries = profile_store.local_leaderboard(ROW_COUNT)
	for index: int in range(ROW_COUNT):
		var populated: bool = index < entries.size()
		row_backgrounds[index].visible = populated
		row_labels[index].visible = populated
		row_labels[index].text = (
			_ranking_row(entries[index], _portrait_layout) if populated else ""
		)
		var personal: bool = populated and global_tab and _is_personal_entry(entries[index])
		row_labels[index].modulate = AMBER if personal else MUTED
		row_backgrounds[index].color = (
			Color(0.12, 0.52, 0.62, 0.28) if personal else ROW_BACKGROUND
		)
	if entries.is_empty():
		row_backgrounds[0].visible = true
		row_labels[0].visible = true
		row_labels[0].text = L10n.t(
			"debrief.global.empty" if global_tab else "debrief.local.empty"
		)
		row_labels[0].modulate = MUTED


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


func _weapon_name(weapon_id: StringName) -> String:
	var key: String = "debrief.weapon.%s" % String(weapon_id).to_lower()
	var translated: String = L10n.t(key)
	return String(weapon_id).replace("_", " ").capitalize() if translated == key else translated


func _is_personal_entry(entry: Dictionary) -> bool:
	var personal_rank: int = int(_personal_rank.get("rank", 0))
	return personal_rank > 0 and int(entry.get("rank", 0)) == personal_rank


func _on_profile_changed(_profile: Dictionary) -> void:
	_sync_callsign_edit()
	_refresh_rows()


func _save_callsign() -> void:
	callsign_uplink_state = &"idle"
	if profile_store == null:
		_show_callsign_status("debrief.callsign.unavailable", RED)
		return
	var result: StringName = profile_store.set_callsign(callsign_edit.text)
	if result != &"ok":
		_show_callsign_status(
			"debrief.callsign.%s" % String(result),
			RED
		)
		return
	var saved_callsign: String = profile_store.callsign()
	callsign_edit.text = saved_callsign
	_update_global_callsign(saved_callsign)
	if OS.has_feature("web"):
		set_callsign_uplink_state(&"pending")
	else:
		_show_callsign_status("debrief.callsign.saved", CYAN)
	_refresh_rows()
	callsign_saved.emit(saved_callsign)


func _sync_callsign_edit() -> void:
	if callsign_edit != null and profile_store != null:
		callsign_edit.text = profile_store.callsign()


func _show_callsign_status(key: String, color: Color) -> void:
	_callsign_status_key = key
	callsign_status_label.text = L10n.t(key)
	callsign_status_label.modulate = color


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


func _build() -> void:
	scrim = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = BACKGROUND
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	backdrop = Button.new()
	backdrop.name = "Backdrop"
	backdrop.flat = true
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.pressed.connect(close)
	add_child(backdrop)
	panel = Panel.new()
	panel.name = "LeaderboardPanel"
	panel.add_theme_stylebox_override(&"panel", _panel_style())
	add_child(panel)
	heading_label = _make_label("Heading", CYAN)
	panel.add_child(heading_label)
	local_tab_button = _make_button("LocalTab", true)
	local_tab_button.pressed.connect(set_tab.bind(Tab.LOCAL))
	panel.add_child(local_tab_button)
	global_tab_button = _make_button("GlobalTab", true)
	global_tab_button.pressed.connect(set_tab.bind(Tab.GLOBAL))
	panel.add_child(global_tab_button)
	callsign_header_label = _make_label("CallsignHeader", CYAN)
	panel.add_child(callsign_header_label)
	callsign_edit = _make_callsign_edit()
	panel.add_child(callsign_edit)
	callsign_save_button = _make_button("CallsignSaveButton")
	callsign_save_button.pressed.connect(_save_callsign)
	panel.add_child(callsign_save_button)
	callsign_edit.text_submitted.connect(func(_value: String) -> void: _save_callsign())
	callsign_status_label = _make_label("CallsignStatus", MUTED)
	callsign_status_label.clip_text = true
	panel.add_child(callsign_status_label)
	board_heading_label = _make_label("BoardHeading", CYAN)
	panel.add_child(board_heading_label)
	status_label = _make_label("GlobalStatus", MUTED)
	panel.add_child(status_label)
	personal_rank_label = _make_label("PersonalRank", AMBER)
	personal_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(personal_rank_label)
	for index: int in range(ROW_COUNT):
		var background: ColorRect = ColorRect.new()
		background.name = "RowBackground%d" % (index + 1)
		background.color = ROW_BACKGROUND
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(background)
		row_backgrounds.append(background)
		var row: Label = _make_label("LeaderboardRow%d" % (index + 1), MUTED)
		row.clip_text = true
		panel.add_child(row)
		row_labels.append(row)
	refresh_button = _make_button("RefreshButton")
	refresh_button.pressed.connect(func() -> void: global_refresh_requested.emit())
	panel.add_child(refresh_button)
	close_button = _make_button("CloseButton")
	close_button.pressed.connect(close)
	panel.add_child(close_button)


func _make_label(node_name: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = color
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_button(node_name: String, toggle: bool = false) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.toggle_mode = toggle
	button.add_theme_color_override(&"font_color", MUTED)
	button.add_theme_color_override(&"font_hover_color", Color("defff7"))
	button.add_theme_color_override(&"font_pressed_color", Color("defff7"))
	button.add_theme_color_override(&"font_focus_color", CYAN)
	button.add_theme_stylebox_override(&"normal", _button_style(Color(0.004, 0.035, 0.055, 0.9), Color(0.2, 0.62, 0.58, 0.5)))
	button.add_theme_stylebox_override(&"hover", _button_style(Color(0.01, 0.08, 0.10, 0.96), CYAN))
	button.add_theme_stylebox_override(&"pressed", _button_style(Color(0.06, 0.24, 0.23, 0.98), CYAN))
	button.add_theme_stylebox_override(&"focus", _button_style(Color(0.01, 0.08, 0.10, 0.96), CYAN, 2))
	return button


func _make_callsign_edit() -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.name = "CallsignEdit"
	edit.max_length = PlayerCombatProfileStore.MAX_CALLSIGN_LENGTH
	edit.focus_mode = Control.FOCUS_ALL
	edit.clear_button_enabled = true
	edit.add_theme_color_override(&"font_color", MUTED)
	edit.add_theme_color_override(&"font_placeholder_color", Color(MUTED, 0.62))
	edit.add_theme_color_override(&"caret_color", CYAN)
	edit.add_theme_color_override(&"selection_color", Color(CYAN, 0.28))
	edit.add_theme_stylebox_override(
		&"normal",
		_button_style(Color(0.004, 0.035, 0.055, 0.9), Color(0.2, 0.62, 0.58, 0.5))
	)
	edit.add_theme_stylebox_override(
		&"focus",
		_button_style(Color(0.01, 0.08, 0.10, 0.96), CYAN, 2)
	)
	return edit


func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color(CYAN, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


func _button_style(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	return style


func _set_font_sizes(heading_size: int, body_size: int, button_size: int) -> void:
	heading_label.add_theme_font_size_override(&"font_size", heading_size)
	for label: Label in [
		callsign_header_label,
		callsign_status_label,
		board_heading_label,
		status_label,
		personal_rank_label,
	]:
		label.add_theme_font_size_override(&"font_size", body_size)
	callsign_edit.add_theme_font_size_override(&"font_size", body_size)
	for row: Label in row_labels:
		row.add_theme_font_size_override(&"font_size", body_size)
	for button: Button in [
		local_tab_button,
		global_tab_button,
		callsign_save_button,
		refresh_button,
		close_button,
	]:
		button.add_theme_font_size_override(&"font_size", button_size)


func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
