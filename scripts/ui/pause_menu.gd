class_name ScrollerPauseMenu
extends CanvasLayer

const PANEL_TEXTURE: Texture2D = preload("res://assets/ui/pause/pause_console.png")
var main: Main
var lease: RuntimeTweakPauseAdapter = RuntimeTweakPauseAdapter.new()
var surface: Control
var frame: PanelContainer
var launcher: Button
var buttons: Dictionary[StringName, Button] = {}
var heading: Label
var reduced_motion: CheckBox
var confirmation: ConfirmationDialog
var pending_action: StringName = &""
var _locale: String = ""


func _ready() -> void:
	layer = 180
	process_mode = Node.PROCESS_MODE_ALWAYS
	launcher = Button.new()
	RuntimeTweakTheme.style_button(launcher)
	launcher.custom_minimum_size = Vector2(108, 44)
	launcher.pressed.connect(open)
	add_child(launcher)
	surface = Control.new()
	surface.theme = RuntimeTweakTheme.compact_theme()
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(surface)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.015, 0.025, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(shade)
	frame = PanelContainer.new()
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = PANEL_TEXTURE
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 64)
		style.set_content_margin(side, 30)
	frame.add_theme_stylebox_override("panel", style)
	surface.add_child(frame)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	frame.add_child(column)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	column.add_child(heading)
	for action: StringName in [&"resume", &"settings", &"restart", &"tutorial", &"title"]:
		var button: Button = Button.new()
		button.custom_minimum_size.y = 48
		RuntimeTweakTheme.style_button(button)
		button.custom_minimum_size.y = 48
		button.pressed.connect(_activate.bind(action))
		buttons[action] = button
		column.add_child(button)
	reduced_motion = CheckBox.new()
	reduced_motion.add_theme_font_size_override("font_size", 18)
	reduced_motion.custom_minimum_size.y = 44
	reduced_motion.toggled.connect(PresentationSettings.set_reduced_motion)
	column.add_child(reduced_motion)
	confirmation = ConfirmationDialog.new()
	confirmation.process_mode = Node.PROCESS_MODE_ALWAYS
	confirmation.confirmed.connect(_confirm_action)
	confirmation.canceled.connect(func() -> void: buttons[&"resume"].grab_focus())
	add_child(confirmation)
	surface.hide()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_locale()


func _process(_delta: float) -> void:
	launcher.visible = main != null and main.city_slice != null and not main.city_slice.game_over_active and not lease.is_active() and not main.gameplay_settings_open() and not main.title_transition_active and not main.runtime_tweak_panel.is_open() and not main.city_slice.urban_siege.pause_coordinator.is_paused()
	if _locale != L10n.current_locale():
		_refresh_locale()


func open() -> bool:
	if main == null or main.city_slice == null or main.city_slice.game_over_active or main.title_transition_active or lease.is_active():
		return false
	if main.city_slice.urban_siege.pause_coordinator.is_paused():
		return false
	if not lease.acquire(main.city_slice, main, &"pause_menu"):
		return false
	surface.show()
	_refresh_locale()
	reduced_motion.set_pressed_no_signal(PresentationSettings.reduced_motion())
	buttons[&"resume"].call_deferred("grab_focus")
	main.menu_audio.play_cue(&"pause")
	return true


func close() -> bool:
	if not lease.is_active():
		return false
	confirmation.hide()
	surface.hide()
	lease.release()
	return true


func is_open() -> bool:
	return surface != null and surface.visible


func _activate(action: StringName) -> void:
	main.menu_audio.play_cue(&"confirm")
	match action:
		&"resume":
			main.menu_audio.play_cue(&"resume")
			close()
		&"settings":
			main.open_gameplay_settings()
		&"restart", &"title":
			pending_action = action
			confirmation.title = L10n.t("pause.confirm_title")
			confirmation.dialog_text = L10n.t("pause.confirm." + String(action))
			confirmation.ok_button_text = L10n.t("pause." + String(action))
			confirmation.cancel_button_text = L10n.t("common.cancel")
			L10n.apply_locale_font(confirmation)
			confirmation.popup_centered(Vector2i(420, 180))
		&"tutorial":
			main.city_slice.tutorial_run = true
			main.city_slice.gameplay_hud.first_run_tutorial.replay()
			close()


func _confirm_action() -> void:
	var action: StringName = pending_action
	close()
	if action == &"restart":
		main.retry_game()
	elif action == &"title":
		main.return_to_title_with_transition()


func _unhandled_input(event: InputEvent) -> void:
	var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START and not Input.is_joy_button_pressed(event.device, JOY_BUTTON_BACK)
	if not event.is_action_pressed(&"ui_cancel") and not start:
		return
	if confirmation.visible or main == null or main.gameplay_settings_open() or main.runtime_tweak_panel.is_open():
		return
	if is_open():
		close()
		get_viewport().set_input_as_handled()
	elif start and open():
		get_viewport().set_input_as_handled()


func _layout() -> void:
	var area: Vector2 = get_viewport().get_visible_rect().size
	surface.size = area
	var portrait: bool = area.y > area.x
	frame.size = Vector2(minf(520 if portrait else 460, area.x - 32), 550 if portrait else 470)
	for button: Button in buttons.values():
		button.custom_minimum_size.y = 60 if portrait else 48
		button.add_theme_font_size_override("font_size", 22 if portrait else 18)
	frame.position = (area - frame.size) * 0.5
	launcher.position = Vector2(area.x - 132, 18 if portrait else 138)
	launcher.size = Vector2(108, 44)


func _refresh_locale() -> void:
	_locale = L10n.current_locale()
	heading.text = L10n.t("pause.heading")
	launcher.text = L10n.t("pause.open")
	launcher.tooltip_text = launcher.text
	for action: StringName in buttons:
		buttons[action].text = L10n.t("pause." + String(action))
	reduced_motion.text = L10n.t("presentation.reduced_motion")
	L10n.apply_locale_font(surface)
	L10n.apply_locale_font(launcher)


func _exit_tree() -> void:
	lease.release()
