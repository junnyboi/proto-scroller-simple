class_name DebugTweakLauncher
extends Button


func _ready() -> void:
	name = "DebugTweakLauncher"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = OS.is_debug_build()
	z_index = 100
	modulate.a = 0.5
	RuntimeTweakTheme.style_button(self, false, true)
	mouse_entered.connect(_refresh_opacity)
	mouse_exited.connect(_refresh_opacity)
	focus_entered.connect(_refresh_opacity)
	focus_exited.connect(_refresh_opacity)
	button_down.connect(_refresh_opacity)
	button_up.connect(_refresh_opacity)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	_layout()
	var label: String = L10n.t("tuning.action.open")
	if text != label:
		text = label
		tooltip_text = text
		accessibility_name = text
		L10n.apply_locale_font(self)


func _layout() -> void:
	size = Vector2(192.0, 44.0)
	var main: Main = get_parent().get_parent() as Main
	var touch_gameplay: bool = DisplayServer.is_touchscreen_available() and main != null and main.city_slice != null and not main.city_slice.game_over_active and not main.city_slice.urban_siege.pause_coordinator.is_paused()
	var bottom_margin: float = 274.0 if touch_gameplay else 18.0
	position = get_viewport_rect().size - size - Vector2(24.0, bottom_margin)


func _refresh_opacity() -> void:
	modulate.a = 1.0 if is_hovered() or has_focus() or button_pressed else 0.5
