class_name WeaponShopStatPreviewPanel
extends Control

const PROJECTED_STAT_FONT_SIZE: int = 22

var background_panel: Panel
var heading_label: Label
var product_label: Label
var rows_label: Label
var active_product_id: StringName = &""


func _ready() -> void:
	name = "WeaponShopStatPreviewPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_controls()
	resized.connect(_apply_layout)
	_apply_layout()


func show_preview(
	product: WeaponShopProduct,
	rows: Array[Dictionary]
) -> void:
	if product == null:
		return
	active_product_id = product.product_id
	heading_label.text = L10n.t("shop.preview.title")
	product_label.text = L10n.t(product.name_key)
	rows_label.text = WeaponShopStatFormatter.format_stacked_rows(rows)
	visible = true


func _build_controls() -> void:
	background_panel = Panel.new()
	background_panel.name = "StatPreviewContainer"
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.012, 0.027, 0.035, 0.94)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.31, 0.64, 0.66, 0.82)
	panel_style.set_corner_radius_all(4)
	background_panel.add_theme_stylebox_override(&"panel", panel_style)
	add_child(background_panel)
	heading_label = _label(14, Color("f1b36f"))
	add_child(heading_label)
	product_label = _label(20, Color("e8f3ef"))
	add_child(product_label)
	rows_label = _label(PROJECTED_STAT_FONT_SIZE, Color("7ae4ff"))
	rows_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(rows_label)


func _apply_layout() -> void:
	var compact: bool = size.y < 180.0
	var padding: float = 18.0 if compact else 22.0
	heading_label.position = Vector2(padding, 10.0 if compact else 14.0)
	heading_label.size = Vector2(size.x - padding * 2.0, 22.0)
	product_label.position = Vector2(padding, 30.0 if compact else 40.0)
	product_label.size = Vector2(size.x - padding * 2.0, 30.0)
	rows_label.position = Vector2(padding, 60.0 if compact else 78.0)
	rows_label.size = Vector2(
		size.x - padding * 2.0,
		68.0 if compact else maxf(size.y - 100.0, 68.0)
	)


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
