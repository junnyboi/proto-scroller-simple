class_name TitleScreen
extends Control

signal start_requested
signal audio_activation_requested
signal settings_closed

const LANDSCAPE_ART: Texture2D = preload(
	"res://art/ui/title_screen/command_deck_landscape.jpg"
)
const PORTRAIT_ART: Texture2D = preload(
	"res://art/ui/title_screen/command_deck_portrait.jpg"
)
const LEADERBOARD_OVERLAY_SCRIPT: Script = preload(
	"res://scripts/ui/title_leaderboard_overlay.gd"
)
const LEADERBOARD_BRIDGE_SCRIPT: Script = preload(
	"res://scripts/network/leaderboard_bridge.gd"
)
var initialized: bool = false
var settings_open: bool = false
var leaderboard_open: bool = false
var settings_only_mode: bool = false
var locale_preference_path: String = L10n.PREFERENCE_PATH
var audio_preference_path: String = AudioVolumeSettings.PREFERENCE_PATH
var input_preference_path: String = InputBindingSettings.PREFERENCE_PATH
var combat_profile: PlayerCombatProfileStore
var leaderboard_overlay: TitleLeaderboardOverlay
var leaderboard_bridge: LeaderboardBridge
var _capture_action: StringName = &""
var _capture_gamepad: bool = false
var _audio_activation_emitted: bool = false
var _web_title_backdrop_active: bool = false

@onready var background_art: TextureRect = %BackgroundArt
@onready var initialize_button: Button = %InitializeButton
@onready var settings_button: Button = %SettingsButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var settings_layer: Control = %SettingsLayer
@onready var settings_backdrop: Button = %SettingsBackdrop
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var settings_heading: Label = %SettingsHeading
@onready var master_volume_label: Label = %MasterVolumeLabel
@onready var master_volume_value: Label = %MasterVolumeValue
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var master_mute_button: Button = %MasterMuteButton
@onready var music_volume_label: Label = %MusicVolumeLabel
@onready var music_volume_value: Label = %MusicVolumeValue
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var music_mute_button: Button = %MusicMuteButton
@onready var sfx_volume_label: Label = %SfxVolumeLabel
@onready var sfx_volume_value: Label = %SfxVolumeValue
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var sfx_mute_button: Button = %SfxMuteButton
@onready var voice_volume_label: Label = %VoiceVolumeLabel
@onready var voice_volume_value: Label = %VoiceVolumeValue
@onready var voice_volume_slider: HSlider = %VoiceVolumeSlider
@onready var voice_mute_button: Button = %VoiceMuteButton
@onready var audio_volume_hint: Label = %AudioVolumeHint
@onready var settings_scroll: ScrollContainer = %SettingsScroll
@onready var controls_heading: Label = %ControlsHeading
@onready var move_left_binding_label: Label = %MoveLeftBindingLabel
@onready var move_right_binding_label: Label = %MoveRightBindingLabel
@onready var smash_binding_label: Label = %SmashBindingLabel
@onready var dodge_binding_label: Label = %DodgeBindingLabel
@onready var binding_hint: Label = %BindingHint
@onready var controller_vibration_toggle: CheckButton = %ControllerVibrationToggle
@onready var reset_bindings_button: Button = %ResetBindingsButton
@onready var settings_close_button: Button = %SettingsCloseButton
@onready var keyboard_binding_buttons: Dictionary[StringName, Button] = {
	&"move_left": %MoveLeftKeyboardButton,
	&"move_right": %MoveRightKeyboardButton,
	&"stomp": %SmashKeyboardButton,
	&"dodge": %DodgeKeyboardButton,
}
@onready var gamepad_binding_buttons: Dictionary[StringName, Button] = {
	&"move_left": %MoveLeftGamepadButton,
	&"move_right": %MoveRightGamepadButton,
	&"stomp": %SmashGamepadButton,
	&"dodge": %DodgeGamepadButton,
}
@onready var language_selector: HBoxContainer = %LanguageSelector
@onready var language_label: Label = %LanguageLabel
@onready var english_button: Button = %EnglishButton
@onready var chinese_button: Button = %ChineseButton
@onready var status_label: Label = %StatusLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var system_value: Label = %SystemValue


func configure_leaderboard(store: PlayerCombatProfileStore) -> void:
	combat_profile = store


func configure_settings_only() -> void:
	settings_only_mode = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if not settings_only_mode:
		_set_web_title_backdrop_active(true)
		_web_title_backdrop_active = true
	initialize_button.pressed.connect(_on_initialize_pressed)
	if not settings_only_mode:
		_build_leaderboard()
	leaderboard_button.pressed.connect(open_leaderboard)
	settings_button.pressed.connect(open_settings)
	settings_backdrop.pressed.connect(close_settings)
	settings_close_button.pressed.connect(close_settings)
	for action: StringName in InputBindingSettings.ACTIONS:
		keyboard_binding_buttons[action].pressed.connect(
			_begin_binding_capture.bind(action, false)
		)
		gamepad_binding_buttons[action].pressed.connect(
			_begin_binding_capture.bind(action, true)
		)
	controller_vibration_toggle.toggled.connect(_on_controller_vibration_toggled)
	reset_bindings_button.pressed.connect(_on_reset_bindings_pressed)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	voice_volume_slider.value_changed.connect(_on_voice_volume_changed)
	master_mute_button.toggled.connect(_on_master_mute_toggled)
	music_mute_button.toggled.connect(_on_music_mute_toggled)
	sfx_mute_button.toggled.connect(_on_sfx_mute_toggled)
	voice_mute_button.toggled.connect(_on_voice_mute_toggled)
	english_button.pressed.connect(_on_english_pressed)
	chinese_button.pressed.connect(_on_chinese_pressed)
	InputBindingSettings.apply_saved(input_preference_path)
	var volume_values: Dictionary = AudioVolumeSettings.apply_saved(audio_preference_path)
	master_volume_slider.set_value_no_signal(float(volume_values[AudioVolumeSettings.Channel.MASTER]))
	music_volume_slider.set_value_no_signal(float(volume_values[AudioVolumeSettings.Channel.MUSIC]))
	sfx_volume_slider.set_value_no_signal(float(volume_values[AudioVolumeSettings.Channel.SFX]))
	voice_volume_slider.set_value_no_signal(float(volume_values[AudioVolumeSettings.Channel.VOICE]))
	master_mute_button.set_pressed_no_signal(
		AudioVolumeSettings.load_muted(AudioVolumeSettings.Channel.MASTER, audio_preference_path)
	)
	music_mute_button.set_pressed_no_signal(
		AudioVolumeSettings.load_muted(AudioVolumeSettings.Channel.MUSIC, audio_preference_path)
	)
	sfx_mute_button.set_pressed_no_signal(
		AudioVolumeSettings.load_muted(AudioVolumeSettings.Channel.SFX, audio_preference_path)
	)
	voice_mute_button.set_pressed_no_signal(
		AudioVolumeSettings.load_muted(AudioVolumeSettings.Channel.VOICE, audio_preference_path)
	)
	controller_vibration_toggle.set_pressed_no_signal(
		InputBindingSettings.controller_vibration_enabled()
	)
	_update_audio_volume_values()
	_refresh_binding_labels()
	_update_mute_button_texts()
	if not settings_only_mode:
		initialize_button.call_deferred("grab_focus")
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_localized_text()
	L10n.apply_locale_font(self)
	L10n.apply_cjk_font(chinese_button)
	_apply_responsive_layout()
	if settings_only_mode:
		_prepare_settings_only_presentation()


func _exit_tree() -> void:
	if _web_title_backdrop_active:
		_set_web_title_backdrop_active(false)
		_web_title_backdrop_active = false


func _input(event: InputEvent) -> void:
	if not settings_only_mode:
		_request_title_audio_activation(event)
	if _capture_action.is_empty():
		return
	if not _capture_gamepad and event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		var keycode: Key = key_event.physical_keycode
		if keycode == KEY_NONE:
			keycode = key_event.keycode
		if keycode == KEY_ESCAPE:
			_cancel_binding_capture()
		else:
			InputBindingSettings.set_keyboard_binding(
				_capture_action,
				keycode,
				input_preference_path
			)
			_complete_binding_capture()
		get_viewport().set_input_as_handled()
		return
	if _capture_gamepad and event is InputEventJoypadButton:
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		if not button_event.pressed:
			return
		InputBindingSettings.set_gamepad_binding(
			_capture_action,
			button_event.button_index,
			input_preference_path
		)
		_complete_binding_capture()
		get_viewport().set_input_as_handled()


func _request_title_audio_activation(event: InputEvent) -> void:
	if _audio_activation_emitted or initialized:
		return
	var trusted_press: bool = false
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		trusted_press = key_event.pressed and not key_event.echo
	elif event is InputEventMouseButton:
		trusted_press = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		trusted_press = (event as InputEventScreenTouch).pressed
	elif event is InputEventJoypadButton:
		trusted_press = (event as InputEventJoypadButton).pressed
	if not trusted_press:
		return
	_audio_activation_emitted = true
	audio_activation_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if settings_only_mode:
		if settings_open and event.is_action_pressed(&"ui_cancel"):
			close_settings(false)
			get_viewport().set_input_as_handled()
		return
	if leaderboard_open and event.is_action_pressed(&"ui_cancel"):
		close_leaderboard()
		get_viewport().set_input_as_handled()
		return
	if settings_open and event.is_action_pressed(&"ui_cancel"):
		close_settings()
		get_viewport().set_input_as_handled()
		return
	if settings_open:
		return


func initialize_game() -> bool:
	if initialized:
		return false
	initialized = true
	close_settings(false)
	close_leaderboard(false)
	status_label.text = L10n.t("title.expedition_active")
	status_label.modulate = Color("72ffd6")
	instruction_label.text = L10n.t("title.deployment_authorized")
	system_value.text = L10n.t("title.deploying")
	system_value.modulate = Color("72ffd6")
	initialize_button.text = L10n.t("title.deploying")
	initialize_button.disabled = true
	settings_button.disabled = true
	leaderboard_button.disabled = true
	english_button.disabled = true
	chinese_button.disabled = true
	return true


func open_settings() -> bool:
	if initialized or settings_open:
		return false
	close_leaderboard(false)
	settings_open = true
	settings_layer.visible = true
	master_volume_slider.call_deferred("grab_focus")
	return true


func close_settings(restore_focus: bool = true) -> bool:
	if not settings_open:
		return false
	_cancel_binding_capture()
	settings_open = false
	settings_layer.visible = false
	if restore_focus and not initialized and not settings_only_mode:
		settings_button.call_deferred("grab_focus")
	settings_closed.emit()
	return true


func _prepare_settings_only_presentation() -> void:
	for child: Node in get_children():
		if child == settings_layer:
			continue
		var canvas_item: CanvasItem = child as CanvasItem
		if canvas_item != null:
			canvas_item.visible = false
	settings_layer.visible = settings_open


func open_leaderboard() -> bool:
	if initialized or leaderboard_open or leaderboard_overlay == null:
		return false
	close_settings(false)
	leaderboard_open = true
	leaderboard_overlay.open(leaderboard_button)
	L10n.apply_locale_font(leaderboard_overlay)
	return true


func close_leaderboard(restore_focus: bool = true) -> bool:
	if not leaderboard_open or leaderboard_overlay == null:
		return false
	leaderboard_open = false
	return leaderboard_overlay.close(restore_focus)


func _on_leaderboard_closed() -> void:
	leaderboard_open = false


func select_language(locale: String) -> bool:
	if initialized or not L10n.set_locale(locale, true, locale_preference_path):
		_sync_language_selector()
		return false
	_apply_localized_text()
	L10n.apply_locale_font(self)
	L10n.apply_cjk_font(chinese_button)
	_apply_responsive_layout()
	return true


func select_automatic_language() -> bool:
	if initialized or not L10n.use_automatic_locale(locale_preference_path):
		_sync_language_selector()
		return false
	_apply_localized_text()
	L10n.apply_locale_font(self)
	L10n.apply_cjk_font(chinese_button)
	_apply_responsive_layout()
	return true


func _on_initialize_pressed() -> void:
	if initialize_game():
		start_requested.emit()


func _on_english_pressed() -> void:
	select_language("en")


func _on_chinese_pressed() -> void:
	select_language("zh-CN")


func _begin_binding_capture(action: StringName, gamepad: bool) -> void:
	_capture_action = action
	_capture_gamepad = gamepad
	_refresh_binding_labels()


func _complete_binding_capture() -> void:
	var completed_action: StringName = _capture_action
	var completed_gamepad: bool = _capture_gamepad
	_capture_action = &""
	_capture_gamepad = false
	_refresh_binding_labels()
	_refresh_control_copy()
	var completed_button: Button = (
		gamepad_binding_buttons[completed_action]
		if completed_gamepad
		else keyboard_binding_buttons[completed_action]
	)
	completed_button.call_deferred("grab_focus")


func _cancel_binding_capture() -> void:
	if _capture_action.is_empty():
		return
	_capture_action = &""
	_capture_gamepad = false
	_refresh_binding_labels()


func _on_controller_vibration_toggled(enabled: bool) -> void:
	InputBindingSettings.set_controller_vibration_enabled(
		enabled,
		input_preference_path
	)


func _on_reset_bindings_pressed() -> void:
	InputBindingSettings.reset_to_defaults(input_preference_path)
	controller_vibration_toggle.set_pressed_no_signal(true)
	_refresh_binding_labels()
	_refresh_control_copy()


func _on_master_volume_changed(value: float) -> void:
	_save_volume(AudioVolumeSettings.Channel.MASTER, value)


func _on_music_volume_changed(value: float) -> void:
	_save_volume(AudioVolumeSettings.Channel.MUSIC, value)


func _on_sfx_volume_changed(value: float) -> void:
	_save_volume(AudioVolumeSettings.Channel.SFX, value)


func _on_voice_volume_changed(value: float) -> void:
	_save_volume(AudioVolumeSettings.Channel.VOICE, value)


func _on_master_mute_toggled(muted: bool) -> void:
	_save_mute(AudioVolumeSettings.Channel.MASTER, muted)


func _on_music_mute_toggled(muted: bool) -> void:
	_save_mute(AudioVolumeSettings.Channel.MUSIC, muted)


func _on_sfx_mute_toggled(muted: bool) -> void:
	_save_mute(AudioVolumeSettings.Channel.SFX, muted)


func _on_voice_mute_toggled(muted: bool) -> void:
	_save_mute(AudioVolumeSettings.Channel.VOICE, muted)


func _save_volume(channel: AudioVolumeSettings.Channel, value: float) -> void:
	AudioVolumeSettings.set_and_save(channel, value, audio_preference_path)
	_update_audio_volume_values()


func _save_mute(channel: AudioVolumeSettings.Channel, muted: bool) -> void:
	AudioVolumeSettings.set_muted_and_save(channel, muted, audio_preference_path)
	_update_mute_button_texts()


func _update_audio_volume_values() -> void:
	master_volume_value.text = "%d%%" % int(round(master_volume_slider.value))
	music_volume_value.text = "%d%%" % int(round(music_volume_slider.value))
	sfx_volume_value.text = "%d%%" % int(round(sfx_volume_slider.value))
	voice_volume_value.text = "%d%%" % int(round(voice_volume_slider.value))


func _update_mute_button_texts() -> void:
	for mute_button: Button in _mute_buttons():
		mute_button.text = L10n.t(
			"title.audio_muted" if mute_button.button_pressed else "title.audio_mute"
		)


func _refresh_binding_labels() -> void:
	for action: StringName in InputBindingSettings.ACTIONS:
		keyboard_binding_buttons[action].text = InputBindingSettings.keyboard_label(action)
		gamepad_binding_buttons[action].text = InputBindingSettings.gamepad_label(action)
	if _capture_action.is_empty():
		binding_hint.text = L10n.t("title.input_remap_hint")
		return
	var target_button: Button = (
		gamepad_binding_buttons[_capture_action]
		if _capture_gamepad
		else keyboard_binding_buttons[_capture_action]
	)
	target_button.text = L10n.t(
		"title.input_press_button" if _capture_gamepad else "title.input_press_key"
	)
	binding_hint.text = L10n.t("title.input_remap_waiting")


func _mute_buttons() -> Array[Button]:
	return [
		master_mute_button,
		music_mute_button,
		sfx_mute_button,
		voice_mute_button,
	]


func is_portrait_layout() -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	return viewport_size.y > viewport_size.x


func _build_leaderboard() -> void:
	leaderboard_overlay = LEADERBOARD_OVERLAY_SCRIPT.new() as TitleLeaderboardOverlay
	add_child(leaderboard_overlay)
	leaderboard_overlay.configure_profile(combat_profile)
	leaderboard_overlay.closed.connect(_on_leaderboard_closed)
	if combat_profile != null:
		leaderboard_bridge = LEADERBOARD_BRIDGE_SCRIPT.new() as LeaderboardBridge
		leaderboard_bridge.name = "TitleLeaderboardBridge"
		add_child(leaderboard_bridge)
		leaderboard_bridge.setup(combat_profile, leaderboard_overlay)


func _apply_localized_text() -> void:
	(%TitleLabel as Label).text = L10n.t("title.command_heading")
	instruction_label.text = L10n.t(
		"title.deployment_authorized" if initialized else "title.command_hook"
	)
	instruction_label.autowrap_mode = (
		TextServer.AUTOWRAP_ARBITRARY
		if L10n.current_locale() == "zh-CN"
		else TextServer.AUTOWRAP_WORD_SMART
	)
	initialize_button.text = (
		L10n.t("title.deploying")
		if initialized
		else L10n.t("title.begin")
	)
	_refresh_control_copy()
	settings_button.text = L10n.t("title.settings")
	leaderboard_button.text = L10n.t("title.leaderboard")
	settings_heading.text = L10n.t("title.settings_heading")
	master_volume_label.text = L10n.t("title.master_volume")
	music_volume_label.text = L10n.t("title.music_volume")
	sfx_volume_label.text = L10n.t("title.sfx_volume")
	voice_volume_label.text = L10n.t("title.voice_volume")
	audio_volume_hint.text = L10n.t("title.audio_volume_hint")
	controls_heading.text = L10n.t("title.controls_settings_heading")
	move_left_binding_label.text = L10n.t("title.control_move_left")
	move_right_binding_label.text = L10n.t("title.control_move_right")
	smash_binding_label.text = L10n.t("title.control_smash")
	dodge_binding_label.text = L10n.t("title.control_dodge")
	controller_vibration_toggle.text = L10n.t("title.controller_vibration")
	reset_bindings_button.text = L10n.t("title.reset_bindings")
	settings_close_button.text = L10n.t("title.settings_close")
	_refresh_binding_labels()
	_update_audio_volume_values()
	_update_mute_button_texts()
	language_label.text = L10n.t("title.language")
	english_button.text = L10n.t("title.language_en")
	chinese_button.text = L10n.t("title.language_zh_cn")
	_sync_language_selector()
	status_label.text = L10n.t(
		"title.expedition_active" if initialized else "title.mission_briefing"
	)
	(%EnemyIntel as Label).text = L10n.t("title.enemy_intel")
	(%RunRule as Label).text = L10n.t("title.run_protocol")
	system_value.text = L10n.t("title.deploying" if initialized else "title.awaiting_pilot")
	($SemanticContract/PrimaryObjective as Label).text = L10n.t(
		"title.primary_objective"
	)
	($SemanticContract/ObjectiveOne as Label).text = L10n.t("title.objective_one")
	($SemanticContract/ObjectiveTwo as Label).text = L10n.t("title.objective_two")
	($SemanticContract/ObjectiveThree as Label).text = L10n.t("title.objective_three")
	if leaderboard_overlay != null:
		leaderboard_overlay.refresh_locale()


func _refresh_control_copy() -> void:
	var bindings: Dictionary = InputBindingSettings.display_placeholders()
	($SemanticContract/BriefingControlsLabel as Label).text = L10n.t(
		"title.controls_body",
		bindings
	)
	($SemanticContract/FieldNote as Label).text = L10n.t("title.field_note", bindings)


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if is_portrait_layout():
		_apply_portrait_layout(viewport_size)
	else:
		_apply_landscape_layout(viewport_size)
	if leaderboard_overlay != null:
		leaderboard_overlay.apply_responsive_layout(viewport_size)


func _apply_landscape_layout(viewport_size: Vector2) -> void:
	var vertical_offset: float = maxf(0.0, (viewport_size.y - 720.0) * 0.5)
	background_art.texture = LANDSCAPE_ART
	_set_rect(%TitleLabel, Rect2(52.0, 246.0 + vertical_offset, 680.0, 78.0))
	_set_rect(%InstructionLabel, Rect2(52.0, 326.0 + vertical_offset, 740.0, 145.0))
	_set_rect(initialize_button, Rect2(52.0, 480.0 + vertical_offset, 360.0, 80.0))
	_set_rect(language_selector, Rect2(52.0, 576.0 + vertical_offset, 282.0, 48.0))
	_set_rect(settings_button, Rect2(viewport_size.x - 212.0, 16.0, 196.0, 48.0))
	_set_rect(leaderboard_button, Rect2(viewport_size.x - 440.0, 16.0, 216.0, 48.0))
	_set_rect(
		settings_panel,
		Rect2(
			(viewport_size.x - 620.0) * 0.5,
			100.0 + vertical_offset,
			620.0,
			520.0
		)
	)
	_set_font_sizes(24, 56, 24)


func _apply_portrait_layout(viewport_size: Vector2) -> void:
	var horizontal_center: float = viewport_size.x * 0.5
	var vertical_offset: float = maxf(0.0, (viewport_size.y - 1280.0) * 0.5)
	background_art.texture = PORTRAIT_ART
	_set_rect(%TitleLabel, Rect2(horizontal_center - 304.0, 88.0, 608.0, 82.0))
	_set_rect(
		%InstructionLabel, Rect2(horizontal_center - 304.0, 174.0, 608.0, 160.0)
	)
	_set_rect(
		initialize_button,
		Rect2(horizontal_center - 256.0, 790.0 + vertical_offset, 512.0, 100.0)
	)
	_set_rect(
		language_selector,
		Rect2(horizontal_center - 186.0, 920.0 + vertical_offset, 372.0, 52.0)
	)
	_set_rect(settings_button, Rect2(viewport_size.x - 216.0, 20.0, 200.0, 56.0))
	_set_rect(leaderboard_button, Rect2(viewport_size.x - 448.0, 20.0, 216.0, 56.0))
	_set_rect(
		settings_panel,
		Rect2(
			horizontal_center - 306.0,
			300.0 + vertical_offset,
			612.0,
			610.0
		)
	)
	_set_font_sizes(24, 48, 24)

func _set_font_sizes(body_size: int, title_size: int, button_size: int) -> void:
	for label_node: Node in find_children("*", "Label", true, false):
		var label: Label = label_node as Label
		label.add_theme_font_size_override(&"font_size", body_size)
	(%TitleLabel as Label).add_theme_font_size_override(&"font_size", title_size)
	initialize_button.add_theme_font_size_override(&"font_size", button_size)
	settings_button.add_theme_font_size_override(&"font_size", body_size)
	leaderboard_button.add_theme_font_size_override(&"font_size", body_size)
	settings_close_button.add_theme_font_size_override(&"font_size", body_size)
	for mute_button: Button in _mute_buttons():
		mute_button.add_theme_font_size_override(&"font_size", body_size)
	for action: StringName in InputBindingSettings.ACTIONS:
		keyboard_binding_buttons[action].add_theme_font_size_override(&"font_size", body_size)
		gamepad_binding_buttons[action].add_theme_font_size_override(&"font_size", body_size)
	controller_vibration_toggle.add_theme_font_size_override(&"font_size", body_size)
	reset_bindings_button.add_theme_font_size_override(&"font_size", body_size)
	language_label.add_theme_font_size_override(&"font_size", body_size)
	english_button.add_theme_font_size_override(&"font_size", body_size)
	chinese_button.add_theme_font_size_override(&"font_size", body_size)


func _sync_language_selector() -> void:
	var chinese_selected: bool = L10n.current_locale() == "zh-CN"
	english_button.set_pressed_no_signal(not chinese_selected)
	chinese_button.set_pressed_no_signal(chinese_selected)


func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	control.set_deferred(&"position", rect.position)
	control.set_deferred(&"size", rect.size)


func _set_web_title_backdrop_active(active: bool) -> void:
	if not OS.has_feature("web"):
		return
	background_art.visible = not active
	get_viewport().transparent_bg = active
	RenderingServer.set_default_clear_color(
		Color(0.0, 0.0, 0.0, 0.0) if active else Color(0.008, 0.016, 0.035, 1.0)
	)
	JavaScriptBridge.eval(
		"window.protoScrollerSetTitleBackdropActive?.(%s);" % [str(active).to_lower()]
	)
