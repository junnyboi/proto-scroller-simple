extends GutTest

const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const LANGUAGE_PREFERENCE_PATH: String = "user://test-title-language.cfg"
const AUDIO_PREFERENCE_PATH: String = "user://test-title-audio.cfg"
const INPUT_PREFERENCE_PATH: String = "user://test-title-input.cfg"
const COMBAT_PROFILE_PATH: String = "user://test-title-combat-profile.json"
const MINIMUM_TEXT_HEIGHT: float = 32.0

var screen: TitleScreen
var combat_profile: PlayerCombatProfileStore


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	if FileAccess.file_exists(TEST_COUNT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_COUNT_PATH))


func before_each() -> void:
	L10n.clear_locale_preference(LANGUAGE_PREFERENCE_PATH)
	AudioVolumeSettings.clear_preference(AUDIO_PREFERENCE_PATH)
	InputBindingSettings.reset_to_defaults(INPUT_PREFERENCE_PATH, false)
	_clear_input_preference()
	_clear_combat_profile()
	_reset_audio_settings()
	L10n.set_locale("en")
	combat_profile = PlayerCombatProfileStore.new()
	add_child_autofree(combat_profile)
	combat_profile.setup(COMBAT_PROFILE_PATH)
	combat_profile.set_callsign("TITLE ACE")
	combat_profile.enrich_and_submit(_leaderboard_summary())
	screen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	screen.configure_leaderboard(combat_profile)
	screen.locale_preference_path = LANGUAGE_PREFERENCE_PATH
	screen.audio_preference_path = AUDIO_PREFERENCE_PATH
	screen.input_preference_path = INPUT_PREFERENCE_PATH
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	L10n.set_locale("en")
	L10n.clear_locale_preference(LANGUAGE_PREFERENCE_PATH)
	AudioVolumeSettings.clear_preference(AUDIO_PREFERENCE_PATH)
	InputBindingSettings.reset_to_defaults(INPUT_PREFERENCE_PATH, false)
	_clear_input_preference()
	_clear_combat_profile()
	_reset_audio_settings()


func test_launch_scene_contract() -> void:
	var title_label: Label = screen.get_node("%TitleLabel") as Label
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Game template - scroller")
	assert_eq(
		ProjectSettings.get_setting("application/run/main_scene"),
		"res://scenes/main/main.tscn"
	)
	assert_eq(title_label.text, L10n.t("title.command_heading"))
	assert_true(initialize_button.text.contains(L10n.t("title.begin")))
	assert_eq(initialize_button.focus_mode, Control.FOCUS_ALL)
	var launch_actions: int = 0
	for button_node: Node in screen.find_children("*", "Button", true, false):
		var button: Button = button_node as Button
		if button.text.contains(L10n.t("title.begin")):
			launch_actions += 1
	assert_eq(launch_actions, 1, "The Command Deck must expose one launch action only.")
	var english_button: Button = screen.get_node("%EnglishButton") as Button
	var chinese_button: Button = screen.get_node("%ChineseButton") as Button
	assert_null(screen.get_node_or_null("%AutomaticButton"))
	assert_eq(title_label.text, "PROTOS")
	var instruction_label: Label = screen.get_node("%InstructionLabel") as Label
	assert_eq(
		instruction_label.text,
		"They killed everyone you loved, and used nanotechnology to replace body fluids "
		+ "and tissue with cybernetics, calling it the evolution of the human race... "
		+ "It's time to put an end to their reign of terror!"
	)
	assert_eq(instruction_label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(instruction_label.get_visible_line_count(), instruction_label.get_line_count())
	assert_null(screen.get_node_or_null("HintLabel"))
	assert_eq(english_button.text, "EN")
	assert_eq(chinese_button.text, "CN")
	assert_true(english_button.button_pressed)
	assert_false(chinese_button.button_pressed)
	assert_eq((screen.get_node("%SettingsButton") as Button).text, L10n.t("title.settings"))
	assert_eq(
		(screen.get_node("%LeaderboardButton") as Button).text,
		L10n.t("title.leaderboard")
	)
	assert_true(screen.select_language("zh-CN"))
	assert_eq(L10n.current_locale(), "zh-CN")
	assert_eq(L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH), "zh-CN")
	assert_eq(title_label.text, "PROTOS")
	assert_true(chinese_button.button_pressed)
	assert_false(english_button.button_pressed)
	assert_eq(
		instruction_label.text,
		"他们杀尽了你爱的人，并用纳米技术，以义体替代人体的体液与组织，"
		+ "还将其称作人类进化……是时候终结他们的恐怖统治了！"
	)
	assert_eq(instruction_label.autowrap_mode, TextServer.AUTOWRAP_ARBITRARY)
	assert_eq(instruction_label.get_visible_line_count(), instruction_label.get_line_count())
	assert_eq((screen.get_node("%SettingsButton") as Button).text, "设置")
	assert_eq(
		(screen.get_node("%SettingsHeading") as Label).text,
		L10n.t("title.settings_heading")
	)
	assert_null(screen.get_node_or_null("%BriefingArt"))
	assert_gt(
		(screen.get_node("%BriefingBackground") as ColorRect).color.a,
		0.95
	)
	assert_true(screen.select_language("en"))
	assert_eq(L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH), "en")
	assert_true(english_button.button_pressed)
	assert_false(chinese_button.button_pressed)
	assert_eq(instruction_label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	_record_test_execution()


func test_spacebar_does_not_activate_the_focused_launch_button() -> void:
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	initialize_button.grab_focus()
	var signal_counts: Dictionary = {"start": 0}
	screen.start_requested.connect(func() -> void: signal_counts.start += 1)
	var space_press: InputEventKey = InputEventKey.new()
	space_press.physical_keycode = KEY_SPACE
	space_press.pressed = true
	assert_true(InputMap.event_is_action(space_press, &"stomp"))
	assert_false(InputMap.event_is_action(space_press, &"ui_accept"))
	Input.parse_input_event(space_press)
	await get_tree().process_frame
	assert_eq(signal_counts.start, 0)
	assert_false(screen.initialized)
	assert_true(initialize_button.has_focus())
	var space_release: InputEventKey = space_press.duplicate() as InputEventKey
	space_release.pressed = false
	Input.parse_input_event(space_release)
	var enter_press: InputEventKey = InputEventKey.new()
	enter_press.keycode = KEY_ENTER
	enter_press.pressed = true
	assert_true(InputMap.event_is_action(enter_press, &"ui_accept"))
	Input.parse_input_event(enter_press)
	var enter_release: InputEventKey = enter_press.duplicate() as InputEventKey
	enter_release.pressed = false
	Input.parse_input_event(enter_release)
	await get_tree().process_frame
	assert_eq(signal_counts.start, 1)
	assert_true(screen.initialized)
	_record_test_execution()


func test_tab_opens_field_briefing_without_rotating_button_focus() -> void:
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	initialize_button.grab_focus()
	assert_true(initialize_button.has_focus())
	var tab_press: InputEventKey = InputEventKey.new()
	tab_press.keycode = KEY_TAB
	tab_press.physical_keycode = KEY_TAB
	tab_press.pressed = true
	Input.parse_input_event(tab_press)
	await get_tree().process_frame
	assert_true(screen.briefing_open)
	assert_true((screen.get_node("%BriefingLayer") as Control).visible)
	assert_true(initialize_button.has_focus())
	assert_false((screen.get_node("%EnglishButton") as Button).has_focus())
	assert_false((screen.get_node("%ChineseButton") as Button).has_focus())
	var tab_release: InputEventKey = tab_press.duplicate() as InputEventKey
	tab_release.pressed = false
	Input.parse_input_event(tab_release)
	_record_test_execution()


func test_gamepad_melee_does_not_activate_the_focused_launch_button() -> void:
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	initialize_button.grab_focus()
	var signal_counts: Dictionary = {"start": 0}
	screen.start_requested.connect(func() -> void: signal_counts.start += 1)
	var melee_press: InputEventJoypadButton = InputEventJoypadButton.new()
	melee_press.device = 0
	melee_press.button_index = JOY_BUTTON_X
	melee_press.pressed = true
	assert_true(InputMap.event_is_action(melee_press, &"stomp"))
	assert_false(InputMap.event_is_action(melee_press, &"ui_accept"))
	Input.parse_input_event(melee_press)
	var melee_release: InputEventJoypadButton = melee_press.duplicate() as InputEventJoypadButton
	melee_release.pressed = false
	Input.parse_input_event(melee_release)
	await get_tree().process_frame
	assert_eq(signal_counts.start, 0)
	assert_false(screen.initialized)
	assert_true(initialize_button.has_focus())
	var confirm_press: InputEventJoypadButton = InputEventJoypadButton.new()
	confirm_press.device = 0
	confirm_press.button_index = JOY_BUTTON_A
	confirm_press.pressed = true
	assert_true(InputMap.event_is_action(confirm_press, &"ui_accept"))
	assert_false(InputMap.event_is_action(confirm_press, &"stomp"))
	Input.parse_input_event(confirm_press)
	var confirm_release: InputEventJoypadButton = (
		confirm_press.duplicate() as InputEventJoypadButton
	)
	confirm_release.pressed = false
	Input.parse_input_event(confirm_release)
	await get_tree().process_frame
	assert_eq(signal_counts.start, 1)
	assert_true(screen.initialized)
	_record_test_execution()


func test_command_deck_omits_controls_panel_and_briefing_preserves_full_intel() -> void:
	var hook: String = (screen.get_node("%InstructionLabel") as Label).text
	var briefing_controls: String = (
		screen.get_node("SemanticContract/BriefingControlsLabel") as Label
	).text
	var field_note: String = (screen.get_node("SemanticContract/FieldNote") as Label).text
	var enemy_intel: String = (screen.get_node("%EnemyIntel") as Label).text
	var run_rule: String = (screen.get_node("%RunRule") as Label).text
	assert_eq(hook, L10n.t("title.command_hook"))
	assert_null(screen.get_node_or_null("StatusRail"))
	assert_null(screen.get_node_or_null("%ControlsLabel"))
	assert_eq(
		briefing_controls,
		L10n.t("title.controls_body", InputBindingSettings.display_placeholders())
	)
	assert_true(field_note.contains("Bindings can be changed"))
	assert_true(field_note.contains("AUTO SAVE"))
	assert_true(
		(screen.get_node("SemanticContract/ObjectiveOne") as Label).text.contains(
			"recover dossiers"
		)
	)
	assert_true(
		(screen.get_node("SemanticContract/ObjectiveThree") as Label).text.contains(
			"Continuity Cradle"
		)
	)
	assert_true(enemy_intel.contains("Armor + aircraft"))
	assert_true(enemy_intel.contains("Reclaimed + carriers"))
	assert_true(run_rule.contains("reset when you Retry"))
	assert_true(screen.open_briefing())
	assert_true((screen.get_node("%BriefingLayer") as Control).visible)
	assert_true(screen.close_briefing())
	assert_false((screen.get_node("%BriefingLayer") as Control).visible)
	_record_test_execution()


func test_initialize_seam_transitions_once() -> void:
	var status_label: Label = screen.get_node("%StatusLabel") as Label
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	assert_false(screen.initialized)
	assert_true(screen.initialize_game())
	assert_true(screen.initialized)
	assert_eq(status_label.text, L10n.t("title.expedition_active"))
	assert_eq(initialize_button.text, L10n.t("title.deploying"))
	assert_true(initialize_button.disabled)
	assert_null(screen.get_node_or_null("%AutomaticButton"))
	assert_true((screen.get_node("%EnglishButton") as Button).disabled)
	assert_true((screen.get_node("%ChineseButton") as Button).disabled)
	assert_true((screen.get_node("%SettingsButton") as Button).disabled)
	assert_true((screen.get_node("%LeaderboardButton") as Button).disabled)
	assert_false(screen.initialize_game(), "A second initialization must reject without mutation.")
	assert_eq(status_label.text, L10n.t("title.expedition_active"))
	_record_test_execution()


func test_first_trusted_title_input_requests_audio_once() -> void:
	var activation_count: Array[int] = [0]
	screen.audio_activation_requested.connect(func() -> void: activation_count[0] += 1)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_A
	screen._input(key_event)
	screen._input(key_event)
	assert_eq(activation_count[0], 1)
	assert_true(screen._audio_activation_emitted)
	_record_test_execution()


func test_fresh_profile_starts_with_eighty_percent_music_volume() -> void:
	var slider: HSlider = screen.get_node("%MusicVolumeSlider") as HSlider
	var value_label: Label = screen.get_node("%MusicVolumeValue") as Label
	assert_almost_eq(slider.value, 80.0, 0.001)
	assert_eq(value_label.text, "80%")
	var music_bus_index: int = AudioServer.get_bus_index(GameAudioBus.MUSIC)
	assert_almost_eq(
		AudioServer.get_bus_volume_db(music_bus_index),
		AudioVolumeSettings.percent_to_db(80.0),
		0.001
	)
	_record_test_execution()


func test_settings_menu_applies_and_persists_the_complete_audio_mix() -> void:
	var settings_layer: Control = screen.get_node("%SettingsLayer") as Control
	var sliders: Dictionary = {
		AudioVolumeSettings.Channel.MASTER: screen.get_node("%MasterVolumeSlider"),
		AudioVolumeSettings.Channel.MUSIC: screen.get_node("%MusicVolumeSlider"),
		AudioVolumeSettings.Channel.SFX: screen.get_node("%SfxVolumeSlider"),
		AudioVolumeSettings.Channel.VOICE: screen.get_node("%VoiceVolumeSlider"),
	}
	var labels: Dictionary = {
		AudioVolumeSettings.Channel.MASTER: screen.get_node("%MasterVolumeValue"),
		AudioVolumeSettings.Channel.MUSIC: screen.get_node("%MusicVolumeValue"),
		AudioVolumeSettings.Channel.SFX: screen.get_node("%SfxVolumeValue"),
		AudioVolumeSettings.Channel.VOICE: screen.get_node("%VoiceVolumeValue"),
	}
	var mute_buttons: Dictionary = {
		AudioVolumeSettings.Channel.MASTER: screen.get_node("%MasterMuteButton"),
		AudioVolumeSettings.Channel.MUSIC: screen.get_node("%MusicMuteButton"),
		AudioVolumeSettings.Channel.SFX: screen.get_node("%SfxMuteButton"),
		AudioVolumeSettings.Channel.VOICE: screen.get_node("%VoiceMuteButton"),
	}
	var requested: Dictionary = {
		AudioVolumeSettings.Channel.MASTER: 82.0,
		AudioVolumeSettings.Channel.MUSIC: 35.0,
		AudioVolumeSettings.Channel.SFX: 64.0,
		AudioVolumeSettings.Channel.VOICE: 46.0,
	}
	assert_false(settings_layer.visible)
	assert_true(screen.open_settings())
	assert_true(settings_layer.visible)
	assert_true((screen.get_node("%SettingsScroll") as ScrollContainer).visible)
	assert_eq(
		(screen.get_node("%ControlsHeading") as Label).text,
		L10n.t("title.controls_settings_heading")
	)
	assert_true((screen.get_node("%ControllerVibrationToggle") as CheckButton).button_pressed)
	for channel: int in AudioVolumeSettings.CHANNELS:
		var slider: HSlider = sliders[channel] as HSlider
		var value_label: Label = labels[channel] as Label
		var percent: float = float(requested[channel])
		slider.value = percent
		assert_eq(value_label.text, "%d%%" % int(percent))
		var bus_index: int = AudioServer.get_bus_index(
			AudioVolumeSettings.bus_name(channel)
		)
		assert_almost_eq(
			AudioServer.get_bus_volume_db(bus_index),
			AudioVolumeSettings.percent_to_db(percent),
			0.01
		)
		assert_almost_eq(
			AudioVolumeSettings.load_percent(channel, AUDIO_PREFERENCE_PATH),
			percent,
			0.01
		)
		var mute_button: Button = mute_buttons[channel] as Button
		mute_button.button_pressed = true
		assert_eq(mute_button.text, L10n.t("title.audio_muted"))
		assert_true(AudioServer.is_bus_mute(bus_index))
		assert_true(AudioVolumeSettings.load_muted(channel, AUDIO_PREFERENCE_PATH))
	assert_true(screen.close_settings())
	assert_false(settings_layer.visible)
	var restored_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	restored_screen.audio_preference_path = AUDIO_PREFERENCE_PATH
	add_child_autofree(restored_screen)
	await get_tree().process_frame
	for channel: int in AudioVolumeSettings.CHANNELS:
		var slider_name: String = {
			AudioVolumeSettings.Channel.MASTER: "%MasterVolumeSlider",
			AudioVolumeSettings.Channel.MUSIC: "%MusicVolumeSlider",
			AudioVolumeSettings.Channel.SFX: "%SfxVolumeSlider",
			AudioVolumeSettings.Channel.VOICE: "%VoiceVolumeSlider",
		}[channel]
		assert_almost_eq(
			(restored_screen.get_node(slider_name) as HSlider).value,
			float(requested[channel]),
			0.01
		)
		var mute_button_name: String = {
			AudioVolumeSettings.Channel.MASTER: "%MasterMuteButton",
			AudioVolumeSettings.Channel.MUSIC: "%MusicMuteButton",
			AudioVolumeSettings.Channel.SFX: "%SfxMuteButton",
			AudioVolumeSettings.Channel.VOICE: "%VoiceMuteButton",
		}[channel]
		var restored_mute_button: Button = (
			restored_screen.get_node(mute_button_name) as Button
		)
		assert_true(restored_mute_button.button_pressed)
		assert_eq(restored_mute_button.text, L10n.t("title.audio_muted"))
	_record_test_execution()


func test_settings_and_briefing_are_mutually_exclusive() -> void:
	assert_true(screen.open_briefing())
	assert_true(screen.open_settings())
	assert_false(screen.briefing_open)
	assert_true(screen.settings_open)
	assert_false((screen.get_node("%BriefingLayer") as Control).visible)
	assert_true(screen.open_briefing())
	assert_true(screen.briefing_open)
	assert_false(screen.settings_open)
	assert_false((screen.get_node("%SettingsLayer") as Control).visible)
	_record_test_execution()


func test_title_leaderboard_exposes_local_and_global_tabs_with_back_navigation() -> void:
	var leaderboard_button: Button = screen.get_node("%LeaderboardButton") as Button
	assert_eq(leaderboard_button.text, L10n.t("title.leaderboard"))
	assert_false(screen.leaderboard_overlay.visible)
	assert_true(screen.open_settings())
	assert_true(screen.open_leaderboard())
	assert_false(screen.settings_open)
	assert_true(screen.leaderboard_open)
	assert_true(screen.leaderboard_overlay.visible)
	assert_eq(
		screen.leaderboard_overlay.local_tab_button.text,
		L10n.t("title.leaderboard_local_tab")
	)
	assert_eq(
		screen.leaderboard_overlay.global_tab_button.text,
		L10n.t("title.leaderboard_global_tab")
	)
	assert_eq(screen.leaderboard_overlay.current_tab, TitleLeaderboardOverlay.Tab.LOCAL)
	assert_true(screen.leaderboard_overlay.local_tab_button.button_pressed)
	assert_false(screen.leaderboard_overlay.global_tab_button.button_pressed)
	assert_true(screen.leaderboard_overlay.row_labels[0].text.contains("TITLE ACE"))
	assert_true(screen.leaderboard_overlay.row_labels[0].text.contains("00043210"))
	assert_true(screen.leaderboard_overlay.row_labels[0].text.contains("SIEGE DRILL"))
	screen.leaderboard_overlay.global_tab_button.pressed.emit()
	assert_eq(screen.leaderboard_overlay.current_tab, TitleLeaderboardOverlay.Tab.GLOBAL)
	assert_true(screen.leaderboard_overlay.global_tab_button.button_pressed)
	assert_eq(
		screen.leaderboard_overlay.status_label.text,
		L10n.t("debrief.global.state.native_local")
	)
	assert_true(
		screen.leaderboard_overlay.row_labels[0].text.contains("TITLE ACE"),
		"Native builds should present the local board as the documented global fallback."
	)
	var cancel_event: InputEventAction = InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	screen._unhandled_input(cancel_event)
	await get_tree().process_frame
	assert_false(screen.leaderboard_open)
	assert_false(screen.leaderboard_overlay.visible)
	assert_eq(get_viewport().gui_get_focus_owner(), leaderboard_button)
	_record_test_execution()


func test_title_leaderboard_saves_validated_callsign_and_refreshes_identity() -> void:
	assert_true(screen.open_leaderboard())
	var overlay: TitleLeaderboardOverlay = screen.leaderboard_overlay
	assert_eq(overlay.callsign_edit.text, "TITLE ACE")
	assert_eq(
		overlay.callsign_edit.max_length,
		PlayerCombatProfileStore.MAX_CALLSIGN_LENGTH
	)
	var saved_callsigns: Array[String] = []
	overlay.callsign_saved.connect(
		func(callsign: String) -> void: saved_callsigns.append(callsign)
	)
	overlay.callsign_edit.text = "  Nova   Prime  "
	overlay.callsign_save_button.pressed.emit()
	assert_eq(combat_profile.callsign(), "Nova Prime")
	assert_eq(overlay.callsign_edit.text, "Nova Prime")
	assert_eq(saved_callsigns, ["Nova Prime"])
	assert_eq(
		overlay.callsign_status_label.text,
		L10n.t("debrief.callsign.saved")
	)
	assert_eq(overlay.callsign_status_label.modulate, TitleLeaderboardOverlay.CYAN)
	assert_true(overlay.row_labels[0].text.contains("Nova Prime"))
	var reloaded_profile: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(reloaded_profile)
	reloaded_profile.setup(COMBAT_PROFILE_PATH)
	assert_eq(reloaded_profile.callsign(), "Nova Prime")
	overlay.callsign_edit.text = "x"
	overlay.callsign_save_button.pressed.emit()
	assert_eq(combat_profile.callsign(), "Nova Prime")
	assert_eq(saved_callsigns, ["Nova Prime"])
	assert_eq(
		overlay.callsign_status_label.text,
		L10n.t("debrief.callsign.too_short")
	)
	assert_eq(overlay.callsign_status_label.modulate, TitleLeaderboardOverlay.RED)
	overlay.callsign_edit.text = "f_u_c_k"
	overlay.callsign_edit.text_submitted.emit(overlay.callsign_edit.text)
	assert_eq(combat_profile.callsign(), "Nova Prime")
	assert_eq(
		overlay.callsign_status_label.text,
		L10n.t("debrief.callsign.inappropriate")
	)
	overlay.set_callsign_uplink_state(&"success")
	assert_eq(overlay.callsign_uplink_state, &"success")
	assert_eq(
		overlay.callsign_status_label.text,
		L10n.t("debrief.callsign.uplink.success")
	)
	_record_test_execution()


func test_title_leaderboard_layout_and_localization_cover_both_orientations() -> void:
	assert_true(screen.open_leaderboard())
	for viewport_size: Vector2 in [Vector2(1280.0, 720.0), Vector2(720.0, 1280.0)]:
		screen.leaderboard_overlay.apply_responsive_layout(viewport_size)
		_assert_rect_inside(
			screen.leaderboard_overlay.panel.get_rect(),
			viewport_size
		)
		assert_false(
			screen.leaderboard_overlay.local_tab_button.get_rect().intersects(
				screen.leaderboard_overlay.global_tab_button.get_rect()
			)
		)
		assert_gte(screen.leaderboard_overlay.local_tab_button.size.y, 44.0)
		_assert_rect_inside(
			screen.leaderboard_overlay.callsign_edit.get_rect(),
			screen.leaderboard_overlay.panel.size
		)
		_assert_rect_inside(
			screen.leaderboard_overlay.callsign_save_button.get_rect(),
			screen.leaderboard_overlay.panel.size
		)
		assert_false(
			screen.leaderboard_overlay.callsign_edit.get_rect().intersects(
				screen.leaderboard_overlay.callsign_save_button.get_rect()
			)
		)
		assert_gte(screen.leaderboard_overlay.callsign_edit.size.y, 44.0)
		assert_gte(screen.leaderboard_overlay.callsign_save_button.size.y, 44.0)
		assert_gte(screen.leaderboard_overlay.close_button.size.y, 44.0)
	assert_true(screen.select_language("zh-CN"))
	assert_eq(screen.leaderboard_overlay.heading_label.text, "排行榜")
	assert_eq(screen.leaderboard_overlay.local_tab_button.text, "本地")
	assert_eq(screen.leaderboard_overlay.global_tab_button.text, "全球")
	assert_eq(screen.leaderboard_overlay.callsign_header_label.text, "操作员呼号")
	assert_eq(screen.leaderboard_overlay.callsign_edit.placeholder_text, "输入呼号")
	assert_eq(screen.leaderboard_overlay.callsign_save_button.text, "保存呼号")
	assert_eq(screen.leaderboard_overlay.close_button.text, "关闭")
	_record_test_execution()


func test_campaign_archive_shows_only_focus_safe_codex_button() -> void:
	var archive_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	archive_screen.configure_campaign({
		"dossiers": PackedStringArray([
			"dossier_business_mercy_exchange_annex",
		]),
		"dossier_count": 1,
		"continuity_generation": 3,
		"seen_endings": PackedStringArray(["PURGE", "DISENTANGLE"]),
	})
	archive_screen.locale_preference_path = LANGUAGE_PREFERENCE_PATH
	archive_screen.audio_preference_path = AUDIO_PREFERENCE_PATH
	archive_screen.input_preference_path = INPUT_PREFERENCE_PATH
	add_child_autofree(archive_screen)
	await get_tree().process_frame
	assert_true(archive_screen.open_briefing())
	assert_false(archive_screen.campaign_panel.panel.visible)
	for summary_label: Label in [
		archive_screen.campaign_panel.heading_label,
		archive_screen.campaign_panel.progress_label,
		archive_screen.campaign_panel.evidence_label,
		archive_screen.campaign_panel.continuity_label,
		archive_screen.campaign_panel.endings_label,
	]:
		assert_false(summary_label.visible)
	assert_true(archive_screen.campaign_panel.codex_button.is_visible_in_tree())
	assert_eq(
		archive_screen.campaign_panel.codex_button.text,
		L10n.t("narrative.campaign.open_codex")
	)
	archive_screen.campaign_panel.codex_button.pressed.emit()
	assert_true(archive_screen.dossier_codex.visible)
	assert_true(
		archive_screen.dossier_codex.detail_title.text.contains("Mercy Exchange Annex")
	)
	assert_false(archive_screen.dossier_codex.detail_body.text.contains("encrypted"))
	archive_screen.dossier_codex.dossier_list.select(1)
	archive_screen.dossier_codex.dossier_list.item_selected.emit(1)
	assert_eq(
		archive_screen.dossier_codex.detail_title.text,
		L10n.t("narrative.codex.locked_title")
	)
	var cancel_event: InputEventAction = InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	archive_screen._unhandled_input(cancel_event)
	assert_false(archive_screen.dossier_codex.visible)
	await get_tree().process_frame
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		archive_screen.campaign_panel.codex_button
	)
	assert_true(archive_screen.select_language("zh-CN"))
	assert_eq(
		archive_screen.campaign_panel.codex_button.text,
		L10n.t("narrative.campaign.open_codex")
	)
	assert_eq(int(archive_screen.campaign_snapshot.dossier_count), 1)
	_record_test_execution()


func test_all_ui_text_meets_the_32_pixel_rendered_height_pin() -> void:
	var measured_controls: int = 0
	var minimum_height: float = INF
	for label_node: Node in screen.find_children("*", "Label", true, false):
		var label: Label = label_node as Label
		minimum_height = minf(minimum_height, _rendered_line_height(label))
		measured_controls += 1
	for button_node: Node in screen.find_children("*", "Button", true, false):
		var button: Button = button_node as Button
		if button.text.is_empty():
			continue
		minimum_height = minf(minimum_height, _rendered_line_height(button))
		measured_controls += 1
	assert_true(measured_controls >= 10, "Expected at least ten live UI text controls.")
	assert_true(
		minimum_height >= MINIMUM_TEXT_HEIGHT,
		"Minimum rendered line height was %.2f px; expected at least %.2f px."
		% [minimum_height, MINIMUM_TEXT_HEIGHT]
	)
	_record_test_execution()


func test_launch_action_does_not_overlap_briefing_action() -> void:
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	var language_selector: HBoxContainer = screen.get_node("%LanguageSelector") as HBoxContainer
	var briefing_toggle: Button = screen.get_node("%BriefingToggle") as Button
	assert_gte(
		language_selector.get_global_rect().position.y,
		initialize_button.get_global_rect().end.y + 16.0,
		"The launch action must retain at least 16 px of bottom spacing."
	)
	assert_false(
		initialize_button.get_global_rect().intersects(briefing_toggle.get_global_rect()),
		"Launch and briefing actions must remain spatially distinct."
	)
	_record_test_execution()


func test_generated_title_art_and_minimal_briefing_contract() -> void:
	var background: TextureRect = screen.get_node("%BackgroundArt") as TextureRect
	assert_true(background.texture.resource_path.contains("command_deck_landscape.jpg"))
	assert_null(screen.get_node_or_null("%BriefingArt"))
	var briefing_background: ColorRect = (
		screen.get_node("%BriefingBackground") as ColorRect
	)
	assert_gt(briefing_background.color.a, 0.95)
	var source_file: FileAccess = FileAccess.open("res://scripts/title_screen.gd", FileAccess.READ)
	var source: String = source_file.get_as_text()
	assert_false(source.contains("func _draw"), "Procedural title graphics are forbidden.")
	assert_false(source.contains("draw_line"), "Procedural title graphics are forbidden.")
	assert_false(source.contains("draw_circle"), "Procedural title graphics are forbidden.")
	assert_true(source.contains("protoScrollerSetTitleBackdropActive"))
	var host_source: String = FileAccess.get_file_as_string("res://../client/src/main.ts")
	assert_true(host_source.contains("title-loop-landscape.mp4"))
	assert_true(host_source.contains("title-loop-portrait.mp4"))
	assert_true(host_source.contains("title-poster-landscape.jpg"))
	assert_true(host_source.contains("title-poster-portrait.jpg"))
	var shell_source: String = FileAccess.get_file_as_string(
		"res://../scripts/patch-title-video-shell.mjs"
	)
	assert_true(shell_source.contains("dynamic canvas resize policy"))
	assert_true(shell_source.contains("canvasResizePolicy\":2"))
	assert_true(shell_source.contains("width: 100dvw"))
	assert_true(shell_source.contains("height: 100dvh"))
	assert_true(shell_source.contains("max-width: none"))
	for runtime_source: String in [host_source, shell_source]:
		assert_true(runtime_source.contains("title-loop-landscape.mp4"))
		assert_true(runtime_source.contains("title-loop-portrait.mp4"))
		assert_true(runtime_source.contains("protoScrollerScheduleTitleBeatCommit"))
		assert_true(runtime_source.contains("protoScrollerCancelTitleBeatCommit"))
		assert_true(runtime_source.contains("requestAnimationFrame"))
		assert_true(runtime_source.contains("requestVideoFrameCallback"))
		assert_true(runtime_source.contains("getOutputTimestamp"))
		assert_true(runtime_source.contains("AudioBufferSourceNode"))
		assert_true(runtime_source.contains("prototype.start"))
		assert_true(runtime_source.contains("commitCallback"))
		assert_true(runtime_source.contains("__PROTO_SCROLLER_TITLE_MUSIC_SYNC__"))
		assert_true(runtime_source.contains("forceTitleVideoReject"))
		assert_true(runtime_source.contains("video-playback-rejected"))
		assert_true(runtime_source.contains("targetPerformanceTime"))
		assert_true(runtime_source.contains("setTimeout"))
		assert_true(runtime_source.contains("TITLE_AUDIO_SCHEDULE_AHEAD_SECONDS"))
		assert_true(runtime_source.contains("TITLE_SOURCE_CAPTURE_TIMEOUT_MS"))
		assert_true(runtime_source.contains("effectiveWhen"))
		assert_true(runtime_source.contains("scheduleToImpact"))
		assert_true(runtime_source.contains("titleTargetOutputPerformanceTime"))
		assert_true(runtime_source.contains("secondsUntilImpact"))
		assert_true(runtime_source.contains("secondsUntilRendered"))
		assert_true(runtime_source.contains("scheduled"))
	assert_true(host_source.contains("88 / 24"))
	assert_true(host_source.contains("66 / 24"))
	_record_test_execution()


func _rendered_line_height(control: Control) -> float:
	var font: Font = control.get_theme_font(&"font")
	var font_size: int = control.get_theme_font_size(&"font_size")
	return font.get_height(font_size)


func _reset_audio_settings() -> void:
	for channel: int in AudioVolumeSettings.CHANNELS:
		AudioVolumeSettings.apply_percent(
			channel,
			AudioVolumeSettings.default_percent(channel)
		)
		AudioVolumeSettings.apply_muted(channel, false)


func _clear_input_preference() -> void:
	if FileAccess.file_exists(INPUT_PREFERENCE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(INPUT_PREFERENCE_PATH))


func _clear_combat_profile() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = COMBAT_PROFILE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _leaderboard_summary() -> RunSummarySnapshot:
	return RunSummarySnapshot.new(
		43210,
		4,
		18,
		3,
		1,
		{},
		{
			"completed": false,
			"highest_combo_tier": 7,
			"total_enemies_defeated": 9,
			"unique_enemy_types": 2,
			"enemy_kills": {&"soldier": 6, &"tank": 3},
			"weapon_kills": {&"SIEGE_DRILL": 7, &"JAB_CROSS": 2},
			"preferred_weapon": &"SIEGE_DRILL",
			"preferred_weapon_kills": 7,
		}
	)


func _assert_rect_inside(rect: Rect2, bounds: Vector2) -> void:
	assert_gte(rect.position.x, 0.0)
	assert_gte(rect.position.y, 0.0)
	assert_lte(rect.end.x, bounds.x + 0.01)
	assert_lte(rect.end.y, bounds.y + 0.01)


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
