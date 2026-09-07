class_name DirectiveChoiceOverlay
extends Control

signal profile_selected(profile: DirectiveProfile)

const PANEL_COLOR: Color = Color(0.015, 0.025, 0.04, 0.96)
const CARD_COLOR: Color = Color(0.055, 0.075, 0.095, 0.98)
const ACCENT_COLOR: Color = Color("f1b36f")

var buttons: Array[Button] = []
var profiles: Array[DirectiveProfile] = []
var panel: ColorRect
var title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	panel = ColorRect.new()
	panel.position = Vector2(126.0, 146.0)
	panel.size = Vector2(1028.0, 406.0)
	panel.color = PANEL_COLOR
	add_child(panel)
	title = Label.new()
	title.position = Vector2(180.0, 174.0)
	title.size = Vector2(920.0, 46.0)
	title.text = L10n.t("directive.select")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 30)
	title.modulate = ACCENT_COLOR
	add_child(title)
	for index: int in range(3):
		buttons.append(_build_card(index))
	get_viewport().size_changed.connect(_sync_to_viewport)
	apply_responsive_layout(get_viewport_rect().size)
	visible = false


func show_choices(options: Array[DirectiveProfile]) -> void:
	profiles = options
	for index: int in range(buttons.size()):
		var profile: DirectiveProfile = profiles[index] if index < profiles.size() else null
		buttons[index].visible = profile != null
		if profile == null:
			continue
		buttons[index].text = L10n.t("directive.choice", {
			"name": L10n.t(profile.display_name),
			"instruction": L10n.t(profile.instruction),
		})
		buttons[index].icon = profile.icon
	visible = true
	if not buttons.is_empty():
		buttons[0].grab_focus()


func hide_choices() -> void:
	visible = false
	profiles.clear()


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if panel == null or title == null:
		return
	if viewport_size.y > viewport_size.x:
		panel.position = Vector2(36.0, 260.0)
		panel.size = Vector2(viewport_size.x - 72.0, 760.0)
		title.position = Vector2(58.0, 292.0)
		title.size = Vector2(viewport_size.x - 116.0, 50.0)
		title.add_theme_font_size_override(&"font_size", 26)
		for index: int in range(buttons.size()):
			buttons[index].position = Vector2(72.0, 378.0 + float(index) * 198.0)
			buttons[index].size = Vector2(viewport_size.x - 144.0, 170.0)
	else:
		panel.position = Vector2(126.0, 146.0)
		panel.size = Vector2(1028.0, 406.0)
		title.position = Vector2(180.0, 174.0)
		title.size = Vector2(920.0, 46.0)
		title.add_theme_font_size_override(&"font_size", 30)
		for index: int in range(buttons.size()):
			buttons[index].position = Vector2(166.0 + float(index) * 324.0, 246.0)
			buttons[index].size = Vector2(300.0, 250.0)


func _sync_to_viewport() -> void:
	apply_responsive_layout(get_viewport_rect().size)


func _build_card(index: int) -> Button:
	var button: Button = Button.new()
	button.name = "DirectiveChoice%d" % index
	button.position = Vector2(166.0 + float(index) * 324.0, 246.0)
	button.size = Vector2(300.0, 250.0)
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override(&"font_size", 18)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.border_color = ACCENT_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override(&"normal", style)
	button.add_theme_stylebox_override(&"focus", style)
	button.pressed.connect(_select.bind(index))
	add_child(button)
	return button


func _select(index: int) -> void:
	if index < 0 or index >= profiles.size() or not visible:
		return
	var profile: DirectiveProfile = profiles[index]
	hide_choices()
	profile_selected.emit(profile)
