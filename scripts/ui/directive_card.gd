class_name DirectiveCard
extends Control

const PANEL_COLOR: Color = Color(0.03, 0.05, 0.08, 0.94)
const TRACK_COLOR: Color = Color(0.11, 0.15, 0.18, 0.98)
const ACCENT_COLOR: Color = Color("f1b36f")
const TIMER_COLOR: Color = Color("7ae4ff")
const COMPLETE_COLOR: Color = Color("5dc9c2")
const FAILURE_COLOR: Color = Color("ff815c")
const RESULT_DISPLAY_SECONDS: float = 2.4
const LANDSCAPE_SIZE: Vector2 = Vector2(432.0, 154.0)
const PORTRAIT_HEIGHT: float = 158.0

var panel: ColorRect
var icon: TextureRect
var title_label: Label
var timer_label: Label
var detail_label: Label
var progress_label: Label
var bank_label: Label
var progress_track: ColorRect
var progress_fill: ColorRect
var timer_track: ColorRect
var timer_fill: ColorRect
var result_remaining: float = 0.0
var countdown_text_assignment_count: int = 0

var _session: DirectiveSession
var _profile: DirectiveProfile
var _countdown_cache: PackedStringArray = PackedStringArray()
var _last_display_second: int = -1
var _progress_ratio: float = 0.0
var _timer_ratio: float = 0.0
var _progress_width: float = 0.0
var _timer_width: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = ColorRect.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.color = PANEL_COLOR
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	icon = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	title_label = _label("Title", 18, ACCENT_COLOR)
	title_label.clip_text = true
	timer_label = _label("Timer", 16, TIMER_COLOR)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	detail_label = _label("Instruction", 14, Color.WHITE)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label = _label("Progress", 13, TIMER_COLOR)
	bank_label = _label("Bank", 13, ACCENT_COLOR)
	bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_track = _bar("ProgressTrack", TRACK_COLOR)
	progress_fill = _bar("ProgressFill", ACCENT_COLOR)
	timer_track = _bar("TimerTrack", TRACK_COLOR)
	timer_fill = _bar("TimerFill", TIMER_COLOR)
	apply_responsive_layout(get_viewport_rect().size)
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if result_remaining > 0.0:
		result_remaining = maxf(result_remaining - delta, 0.0)
		if is_zero_approx(result_remaining):
			hide_card()
		return
	if _profile == null or _session == null or _session.active_profile != _profile:
		return
	_update_countdown(_session.remaining, _profile.duration_seconds)


func show_directive(
	profile: DirectiveProfile,
	current: int,
	target: int,
	bank: int,
	session: DirectiveSession = null
) -> void:
	if profile == null:
		hide_card()
		return
	result_remaining = 0.0
	_profile = profile
	_session = session
	visible = true
	icon.texture = profile.icon
	title_label.text = L10n.t(profile.display_name)
	detail_label.text = L10n.t(profile.instruction)
	bank_label.text = L10n.t("directive.pending", {"value": bank})
	title_label.modulate = ACCENT_COLOR
	bank_label.modulate = ACCENT_COLOR
	_set_active_telemetry_visible(true)
	_build_countdown_cache(profile.duration_seconds)
	set_progress(profile, current, target)
	_update_countdown(
		session.remaining if session != null else profile.duration_seconds,
		profile.duration_seconds
	)
	set_process(session != null)


func set_progress(profile: DirectiveProfile, current: int, target: int) -> void:
	if profile == null or profile != _profile or result_remaining > 0.0:
		return
	var safe_target: int = maxi(target, 1)
	var safe_current: int = clampi(current, 0, safe_target)
	_progress_ratio = clampf(float(safe_current) / float(safe_target), 0.0, 1.0)
	progress_fill.size.x = _progress_width * _progress_ratio
	progress_label.text = L10n.t("directive.progress_short", {
		"current": safe_current,
		"target": safe_target,
	})


func set_bank(value: int) -> void:
	if result_remaining > 0.0 or _profile == null:
		return
	bank_label.text = L10n.t("directive.pending", {"value": maxi(value, 0)})


func hide_card() -> void:
	result_remaining = 0.0
	_session = null
	_profile = null
	_countdown_cache.clear()
	_last_display_second = -1
	visible = false
	set_process(false)


func show_result(text: String, success: bool, score_delta: int = 0) -> void:
	_session = null
	_profile = null
	visible = true
	title_label.text = text
	title_label.modulate = COMPLETE_COLOR if success else FAILURE_COLOR
	detail_label.text = L10n.t(
		"directive.score_secured" if success else "directive.score_penalty"
	)
	bank_label.text = L10n.t(
		"directive.secured_value" if success else "directive.penalty_value",
		{"value": maxi(score_delta, 0)}
	)
	bank_label.modulate = COMPLETE_COLOR if success else FAILURE_COLOR
	_set_active_telemetry_visible(false)
	result_remaining = RESULT_DISPLAY_SECONDS
	set_process(true)


func apply_responsive_layout(viewport_size: Vector2) -> void:
	var portrait: bool = viewport_size.y > viewport_size.x
	size = (
		Vector2(minf(LANDSCAPE_SIZE.x, viewport_size.x - 36.0), PORTRAIT_HEIGHT)
		if portrait
		else LANDSCAPE_SIZE
	)
	icon.position = Vector2(10.0, 12.0)
	icon.size = Vector2(60.0, 60.0)
	var content_x: float = 80.0
	var content_width: float = size.x - content_x - 10.0
	title_label.position = Vector2(content_x, 8.0)
	title_label.size = Vector2(content_width - 78.0, 26.0)
	timer_label.position = Vector2(size.x - 84.0, 8.0)
	timer_label.size = Vector2(74.0, 26.0)
	detail_label.position = Vector2(content_x, 34.0)
	detail_label.size = Vector2(content_width, 36.0)
	progress_track.position = Vector2(content_x, 75.0)
	progress_track.size = Vector2(content_width, 10.0)
	progress_fill.position = progress_track.position + Vector2(2.0, 2.0)
	_progress_width = maxf(progress_track.size.x - 4.0, 0.0)
	progress_fill.size = Vector2(_progress_width * _progress_ratio, 6.0)
	timer_track.position = Vector2(content_x, 91.0)
	timer_track.size = Vector2(content_width, 8.0)
	timer_fill.position = timer_track.position + Vector2(2.0, 2.0)
	_timer_width = maxf(timer_track.size.x - 4.0, 0.0)
	timer_fill.size = Vector2(_timer_width * _timer_ratio, 4.0)
	progress_label.position = Vector2(10.0, 108.0)
	progress_label.size = Vector2(size.x * 0.46, 22.0)
	bank_label.position = Vector2(size.x * 0.46, 108.0)
	bank_label.size = Vector2(size.x * 0.54 - 10.0, 22.0)


func _label(name_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = name_value
	label.add_theme_font_size_override(&"font_size", font_size)
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _bar(name_value: String, color: Color) -> ColorRect:
	var bar: ColorRect = ColorRect.new()
	bar.name = name_value
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	return bar


func _build_countdown_cache(duration: float) -> void:
	_countdown_cache.clear()
	var maximum_second: int = maxi(ceili(duration), 0)
	_countdown_cache.resize(maximum_second + 1)
	for second: int in range(maximum_second + 1):
		_countdown_cache[second] = L10n.t("directive.time_remaining", {"seconds": second})
	_last_display_second = -1


func _update_countdown(remaining: float, duration: float) -> void:
	_timer_ratio = clampf(remaining / maxf(duration, 0.001), 0.0, 1.0)
	timer_fill.size.x = _timer_width * _timer_ratio
	var display_second: int = clampi(
		ceili(maxf(remaining, 0.0)),
		0,
		maxi(_countdown_cache.size() - 1, 0)
	)
	if display_second == _last_display_second or _countdown_cache.is_empty():
		return
	_last_display_second = display_second
	timer_label.text = _countdown_cache[display_second]
	countdown_text_assignment_count += 1


func _set_active_telemetry_visible(value: bool) -> void:
	timer_label.visible = value
	progress_label.visible = value
	progress_track.visible = value
	progress_fill.visible = value
	timer_track.visible = value
	timer_fill.visible = value
