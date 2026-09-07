class_name InputBindingSettings
extends RefCounted

const PREFERENCE_PATH: String = "user://input_bindings.cfg"
const ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"stomp",
	&"dodge",
]
const DEFAULT_KEY_CODES: Dictionary = {
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"stomp": KEY_SPACE,
	&"dodge": KEY_SHIFT,
}
const KEYBOARD_ALIASES: Dictionary = {
	&"move_left": [KEY_LEFT],
	&"move_right": [KEY_RIGHT],
}
const DEFAULT_GAMEPAD_BUTTONS: Dictionary = {
	&"move_left": JOY_BUTTON_DPAD_LEFT,
	&"move_right": JOY_BUTTON_DPAD_RIGHT,
	&"stomp": JOY_BUTTON_X,
	&"dodge": JOY_BUTTON_B,
}
const RESERVED_MELEE_KEY: Key = KEY_SPACE
const RESERVED_UI_CONFIRM_BUTTON: JoyButton = JOY_BUTTON_A

static var _controller_vibration_enabled: bool = true


static func apply_saved(path: String = PREFERENCE_PATH) -> bool:
	_apply_default_bindings()
	_controller_vibration_enabled = true
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(path)
	if load_error == ERR_FILE_NOT_FOUND:
		return true
	if load_error != OK:
		return false
	for action: StringName in ACTIONS:
		var keyboard_code: Key = int(
			config.get_value("keyboard", String(action), DEFAULT_KEY_CODES[action])
		) as Key
		if keyboard_code == RESERVED_MELEE_KEY and action != &"stomp":
			keyboard_code = DEFAULT_KEY_CODES[action] as Key
		var saved_gamepad_button: JoyButton = int(
			config.get_value(
				"gamepad",
				String(action),
				DEFAULT_GAMEPAD_BUTTONS[action]
			)
		) as JoyButton
		if saved_gamepad_button == RESERVED_UI_CONFIRM_BUTTON:
			saved_gamepad_button = DEFAULT_GAMEPAD_BUTTONS[action] as JoyButton
		if keyboard_code != KEY_NONE:
			_replace_keyboard_event(action, keyboard_code)
		if saved_gamepad_button >= JOY_BUTTON_A and saved_gamepad_button < JOY_BUTTON_MAX:
			_replace_gamepad_button(action, saved_gamepad_button)
	_controller_vibration_enabled = bool(
		config.get_value("feedback", "controller_vibration", true)
	)
	enforce_spacebar_melee_exclusivity()
	enforce_gamepad_confirm_exclusivity()
	return true


static func set_keyboard_binding(
	action: StringName,
	keycode: Key,
	path: String = PREFERENCE_PATH
) -> bool:
	if not ACTIONS.has(action) or keycode == KEY_NONE:
		return false
	if keycode == RESERVED_MELEE_KEY and action != &"stomp":
		return false
	if keycode == KEY_LEFT and action != &"move_left":
		return false
	if keycode == KEY_RIGHT and action != &"move_right":
		return false
	var previous_key: Key = keyboard_key(action)
	var conflict_action: StringName = _action_for_keyboard(keycode, action)
	if not conflict_action.is_empty():
		_replace_keyboard_event(conflict_action, previous_key)
	_replace_keyboard_event(action, keycode)
	return _save(path) == OK


static func set_gamepad_binding(
	action: StringName,
	button: JoyButton,
	path: String = PREFERENCE_PATH
) -> bool:
	if (
		not ACTIONS.has(action)
		or button < JOY_BUTTON_A
		or button >= JOY_BUTTON_MAX
		or button == RESERVED_UI_CONFIRM_BUTTON
	):
		return false
	var previous_button: JoyButton = gamepad_button(action)
	var conflict_action: StringName = _action_for_gamepad_button(button, action)
	if not conflict_action.is_empty():
		_replace_gamepad_button(conflict_action, previous_button)
	_replace_gamepad_button(action, button)
	return _save(path) == OK


static func reset_to_defaults(
	path: String = PREFERENCE_PATH,
	persist: bool = true
) -> bool:
	_apply_default_bindings()
	_controller_vibration_enabled = true
	if not persist:
		return true
	return _save(path) == OK


static func set_controller_vibration_enabled(
	enabled: bool,
	path: String = PREFERENCE_PATH
) -> bool:
	_controller_vibration_enabled = enabled
	return _save(path) == OK


static func controller_vibration_enabled() -> bool:
	return _controller_vibration_enabled


static func enforce_spacebar_melee_exclusivity() -> void:
	_remove_spacebar_events(&"ui_accept")
	for action: StringName in ACTIONS:
		if action != &"stomp":
			_remove_spacebar_events(action)


static func enforce_gamepad_confirm_exclusivity() -> void:
	_replace_gamepad_button(&"ui_accept", RESERVED_UI_CONFIRM_BUTTON)
	for action: StringName in ACTIONS:
		_remove_gamepad_button_events(action, RESERVED_UI_CONFIRM_BUTTON)


static func keyboard_key(action: StringName) -> Key:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null:
			return key_event.physical_keycode as Key
	return KEY_NONE


static func gamepad_button(action: StringName) -> JoyButton:
	for event: InputEvent in InputMap.action_get_events(action):
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		if button_event != null:
			return button_event.button_index as JoyButton
	return JOY_BUTTON_INVALID


static func keyboard_label(action: StringName) -> String:
	var label: String = OS.get_keycode_string(keyboard_key(action))
	return label.to_upper() if not label.is_empty() else "—"


static func display_placeholders() -> Dictionary:
	return {
		"move_left": keyboard_label(&"move_left"),
		"move_right": keyboard_label(&"move_right"),
		"smash": keyboard_label(&"stomp"),
		"dodge": keyboard_label(&"dodge"),
		"pad_left": gamepad_label(&"move_left"),
		"pad_right": gamepad_label(&"move_right"),
		"pad_smash": gamepad_label(&"stomp"),
		"pad_dodge": gamepad_label(&"dodge"),
	}


static func gamepad_label(action: StringName) -> String:
	match gamepad_button(action):
		JOY_BUTTON_A:
			return L10n.t("input.gamepad.a")
		JOY_BUTTON_B:
			return L10n.t("input.gamepad.b")
		JOY_BUTTON_X:
			return L10n.t("input.gamepad.x")
		JOY_BUTTON_Y:
			return L10n.t("input.gamepad.y")
		JOY_BUTTON_BACK:
			return L10n.t("input.gamepad.back")
		JOY_BUTTON_START:
			return L10n.t("input.gamepad.start")
		JOY_BUTTON_LEFT_STICK:
			return L10n.t("input.gamepad.left_stick")
		JOY_BUTTON_RIGHT_STICK:
			return L10n.t("input.gamepad.right_stick")
		JOY_BUTTON_LEFT_SHOULDER:
			return L10n.t("input.gamepad.left_shoulder")
		JOY_BUTTON_RIGHT_SHOULDER:
			return L10n.t("input.gamepad.right_shoulder")
		JOY_BUTTON_DPAD_UP:
			return L10n.t("input.gamepad.up")
		JOY_BUTTON_DPAD_DOWN:
			return L10n.t("input.gamepad.down")
		JOY_BUTTON_DPAD_LEFT:
			return L10n.t("input.gamepad.left")
		JOY_BUTTON_DPAD_RIGHT:
			return L10n.t("input.gamepad.right")
		_:
			return L10n.t("input.gamepad.button", {"button": gamepad_button(action)})


static func _apply_default_bindings() -> void:
	for action: StringName in ACTIONS:
		_replace_keyboard_event(action, DEFAULT_KEY_CODES[action] as Key)
		_replace_gamepad_button(action, DEFAULT_GAMEPAD_BUTTONS[action] as JoyButton)
	enforce_spacebar_melee_exclusivity()
	enforce_gamepad_confirm_exclusivity()


static func _remove_spacebar_events(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event == null:
			continue
		if (
			key_event.keycode == RESERVED_MELEE_KEY
			or key_event.physical_keycode == RESERVED_MELEE_KEY
			or key_event.unicode == int(RESERVED_MELEE_KEY)
		):
			InputMap.action_erase_event(action, event)


static func _replace_keyboard_event(action: StringName, keycode: Key) -> void:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var replacement: InputEventKey = InputEventKey.new()
	replacement.physical_keycode = keycode
	InputMap.action_add_event(action, replacement)
	for alias_key: Key in KEYBOARD_ALIASES.get(action, []):
		if alias_key == keycode:
			continue
		var alias_event: InputEventKey = InputEventKey.new()
		alias_event.physical_keycode = alias_key
		InputMap.action_add_event(action, alias_event)


static func _replace_gamepad_button(action: StringName, button: JoyButton) -> void:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(action, event)
	var replacement: InputEventJoypadButton = InputEventJoypadButton.new()
	replacement.button_index = button
	InputMap.action_add_event(action, replacement)


static func _remove_gamepad_button_events(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for event: InputEvent in InputMap.action_get_events(action):
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		if button_event != null and button_event.button_index == button:
			InputMap.action_erase_event(action, event)


static func _action_for_keyboard(
	keycode: Key,
	excluded_action: StringName
) -> StringName:
	for action: StringName in ACTIONS:
		if action != excluded_action and keyboard_key(action) == keycode:
			return action
	return &""


static func _action_for_gamepad_button(
	button: JoyButton,
	excluded_action: StringName
) -> StringName:
	for action: StringName in ACTIONS:
		if action != excluded_action and gamepad_button(action) == button:
			return action
	return &""


static func _save(path: String) -> Error:
	var config: ConfigFile = ConfigFile.new()
	for action: StringName in ACTIONS:
		config.set_value("keyboard", String(action), int(keyboard_key(action)))
		config.set_value("gamepad", String(action), int(gamepad_button(action)))
	config.set_value("feedback", "controller_vibration", _controller_vibration_enabled)
	var absolute_directory: String = ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(absolute_directory)
	return config.save(path)
