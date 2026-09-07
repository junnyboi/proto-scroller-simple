class_name FieldBriefingPanel
extends Control

signal opened
signal closed

const ACCENT_COLOR: Color = Color("62f5df")
const MUTED_COLOR: Color = Color("b9c9ce")
const PANEL_COLOR: Color = Color(0.012, 0.035, 0.052, 0.97)
const PROMPT_LANDSCAPE_SIZE: Vector2 = Vector2(166.0, 24.0)
const PROMPT_PORTRAIT_WIDTH: float = 125.0
const PROMPT_HEIGHT: float = 24.0
const PROMPT_LANDSCAPE_FONT_SIZE: int = 10
const PROMPT_PORTRAIT_FONT_SIZE: int = 8

var prompt_button: Button
var overlay: Control
var panel: ColorRect
var heading_label: Label
var subheading_label: Label
var tips_label: Label
var close_button: Button
var pause_coordinator: RunPauseCoordinator
var robot: GiantRobotController
var mobile_controls: MobileControls
var pause_token: int = 0
var _available: bool = true


func _ready() -> void:
	name = "FieldBriefingPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 36
	_build_prompt()
	_build_overlay()
	refresh_locale()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	apply_responsive_layout(get_viewport_rect().size)
	L10n.apply_locale_font(self)


func configure(
	p_pause_coordinator: RunPauseCoordinator,
	p_robot: GiantRobotController,
	p_mobile_controls: MobileControls
) -> void:
	pause_coordinator = p_pause_coordinator
	robot = p_robot
	mobile_controls = p_mobile_controls


func set_available(available: bool) -> void:
	_available = available
	if not available:
		close(false)
	if prompt_button != null:
		prompt_button.visible = available


func open() -> bool:
	if (
		not _available
		or overlay == null
		or overlay.visible
		or pause_coordinator == null
		or pause_coordinator.is_paused()
	):
		return false
	pause_token = pause_coordinator.acquire(&"field_briefing")
	if pause_token == 0:
		return false
	overlay.visible = true
	prompt_button.text = L10n.t("briefing.close_prompt")
	close_button.call_deferred(&"grab_focus")
	opened.emit()
	return true


func close(restore_prompt_focus: bool = true) -> bool:
	if overlay == null or not overlay.visible:
		return false
	overlay.visible = false
	if pause_coordinator != null and pause_token != 0:
		pause_coordinator.release(pause_token)
	pause_token = 0
	prompt_button.text = L10n.t("briefing.open_prompt")
	if restore_prompt_focus and _available:
		prompt_button.call_deferred(&"grab_focus")
	closed.emit()
	return true


func toggle() -> bool:
	if overlay != null and overlay.visible:
		return close()
	return open()


func is_open() -> bool:
	return overlay != null and overlay.visible


func refresh_locale() -> void:
	if prompt_button == null:
		return
	var bindings: Dictionary = InputBindingSettings.display_placeholders()
	prompt_button.text = L10n.t(
		"briefing.close_prompt" if is_open() else "briefing.open_prompt"
	)
	heading_label.text = L10n.t("briefing.heading")
	subheading_label.text = L10n.t("briefing.subtitle")
	tips_label.text = L10n.t("briefing.tips_body", bindings)
	close_button.text = L10n.t("briefing.close_button")


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if prompt_button == null:
		return
	if viewport_size.y > viewport_size.x:
		_apply_portrait_layout(viewport_size)
	else:
		_apply_landscape_layout(viewport_size)


func _on_viewport_size_changed() -> void:
	apply_responsive_layout(get_viewport_rect().size)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"field_briefing"):
		if toggle():
			get_viewport().set_input_as_handled()
		return
	if is_open() and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_prompt() -> void:
	prompt_button = Button.new()
	prompt_button.name = "FieldBriefingPrompt"
	prompt_button.focus_mode = Control.FOCUS_ALL
	prompt_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	prompt_button.add_theme_font_size_override(&"font_size", 19)
	prompt_button.add_theme_color_override(&"font_color", ACCENT_COLOR)
	prompt_button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	prompt_button.add_theme_color_override(&"font_focus_color", Color.WHITE)
	var normal_style: StyleBoxFlat = _panel_style(Color(0.006, 0.03, 0.045, 0.84), 1)
	normal_style.border_color = Color(0.25, 0.82, 0.75, 0.45)
	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.02, 0.09, 0.10, 0.94)
	hover_style.border_color = ACCENT_COLOR
	prompt_button.add_theme_stylebox_override(&"normal", normal_style)
	prompt_button.add_theme_stylebox_override(&"hover", hover_style)
	prompt_button.add_theme_stylebox_override(&"pressed", hover_style)
	prompt_button.add_theme_stylebox_override(&"focus", hover_style)
	prompt_button.pressed.connect(toggle)
	add_child(prompt_button)


func _build_overlay() -> void:
	overlay = Control.new()
	overlay.name = "BriefingOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.008, 0.015, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var backdrop: Button = Button.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.flat = true
	backdrop.pressed.connect(close)
	overlay.add_child(backdrop)
	panel = ColorRect.new()
	panel.name = "BriefingCard"
	panel.color = PANEL_COLOR
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)
	heading_label = Label.new()
	heading_label.name = "Heading"
	heading_label.modulate = ACCENT_COLOR
	heading_label.add_theme_font_size_override(&"font_size", 36)
	panel.add_child(heading_label)
	subheading_label = Label.new()
	subheading_label.name = "Subtitle"
	subheading_label.modulate = MUTED_COLOR
	subheading_label.add_theme_font_size_override(&"font_size", 16)
	panel.add_child(subheading_label)
	tips_label = Label.new()
	tips_label.name = "Tips"
	tips_label.modulate = Color("e4f3f2")
	tips_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tips_label.add_theme_font_size_override(&"font_size", 23)
	panel.add_child(tips_label)
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.add_theme_font_size_override(&"font_size", 20)
	close_button.pressed.connect(close)
	panel.add_child(close_button)


func _apply_landscape_layout(viewport_size: Vector2) -> void:
	prompt_button.position = Vector2(
		24.0, viewport_size.y - 18.0 - PROMPT_LANDSCAPE_SIZE.y
	)
	prompt_button.size = PROMPT_LANDSCAPE_SIZE
	prompt_button.add_theme_font_size_override(
		&"font_size", PROMPT_LANDSCAPE_FONT_SIZE
	)
	var card_size: Vector2 = Vector2(minf(790.0, viewport_size.x - 64.0), 500.0)
	panel.position = (viewport_size - card_size) * 0.5
	panel.size = card_size
	heading_label.position = Vector2(38.0, 30.0)
	heading_label.size = Vector2(card_size.x - 76.0, 52.0)
	heading_label.add_theme_font_size_override(&"font_size", 36)
	subheading_label.position = Vector2(40.0, 84.0)
	subheading_label.size = Vector2(card_size.x - 80.0, 34.0)
	subheading_label.add_theme_font_size_override(&"font_size", 16)
	tips_label.position = Vector2(40.0, 122.0)
	tips_label.size = Vector2(card_size.x - 80.0, 292.0)
	tips_label.add_theme_font_size_override(&"font_size", 23)
	close_button.position = Vector2(card_size.x - 238.0, card_size.y - 68.0)
	close_button.size = Vector2(200.0, 46.0)


func _apply_portrait_layout(viewport_size: Vector2) -> void:
	prompt_button.position = Vector2(16.0, viewport_size.y - 18.0 - PROMPT_HEIGHT)
	prompt_button.size = Vector2(
		minf(PROMPT_PORTRAIT_WIDTH, viewport_size.x - 32.0), PROMPT_HEIGHT
	)
	prompt_button.add_theme_font_size_override(
		&"font_size", PROMPT_PORTRAIT_FONT_SIZE
	)
	var card_size: Vector2 = Vector2(viewport_size.x - 48.0, minf(610.0, viewport_size.y - 160.0))
	panel.position = Vector2(24.0, maxf(80.0, (viewport_size.y - card_size.y) * 0.5))
	panel.size = card_size
	heading_label.position = Vector2(26.0, 24.0)
	heading_label.size = Vector2(card_size.x - 52.0, 48.0)
	heading_label.add_theme_font_size_override(&"font_size", 30)
	subheading_label.position = Vector2(28.0, 74.0)
	subheading_label.size = Vector2(card_size.x - 56.0, 54.0)
	subheading_label.add_theme_font_size_override(&"font_size", 14)
	tips_label.position = Vector2(28.0, 124.0)
	tips_label.size = Vector2(card_size.x - 56.0, card_size.y - 210.0)
	tips_label.add_theme_font_size_override(&"font_size", 20)
	close_button.position = Vector2(28.0, card_size.y - 68.0)
	close_button.size = Vector2(card_size.x - 56.0, 46.0)


func _panel_style(color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = ACCENT_COLOR
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style
