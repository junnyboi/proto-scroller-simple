extends GutTest

const TEST_PREFERENCE_PATH: String = "user://test-audio-volume-settings.cfg"
const CONTROLLED_CHANNELS: Array[int] = [
	AudioVolumeSettings.Channel.MASTER,
	AudioVolumeSettings.Channel.MUSIC,
	AudioVolumeSettings.Channel.SFX,
	AudioVolumeSettings.Channel.VOICE,
]


func before_each() -> void:
	AudioVolumeSettings.clear_preference(TEST_PREFERENCE_PATH)
	_reset_defaults()


func after_each() -> void:
	AudioVolumeSettings.clear_preference(TEST_PREFERENCE_PATH)
	_reset_defaults()


func test_production_bus_hierarchy_exists_with_intentional_parent_sends() -> void:
	AudioVolumeSettings.ensure_bus_hierarchy()
	var expected_sends: Dictionary = {
		GameAudioBus.MUSIC: GameAudioBus.MASTER,
		GameAudioBus.SFX: GameAudioBus.MASTER,
		GameAudioBus.MECHANICS: GameAudioBus.SFX,
		GameAudioBus.THREAT: GameAudioBus.SFX,
		GameAudioBus.VOICE: GameAudioBus.MASTER,
		GameAudioBus.UI: GameAudioBus.MASTER,
		GameAudioBus.AMBIENCE: GameAudioBus.SFX,
	}
	for bus: StringName in expected_sends:
		var index: int = AudioServer.get_bus_index(bus)
		assert_gte(index, 0, bus)
		assert_eq(AudioServer.get_bus_send(index), expected_sends[bus], bus)


func test_unsaved_default_mix_sets_music_to_eighty_percent_below_sfx() -> void:
	assert_almost_eq(
		AudioVolumeSettings.default_percent(AudioVolumeSettings.Channel.MUSIC),
		80.0,
		0.001
	)
	assert_almost_eq(
		AudioVolumeSettings.default_percent(AudioVolumeSettings.Channel.SFX),
		100.0,
		0.001
	)
	assert_almost_eq(
		AudioVolumeSettings.load_percent(
			AudioVolumeSettings.Channel.MUSIC,
			TEST_PREFERENCE_PATH
		),
		80.0,
		0.001
	)
	var values: Dictionary = AudioVolumeSettings.apply_saved(TEST_PREFERENCE_PATH)
	assert_almost_eq(
		float(values[AudioVolumeSettings.Channel.MUSIC]),
		80.0,
		0.001
	)
	var music_bus_index: int = AudioServer.get_bus_index(GameAudioBus.MUSIC)
	assert_almost_eq(
		AudioServer.get_bus_volume_db(music_bus_index),
		AudioVolumeSettings.percent_to_db(80.0),
		0.001
	)


func test_volume_conversion_and_all_channel_preferences_are_bounded() -> void:
	assert_almost_eq(AudioVolumeSettings.percent_to_db(100.0), 0.0, 0.001)
	assert_almost_eq(
		AudioVolumeSettings.percent_to_db(0.0),
		AudioVolumeSettings.SILENCE_FLOOR_DB,
		0.001
	)
	var requested: Dictionary = {
		AudioVolumeSettings.Channel.MASTER: 80.0,
		AudioVolumeSettings.Channel.MUSIC: 35.0,
		AudioVolumeSettings.Channel.SFX: 62.0,
		AudioVolumeSettings.Channel.VOICE: 48.0,
	}
	for channel: int in CONTROLLED_CHANNELS:
		var percent: float = float(requested[channel])
		assert_eq(
			AudioVolumeSettings.set_and_save(channel, percent, TEST_PREFERENCE_PATH),
			OK
		)
		assert_almost_eq(
			AudioVolumeSettings.load_percent(channel, TEST_PREFERENCE_PATH),
			percent,
			0.001
		)
		var bus_index: int = AudioServer.get_bus_index(AudioVolumeSettings.bus_name(channel))
		assert_almost_eq(
			AudioServer.get_bus_volume_db(bus_index),
			AudioVolumeSettings.percent_to_db(percent),
			0.001
		)
	assert_eq(
		AudioVolumeSettings.set_and_save(
			AudioVolumeSettings.Channel.MASTER,
			135.0,
			TEST_PREFERENCE_PATH
		),
		OK
	)
	assert_almost_eq(
		AudioVolumeSettings.load_percent(
			AudioVolumeSettings.Channel.MASTER,
			TEST_PREFERENCE_PATH
		),
		100.0,
		0.001
	)
	assert_eq(
		AudioVolumeSettings.set_and_save(
			AudioVolumeSettings.Channel.VOICE,
			-20.0,
			TEST_PREFERENCE_PATH
		),
		OK
	)
	assert_almost_eq(
		AudioVolumeSettings.load_percent(
			AudioVolumeSettings.Channel.VOICE,
			TEST_PREFERENCE_PATH
		),
		0.0,
		0.001
	)


func test_each_channel_mute_is_persistent_and_preserves_its_volume() -> void:
	for channel: int in CONTROLLED_CHANNELS:
		var percent: float = 25.0 + float(channel) * 10.0
		assert_eq(
			AudioVolumeSettings.set_and_save(channel, percent, TEST_PREFERENCE_PATH),
			OK
		)
		assert_eq(
			AudioVolumeSettings.set_muted_and_save(channel, true, TEST_PREFERENCE_PATH),
			OK
		)
		var bus_index: int = AudioServer.get_bus_index(AudioVolumeSettings.bus_name(channel))
		assert_true(AudioServer.is_bus_mute(bus_index), AudioVolumeSettings.bus_name(channel))
		assert_true(
			AudioVolumeSettings.load_muted(channel, TEST_PREFERENCE_PATH),
			AudioVolumeSettings.bus_name(channel)
		)
		assert_almost_eq(
			AudioVolumeSettings.load_percent(channel, TEST_PREFERENCE_PATH),
			percent,
			0.001
		)
		assert_eq(
			AudioVolumeSettings.set_muted_and_save(channel, false, TEST_PREFERENCE_PATH),
			OK
		)
		assert_false(AudioServer.is_bus_mute(bus_index), AudioVolumeSettings.bus_name(channel))
	AudioVolumeSettings.apply_saved(TEST_PREFERENCE_PATH)
	for channel: int in CONTROLLED_CHANNELS:
		assert_false(
			AudioVolumeSettings.load_muted(channel, TEST_PREFERENCE_PATH),
			AudioVolumeSettings.bus_name(channel)
		)


func test_duck_controller_uses_saved_music_volume_as_restoration_baseline() -> void:
	assert_eq(
		AudioVolumeSettings.set_and_save(
			AudioVolumeSettings.Channel.MUSIC,
			35.0,
			TEST_PREFERENCE_PATH
		),
		OK
	)
	AudioVolumeSettings.apply_saved(TEST_PREFERENCE_PATH)
	var duck: MusicDuckController = MusicDuckController.new()
	add_child_autofree(duck)
	await get_tree().process_frame
	var expected_base_db: float = AudioVolumeSettings.percent_to_db(35.0)
	assert_almost_eq(duck.base_volume_db(), expected_base_db, 0.01)
	duck.set_ducked(true, true)
	assert_almost_eq(duck.current_volume_db(), expected_base_db + duck.duck_db, 0.01)
	duck.set_ducked(false, true)
	assert_almost_eq(duck.current_volume_db(), expected_base_db, 0.01)


func _reset_defaults() -> void:
	for channel: int in CONTROLLED_CHANNELS:
		AudioVolumeSettings.apply_percent(
			channel,
			AudioVolumeSettings.default_percent(channel)
		)
		AudioVolumeSettings.apply_muted(channel, false)
