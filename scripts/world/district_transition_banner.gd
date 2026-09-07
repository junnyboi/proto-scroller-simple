class_name DistrictTransitionBanner
extends CanvasLayer

const FADE_IN_SECONDS: float = 0.18
const HOLD_SECONDS: float = 1.65
const FADE_OUT_SECONDS: float = 0.42
const TOTAL_SECONDS: float = FADE_IN_SECONDS + HOLD_SECONDS + FADE_OUT_SECONDS

var panel: PanelContainer
var label: Label
var presentation_count: int = 0
var _elapsed: float = 0.0


func _ready() -> void:
	layer = 95
	var root_control: Control = Control.new()
	root_control.name = "DistrictTransitionRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	panel = PanelContainer.new()
	panel.name = "DistrictTransitionPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.size = Vector2(500.0, 72.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("d9141921")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("6ba6b5")
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	root_control.add_child(panel)
	label = Label.new()
	label.name = "DistrictTransitionLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("e8f3ef"))
	label.add_theme_font_size_override("font_size", 19)
	panel.add_child(label)
	_position_panel()
	get_viewport().size_changed.connect(_position_panel)
	panel.visible = false
	set_process(false)


func present(district: CityDistrictProfile, logical_chunk: int) -> void:
	if district == null:
		return
	label.text = "%s  //  %s\nFORWARD SECTOR %02d" % [
		district.district_id,
		district.display_name.to_upper(),
		maxi(logical_chunk, 0),
	]
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_color = district.accent_color.lightened(0.18)
	label.add_theme_color_override(
		"font_color",
		district.accent_color.lightened(0.42)
	)
	_elapsed = 0.0
	panel.modulate.a = 0.0
	panel.visible = true
	presentation_count += 1
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TOTAL_SECONDS:
		panel.visible = false
		set_process(false)
		return
	if _elapsed < FADE_IN_SECONDS:
		panel.modulate.a = _elapsed / FADE_IN_SECONDS
	elif _elapsed < FADE_IN_SECONDS + HOLD_SECONDS:
		panel.modulate.a = 1.0
	else:
		panel.modulate.a = (
			1.0
			- (_elapsed - FADE_IN_SECONDS - HOLD_SECONDS) / FADE_OUT_SECONDS
		)


func _position_panel() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(
		(viewport_size.x - panel.size.x) * 0.5,
		240.0 if viewport_size.y > viewport_size.x else 166.0
	)
