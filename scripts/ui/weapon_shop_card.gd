class_name WeaponShopCard
extends Button

signal purchase_requested(product_id: StringName)
signal preview_requested(product_id: StringName)
signal insufficient_attempted(product_id: StringName)

const AVAILABLE_COLOR: Color = Color("7ae4ff")
const PRICE_COLOR: Color = Color("f1b36f")
const MUTED_COLOR: Color = Color("75838b")

var product: WeaponShopProduct
var status: StringName = &"missing"
var accent_color: Color = AVAILABLE_COLOR
var product_icon: TextureRect
var title_label: Label
var description_label: Label
var price_label: Label
var state_label: Label


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build_contents()
	pressed.connect(_on_pressed)
	resized.connect(_apply_layout)
	_apply_style(false)


func configure(
	p_product: WeaponShopProduct,
	p_status: StringName,
	p_accent_color: Color
) -> void:
	product = p_product
	accent_color = p_accent_color
	product_icon.texture = WeaponShopVisualCatalog.product_icon(product.product_id)
	title_label.text = L10n.t(product.name_key)
	description_label.text = L10n.t(product.description_key)
	price_label.text = L10n.t("shop.price", {"price": "%05d" % product.price})
	set_status(p_status)


func set_status(p_status: StringName) -> void:
	status = p_status
	disabled = false
	match status:
		&"sold":
			state_label.text = L10n.t("shop.sold")
			state_label.modulate = MUTED_COLOR
		&"healthy":
			state_label.text = L10n.t("shop.full_integrity")
			state_label.modulate = MUTED_COLOR
		&"funds":
			state_label.text = L10n.t("shop.insufficient")
			state_label.modulate = Color("d98262")
		_:
			state_label.text = L10n.t("shop.buy")
			state_label.modulate = accent_color
	_apply_style(has_focus())


func available() -> bool:
	return product != null and status == &"available"


func _build_contents() -> void:
	text = ""
	product_icon = TextureRect.new()
	product_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	product_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	product_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(product_icon)
	title_label = _label(20, Color("e8f3ef"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)
	description_label = _label(15, Color("b7c4cb"))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(description_label)
	price_label = _label(22, PRICE_COLOR)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(price_label)
	state_label = _label(16, AVAILABLE_COLOR)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(state_label)
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	mouse_entered.connect(_request_preview)


func _apply_layout() -> void:
	var padding: float = 14.0
	var compact: bool = size.y < 250.0
	if compact:
		var icon_size: float = minf(size.y - 48.0, 120.0)
		var text_left: float = icon_size + 42.0
		product_icon.position = Vector2(18.0, (size.y - icon_size) * 0.5)
		product_icon.size = Vector2(icon_size, icon_size)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.position = Vector2(text_left, 18.0)
		title_label.size = Vector2(size.x - text_left - 20.0, 34.0)
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		description_label.position = Vector2(text_left, 54.0)
		description_label.size = Vector2(size.x - text_left - 20.0, 72.0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		price_label.position = Vector2(text_left, size.y - 56.0)
		price_label.size = Vector2(220.0, 30.0)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state_label.position = Vector2(size.x - 220.0, size.y - 54.0)
		state_label.size = Vector2(198.0, 26.0)
		return
	var icon_size: float = minf(size.x * 0.46, 136.0)
	product_icon.position = Vector2((size.x - icon_size) * 0.5, 8.0)
	product_icon.size = Vector2(icon_size, icon_size)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(padding, product_icon.position.y + icon_size - 4.0)
	title_label.size = Vector2(size.x - padding * 2.0, 44.0)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.position = Vector2(padding, title_label.position.y + 42.0)
	description_label.size = Vector2(
		size.x - padding * 2.0,
		maxf(size.y - description_label.position.y - 66.0, 34.0)
	)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.position = Vector2(padding, size.y - 60.0)
	price_label.size = Vector2(size.x - padding * 2.0, 28.0)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.position = Vector2(padding, size.y - 31.0)
	state_label.size = Vector2(size.x - padding * 2.0, 22.0)


func _apply_style(focused: bool) -> void:
	var unavailable: bool = status != &"available"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.055, 0.88 if not unavailable else 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = accent_color if focused else Color("50636c")
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	add_theme_stylebox_override(&"normal", style)
	add_theme_stylebox_override(&"hover", style)
	add_theme_stylebox_override(&"focus", style)
	add_theme_stylebox_override(&"pressed", style)
	modulate = Color(0.72, 0.76, 0.78, 1.0) if unavailable else Color.WHITE


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_focus_changed(focused: bool) -> void:
	_apply_style(focused)
	if focused:
		_request_preview()


func _request_preview() -> void:
	if product != null:
		preview_requested.emit(product.product_id)


func _on_pressed() -> void:
	_request_preview()
	if available():
		purchase_requested.emit(product.product_id)
	elif product != null and status == &"funds":
		insufficient_attempted.emit(product.product_id)
