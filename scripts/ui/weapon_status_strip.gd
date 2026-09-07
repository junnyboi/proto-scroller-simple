class_name WeaponStatusStrip
extends Control

const ORDER: Array[StringName] = [
	&"MACHINE_GUN",
	&"MISSILE",
	&"LASER",
	&"FLAMETHROWER",
]
const LABELS: Dictionary[StringName, String] = {
	&"MACHINE_GUN": "weapon.machine_gun",
	&"MISSILE": "weapon.missile",
	&"LASER": "weapon.laser",
	&"FLAMETHROWER": "weapon.flamethrower",
}

var label: Label
var ranks: Dictionary[StringName, int] = {}


func _ready() -> void:
	name = "WeaponStatusStrip"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.add_theme_font_size_override(&"font_size", 15)
	label.modulate = Color("b7c4cb")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	for upgrade_id: StringName in ORDER:
		ranks[upgrade_id] = 0
	_refresh()
	get_viewport().size_changed.connect(apply_responsive_layout)
	apply_responsive_layout()


func set_rank(upgrade_id: StringName, rank: int, _max_rank: int) -> void:
	if not ranks.has(upgrade_id):
		return
	ranks[upgrade_id] = maxi(rank, 0)
	_refresh()


func apply_responsive_layout() -> void:
	if label == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.y > viewport_size.x:
		position = Vector2(0.0, 204.0)
		size = Vector2(minf(300.0, viewport_size.x * 0.46), 20.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.add_theme_font_size_override(&"font_size", 10)
	else:
		position = Vector2(466.0, 146.0)
		size = Vector2(500.0, 24.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", 15)
	label.size = size


func _refresh() -> void:
	var entries: PackedStringArray = []
	for upgrade_id: StringName in ORDER:
		entries.append(L10n.t("weapon.entry", {
			"label": L10n.t(LABELS[upgrade_id]),
			"rank": ranks[upgrade_id],
		}))
	label.text = L10n.t("weapon.separator").join(entries)
