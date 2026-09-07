class_name CareerWeaponHistoryChart
extends Control

enum DisplayMode { KILLS, SHARE }

const MAX_RUNS: int = 12
const MAX_SERIES: int = 3
const BACKGROUND: Color = Color(0.008, 0.020, 0.029, 0.98)
const GRID: Color = Color(0.18, 0.34, 0.39, 0.42)
const TEXT: Color = Color("a9bdc4")
const SERIES_COLORS: Array[Color] = [
	Color("7ae4ff"),
	Color("f1b36f"),
	Color("ff695c"),
]

var display_mode: DisplayMode = DisplayMode.KILLS
var selected_index: int = -1
var _history: Array[Dictionary] = []
var _series_ids: Array[StringName] = []


func _ready() -> void:
	name = "CareerWeaponHistoryChart"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	L10n.apply_locale_font(self)


func set_history(history: Array[Dictionary]) -> void:
	_history.clear()
	var first_index: int = maxi(history.size() - MAX_RUNS, 0)
	for index: int in range(first_index, history.size()):
		_history.append(history[index].duplicate(true))
	_series_ids = _select_series(_history)
	selected_index = _history.size() - 1 if not _history.is_empty() else -1
	queue_redraw()


func set_display_mode(mode: DisplayMode) -> void:
	if display_mode == mode:
		return
	display_mode = mode
	queue_redraw()


func select_index(index: int) -> void:
	if _history.is_empty():
		selected_index = -1
	else:
		selected_index = clampi(index, 0, _history.size() - 1)
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"history_size": _history.size(),
		"series_ids": _series_ids.duplicate(),
		"selected_index": selected_index,
		"mode": DisplayMode.keys()[display_mode],
		"chart_rect": _chart_rect(),
	}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		select_index(_index_at_x((event as InputEventMouseMotion).position.x))
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		select_index(_index_at_x((event as InputEventMouseButton).position.x))
		grab_focus()
		accept_event()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		select_index(_index_at_x((event as InputEventScreenTouch).position.x))
		grab_focus()
		accept_event()
	elif event.is_action_pressed(&"ui_left"):
		select_index(selected_index - 1)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		select_index(selected_index + 1)
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	var font: Font = _drawing_font()
	var chart: Rect2 = _chart_rect()
	if _history.is_empty():
		_draw_centered_text(
			L10n.t("debrief.history.empty"),
			Rect2(Vector2.ZERO, size),
			16,
			TEXT,
			font
		)
		return
	for grid_index: int in range(5):
		var ratio: float = float(grid_index) / 4.0
		var y: float = lerpf(chart.end.y, chart.position.y, ratio)
		draw_line(Vector2(chart.position.x, y), Vector2(chart.end.x, y), GRID, 1.0)
	var maximum: float = 100.0 if display_mode == DisplayMode.SHARE else _maximum_value()
	maximum = maxf(maximum, 1.0)
	for series_index: int in range(_series_ids.size()):
		var points: PackedVector2Array = PackedVector2Array()
		for history_index: int in range(_history.size()):
			var value: float = _value_for(_history[history_index], _series_ids[series_index])
			points.append(Vector2(
				_x_for_index(history_index, chart),
				lerpf(chart.end.y, chart.position.y, clampf(value / maximum, 0.0, 1.0))
			))
		if points.size() > 1:
			draw_polyline(points, SERIES_COLORS[series_index], 3.0, true)
		for point_index: int in range(points.size()):
			var radius: float = 5.0 if point_index == selected_index else 3.0
			draw_circle(points[point_index], radius, SERIES_COLORS[series_index], true)
	_draw_axis_labels(chart, maximum, font)
	_draw_legend(font)
	_draw_selection(chart, font)


func _draw_axis_labels(chart: Rect2, maximum: float, font: Font) -> void:
	var font_size: int = 12
	for label_index: int in range(3):
		var ratio: float = float(label_index) / 2.0
		var value: int = roundi(maximum * ratio)
		var suffix: String = "%" if display_mode == DisplayMode.SHARE else ""
		var y: float = lerpf(chart.end.y, chart.position.y, ratio)
		draw_string(
			font,
			Vector2(6.0, y + 4.0),
			"%d%s" % [value, suffix],
			HORIZONTAL_ALIGNMENT_LEFT,
			44.0,
			font_size,
			TEXT
		)
	for history_index: int in range(_history.size()):
		if history_index % 2 != 0 and _history.size() > 7:
			continue
		var run_number: int = int(_history[history_index].get("run_number", history_index + 1))
		draw_string(
			font,
			Vector2(_x_for_index(history_index, chart) - 14.0, chart.end.y + 20.0),
			"#%d" % run_number,
			HORIZONTAL_ALIGNMENT_CENTER,
			28.0,
			font_size,
			TEXT
		)


func _draw_legend(font: Font) -> void:
	for index: int in range(_series_ids.size()):
		var x: float = 58.0 + float(index) * maxf((size.x - 75.0) / 3.0, 120.0)
		draw_circle(Vector2(x, 15.0), 4.0, SERIES_COLORS[index])
		draw_string(
			font,
			Vector2(x + 9.0, 19.0),
			_weapon_name(_series_ids[index]),
			HORIZONTAL_ALIGNMENT_LEFT,
			maxf((size.x - 110.0) / 3.0, 95.0),
			12,
			TEXT
		)


func _draw_selection(chart: Rect2, font: Font) -> void:
	if selected_index < 0 or selected_index >= _history.size():
		return
	var x: float = _x_for_index(selected_index, chart)
	draw_line(Vector2(x, chart.position.y), Vector2(x, chart.end.y), Color(1.0, 1.0, 1.0, 0.25), 1.0)
	var entry: Dictionary = _history[selected_index]
	var tooltip_width: float = minf(250.0, chart.size.x * 0.55)
	var tooltip_x: float = clampf(x + 12.0, chart.position.x, chart.end.x - tooltip_width)
	var tooltip: Rect2 = Rect2(tooltip_x, chart.position.y + 10.0, tooltip_width, 78.0)
	draw_rect(tooltip, Color(0.02, 0.055, 0.068, 0.98), true)
	draw_rect(tooltip, Color("7ae4ff"), false, 1.0)
	var details: String = L10n.t("debrief.history.tooltip", {
		"run": int(entry.get("run_number", selected_index + 1)),
		"score": "%08d" % int(entry.get("score", 0)),
		"tier": int(entry.get("highest_combo_tier", 0)),
		"weapon": _weapon_name(StringName(entry.get("preferred_weapon", "UNKNOWN"))),
	})
	draw_multiline_string(
		font,
		tooltip.position + Vector2(10.0, 20.0),
		details,
		HORIZONTAL_ALIGNMENT_LEFT,
		tooltip.size.x - 20.0,
		13,
		-1,
		TEXT
	)


func _draw_centered_text(
	text: String,
	rect: Rect2,
	font_size: int,
	color: Color,
	font: Font
) -> void:
	var text_size: Vector2 = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	)
	draw_string(
		font,
		rect.position + (rect.size - text_size) * 0.5 + Vector2(0.0, text_size.y),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)


func _drawing_font() -> Font:
	return get_theme_font(&"font")


func _select_series(history: Array[Dictionary]) -> Array[StringName]:
	var totals: Dictionary = {}
	for entry: Dictionary in history:
		var counts: Dictionary = entry.get("weapon_kills", {}) as Dictionary
		for key: Variant in counts:
			var identifier: StringName = StringName(key)
			totals[identifier] = int(totals.get(identifier, 0)) + maxi(int(counts[key]), 0)
	var selected: Array[StringName] = []
	for ranked: Dictionary in CombatRunTelemetry.ranked_entries(totals, MAX_SERIES):
		selected.append(ranked.id as StringName)
	return selected


func _maximum_value() -> float:
	var maximum: float = 1.0
	for entry: Dictionary in _history:
		for weapon_id: StringName in _series_ids:
			maximum = maxf(maximum, _value_for(entry, weapon_id))
	return maximum


func _value_for(entry: Dictionary, weapon_id: StringName) -> float:
	var counts: Dictionary = entry.get("weapon_kills", {}) as Dictionary
	var value: float = float(maxi(int(counts.get(String(weapon_id), counts.get(weapon_id, 0))), 0))
	if display_mode != DisplayMode.SHARE:
		return value
	var total: int = 0
	for count: Variant in counts.values():
		total += maxi(int(count), 0)
	return 0.0 if total <= 0 else value * 100.0 / float(total)


func _chart_rect() -> Rect2:
	return Rect2(52.0, 30.0, maxf(size.x - 68.0, 1.0), maxf(size.y - 64.0, 1.0))


func _x_for_index(index: int, chart: Rect2) -> float:
	if _history.size() <= 1:
		return chart.position.x + chart.size.x * 0.5
	return chart.position.x + chart.size.x * float(index) / float(_history.size() - 1)


func _index_at_x(x: float) -> int:
	if _history.is_empty():
		return -1
	var chart: Rect2 = _chart_rect()
	var ratio: float = clampf((x - chart.position.x) / maxf(chart.size.x, 1.0), 0.0, 1.0)
	return roundi(ratio * float(_history.size() - 1))


func _weapon_name(weapon_id: StringName) -> String:
	var key: String = "debrief.weapon.%s" % String(weapon_id).to_lower()
	var translated: String = L10n.t(key)
	return String(weapon_id).replace("_", " ") if translated == key else translated
