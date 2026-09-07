extends GutTest

const PROFILE_PATH: String = "user://contract_profile.json"
const TUTORIAL_PATH: String = "user://contract_tutorial.cfg"
const TUNING_PATH: String = "user://contract_tuning.json"
const PRESENTATION_PATH: String = "user://contract_presentation.cfg"


func before_each() -> void:
	_cleanup()
	PresentationSettings.preference_path = PRESENTATION_PATH
	PresentationSettings._loaded = false
	PresentationSettings._reduced_motion = false
	L10n.set_locale("en")


func after_each() -> void:
	get_tree().paused = false
	RuntimeTweakAccess.unbind_service()
	AudioVolumeSettings.apply_saved()
	PresentationSettings.preference_path = PresentationSettings.PATH
	PresentationSettings._loaded = false
	PresentationSettings._reduced_motion = false
	L10n.set_locale("en")
	_cleanup()


func test_stage_registry_validates_single_act_and_rejects_invalid_scene_and_enemy() -> void:
	var registry: ScrollerStageRegistry = ScrollerStageRegistry.new()
	assert_eq(registry.stages.size(), 1)
	assert_true(registry.validation_errors().is_empty())
	assert_null(registry.at(-1))
	assert_false(registry.has_next(0))
	var stage: ScrollerStageDefinition = registry.at(0).duplicate(true)
	stage.stage_id = &"SYNTHETIC_TEST"
	registry.stages.append(stage)
	assert_true(registry.has_next(0))
	assert_true(registry.validation_errors().is_empty())
	stage.stage_id = registry.at(0).stage_id
	assert_false(registry.validation_errors().is_empty())
	stage.stage_id = &"SYNTHETIC_TEST"
	stage.scene = load("res://scenes/title_screen.tscn")
	assert_false(registry.validation_errors().is_empty())
	stage.scene = registry.at(0).scene
	var spawn: EnemySpawnEntry = EnemySpawnEntry.new()
	spawn.kind = &"MISSING_ENEMY"
	var beat: DistrictBeat = DistrictBeat.new()
	beat.maximum_threat = 1
	beat.spawns.append(spawn)
	var act: DistrictAct = DistrictAct.new()
	act.beats.append(beat)
	stage.district = DistrictDefinition.new()
	stage.district.acts.append(act)
	assert_false(registry.validation_errors().is_empty())


func test_registered_second_stage_routes_without_another_authored_act() -> void:
	var main: Main = await _main()
	var second: ScrollerStageDefinition = main.stage_registry.at(0).duplicate()
	second.stage_id = &"SYNTHETIC_TEST"
	main.stage_registry.stages.append(second)
	main.start_game()
	await get_tree().process_frame
	var first_id: String = main.city_slice.run_id
	main.city_slice.run_lifecycle._finish_run(true)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(main.active_stage_index, 1)
	assert_eq(main.city_slice.stage_id, &"SYNTHETIC_TEST")
	assert_ne(main.city_slice.run_id, first_id)
	assert_false(main.city_slice.game_over_active)
	main._return_to_title()
	main.stage_registry.stages.clear()
	main.start_game()
	assert_null(main.city_slice)
	assert_not_null(main.title_screen)
	assert_false(main.startup_errors.is_empty())


func test_title_pause_settings_and_debrief_tuning_restore_nested_state() -> void:
	var main: Main = await _main()
	assert_true(main.runtime_tweak_panel.open())
	assert_true(get_tree().paused)
	await get_tree().process_frame
	assert_lte(main.runtime_tweak_panel.frame.get_rect().end.y, get_viewport().get_visible_rect().size.y - 60)
	assert_true(main.runtime_tweak_panel.close())
	assert_false(get_tree().paused)
	main.start_game()
	await get_tree().process_frame
	var city: CitySlice = main.city_slice
	city.urban_siege.pause_coordinator.release_all()
	assert_true(main.pause_menu.open())
	var tutorial: FirstRunCombatTutorial = city.gameplay_hud.first_run_tutorial
	var tutorial_seconds: float = tutorial._step_seconds
	tutorial._process(40.0)
	assert_eq(tutorial._step_seconds, tutorial_seconds, "Onboarding timeout freezes with its modal parent")
	assert_false(city.robot.can_process())
	main.open_gameplay_settings()
	assert_true(main.gameplay_settings_open())
	assert_eq(city.urban_siege.pause_coordinator.lease_reasons().size(), 2)
	main.gameplay_settings_screen.close_settings(false)
	assert_true(main.pause_menu.is_open())
	assert_true(get_tree().paused)
	assert_true(main.runtime_tweak_panel.open())
	assert_true(main.runtime_tweak_panel.close())
	assert_true(get_tree().paused)
	assert_false(city.robot.can_process())
	assert_true(main.pause_menu.close())
	assert_false(get_tree().paused)
	assert_true(city.robot.can_process())
	assert_false(city.urban_siege.pause_coordinator.is_paused())
	city.run_lifecycle._finish_run(false)
	assert_true(main.runtime_tweak_panel.open())
	assert_true(main.runtime_tweak_panel.close())
	assert_false(get_tree().paused)


func test_pause_navigation_requires_confirmation_and_retry_gets_new_identity() -> void:
	var main: Main = await _main()
	main.start_game()
	await get_tree().process_frame
	var previous_id: String = main.city_slice.run_id
	main.city_slice.urban_siege.pause_coordinator.release_all()
	assert_true(main.pause_menu.open())
	main.pause_menu._activate(&"restart")
	assert_true(main.pause_menu.confirmation.visible)
	assert_eq(main.city_slice.run_id, previous_id)
	main.pause_menu._confirm_action()
	await get_tree().process_frame
	assert_ne(main.city_slice.run_id, previous_id)
	assert_false(get_tree().paused)


func test_tutorial_replay_input_switch_locale_and_timeout_hint() -> void:
	var tutorial: FirstRunCombatTutorial = FirstRunCombatTutorial.new()
	tutorial.preference_path = TUTORIAL_PATH
	add_child_autofree(tutorial)
	tutorial.skip_button.pressed.emit()
	assert_true(tutorial.completed)
	tutorial.replay()
	assert_true(tutorial.tutorial_active)
	assert_false(FileAccess.file_exists(TUTORIAL_PATH))
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_A
	tutorial._input(key)
	assert_eq(tutorial.input_method, &"keyboard")
	assert_false(tutorial.body_label.text.contains("stick"))
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	tutorial._input(pad)
	assert_eq(tutorial.input_method, &"gamepad")
	assert_true(tutorial.body_label.text.contains("D-PAD"))
	L10n.set_locale("zh-CN")
	tutorial._process(36.0)
	assert_true(tutorial.body_label.text.contains("暂停"))
	assert_eq(tutorial.panel.size.y, 236.0)
	assert_true(tutorial.tutorial_active)


func test_top_scores_survive_history_rollover_and_run_submission_is_idempotent() -> void:
	var store: PlayerCombatProfileStore = _store()
	store.set_callsign("ECHO-7")
	var best: RunSummarySnapshot = _contract_summary(9000, "best")
	var enriched: RunSummarySnapshot = store.enrich_and_submit(best)
	store.enrich_and_submit(enriched)
	assert_eq(store.snapshot().total_runs, 1)
	store.set_callsign("NOVA-7")
	for index: int in range(35):
		store.enrich_and_submit(_contract_summary(index, "run-%d" % index))
	assert_eq(store.history_snapshot().size(), 30)
	assert_eq(store.local_leaderboard().size(), 10)
	assert_eq(store.local_leaderboard()[0].score, 9000)
	assert_eq(store.local_leaderboard()[0].callsign, "ECHO-7")
	assert_eq(enriched.run_id, "best")
	assert_eq(enriched.stage_id, &"BUSINESS_ACT_1")
	assert_eq(enriched.duration_seconds, 42.5)
	var reloaded: PlayerCombatProfileStore = _store()
	assert_eq(reloaded.local_leaderboard()[0].run_id, "best")
	assert_eq(reloaded.history_snapshot()[-1].configuration_hash, "baseline-test")


func test_malformed_profile_and_leaderboard_values_have_safe_fallbacks() -> void:
	var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 2, "callsign": {}, "best_score": [], "lifetime_weapon_kills": {"BAD": {}}, "run_history": [{"run_id": "bad", "score": {}, "duration_seconds": "bad", "weapon_kills": {"BAD": []}}], "top_runs": "bad"}))
	file.close()
	var store: PlayerCombatProfileStore = _store()
	assert_eq(store.snapshot().best_score, 0)
	assert_eq(store.history_snapshot()[0].score, 0)
	var bridge: LeaderboardBridge = LeaderboardBridge.new()
	add_child_autofree(bridge)
	bridge.setup(store, null)
	var entries: Array[Dictionary] = bridge._sanitize_entries([null, {}, {"rank": {}, "callsign": [], "bestScore": "invalid"}])
	assert_eq(entries.size(), 2)
	assert_eq(entries[1].best_score, 0)
	bridge._pending["test"] = {"type": &"list"}
	bridge._handle_response({"channel": LeaderboardBridge.CHANNEL, "version": 1, "requestId": "test", "ok": true, "data": []})
	assert_eq(bridge.state, &"local_fallback")
	bridge._handle_response({"channel": {}, "version": {}, "requestId": []})
	assert_eq(bridge.state, &"local_fallback")


func test_debug_tutorial_and_tweaked_runs_never_make_global_candidates() -> void:
	var store: PlayerCombatProfileStore = _store()
	var bridge: LeaderboardBridge = LeaderboardBridge.new()
	add_child_autofree(bridge)
	bridge.setup(store, null)
	for flag: String in ["debug_run", "tutorial_run"]:
		var summary: RunSummarySnapshot = RunSummarySnapshot.new(100, 1, 1, 1, 0, {}, {flag: true})
		assert_eq(store.leaderboard_candidate(summary), {})
		bridge.submit_summary(summary)
		assert_true(bridge.last_submission_blocked)
	assert_false(store.leaderboard_candidate(_contract_summary(100, "eligible")).is_empty())


func test_score_caps_and_invalid_checkpoint_values() -> void:
	var score: RunScore = RunScore.new()
	add_child_autofree(score)
	score.restore_attempt_state({"safe_score": RunScore.MAX_SCORE + 20, "pending_value": 9000})
	assert_eq(score.score, RunScore.MAX_SCORE)
	assert_eq(score.pending_bank.value, 0)
	score.restore_attempt_state({"safe_score": {}, "pending_value": "bad", "pending_remaining": INF})
	assert_eq(score.score, 0)
	assert_eq(score.pending_bank.bank_remaining, 0.0)
	assert_eq(_contract_summary(-100, "negative").score, 0)


func test_audio_filter_and_reduced_motion_are_live_and_cosmetic() -> void:
	var service: RuntimeTweakService = RuntimeTweakService.new()
	add_child_autofree(service)
	assert_true(service.setup(RuntimeTweakCatalog.DEFAULT_PATH, TUNING_PATH).is_empty())
	service.freeze_run(7)
	var effects: ScreenEffects = ScreenEffects.new()
	add_child_autofree(effects)
	service.set_value(&"audio.ui.volume", 25.0)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"UI")), linear_to_db(0.25), 0.001)
	service.set_value(&"audio.ui.muted", true)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"UI")))
	service.set_value(&"interface.filter_enabled", false)
	effects.refresh()
	assert_false(effects.overlay.visible)
	service.set_value(&"interface.filter_enabled", true)
	service.set_value(&"interface.filter_intensity", 0.75)
	effects.refresh()
	assert_eq(effects.shader_material.get_shader_parameter("intensity"), 0.75)
	assert_true(service.provenance.ranked_eligible())
	PresentationSettings.set_reduced_motion(true)
	PresentationSettings._loaded = false
	assert_true(PresentationSettings.reduced_motion())
	var camera: CameraRig = CameraRig.new()
	add_child_autofree(camera)
	camera.add_impact_impulse(Vector2(10, 10))
	assert_eq(camera.impact_velocity, Vector2.ZERO)
	service.reset_all()
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"UI")))
	for category: StringName in service.catalog.categories():
		assert_lte(service.catalog.descriptors_for_category(category).size(), RuntimeTweakPanel.ROW_POOL_SIZE)


func test_default_leaderboard_has_no_global_route_or_request() -> void:
	var main: Main = await _main()
	main.title_screen.open_leaderboard()
	var board: TitleLeaderboardOverlay = main.title_screen.leaderboard_overlay
	assert_false(board.global_tab_button.visible)
	board.set_tab(TitleLeaderboardOverlay.Tab.GLOBAL)
	assert_eq(board.current_tab, TitleLeaderboardOverlay.Tab.LOCAL)
	assert_false(LeaderboardBridge.GLOBAL_ENABLED)
	assert_false(main.title_screen.leaderboard_bridge._send_request(&"list", {}))
	assert_eq(main.title_screen.leaderboard_bridge.debug_snapshot().request_counter, 0)


func test_menu_audio_binds_new_controls_once_and_caps_voices() -> void:
	var main: Main = await _main()
	var button: Button = Button.new()
	main.add_child(button)
	main.menu_audio._bind_control(button)
	main.menu_audio.last_cue_msec = -1000
	var before: int = main.menu_audio.play_count
	button.pressed.emit()
	assert_eq(main.menu_audio.play_count, before + 1)
	assert_eq(main.menu_audio.voices.size(), 4)
	for voice: AudioStreamPlayer in main.menu_audio.voices:
		assert_eq(voice.bus, &"UI")


func _main() -> Main:
	var main: Main = load("res://scenes/main/main.tscn").instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	return main


func _store() -> PlayerCombatProfileStore:
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(PROFILE_PATH)
	return store


func _contract_summary(score: int, id: String) -> RunSummarySnapshot:
	return RunSummarySnapshot.new(score, 2, 4, 1, 0, {}, {"run_id": id, "stage_id": &"BUSINESS_ACT_1", "duration_seconds": 42.5, "finished_unix_time": 1700000000, "completed": true}).with_tuning_provenance({"ranked_eligible": true, "configuration_hash": "baseline-test"})


func _cleanup() -> void:
	for path: String in [PROFILE_PATH, TUTORIAL_PATH, TUNING_PATH, PRESENTATION_PATH]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
