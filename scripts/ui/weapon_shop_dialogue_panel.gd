class_name WeaponShopDialoguePanel
extends Control

signal dismissed

var shade: ColorRect
var panel: ColorRect
var portrait: TextureRect
var operator_label: Label
var body_label: Label
var continue_button: Button
var active: bool = false
var _input_armed_frame: int = 0


func _ready() -> void:
	name = "WeaponShopDialoguePanel"
	z_index = 40
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_controls()
	visible = false
	get_viewport().size_changed.connect(apply_responsive_layout)
	apply_responsive_layout()


func _unhandled_input(event: InputEvent) -> void:
	if not active or Engine.get_process_frames() < _input_armed_frame:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()


func show_dialogue(district_id: StringName) -> void:
	portrait.texture = WeaponShopVisualCatalog.operator_portrait(district_id)
	operator_label.text = L10n.t(WeaponShopVisualCatalog.operator_name_key(district_id))
	body_label.text = L10n.t(WeaponShopVisualCatalog.dialogue_key(district_id))
	active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_input_armed_frame = Engine.get_process_frames() + 2
	apply_responsive_layout()
	continue_button.grab_focus()


func hide_dialogue() -> void:
	active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	release_focus()


func apply_responsive_layout() -> void:
	if shade == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	shade.size = viewport_size
	if viewport_size.y > viewport_size.x:
		_apply_portrait(viewport_size)
	else:
		_apply_landscape(viewport_size)


func _build_controls() -> void:
	shade = ColorRect.new()
	shade.color = Color(0.004, 0.008, 0.012, 0.76)
	add_child(shade)
	panel = ColorRect.new()
	panel.color = Color(0.018, 0.032, 0.04, 0.98)
	add_child(panel)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	operator_label = _label(27, Color("f1b36f"))
	add_child(operator_label)
	body_label = _label(22, Color("e8f3ef"))
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(body_label)
	continue_button = Button.new()
	continue_button.text = L10n.t("shop.dialogue.continue")
	continue_button.add_theme_font_size_override(&"font_size", 22)
	continue_button.pressed.connect(_dismiss)
	add_child(continue_button)


func _apply_landscape(viewport_size: Vector2) -> void:
	panel.position = Vector2(94.0, viewport_size.y - 286.0)
	panel.size = Vector2(viewport_size.x - 188.0, 230.0)
	portrait.position = Vector2(112.0, viewport_size.y - 390.0)
	portrait.size = Vector2(310.0, 310.0)
	operator_label.position = Vector2(414.0, viewport_size.y - 258.0)
	operator_label.size = Vector2(viewport_size.x - 680.0, 38.0)
	body_label.position = Vector2(414.0, viewport_size.y - 216.0)
	body_label.size = Vector2(viewport_size.x - 680.0, 112.0)
	continue_button.position = Vector2(viewport_size.x - 292.0, viewport_size.y - 128.0)
	continue_button.size = Vector2(176.0, 52.0)


func _apply_portrait(viewport_size: Vector2) -> void:
	panel.position = Vector2(34.0, viewport_size.y * 0.42)
	panel.size = Vector2(viewport_size.x - 68.0, viewport_size.y * 0.50)
	portrait.position = Vector2((viewport_size.x - 330.0) * 0.5, viewport_size.y * 0.17)
	portrait.size = Vector2(330.0, 330.0)
	operator_label.position = Vector2(62.0, viewport_size.y * 0.47)
	operator_label.size = Vector2(viewport_size.x - 124.0, 46.0)
	operator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.position = Vector2(62.0, viewport_size.y * 0.53)
	body_label.size = Vector2(viewport_size.x - 124.0, viewport_size.y * 0.24)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_button.position = Vector2((viewport_size.x - 220.0) * 0.5, viewport_size.y * 0.82)
	continue_button.size = Vector2(220.0, 62.0)


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _dismiss() -> void:
	if not active:
		return
	hide_dialogue()
	dismissed.emit()
