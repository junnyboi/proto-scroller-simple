class_name WeaponShopConfirmationPanel
extends Control

signal confirmed(product_id: StringName)
signal canceled

var shade: ColorRect
var frame_texture: TextureRect
var module_icon: TextureRect
var prompt_label: Label
var product_label: Label
var stat_label: Label
var score_label: Label
var confirm_button: Button
var cancel_button: Button
var product: WeaponShopProduct
var active: bool = false
var _input_armed_frame: int = 0


func _ready() -> void:
	name = "WeaponShopConfirmationPanel"
	z_index = 60
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_controls()
	visible = false
	get_viewport().size_changed.connect(apply_responsive_layout)
	apply_responsive_layout()


func _unhandled_input(event: InputEvent) -> void:
	if not active or Engine.get_process_frames() < _input_armed_frame:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()


func show_confirmation(
	p_product: WeaponShopProduct,
	preview_rows: Array[Dictionary],
	current_score: int
) -> void:
	if p_product == null:
		return
	product = p_product
	module_icon.texture = WeaponShopVisualCatalog.product_icon(product.product_id)
	prompt_label.text = L10n.t("shop.confirm.title")
	product_label.text = L10n.t(product.name_key)
	stat_label.text = WeaponShopStatFormatter.format_rows(preview_rows)
	score_label.text = L10n.t("shop.confirm.score", {
		"before": "%08d" % current_score,
		"after": "%08d" % maxi(current_score - product.price, 0),
	})
	confirm_button.text = L10n.t("shop.confirm.buy", {"price": product.price})
	cancel_button.text = L10n.t("shop.confirm.cancel")
	active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_input_armed_frame = Engine.get_process_frames() + 2
	apply_responsive_layout()
	confirm_button.grab_focus()


func hide_confirmation() -> void:
	active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	product = null
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
	shade.color = Color(0.002, 0.006, 0.01, 0.82)
	add_child(shade)
	frame_texture = TextureRect.new()
	frame_texture.texture = WeaponShopVisualCatalog.CONFIRMATION_FRAME
	frame_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_texture.stretch_mode = TextureRect.STRETCH_SCALE
	frame_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame_texture)
	module_icon = TextureRect.new()
	module_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	module_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	module_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(module_icon)
	prompt_label = _label(18, Color("d98262"))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt_label)
	product_label = _label(28, Color("e8f3ef"))
	product_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(product_label)
	stat_label = _label(19, Color("7ae4ff"))
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(stat_label)
	score_label = _label(20, Color("f1b36f"))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(score_label)
	confirm_button = Button.new()
	confirm_button.add_theme_font_size_override(&"font_size", 20)
	confirm_button.pressed.connect(_confirm)
	add_child(confirm_button)
	cancel_button = Button.new()
	cancel_button.add_theme_font_size_override(&"font_size", 20)
	cancel_button.pressed.connect(_cancel)
	add_child(cancel_button)
	confirm_button.focus_neighbor_right = cancel_button.get_path()
	cancel_button.focus_neighbor_left = confirm_button.get_path()


func _apply_landscape(viewport_size: Vector2) -> void:
	var panel_size: Vector2 = Vector2(760.0, 510.0)
	var panel_origin: Vector2 = (viewport_size - panel_size) * 0.5
	frame_texture.position = panel_origin
	frame_texture.size = panel_size
	module_icon.position = panel_origin + Vector2(290.0, 58.0)
	module_icon.size = Vector2(180.0, 180.0)
	prompt_label.position = panel_origin + Vector2(90.0, 34.0)
	prompt_label.size = Vector2(580.0, 30.0)
	product_label.position = panel_origin + Vector2(80.0, 224.0)
	product_label.size = Vector2(600.0, 44.0)
	stat_label.position = panel_origin + Vector2(90.0, 274.0)
	stat_label.size = Vector2(580.0, 82.0)
	score_label.position = panel_origin + Vector2(90.0, 358.0)
	score_label.size = Vector2(580.0, 34.0)
	confirm_button.position = panel_origin + Vector2(132.0, 414.0)
	confirm_button.size = Vector2(230.0, 56.0)
	cancel_button.position = panel_origin + Vector2(398.0, 414.0)
	cancel_button.size = Vector2(230.0, 56.0)


func _apply_portrait(viewport_size: Vector2) -> void:
	var panel_size: Vector2 = Vector2(viewport_size.x - 54.0, 700.0)
	var panel_origin: Vector2 = Vector2(27.0, (viewport_size.y - panel_size.y) * 0.5)
	frame_texture.position = panel_origin
	frame_texture.size = panel_size
	module_icon.position = Vector2((viewport_size.x - 220.0) * 0.5, panel_origin.y + 72.0)
	module_icon.size = Vector2(220.0, 220.0)
	prompt_label.position = panel_origin + Vector2(44.0, 38.0)
	prompt_label.size = Vector2(panel_size.x - 88.0, 34.0)
	product_label.position = panel_origin + Vector2(44.0, 294.0)
	product_label.size = Vector2(panel_size.x - 88.0, 52.0)
	stat_label.position = panel_origin + Vector2(44.0, 354.0)
	stat_label.size = Vector2(panel_size.x - 88.0, 116.0)
	score_label.position = panel_origin + Vector2(44.0, 478.0)
	score_label.size = Vector2(panel_size.x - 88.0, 48.0)
	confirm_button.position = panel_origin + Vector2(62.0, 558.0)
	confirm_button.size = Vector2(panel_size.x - 124.0, 58.0)
	cancel_button.position = panel_origin + Vector2(62.0, 626.0)
	cancel_button.size = Vector2(panel_size.x - 124.0, 50.0)


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _confirm() -> void:
	if not active or product == null:
		return
	var product_id: StringName = product.product_id
	hide_confirmation()
	confirmed.emit(product_id)


func _cancel() -> void:
	if not active:
		return
	hide_confirmation()
	canceled.emit()
