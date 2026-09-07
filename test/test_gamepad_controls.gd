extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const TEST_PREFERENCE_PATH: String = "user://test-input-bindings.cfg"


func before_each() -> void:
	InputBindingSettings.reset_to_defaults(TEST_PREFERENCE_PATH, false)
	_clear_preference()


func after_each() -> void:
	for action: StringName in [&"stomp", &"dodge", &"move_left", &"move_right", &"ui_accept"]:
		Input.action_release(action)
	# Synthetic presses/releases can share one frame. Drain their edge flags
	# before another city starts polling input in the next test.
	await get_tree().physics_frame
	await get_tree().process_frame
	InputBindingSettings.reset_to_defaults(TEST_PREFERENCE_PATH, false)
	_clear_preference()


func test_project_maps_standard_gamepad_pilot_controls() -> void:
	assert_true(_has_joy_motion(&"move_left", JOY_AXIS_LEFT_X, -1.0))
	assert_true(_has_joy_motion(&"move_right", JOY_AXIS_LEFT_X, 1.0))
	assert_true(_has_joy_button(&"move_left", JOY_BUTTON_DPAD_LEFT))
	assert_true(_has_joy_button(&"move_right", JOY_BUTTON_DPAD_RIGHT))
	assert_true(_has_joy_button(&"ui_accept", JOY_BUTTON_A))
	assert_true(_has_joy_button(&"stomp", JOY_BUTTON_X))
	assert_false(_has_joy_button(&"stomp", JOY_BUTTON_A))
	assert_false(_has_joy_button(&"ui_accept", JOY_BUTTON_X))
	assert_true(_has_joy_button(&"dodge", JOY_BUTTON_B))
	assert_true(_has_key(&"stomp", KEY_SPACE))
	assert_false(_has_key(&"ui_accept", KEY_SPACE))
	assert_eq(InputBindingSettings.keyboard_key(&"dodge"), KEY_SHIFT)
	_record_test_execution()


func test_spacebar_is_reserved_for_melee_and_sanitized_from_other_actions() -> void:
	var ui_space: InputEventKey = InputEventKey.new()
	ui_space.keycode = KEY_SPACE
	ui_space.unicode = int(KEY_SPACE)
	InputMap.action_add_event(&"ui_accept", ui_space)
	var movement_space: InputEventKey = InputEventKey.new()
	movement_space.physical_keycode = KEY_SPACE
	InputMap.action_add_event(&"move_left", movement_space)
	assert_true(_has_key(&"ui_accept", KEY_SPACE))
	assert_true(_has_key(&"move_left", KEY_SPACE))
	InputBindingSettings.enforce_spacebar_melee_exclusivity()
	assert_false(_has_key(&"ui_accept", KEY_SPACE))
	assert_false(_has_key(&"move_left", KEY_SPACE))
	assert_true(_has_key(&"stomp", KEY_SPACE))
	assert_false(
		InputBindingSettings.set_keyboard_binding(
			&"move_right",
			KEY_SPACE,
			TEST_PREFERENCE_PATH
		)
	)
	assert_eq(InputBindingSettings.keyboard_key(&"move_right"), KEY_D)
	_record_test_execution()


func test_gamepad_confirm_is_reserved_and_never_overlaps_melee() -> void:
	var stale_confirm_on_melee: InputEventJoypadButton = InputEventJoypadButton.new()
	stale_confirm_on_melee.button_index = JOY_BUTTON_A
	InputMap.action_add_event(&"stomp", stale_confirm_on_melee)
	var stale_melee_on_confirm: InputEventJoypadButton = InputEventJoypadButton.new()
	stale_melee_on_confirm.button_index = JOY_BUTTON_X
	InputMap.action_add_event(&"ui_accept", stale_melee_on_confirm)
	assert_true(_has_joy_button(&"stomp", JOY_BUTTON_A))
	assert_true(_has_joy_button(&"ui_accept", JOY_BUTTON_X))
	InputBindingSettings.enforce_gamepad_confirm_exclusivity()
	assert_true(_has_joy_button(&"ui_accept", JOY_BUTTON_A))
	assert_false(_has_joy_button(&"ui_accept", JOY_BUTTON_X))
	assert_true(_has_joy_button(&"stomp", JOY_BUTTON_X))
	assert_false(_has_joy_button(&"stomp", JOY_BUTTON_A))
	assert_false(
		InputBindingSettings.set_gamepad_binding(
			&"stomp",
			JOY_BUTTON_A,
			TEST_PREFERENCE_PATH
		)
	)
	assert_eq(InputBindingSettings.gamepad_button(&"stomp"), JOY_BUTTON_X)
	var legacy_config: ConfigFile = ConfigFile.new()
	legacy_config.set_value("gamepad", "stomp", int(JOY_BUTTON_A))
	assert_eq(legacy_config.save(TEST_PREFERENCE_PATH), OK)
	assert_true(InputBindingSettings.apply_saved(TEST_PREFERENCE_PATH))
	assert_eq(InputBindingSettings.gamepad_button(&"stomp"), JOY_BUTTON_X)
	assert_true(_has_joy_button(&"ui_accept", JOY_BUTTON_A))
	assert_false(_has_joy_button(&"stomp", JOY_BUTTON_A))
	_record_test_execution()


func test_gamepad_confirm_does_not_start_melee_but_x_square_does() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	var confirm_press: InputEventJoypadButton = InputEventJoypadButton.new()
	confirm_press.device = 0
	confirm_press.button_index = JOY_BUTTON_A
	confirm_press.pressed = true
	Input.parse_input_event(confirm_press)
	city.robot._physics_process(1.0 / 60.0)
	assert_false(city.contextual_attacks.is_charging())
	var confirm_release: InputEventJoypadButton = (
		confirm_press.duplicate() as InputEventJoypadButton
	)
	confirm_release.pressed = false
	Input.parse_input_event(confirm_release)
	city.robot._physics_process(1.0 / 60.0)
	var melee_press: InputEventJoypadButton = InputEventJoypadButton.new()
	melee_press.device = 0
	melee_press.button_index = JOY_BUTTON_X
	melee_press.pressed = true
	assert_true(InputMap.event_is_action(melee_press, &"stomp"))
	assert_false(InputMap.event_is_action(melee_press, &"ui_accept"))
	Input.action_press(&"stomp")
	city.robot._physics_process(1.0 / 60.0)
	assert_true(city.contextual_attacks.is_charging())
	Input.action_release(&"stomp")
	city.robot._physics_process(1.0 / 60.0)
	city.robot.set_physics_process(false)
	_record_test_execution()


func test_physical_shift_event_starts_keyboard_dash() -> void:
	var shift_press: InputEventKey = InputEventKey.new()
	shift_press.physical_keycode = KEY_SHIFT
	shift_press.pressed = true
	assert_true(InputMap.event_is_action(shift_press, &"dodge"))
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var robot: GiantRobotController = city.robot
	robot.collision_mask = 0
	robot.gravity = 0.0
	robot.facing = -1
	Input.parse_input_event(shift_press)
	await get_tree().physics_frame
	var shift_release: InputEventKey = shift_press.duplicate() as InputEventKey
	shift_release.pressed = false
	Input.parse_input_event(shift_release)
	await get_tree().physics_frame
	assert_eq(robot.locomotion_state, GiantRobotController.LocomotionState.DODGE)
	assert_eq(robot.facing, -1)
	assert_eq(robot.dodge_count, 1)
	robot.set_physics_process(false)
	robot.cancel_dodge()
	_record_test_execution()


func test_dedicated_dodge_uses_direction_then_falls_back_to_facing() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var robot: GiantRobotController = city.robot
	robot.set_physics_process(false)
	robot.collision_mask = 0
	robot.gravity = 0.0
	assert_true(robot.request_dodge(-1))
	assert_eq(robot.facing, -1)
	assert_eq(robot.locomotion_state, GiantRobotController.LocomotionState.DODGE)
	assert_eq(robot.dodge_count, 1)
	robot.physics_step(0.0, robot.dodge_duration)
	robot.physics_step(0.0, robot.dodge_cooldown_seconds)
	robot.facing = 1
	assert_true(robot.request_dodge())
	assert_eq(robot.facing, 1)
	assert_eq(robot.dodge_count, 2)
	_record_test_execution()


func test_bindings_persist_and_conflicts_swap_instead_of_duplicate() -> void:
	assert_true(
		InputBindingSettings.set_keyboard_binding(
			&"move_left",
			KEY_J,
			TEST_PREFERENCE_PATH
		)
	)
	assert_true(
		InputBindingSettings.set_gamepad_binding(
			&"stomp",
			JOY_BUTTON_Y,
			TEST_PREFERENCE_PATH
		)
	)
	assert_true(
		InputBindingSettings.set_controller_vibration_enabled(
			false,
			TEST_PREFERENCE_PATH
		)
	)
	InputBindingSettings.reset_to_defaults(TEST_PREFERENCE_PATH, false)
	assert_eq(InputBindingSettings.keyboard_key(&"move_left"), KEY_A)
	assert_eq(InputBindingSettings.gamepad_button(&"stomp"), JOY_BUTTON_X)
	assert_true(InputBindingSettings.controller_vibration_enabled())
	assert_true(InputBindingSettings.apply_saved(TEST_PREFERENCE_PATH))
	assert_eq(InputBindingSettings.keyboard_key(&"move_left"), KEY_J)
	assert_eq(InputBindingSettings.gamepad_button(&"stomp"), JOY_BUTTON_Y)
	assert_false(InputBindingSettings.controller_vibration_enabled())
	assert_true(
		InputBindingSettings.set_keyboard_binding(
			&"move_right",
			KEY_J,
			TEST_PREFERENCE_PATH
		)
	)
	assert_eq(InputBindingSettings.keyboard_key(&"move_left"), KEY_D)
	assert_eq(InputBindingSettings.keyboard_key(&"move_right"), KEY_J)
	_record_test_execution()


func test_gamepad_vibration_is_bounded_and_respects_saved_opt_out() -> void:
	var haptics: HapticsAdapter = HapticsAdapter.new()
	haptics.setup(0, 3)
	add_child_autofree(haptics)
	await get_tree().process_frame
	assert_false(haptics.mobile_device_detected)
	assert_eq(haptics.gamepad_device_id, 3)
	assert_true(haptics.pulse(250))
	assert_eq(haptics.request_count, 1)
	assert_eq(haptics.gamepad_vibration_request_count, 1)
	assert_eq(haptics.last_duration_ms, 100)
	assert_between(haptics.last_weak_magnitude, 0.18, 0.55)
	assert_between(haptics.last_strong_magnitude, 0.35, 1.0)
	assert_eq(haptics.last_gamepad_duration_seconds, 0.10)
	assert_true(
		InputBindingSettings.set_controller_vibration_enabled(
			false,
			TEST_PREFERENCE_PATH
		)
	)
	assert_false(haptics.pulse(52))
	assert_eq(haptics.request_count, 1)
	assert_eq(haptics.gamepad_vibration_request_count, 1)
	_record_test_execution()


func test_settings_capture_updates_labels_and_reset_restores_defaults() -> void:
	var screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	screen.input_preference_path = TEST_PREFERENCE_PATH
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(screen.open_settings())
	var left_keyboard: Button = screen.get_node("%MoveLeftKeyboardButton") as Button
	left_keyboard.pressed.emit()
	assert_eq(left_keyboard.text, L10n.t("title.input_press_key"))
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_J
	key_event.pressed = true
	screen._input(key_event)
	assert_eq(InputBindingSettings.keyboard_key(&"move_left"), KEY_J)
	assert_eq(left_keyboard.text, "J")
	var dodge_gamepad: Button = screen.get_node("%DodgeGamepadButton") as Button
	dodge_gamepad.pressed.emit()
	assert_eq(dodge_gamepad.text, L10n.t("title.input_press_button"))
	var button_event: InputEventJoypadButton = InputEventJoypadButton.new()
	button_event.button_index = JOY_BUTTON_Y
	button_event.pressed = true
	screen._input(button_event)
	assert_eq(InputBindingSettings.gamepad_button(&"dodge"), JOY_BUTTON_Y)
	assert_eq(dodge_gamepad.text, "Y / TRIANGLE")
	dodge_gamepad.pressed.emit()
	var reserved_confirm_event: InputEventJoypadButton = InputEventJoypadButton.new()
	reserved_confirm_event.button_index = JOY_BUTTON_A
	reserved_confirm_event.pressed = true
	screen._input(reserved_confirm_event)
	assert_eq(InputBindingSettings.gamepad_button(&"dodge"), JOY_BUTTON_Y)
	assert_eq(dodge_gamepad.text, "Y / TRIANGLE")
	assert_null(screen.get_node_or_null("StatusRail"))
	assert_null(screen.get_node_or_null("%ControlsLabel"))
	var vibration_toggle: CheckButton = (
		screen.get_node("%ControllerVibrationToggle") as CheckButton
	)
	vibration_toggle.button_pressed = false
	assert_false(InputBindingSettings.controller_vibration_enabled())
	(screen.get_node("%ResetBindingsButton") as Button).pressed.emit()
	assert_eq(InputBindingSettings.keyboard_key(&"move_left"), KEY_A)
	assert_eq(InputBindingSettings.gamepad_button(&"dodge"), JOY_BUTTON_B)
	assert_true(InputBindingSettings.controller_vibration_enabled())
	assert_true(vibration_toggle.button_pressed)
	assert_eq(left_keyboard.text, "A")
	assert_eq(dodge_gamepad.text, "B / CIRCLE")
	_record_test_execution()


func _has_joy_button(action: StringName, button_index: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		if button_event != null and button_event.button_index == button_index:
			return true
	return false


func _has_key(action: StringName, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event == null:
			continue
		if (
			key_event.keycode == keycode
			or key_event.physical_keycode == keycode
			or key_event.unicode == int(keycode)
		):
			return true
	return false


func _has_joy_motion(action: StringName, axis: JoyAxis, axis_value: float) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		if (
			motion_event != null
			and motion_event.axis == axis
			and is_equal_approx(motion_event.axis_value, axis_value)
		):
			return true
	return false


func _clear_preference() -> void:
	if FileAccess.file_exists(TEST_PREFERENCE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PREFERENCE_PATH))


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
