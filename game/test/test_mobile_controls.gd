extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"


func test_mobile_detection_floating_joystick_and_smash_multitouch() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var desktop_controls: MobileControls = MobileControls.new()
	desktop_controls.detection_override = 0
	add_child_autofree(desktop_controls)
	await get_tree().process_frame
	assert_false(desktop_controls.mobile_device_detected)
	assert_false(desktop_controls.visible)
	var controls: MobileControls = MobileControls.new()
	controls.detection_override = 1
	add_child_autofree(controls)
	await get_tree().process_frame
	assert_true(controls.mobile_device_detected)
	assert_true(controls.visible)
	assert_gt(controls.smash_bounds().position.x, 1000.0)
	assert_gt(controls.smash_bounds().position.y, 500.0)
	controls.handle_touch_input(_screen_touch(3, Vector2(240.0, 520.0), true))
	assert_true(controls.joystick_active)
	assert_eq(controls.joystick_touch_index(), 3)
	controls.handle_touch_input(_screen_drag(3, Vector2(330.0, 520.0)))
	for response_step: int in range(5):
		controls.process_controls(1.0 / 60.0)
	assert_gt(controls.movement_axis(), 0.8)
	var smash_position: Vector2 = controls.smash_bounds().get_center()
	controls.handle_touch_input(_screen_touch(9, smash_position, true))
	assert_eq(controls.smash_press_count, 1)
	assert_eq(controls.smash_touch_index(), 9)
	assert_eq(controls.joystick_touch_index(), 3)
	assert_true(controls.joystick_active)
	assert_gt(controls.movement_axis(), 0.8)
	controls.handle_touch_input(_screen_drag(3, Vector2(155.0, 520.0)))
	for reversal_step: int in range(6):
		controls.process_controls(1.0 / 60.0)
	assert_lte(controls.movement_axis(), -0.8)
	controls.handle_touch_input(_screen_touch(9, smash_position, false))
	assert_eq(controls.smash_touch_index(), -1)
	assert_eq(controls.smash_release_count, 1)
	assert_true(controls.joystick_active)
	assert_lte(controls.movement_axis(), -0.8)
	controls.process_controls(controls.smash_cooldown)
	controls.handle_touch_input(_screen_touch(10, smash_position, true))
	assert_eq(controls.smash_press_count, 2)
	assert_eq(controls.smash_touch_index(), 10)
	controls.handle_touch_input(_screen_touch(10, smash_position, false))
	assert_eq(controls.smash_release_count, 2)
	controls.handle_touch_input(_screen_touch(3, Vector2(330.0, 520.0), false))
	for settle_step: int in range(5):
		controls.process_controls(1.0 / 60.0)
	assert_false(controls.joystick_active)
	assert_lt(absf(controls.movement_axis()), 0.05)
	_record_test_execution()


func test_disabling_mobile_controls_does_not_release_a_held_smash() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var controls: MobileControls = MobileControls.new()
	controls.detection_override = 1
	add_child_autofree(controls)
	await get_tree().process_frame
	var smash_position: Vector2 = controls.smash_bounds().get_center()
	controls.handle_touch_input(_screen_touch(41, smash_position, true))
	assert_eq(controls.smash_press_count, 1)
	assert_eq(controls.smash_release_count, 0)
	assert_eq(controls.smash_touch_index(), 41)
	controls.set_controls_enabled(false)
	assert_eq(controls.smash_touch_index(), -1)
	assert_eq(controls.smash_release_count, 0)
	controls.handle_touch_input(_screen_touch(41, smash_position, false))
	assert_eq(controls.smash_release_count, 0)
	_record_test_execution()


func test_portrait_dash_button_stacks_above_smash_and_uses_joystick_direction() -> void:
	get_tree().root.size = Vector2i(720, 1280)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	var smash_rect: Rect2 = city.mobile_controls.smash_bounds()
	var dash_rect: Rect2 = city.mobile_controls.dash_bounds()
	assert_gt(dash_rect.position.x, 500.0)
	assert_lt(dash_rect.end.y, smash_rect.position.y)
	assert_lt(dash_rect.size.x, smash_rect.size.x)
	assert_lt(dash_rect.size.y, smash_rect.size.y)
	assert_almost_eq(dash_rect.get_center().x, smash_rect.get_center().x, 0.01)
	city.mobile_controls.handle_touch_input(
		_screen_touch(40, Vector2(180.0, 1040.0), true)
	)
	city.mobile_controls.handle_touch_input(
		_screen_drag(40, Vector2(85.0, 1040.0))
	)
	for response_step: int in range(5):
		city.mobile_controls.process_controls(1.0 / 60.0)
	assert_lt(city.mobile_controls.movement_axis(), -0.8)
	city.mobile_controls.handle_touch_input(
		_screen_touch(41, dash_rect.get_center(), true)
	)
	assert_eq(city.mobile_controls.dash_press_count, 1)
	assert_eq(city.mobile_controls.dash_touch_index(), 41)
	assert_eq(city.mobile_controls.joystick_touch_index(), 40)
	assert_eq(city.mobile_controls.smash_touch_index(), -1)
	assert_true(city.mobile_controls.joystick_active)
	assert_eq(city.robot.locomotion_state, GiantRobotController.LocomotionState.DODGE)
	assert_eq(city.robot.facing, -1)
	assert_eq(city.robot.dodge_count, 1)
	assert_false(city.mobile_controls.dash_ready_feedback_active())
	assert_lt(city.mobile_controls.dash_button.modulate.a, 0.60)
	city.mobile_controls.handle_touch_input(
		_screen_touch(41, dash_rect.get_center(), false)
	)
	city.mobile_controls.handle_touch_input(
		_screen_touch(40, Vector2(85.0, 1040.0), false)
	)
	assert_eq(city.mobile_controls.dash_touch_index(), -1)
	assert_eq(city.mobile_controls.joystick_touch_index(), -1)
	city.robot.physics_step(0.0, city.robot.dodge_cooldown_seconds + 0.01)
	assert_true(city.mobile_controls.dash_ready_feedback_active())
	assert_eq(city.mobile_controls.dash_ready_pulse_count(), 1)
	city.mobile_controls.process_controls(0.15)
	assert_gt(city.mobile_controls.dash_button.scale.x, 1.08)
	assert_eq(city.mobile_controls.dash_button.scale.x, city.mobile_controls.dash_button.scale.y)
	_record_test_execution()


func test_mobile_controls_drive_robot_and_remain_live_after_defeat() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	await get_tree().physics_frame
	assert_true(city.mobile_controls.mobile_device_detected)
	assert_true(city.mobile_controls.visible)
	assert_eq(city.mobile_controls.get_parent().name, "HUD")
	var start_x: float = city.robot.position.x
	city.robot.set_physics_process(false)
	city.mobile_controls.handle_touch_input(
		_screen_touch(2, Vector2(210.0, 530.0), true)
	)
	city.mobile_controls.handle_touch_input(
		_screen_drag(2, Vector2(300.0, 530.0))
	)
	for response_step: int in range(8):
		city.mobile_controls.process_controls(1.0 / 60.0)
	assert_gt(city.robot.virtual_move_axis, 0.8)
	for movement_step: int in range(60):
		city.robot.physics_step(city.robot.virtual_move_axis, 1.0 / 60.0)
		await get_tree().physics_frame
	assert_gt(city.robot.position.x, start_x + 150.0)
	city.car.current_health = 1.0
	city.robot.velocity.x = 0.0
	var smash_position: Vector2 = city.mobile_controls.smash_bounds().get_center()
	city.mobile_controls.handle_touch_input(
		_screen_touch(8, smash_position, true)
	)
	assert_true(city.contextual_attacks.current_spec.is_ground_smash())
	assert_true(city.contextual_attacks.is_charging())
	assert_eq(city.mobile_controls.joystick_touch_index(), 2)
	assert_eq(city.mobile_controls.smash_touch_index(), 8)
	assert_eq(city.haptics_adapter.request_count, 0)
	city.mobile_controls.handle_touch_input(
		_screen_touch(8, smash_position, false)
	)
	assert_false(city.contextual_attacks.is_charging())
	assert_eq(city.mobile_controls.smash_release_count, 1)
	var ground_spec: AttackSpec = city.contextual_attacks.current_spec
	await get_tree().create_timer(ground_spec.anticipation_seconds + 0.03).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(city.car.is_broken)
	assert_eq(city.haptics_adapter.request_count, 1)
	await get_tree().create_timer(
		ground_spec.active_seconds + ground_spec.recovery_seconds + 0.03
	).timeout
	var haptic_count_after_ground_smash: int = city.haptics_adapter.request_count
	city.robot.velocity.x = city.robot.max_speed * 0.8
	city.tank.activate(
		city.robot.global_position + Vector2(120.0 * float(city.robot.facing), 60.0),
		city.robot
	)
	city.tank.current_health = 1.0
	city.tank.set_physics_process(false)
	city.mobile_controls.process_controls(city.mobile_controls.smash_cooldown)
	city.mobile_controls.handle_touch_input(
		_screen_touch(9, smash_position, true)
	)
	assert_not_null(city.contextual_attacks.current_spec)
	if city.contextual_attacks.current_spec == null:
		return
	assert_true(city.contextual_attacks.current_spec.is_jab_cross())
	assert_true(city.contextual_attacks.is_charging())
	assert_eq(city.mobile_controls.joystick_touch_index(), 2)
	assert_eq(city.mobile_controls.smash_touch_index(), 9)
	city.mobile_controls.handle_touch_input(
		_screen_touch(9, smash_position, false)
	)
	assert_false(city.contextual_attacks.is_charging())
	assert_eq(city.mobile_controls.smash_release_count, 2)
	var jab_spec: AttackSpec = city.contextual_attacks.current_spec
	await get_tree().create_timer(jab_spec.anticipation_seconds + 0.03).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_gt(city.contextual_attacks.jab_cross_impact.last_query_count, 0)
	assert_gt(city.contextual_attacks.jab_cross_impact.last_accepted_targets, 0)
	assert_lt(city.tank.current_health, city.tank.max_health)
	assert_gte(city.haptics_adapter.request_count, haptic_count_after_ground_smash + 1)
	assert_true(city.mobile_controls.joystick_active)
	var structural_cell: Destructible2D
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			var candidate: Destructible2D = city.building.get_cell(column, row)
			if candidate != null and not candidate.is_destroyed():
				structural_cell = candidate
				break
		if structural_cell != null:
			break
	assert_not_null(structural_cell)
	if structural_cell == null:
		return
	assert_false(structural_cell.is_destroyed())
	assert_true(
		structural_cell.receive_damage(
			DamageEvent.new(
				9301,
				city.robot,
				structural_cell.max_health + 1.0,
				&"structural",
				structural_cell.global_position,
				Vector2.RIGHT,
				260.0
			)
		)
	)
	await get_tree().process_frame
	assert_gte(city.haptics_adapter.request_count, haptic_count_after_ground_smash + 2)
	assert_eq(city.haptics_adapter.last_duration_ms, 52)
	city.robot.receive_damage(DamageEvent.new(9201, null, 9999.0))
	assert_true(city.game_over_active)
	assert_true(city.mobile_controls.joystick_active)
	assert_gt(city.mobile_controls.movement_axis(), 0.8)
	assert_eq(city.mobile_controls.joystick_touch_index(), 2)
	assert_eq(city.mobile_controls.smash_touch_index(), -1)
	assert_eq(city.mobile_controls.dash_touch_index(), -1)
	_record_test_execution()


func test_mobile_joystick_double_flick_dodges_in_selected_direction() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	for tap_index: int in range(2):
		var touch_index: int = 20 + tap_index
		city.mobile_controls.handle_touch_input(
			_screen_touch(touch_index, Vector2(210.0, 530.0), true)
		)
		city.mobile_controls.handle_touch_input(
			_screen_drag(touch_index, Vector2(300.0, 530.0))
		)
		city.mobile_controls.handle_touch_input(
			_screen_touch(touch_index, Vector2(300.0, 530.0), false)
		)
	assert_eq(city.robot.locomotion_state, GiantRobotController.LocomotionState.DODGE)
	assert_eq(city.robot.facing, 1)
	assert_eq(city.robot.dodge_count, 1)
	assert_eq(city.mobile_controls.smash_press_count, 0)
	_record_test_execution()


func test_mobile_smash_touch_cancels_dodge_into_half_momentum_melee() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	assert_true(city.robot._start_dodge(-1))
	var smash_position: Vector2 = city.mobile_controls.smash_bounds().get_center()
	city.mobile_controls.handle_touch_input(
		_screen_touch(31, smash_position, true)
	)
	var spec: AttackSpec = city.contextual_attacks.current_spec
	assert_not_null(spec)
	if spec == null:
		return
	assert_eq(city.mobile_controls.smash_press_count, 1)
	assert_true(city.contextual_attacks.is_charging())
	assert_true(spec.is_jab_cross())
	assert_eq(spec.facing, -1)
	assert_almost_eq(spec.speed_ratio, 0.50, 0.0001)
	assert_almost_eq(spec.impulse_per_mass, 540.0, 0.001)
	assert_eq(
		city.robot.locomotion_state,
		GiantRobotController.LocomotionState.ATTACK_LOCKED
	)
	assert_false(city.robot.dodge_invulnerable)
	city.contextual_attacks._process(1.0)
	city.mobile_controls.handle_touch_input(
		_screen_touch(31, smash_position, false)
	)
	assert_false(city.contextual_attacks.is_charging())
	assert_eq(city.mobile_controls.smash_release_count, 1)
	spec = city.contextual_attacks.current_spec
	assert_almost_eq(spec.actor_damage, 108.75, 0.001)
	assert_almost_eq(spec.structural_damage, 93.75, 0.001)
	assert_almost_eq(spec.impulse_per_mass, 540.0, 0.001)
	_record_test_execution()


func _screen_touch(
	index: int,
	position: Vector2,
	pressed: bool
) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _screen_drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
