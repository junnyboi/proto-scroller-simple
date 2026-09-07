class_name RuntimeTweakTheme
extends RefCounted

const BACKDROP: Color = Color(0.002, 0.010, 0.018, 0.88)
const SURFACE: Color = Color(0.014, 0.035, 0.050, 0.985)
const SURFACE_RAISED: Color = Color(0.026, 0.060, 0.078, 0.98)
const BORDER: Color = Color(0.26, 0.58, 0.64, 0.52)
const ACCENT: Color = Color("62f5df")
const AMBER: Color = Color("f0ad4e")
const TEXT: Color = Color("e9f6f5")
const MUTED: Color = Color("96aeb4")
const DANGER: Color = Color("ff7580")


static func panel_style(raised: bool = false, compact: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SURFACE_RAISED if raised else SURFACE
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0 if compact else 14.0
	style.content_margin_right = 8.0 if compact else 14.0
	style.content_margin_top = 4.0 if compact else 10.0
	style.content_margin_bottom = 4.0 if compact else 10.0
	return style


static func button_style(
	color: Color = SURFACE_RAISED,
	border: Color = BORDER,
	compact: bool = false
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7.0 if compact else 12.0
	style.content_margin_right = 7.0 if compact else 12.0
	style.content_margin_top = 3.0 if compact else 8.0
	style.content_margin_bottom = 3.0 if compact else 8.0
	return style


static func style_button(button: Button, accent: bool = false, compact: bool = false) -> void:
	button.custom_minimum_size.y = 32.0 if compact else 46.0
	button.add_theme_font_size_override(&"font_size", 12 if compact else 16)
	button.add_theme_color_override(&"font_color", TEXT)
	button.add_theme_color_override(&"font_focus_color", TEXT)
	var normal: StyleBoxFlat = button_style(
		Color(0.18, 0.12, 0.035, 0.98) if accent else SURFACE_RAISED,
		AMBER if accent else BORDER,
		compact
	)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.17, 0.055, 1.0) if accent else Color(0.04, 0.11, 0.13, 1.0)
	hover.border_color = AMBER if accent else ACCENT
	button.add_theme_stylebox_override(&"normal", normal)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"pressed", hover)
	button.add_theme_stylebox_override(&"focus", hover)


static func compact_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 16
	for type: StringName in [&"Label", &"Button", &"LineEdit", &"OptionButton", &"CheckButton", &"CheckBox", &"PopupMenu"]:
		theme.set_font_size(&"font_size", type, 16)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		theme.set_stylebox(state, &"Button", button_style(SURFACE_RAISED, ACCENT if state == &"focus" else BORDER, true))
		theme.set_stylebox(state, &"LineEdit", button_style(SURFACE_RAISED, BORDER, true))
	return theme
