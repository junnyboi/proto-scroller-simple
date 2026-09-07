class_name TransmissionToast
extends Control

const QUEUE_CAPACITY: int = 3
const PANEL_COLOR: Color = Color(0.015, 0.035, 0.05, 0.92)
const ACCENT_COLOR: Color = Color("72e5ec")
const BODY_COLOR: Color = Color("d8e8ec")
const HUD_LEFT_MARGIN: float = 24.0
const LANDSCAPE_TOP: float = 172.0
const PORTRAIT_TOP: float = 170.0

var presentation_suppressed: bool = false
var panel: ColorRect
var speaker_label: Label
var line_label: Label
var _queue: Array[Dictionary] = []
var _active: Dictionary = {}
var _remaining: float = 0.0
var _seen_events: Dictionary[StringName, bool] = {}


func _ready() -> void:
	name = "TransmissionToast"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 12
	_build()
	visible = false
	set_process(true)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if presentation_suppressed:
		hide()
		return
	if not _active.is_empty():
		visible = not presentation_suppressed
	if _active.is_empty():
		_show_next()
		return
	_remaining -= maxf(delta, 0.0)
	if _remaining <= 0.0:
		_active.clear()
		visible = false
		_show_next()


func present(
	event_id: StringName,
	speaker_key: String,
	line_key: String,
	duration: float,
	priority: int = 0
) -> bool:
	if event_id.is_empty() or _seen_events.has(event_id):
		return false
	_seen_events[event_id] = true
	var record: Dictionary = {
		"event_id": event_id,
		"speaker_key": speaker_key,
		"line_key": line_key,
		"duration": clampf(duration, 1.0, 8.0),
		"priority": priority,
	}
	if _active.is_empty():
		_active = record
		_apply_active()
		return true
	if _queue.size() >= QUEUE_CAPACITY:
		var lowest_index: int = 0
		for index: int in range(1, _queue.size()):
			if int(_queue[index].priority) < int(_queue[lowest_index].priority):
				lowest_index = index
		if int(_queue[lowest_index].priority) > priority:
			return false
		_queue.remove_at(lowest_index)
	_queue.append(record)
	return true


func pending_count() -> int:
	return _queue.size()


func active_event_id() -> StringName:
	return StringName(_active.get("event_id", &""))


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if viewport_size.y > viewport_size.x:
		position = Vector2(HUD_LEFT_MARGIN, PORTRAIT_TOP)
		size = Vector2(maxf(viewport_size.x - 48.0, 320.0), 122.0)
	else:
		size = Vector2(minf(620.0, viewport_size.x - 80.0), 104.0)
		position = Vector2(HUD_LEFT_MARGIN, LANDSCAPE_TOP)
	panel.size = size
	speaker_label.position = Vector2(18.0, 12.0)
	speaker_label.size = Vector2(size.x - 36.0, 26.0)
	line_label.position = Vector2(18.0, 40.0)
	line_label.size = Vector2(size.x - 36.0, size.y - 50.0)
	line_label.add_theme_font_size_override(
		&"font_size",
		17 if viewport_size.y > viewport_size.x else 19
	)


func _show_next() -> void:
	if _queue.is_empty():
		return
	_active = _queue.pop_front()
	_apply_active()


func _apply_active() -> void:
	_remaining = float(_active.duration)
	speaker_label.text = L10n.t(String(_active.speaker_key))
	line_label.text = L10n.t(String(_active.line_key))
	visible = not presentation_suppressed


func _build() -> void:
	panel = ColorRect.new()
	panel.color = PANEL_COLOR
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override(&"font_size", 14)
	speaker_label.modulate = ACCENT_COLOR
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(speaker_label)
	line_label = Label.new()
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line_label.modulate = BODY_COLOR
	line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line_label)


func set_suppressed(suppressed: bool) -> void:
	presentation_suppressed = suppressed
	if suppressed:
		hide()
