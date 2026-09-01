extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

var city: CitySlice
var main: Main


func after_each() -> void:
	if get_tree().paused:
		get_tree().paused = false
	RuntimeTweakAccess.unbind_service()


func test_pause_adapter_freezes_tree_neutralizes_input_and_restores_exact_state() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var adapter: RuntimeTweakPauseAdapter = RuntimeTweakPauseAdapter.new()
	Input.action_press(&"stomp")
	Input.action_press(&"dodge")
	var mobile_before: bool = city.mobile_controls.controls_enabled()
	var physics_before: bool = city.robot.is_physics_processing()
	assert_true(adapter.acquire(city))
	assert_true(get_tree().paused)
	assert_false(Input.is_action_pressed(&"stomp"))
	assert_false(Input.is_action_pressed(&"dodge"))
	assert_false(city.mobile_controls.controls_enabled())
	assert_false(city.robot.is_physics_processing())
	assert_eq(city.urban_siege.pause_coordinator.lease_reasons(), [&"runtime_tuning"])
	var robot_position: Vector2 = city.robot.global_position
	var hazard_activations: int = city.urban_siege.hazards.activation_count
	var timer_finished: Array[bool] = [false]
	get_tree().create_timer(0.01, false).timeout.connect(func() -> void:
		timer_finished[0] = true
	)
	for _frame: int in range(120):
		await get_tree().process_frame
	assert_eq(city.robot.global_position, robot_position)
	assert_eq(city.urban_siege.hazards.activation_count, hazard_activations)
	assert_false(timer_finished[0])
	assert_true(adapter.release())
	assert_false(get_tree().paused)
	await get_tree().create_timer(0.02).timeout
	assert_true(timer_finished[0])
	assert_eq(city.mobile_controls.controls_enabled(), mobile_before)
	assert_eq(city.robot.is_physics_processing(), physics_before)


func test_modal_policy_rejects_existing_pause_owner_without_stealing_lease() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var coordinator: RunPauseCoordinator = city.urban_siege.pause_coordinator
	var modal_token: int = coordinator.acquire(&"other_modal")
	var status: Dictionary = RuntimeTweakModalPolicy.entry_status(city)
	assert_false(bool(status.allowed))
	assert_eq(status.reason, &"other_modal")
	var adapter: RuntimeTweakPauseAdapter = RuntimeTweakPauseAdapter.new()
	assert_false(adapter.acquire(city))
	assert_eq(coordinator.lease_count(), 1)
	assert_true(coordinator.release(modal_token))


func test_main_mounts_fixed_panel_and_space_cannot_activate_focused_close() -> void:
	main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	var panel: RuntimeTweakPanel = main.runtime_tweak_panel
	assert_not_null(panel)
	assert_not_null(main.runtime_tweak_layer)
	assert_eq(main.runtime_tweak_layer.layer, 200)
	assert_eq(panel.get_parent(), main.runtime_tweak_layer)
	assert_eq(panel.rows.size(), RuntimeTweakPanel.ROW_POOL_SIZE)
	assert_eq(panel.category_selector.item_count, 7)
	assert_true(panel.open())
	assert_true(get_tree().paused)
	panel.close_button.grab_focus()
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	panel._unhandled_input(space)
	assert_true(panel.is_open())
	assert_true(get_tree().paused)
	assert_true(panel.close())
	assert_false(get_tree().paused)


func test_bottom_right_hud_button_opens_pause_safe_tuning_panel() -> void:
	L10n.set_locale("en")
	main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	var panel: RuntimeTweakPanel = main.runtime_tweak_panel
	var hud: GameplayHud = main.city_slice.gameplay_hud
	var button: Button = hud.tweak_controls_button
	var disclaimer: Label = hud.tweak_leaderboard_disclaimer
	var viewport_size: Vector2 = main.get_viewport().get_visible_rect().size
	assert_not_null(button)
	assert_not_null(disclaimer)
	assert_eq(button.text, "TWEAK CONTROLS")
	assert_true(button.visible)
	assert_eq(button.size, Vector2(138.0, 24.0))
	assert_eq(button.get_theme_font_size(&"font_size"), 9)
	assert_eq(button.z_index, GameplayHud.TWEAK_BUTTON_Z_INDEX)
	assert_gt(button.z_index, hud.game_over_overlay.z_index)
	assert_gt(button.z_index, hud.directive_choice_overlay.z_index)
	assert_eq(button.self_modulate.a, GameplayHud.TWEAK_BUTTON_IDLE_OPACITY)
	button.mouse_entered.emit()
	assert_eq(button.self_modulate.a, GameplayHud.TWEAK_BUTTON_HOVER_OPACITY)
	button.mouse_exited.emit()
	assert_eq(button.self_modulate.a, GameplayHud.TWEAK_BUTTON_IDLE_OPACITY)
	hud._set_tuning_provenance({"ranked_eligible": true})
	assert_false(disclaimer.visible)
	assert_lte(button.position.x + button.size.x, viewport_size.x)
	assert_lte(button.position.y + button.size.y, viewport_size.y)
	main.runtime_tweak_service.mark_sandbox(&"hud_disclaimer_test")
	assert_true(disclaimer.visible)
	assert_eq(disclaimer.text, "tweaks active, leaderboard disabled")
	assert_eq(disclaimer.get_theme_color(&"font_color"), Color("ff695c"))
	for size: Vector2 in [Vector2(1280.0, 720.0), Vector2(720.0, 1280.0)]:
		hud._layout_tweak_controls_button(size)
		assert_eq(button.size, Vector2(138.0, 24.0))
		assert_eq(
			button.get_theme_font_size(&"font_size"),
			8 if size.y > size.x else 9
		)
		assert_eq(
			button.position.x + button.size.x,
			size.x - GameplayHud.TWEAK_BUTTON_RIGHT_MARGIN
		)
		assert_eq(
			button.position.y + button.size.y,
			size.y - GameplayHud.TWEAK_BUTTON_BOTTOM_MARGIN
		)
		assert_lte(
			disclaimer.position.y + disclaimer.size.y,
			button.position.y
		)
		assert_lte(disclaimer.position.x + disclaimer.size.x, size.x)
		assert_lte(disclaimer.position.y + disclaimer.size.y, size.y)
	assert_false(panel.is_open())
	button.pressed.emit()
	assert_true(panel.is_open())
	assert_true(get_tree().paused)
	assert_true(panel.close())
	assert_false(get_tree().paused)


func test_panel_fits_landscape_and_portrait_without_rebuilding_rows() -> void:
	main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	var panel: RuntimeTweakPanel = main.runtime_tweak_panel
	var row_ids: Array[int] = []
	for row: TweakControlRow in panel.rows:
		row_ids.append(row.get_instance_id())
	for size: Vector2 in [Vector2(1280.0, 720.0), Vector2(720.0, 1280.0)]:
		panel.apply_responsive_layout(size)
		assert_eq(panel.grow_horizontal, Control.GROW_DIRECTION_END)
		assert_eq(panel.grow_vertical, Control.GROW_DIRECTION_END)
		assert_eq(panel.position, Vector2.ZERO)
		assert_eq(panel.size, size)
		assert_gte(panel.frame.position.x, 0.0)
		assert_gte(panel.frame.position.y, 0.0)
		assert_lte(panel.frame.position.x + panel.frame.size.x, size.x)
		assert_lte(panel.frame.position.y + panel.frame.size.y, size.y)
	var final_ids: Array[int] = []
	for row: TweakControlRow in panel.rows:
		final_ids.append(row.get_instance_id())
	assert_eq(final_ids, row_ids)


func test_parameter_list_is_dense_scroll_first_and_color_editable() -> void:
	main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	var panel: RuntimeTweakPanel = main.runtime_tweak_panel
	var player_index: int = -1
	for index: int in range(panel.category_selector.item_count):
		if StringName(panel.category_selector.get_item_metadata(index)) == &"PLAYER":
			player_index = index
			break
	assert_gte(player_index, 0)
	panel.category_selector.select(player_index)
	panel._on_filter_changed(player_index)
	assert_eq(panel._filtered.size(), 32)
	assert_eq(panel.rows.size(), 32)
	assert_eq(panel.rows_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
	assert_true(panel.rows_scroll.follow_focus)
	var visible_rows: int = 0
	var color_row: TweakControlRow
	for row: TweakControlRow in panel.rows:
		assert_lte(row.custom_minimum_size.y, 42.0)
		if row.visible:
			visible_rows += 1
		if row.descriptor != null and row.descriptor.id == &"player.visual.tint":
			color_row = row
	assert_eq(visible_rows, 32)
	assert_not_null(color_row)
	assert_true(color_row.color_picker.visible)
	assert_false(color_row.slider.visible)
	assert_false(color_row.toggle.visible)
	color_row.color_picker.color_changed.emit(Color("62f5df"))
	assert_eq(main.runtime_tweak_service.requested_value(&"player.visual.tint"), "#62f5df")


func test_category_popup_receives_and_releases_the_cjk_font_override() -> void:
	L10n.set_locale("zh-CN")
	main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	var panel: RuntimeTweakPanel = main.runtime_tweak_panel
	panel.refresh_locale()
	var popup: PopupMenu = panel.category_selector.get_popup()
	var player_index: int = -1
	for index: int in range(panel.category_selector.item_count):
		if StringName(panel.category_selector.get_item_metadata(index)) == &"PLAYER":
			player_index = index
			break
	assert_gte(player_index, 0)
	assert_true(popup.has_theme_font_override(&"font"))
	assert_eq(panel.category_selector.get_item_text(player_index), "玩家")
	L10n.set_locale("en")
	panel.refresh_locale()
	assert_false(popup.has_theme_font_override(&"font"))
	assert_eq(panel.category_selector.get_item_text(player_index), "PLAYER")


func test_sandbox_denial_is_clean_and_success_marks_run_without_node_growth() -> void:
	main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	var panel: RuntimeTweakPanel = main.runtime_tweak_panel
	assert_true(panel.open())
	var service: RuntimeTweakService = main.runtime_tweak_service
	var node_count_before: int = _node_count(main.city_slice)
	var denied: Dictionary = panel.sandbox.spawn_enemy(&"not_allowlisted")
	assert_false(bool(denied.ok))
	assert_eq(service.provenance.status, RunTuningProvenance.BASELINE)
	var spawned: Dictionary = panel.sandbox.spawn_enemy(&"soldier")
	assert_true(bool(spawned.ok))
	assert_eq(service.provenance.status, RunTuningProvenance.SANDBOX)
	assert_eq(_node_count(main.city_slice), node_count_before)
	main.city_slice.robot.current_health = maxf(
		main.city_slice.robot.max_health - TuningSandboxRunner.REPAIR_GRANT,
		1.0
	)
	var repaired: Dictionary = panel.sandbox.repair_chassis()
	assert_true(bool(repaired.ok))
	assert_eq(repaired.amount, TuningSandboxRunner.REPAIR_GRANT)
	assert_true(panel.close())


func _node_count(root: Node) -> int:
	var total: int = 1
	for child: Node in root.get_children():
		total += _node_count(child)
	return total
