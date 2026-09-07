extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")


func test_shared_settings_pauses_and_close_resumes_gameplay() -> void:
	var main: Main = await _spawn_gameplay()
	var city: CitySlice = main.city_slice
	var coordinator: RunPauseCoordinator = city.urban_siege.pause_coordinator
	var escape_event: InputEventKey = _escape_event()
	assert_true(escape_event.is_action_pressed(&"ui_cancel"))
	main.open_gameplay_settings()
	assert_true(main.gameplay_settings_open())
	assert_not_null(main.gameplay_settings_layer)
	assert_eq(main.gameplay_settings_layer.layer, Main.GAMEPLAY_SETTINGS_LAYER)
	assert_true(main.gameplay_settings_screen.settings_only_mode)
	assert_true(main.gameplay_settings_screen.settings_layer.is_visible_in_tree())
	assert_eq(coordinator.lease_reasons(), [Main.GAMEPLAY_SETTINGS_PAUSE_REASON])
	assert_false(city.robot.can_process())
	assert_false(city.mobile_controls.controls_enabled())
	assert_false(city.encounter_runtime.can_process())
	for child: Node in main.gameplay_settings_screen.get_children():
		if child == main.gameplay_settings_screen.settings_layer:
			continue
		var canvas_item: CanvasItem = child as CanvasItem
		if canvas_item != null:
			assert_false(canvas_item.visible, child.name)
	main.gameplay_settings_screen.settings_close_button.pressed.emit()
	assert_false(main.gameplay_settings_open())
	assert_false(main.gameplay_settings_screen.settings_layer.visible)
	assert_false(coordinator.is_paused())
	assert_true(city.robot.is_physics_processing())
	assert_true(city.mobile_controls.controls_enabled())
	assert_eq(city.encounter_runtime.process_mode, Node.PROCESS_MODE_INHERIT)


func test_escape_closes_settings_and_existing_pause_owner_blocks_opening() -> void:
	var main: Main = await _spawn_gameplay()
	var city: CitySlice = main.city_slice
	var coordinator: RunPauseCoordinator = city.urban_siege.pause_coordinator
	var blocking_token: int = coordinator.acquire(&"existing_modal")
	main.open_gameplay_settings()
	assert_false(main.gameplay_settings_open())
	assert_null(main.gameplay_settings_layer)
	assert_eq(coordinator.lease_reasons(), [&"existing_modal"])
	assert_true(coordinator.release(blocking_token))
	main.open_gameplay_settings()
	assert_true(main.gameplay_settings_open())
	main.gameplay_settings_screen._unhandled_input(_escape_event())
	assert_false(main.gameplay_settings_open())
	assert_false(coordinator.is_paused())
	assert_true(city.robot.is_physics_processing())
	assert_true(city.mobile_controls.controls_enabled())


func test_viewport_routes_escape_to_open_then_close_without_reusing_the_press() -> void:
	var main: Main = await _spawn_gameplay()
	Input.parse_input_event(_escape_event())
	await get_tree().process_frame
	Input.parse_input_event(_escape_release_event())
	await get_tree().process_frame
	assert_true(main.pause_menu.is_open())
	assert_true(main.city_slice.urban_siege.pause_coordinator.is_paused())
	Input.parse_input_event(_escape_event())
	await get_tree().process_frame
	Input.parse_input_event(_escape_release_event())
	await get_tree().process_frame
	assert_false(main.pause_menu.is_open())
	assert_false(main.city_slice.urban_siege.pause_coordinator.is_paused())


func _spawn_gameplay() -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	assert_not_null(main.city_slice)
	return main


func _escape_event() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	return event


func _escape_release_event() -> InputEventKey:
	var event: InputEventKey = _escape_event()
	event.pressed = false
	return event
