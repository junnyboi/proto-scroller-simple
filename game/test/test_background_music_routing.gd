extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")


func test_background_music_player_is_persistent_and_routes_to_music_bus() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	var player: AudioStreamPlayer = main.background_music_player
	assert_not_null(player)
	assert_not_null(player.stream)
	assert_true(player.stream is AudioStreamOggVorbis)
	var music_stream: AudioStreamOggVorbis = player.stream as AudioStreamOggVorbis
	assert_true(music_stream.loop)
	assert_almost_eq(music_stream.get_length(), 28.0, 0.05)
	assert_false(player.autoplay)
	assert_not_null(main.title_screen)
	assert_eq(player.playing, main.background_music_output_available())
	assert_eq(player.bus, &"Music")
	assert_eq(player.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_gte(AudioServer.get_bus_index(player.bus), 0)
	main.start_game()
	await get_tree().process_frame
	assert_same(main.background_music_player, player)
	assert_eq(player.get_parent(), main)


func test_title_queues_music_immediately_for_native_and_web_environments() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	assert_eq(
		main.background_music_player.playing,
		main.background_music_output_available()
	)
	main.background_music_player.stop()
	main._start_background_music_for_environment(true)
	assert_true(main.background_music_player.playing)
	main.background_music_player.stop()
	main._start_background_music_for_environment(false)
	assert_eq(
		main.background_music_player.playing,
		main.background_music_output_available()
	)


func test_return_to_title_restart_retriggers_bgm_from_sample_zero() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.background_music_player.play(12.0)
	assert_gt(main.background_music_player.get_playback_position(), 10.0)
	main._restart_title_music_for_environment(true)
	assert_true(main.background_music_player.playing)
	assert_lt(main.background_music_player.get_playback_position(), 0.25)
	assert_eq(main.title_music_restart_count, 1)
	assert_true(main._title_music_committed)


func test_title_sync_constants_are_orientation_and_latency_bounded() -> void:
	assert_almost_eq(Main.TITLE_IMPACT_HOLD_SECONDS, 0.35, 0.001)
	assert_almost_eq(Main.TITLE_PREWARM_POSITION_SECONDS, 0.5, 0.001)
	assert_gt(Main.TITLE_SYNC_FALLBACK_SECONDS, 0.0)
	assert_lte(Main.TITLE_SYNC_FALLBACK_SECONDS, 10.0)


func test_title_sync_source_keeps_cached_callbacks_and_browser_commit_only() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/main/main.gd"
	)
	assert_true(source.contains("_title_music_commit_callback: JavaScriptObject"))
	assert_true(source.contains("_title_music_calibration_callback: JavaScriptObject"))
	assert_true(source.contains("JavaScriptBridge.create_callback"))
	assert_true(source.contains("protoScrollerScheduleTitleBeatCommit"))
	assert_true(source.contains("protoScrollerCancelTitleBeatCommit"))
	assert_true(source.contains("protoScrollerResumeTitleAudio"))
	assert_true(source.contains("background_music_player.play(0.0)"))
	assert_true(source.contains("TITLE_PREWARM_POSITION_SECONDS"))
	assert_true(source.contains("AudioServer.set_bus_mute"))
	assert_true(source.contains("phase == \"scheduled\""))
	assert_true(source.contains("seconds_until_rendered"))
	assert_true(source.contains("audio_activation_requested.connect"))
	assert_true(source.contains("_activate_title_music_from_interaction"))
	assert_false(source.contains("func _process"))
	var shell_patcher: String = FileAccess.get_file_as_string(
		"res://../scripts/patch-title-video-shell.mjs"
	)
	assert_true(shell_patcher.contains("window.protoScrollerResumeTitleAudio"))
	assert_true(shell_patcher.contains("title-interaction-resumed"))


func test_background_music_releases_stream_on_main_exit() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	var player: AudioStreamPlayer = main.background_music_player
	assert_eq(player.playing, main.background_music_output_available())
	assert_not_null(player.stream)
	main._exit_tree()
	assert_false(player.playing)
	assert_null(player.stream)


func test_dummy_audio_driver_does_not_start_an_ogg_decoder() -> void:
	if AudioServer.get_driver_name() != Main.DUMMY_AUDIO_DRIVER_NAME:
		pending("Requires Godot's Dummy audio driver")
		return
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	assert_false(main.background_music_output_available())
	assert_false(main.background_music_player.playing)
	assert_not_null(main.background_music_player.stream)


func test_web_feature_keeps_bgm_available_with_dummy_driver_name() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	assert_true(
		main._background_music_output_available_for_environment(
			Main.DUMMY_AUDIO_DRIVER_NAME,
			true
		)
	)
	assert_false(
		main._background_music_output_available_for_environment(
			Main.DUMMY_AUDIO_DRIVER_NAME,
			false
		)
	)
	main.free()


func test_music_duck_controller_changes_the_players_music_bus() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	var player: AudioStreamPlayer = main.background_music_player
	var duck: MusicDuckController = main.city_slice.music_duck_controller
	duck.attack_seconds = 0.0
	duck.release_seconds = 0.0
	duck.set_ducked(false, true)
	var music_bus_index: int = AudioServer.get_bus_index(player.bus)
	var baseline_db: float = AudioServer.get_bus_volume_db(music_bus_index)
	duck.set_ducked(true, true)
	assert_almost_eq(
		AudioServer.get_bus_volume_db(music_bus_index),
		baseline_db + duck.duck_db,
		0.01
	)
	duck.set_ducked(false, true)
	assert_almost_eq(AudioServer.get_bus_volume_db(music_bus_index), baseline_db, 0.01)
