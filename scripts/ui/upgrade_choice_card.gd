class_name UpgradeChoiceCard
extends Button

signal chosen(upgrade_id: StringName)

const PANEL: Color = Color(0.025, 0.055, 0.075, 0.98)
const PANEL_HOVER: Color = Color(0.045, 0.09, 0.115, 0.99)
const ACCENT: Color = Color("f1b36f")
const MUTED: Color = Color("b7c4cb")

var upgrade_id: StringName
var title_label: Label
var rank_label: Label
var description_label: Label
var glyph_label: Label
var icon_rect: TextureRect
var current_rank: int = 0
var maximum_rank: int = 1


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	text = ""
	pressed.connect(_emit_chosen)
	_build_style()
	_build_content()


func configure(profile: UpgradeProfile, rank: int) -> void:
	upgrade_id = profile.upgrade_id
	current_rank = clampi(rank, 0, profile.max_rank)
	maximum_rank = profile.max_rank
	title_label.text = L10n.t(profile.display_name)
	rank_label.text = L10n.t("upgrade.rank", {
		"current": current_rank,
		"next": mini(current_rank + 1, maximum_rank),
		"maximum": maximum_rank,
	})
	description_label.text = L10n.t(profile.description)
	glyph_label.text = _glyph_for(profile.category)
	if profile.icon != null:
		icon_rect.texture = profile.icon
		icon_rect.visible = true
		glyph_label.visible = false
	else:
		icon_rect.texture = null
		icon_rect.visible = false
		glyph_label.visible = true
	queue_redraw()


func _draw() -> void:
	var pip_width: float = 22.0
	var gap: float = 8.0
	var total_width: float = pip_width * 5.0 + gap * 4.0
	var origin: Vector2 = Vector2((size.x - total_width) * 0.5, size.y - 28.0)
	for index: int in range(5):
		var active: bool = index < current_rank
		var available: bool = index < maximum_rank
		var color: Color = (
			ACCENT if active else Color(0.18, 0.25, 0.28, 0.95)
		)
		if not available:
			color = Color(0.08, 0.11, 0.13, 0.72)
		draw_rect(Rect2(origin + Vector2((pip_width + gap) * index, 0.0),
			Vector2(pip_width, 7.0)), color, true)


func _build_style() -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = PANEL
	normal.border_color = Color(0.24, 0.55, 0.58, 0.92)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(12)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = PANEL_HOVER
	hover.border_color = ACCENT
	var pressed_style: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.07, 0.12, 0.14, 1.0)
	add_theme_stylebox_override(&"normal", normal)
	add_theme_stylebox_override(&"hover", hover)
	add_theme_stylebox_override(&"focus", hover)
	add_theme_stylebox_override(&"pressed", pressed_style)


func _build_content() -> void:
	icon_rect = TextureRect.new()
	icon_rect.position = Vector2(20.0, 16.0)
	icon_rect.size = Vector2(68.0, 58.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.visible = false
	add_child(icon_rect)
	glyph_label = Label.new()
	glyph_label.position = Vector2(20.0, 16.0)
	glyph_label.size = Vector2(68.0, 58.0)
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph_label.add_theme_font_size_override(&"font_size", 34)
	glyph_label.modulate = ACCENT
	glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glyph_label)
	title_label = Label.new()
	title_label.position = Vector2(94.0, 16.0)
	title_label.size = Vector2(280.0, 38.0)
	title_label.add_theme_font_size_override(&"font_size", 25)
	title_label.modulate = ACCENT
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)
	rank_label = Label.new()
	rank_label.position = Vector2(94.0, 52.0)
	rank_label.size = Vector2(280.0, 26.0)
	rank_label.add_theme_font_size_override(&"font_size", 17)
	rank_label.modulate = MUTED
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rank_label)
	description_label = Label.new()
	description_label.position = Vector2(22.0, 92.0)
	description_label.size = Vector2(350.0, 92.0)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.add_theme_font_size_override(&"font_size", 19)
	description_label.modulate = Color(0.9, 0.94, 0.95, 1.0)
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(description_label)


func _glyph_for(category: StringName) -> String:
	match category:
		&"defense":
			return "⬡"
		&"weapon":
			return "✦"
		&"mobility":
			return "»"
		&"melee":
			return "◎"
		_:
			return "◆"


func _emit_chosen() -> void:
	chosen.emit(upgrade_id)
