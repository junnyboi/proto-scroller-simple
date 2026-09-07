extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const FAST_SCALE: float = 0.18


func test_begin_expedition_fades_through_black_and_booms_once() -> void:
	var main: Main = await _spawn_main()
	var overlay: ColorRect = main.transition_overlay
	var launch_button: Button = main.title_screen.initialize_button
	assert_eq(main.transition_boom_player.stream, Main.TRANSITION_BOOM_SFX)
	assert_eq(main.transition_boom_player.bus, GameAudioBus.UI)
	assert_almost_eq(Main.TRANSITION_BOOM_SFX.get_length(), 1.35, 0.01)
	launch_button.pressed.emit()
	launch_button.pressed.emit()
	assert_true(main.title_transition_active)
	assert_eq(main.transition_boom_play_count, 0)
	await _wait_for_transition(main)
	assert_eq(main.transition_kind, &"start_game")
	assert_eq(main.transition_boom_play_count, 1)
	assert_almost_eq(main.transition_boom_last_alpha, 1.0, 0.001)
	assert_null(main.title_screen)
	assert_not_null(main.city_slice)
	_assert_overlay_released(overlay)


func test_player_defeat_fades_to_summary_and_booms_at_full_black() -> void:
	var main: Main = await _spawn_gameplay()
	var defeated_city: CitySlice = main.city_slice
	assert_true(defeated_city.robot.receive_damage(DamageEvent.new(91_001, null, 99_999.0)))
	assert_true(main.title_transition_active)
	assert_false(defeated_city.game_over_active)
	assert_eq(main.transition_boom_play_count, 0)
	await _wait_for_transition(main)
	assert_eq(main.transition_kind, &"defeat")
	assert_eq(main.transition_boom_play_count, 1)
	assert_almost_eq(main.transition_boom_last_alpha, 1.0, 0.001)
	assert_same(main.city_slice, defeated_city)
	assert_true(defeated_city.game_over_active)
	assert_true(defeated_city.gameplay_hud.game_over_overlay.visible)
	assert_true(defeated_city.gameplay_hud.title_button.visible)
	assert_eq(defeated_city.gameplay_hud.title_button.text, "TITLE SCREEN")
	defeated_city.gameplay_hud._apply_portrait_layout(Vector2(720.0, 1280.0))
	assert_gt(defeated_city.gameplay_hud.title_button.position.x, 340.0)
	assert_gt(
		defeated_city.gameplay_hud.title_button.position.x,
		defeated_city.gameplay_hud.retry_button.position.x
	)
	assert_lte(
		defeated_city.gameplay_hud.title_button.position.x
		+ defeated_city.gameplay_hud.title_button.size.x,
		638.0
	)
	_assert_overlay_released(main.transition_overlay)


func test_return_to_title_fades_and_booms_once_after_defeat() -> void:
	var main: Main = await _spawn_gameplay()
	var fatal_event: DamageEvent = DamageEvent.new(91_002, null, 99_999.0)
	assert_true(main.city_slice.robot.receive_damage(fatal_event))
	await _wait_for_transition(main)
	var title_button: Button = main.city_slice.gameplay_hud.title_button
	title_button.pressed.emit()
	title_button.pressed.emit()
	assert_true(main.title_transition_active)
	assert_eq(main.transition_boom_play_count, 1)
	await _wait_for_transition(main)
	assert_eq(main.transition_kind, &"return_title")
	assert_eq(main.transition_boom_play_count, 2)
	assert_almost_eq(main.transition_boom_last_alpha, 1.0, 0.001)
	assert_null(main.city_slice)
	assert_not_null(main.title_screen)
	assert_true(main.title_screen.initialize_button.visible)
	assert_eq(main.title_music_restart_count, 1)
	assert_eq(
		main.background_music_player.playing,
		main.background_music_output_available()
	)
	_assert_overlay_released(main.transition_overlay)


func _spawn_main() -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.title_transition_duration_scale = FAST_SCALE
	return main


func _spawn_gameplay() -> Main:
	var main: Main = await _spawn_main()
	main.start_game()
	await get_tree().process_frame
	assert_not_null(main.city_slice)
	return main


func _wait_for_transition(main: Main) -> void:
	for _frame: int in range(240):
		if not main.title_transition_active:
			return
		await get_tree().process_frame
	fail_test("transition did not complete")


func _assert_overlay_released(overlay: ColorRect) -> void:
	assert_false(overlay.visible)
	assert_almost_eq(overlay.modulate.a, 0.0, 0.001)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
