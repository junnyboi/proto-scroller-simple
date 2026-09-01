extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_both_bosses_have_unique_looping_lyria_tracks() -> void:
	var director: BossMusicDirector = _director()
	var paths: Dictionary[String, bool] = {}
	assert_eq(director.track_count(), 2)
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		var stream: AudioStream = director.stream_for_boss(definition.boss_id)
		assert_not_null(stream, definition.boss_id)
		assert_false(paths.has(stream.resource_path), stream.resource_path)
		paths[stream.resource_path] = true
		assert_true(stream is AudioStreamOggVorbis)
		assert_true((stream as AudioStreamOggVorbis).loop)


func test_web_export_keeps_every_preloaded_boss_theme() -> void:
	var export_presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_false(
		export_presets.contains("audio/music/bosses/*"),
		"Preloaded boss tracks cannot be excluded from the Web PCK",
	)
	for stream: AudioStream in BossMusicDirector.TRACKS.values():
		assert_true(FileAccess.file_exists(stream.resource_path), stream.resource_path)


func test_one_prewarmed_player_switches_tracks_without_allocating_children() -> void:
	var director: BossMusicDirector = _director()
	var initial_children: int = director.get_child_count()
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		assert_true(director.play_definition(definition))
		assert_eq(director.active_boss_id, definition.boss_id)
		assert_eq(director.player.stream, director.stream_for_boss(definition.boss_id))
		assert_eq(director.get_child_count(), initial_children)
	assert_eq(director.play_count, 2)


func test_retry_does_not_restart_an_already_playing_boss_theme() -> void:
	var director: BossMusicDirector = _director()
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(
		&"SETTLEMENT_ENGINE_S04"
	)
	assert_true(director.play_definition(definition))
	var play_count: int = director.play_count
	assert_true(director.play_definition(definition))
	assert_eq(director.play_count, play_count)


func test_background_bed_stops_for_boss_and_resumes_at_saved_position() -> void:
	var background: AudioStreamPlayer = AudioStreamPlayer.new()
	background.stream = BossMusicDirector.TRACKS[&"SETTLEMENT_ENGINE_S04"]
	add_child_autofree(background)
	background.play(0.25)
	var director: BossMusicDirector = BossMusicDirector.new()
	director.setup(background)
	add_child_autofree(director)
	assert_true(director.play_definition(BossCampaignCatalog.definition(&"SAMARITAN_15")))
	assert_false(background.playing)
	director.stop_music()
	assert_true(background.playing)
	assert_eq(director.active_boss_id, &"")
	assert_null(director.player.stream)


func test_audio_off_keeps_boss_state_and_visual_contract_available() -> void:
	var music_bus: int = AudioServer.get_bus_index(GameAudioBus.MUSIC)
	var was_muted: bool = AudioServer.is_bus_mute(music_bus)
	AudioServer.set_bus_mute(music_bus, true)
	var director: BossMusicDirector = _director()
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(&"SAMARITAN_15")
	assert_true(director.play_definition(definition))
	assert_eq(director.active_boss_id, &"SAMARITAN_15")
	assert_not_null(definition.display_name_key)
	assert_not_null(definition.evidence_flag_id)
	AudioServer.set_bus_mute(music_bus, was_muted)


func test_completed_theme_carries_until_next_boss_then_switches() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(
		&"SETTLEMENT_ENGINE_S04"
	)
	campaign.attempt_started.emit(definition)
	assert_eq(campaign.music_director.active_boss_id, definition.boss_id)
	assert_eq(
		campaign.music_director.player.stream,
		campaign.music_director.stream_for_boss(definition.boss_id)
	)
	campaign.boss_completed.emit(definition)
	assert_eq(campaign.music_director.active_boss_id, definition.boss_id)
	assert_true(campaign.music_director.player.playing)
	assert_eq(campaign.music_director.stop_count, 0)
	var next_definition: BossEncounterDefinition = BossCampaignCatalog.definition(
		&"SAMARITAN_15"
	)
	campaign.attempt_started.emit(next_definition)
	assert_eq(campaign.music_director.active_boss_id, next_definition.boss_id)
	assert_eq(
		campaign.music_director.player.stream,
		campaign.music_director.stream_for_boss(next_definition.boss_id)
	)
	assert_eq(campaign.music_director.play_count, 2)
	campaign.stop()
	assert_eq(campaign.music_director.active_boss_id, &"")
	assert_null(campaign.music_director.player.stream)


func _director() -> BossMusicDirector:
	var director: BossMusicDirector = BossMusicDirector.new()
	add_child_autofree(director)
	return director
