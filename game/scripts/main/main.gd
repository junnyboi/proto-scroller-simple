class_name Main
extends Node

const TITLE_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const RUNTIME_TWEAK_PANEL_SCENE: PackedScene = preload(
	"res://scenes/ui/runtime_tweak_panel.tscn"
)
const RESPONSIVE_VIEWPORT_SCRIPT: Script = preload(
	"res://scripts/main/responsive_viewport.gd"
)
const TRANSITION_BOOM_SFX: AudioStream = preload(
	"res://audio/sfx/ui/transition_full_black_boom.wav"
)
const CAMPAIGN_PROGRESS_SCRIPT: Script = preload(
	"res://scripts/narrative/campaign_progress_store.gd"
)
const COMBAT_PROFILE_SCRIPT: Script = preload(
	"res://scripts/rampage/player_combat_profile_store.gd"
)
const RUNTIME_TWEAK_SERVICE_SCRIPT: Script = preload(
	"res://scripts/tuning/runtime_tweak_service.gd"
)
const RUNTIME_AUDIO_TUNING_SCRIPT: Script = preload(
	"res://scripts/audio/runtime_audio_tuning.gd"
)
const TEMPLATE_MAIN_SCENE: PackedScene = preload(
	"res://scenes/template/template_main.tscn"
)
const DUMMY_AUDIO_DRIVER_NAME: String = "Dummy"
const FADE_TO_BLACK_SECONDS: float = 0.45
const FADE_FROM_BLACK_SECONDS: float = 0.35
const TITLE_IMPACT_HOLD_SECONDS: float = 0.35
const TITLE_PREWARM_POSITION_SECONDS: float = 0.5
const TITLE_SYNC_FALLBACK_SECONDS: float = 10.0
const GAMEPLAY_SETTINGS_LAYER: int = 90
const GAMEPLAY_SETTINGS_PAUSE_REASON: StringName = &"settings_dialog"

var title_screen: TitleScreen
var city_slice: CitySlice
var responsive_viewport: ResponsiveViewport
var campaign_progress: CampaignProgressStore
var combat_profile: PlayerCombatProfileStore
var runtime_tweak_service: RuntimeTweakService
var runtime_audio_tuning: RuntimeAudioTuning
var runtime_tweak_layer: CanvasLayer
var runtime_tweak_panel: RuntimeTweakPanel
var gameplay_settings_layer: CanvasLayer
var gameplay_settings_screen: TitleScreen
var template_runtime: TemplateMain
var forced_next_run_seed: int = -1
var forced_next_district_index: int = -1
var title_transition_active: bool = false
var title_transition_duration_scale: float = 1.0
var transition_kind: StringName = &"idle"
var transition_boom_play_count: int = 0
var transition_boom_last_alpha: float = -1.0
var _last_tuned_transition_duration_scale: float = 1.0
var title_music_restart_count: int = 0
var _title_transition_started_msec: int = 0
var _transition_sequence_id: int = 0
var _title_music_sync_pending: bool = false
var _title_music_committed: bool = false
var _title_music_commit_msec: int = 0
var _title_web_window: JavaScriptObject = null
var _title_music_commit_callback: JavaScriptObject = null
var _title_music_calibration_callback: JavaScriptObject = null
var _gameplay_settings_pause_token: int = 0
var _settings_robot_physics_was_enabled: bool = true
var _settings_mobile_controls_were_enabled: bool = true
@onready var background_music_player: AudioStreamPlayer = %BackgroundMusicPlayer
@onready var transition_boom_player: AudioStreamPlayer = %TransitionBoomPlayer
@onready var transition_overlay: ColorRect = %TransitionOverlay


func _ready() -> void:
	if TemplateRuntimeSelector.requested():
		template_runtime = TEMPLATE_MAIN_SCENE.instantiate() as TemplateMain
		add_child(template_runtime)
		return
	InputBindingSettings.apply_saved()
	AudioVolumeSettings.apply_saved()
	combat_profile = COMBAT_PROFILE_SCRIPT.new() as PlayerCombatProfileStore
	combat_profile.name = "PlayerCombatProfileStore"
	add_child(combat_profile)
	combat_profile.setup()
	campaign_progress = CAMPAIGN_PROGRESS_SCRIPT.new() as CampaignProgressStore
	campaign_progress.name = "CampaignProgressStore"
	add_child(campaign_progress)
	campaign_progress.setup()
	responsive_viewport = RESPONSIVE_VIEWPORT_SCRIPT.new() as ResponsiveViewport
	responsive_viewport.name = "ResponsiveViewport"
	add_child(responsive_viewport)
	responsive_viewport.setup()
	runtime_tweak_service = RUNTIME_TWEAK_SERVICE_SCRIPT.new() as RuntimeTweakService
	runtime_tweak_service.name = "RuntimeTweakService"
	add_child(runtime_tweak_service)
	var tuning_errors: PackedStringArray = runtime_tweak_service.setup()
	assert(tuning_errors.is_empty(), "Runtime tuning setup failed: %s" % [tuning_errors])
	runtime_audio_tuning = RUNTIME_AUDIO_TUNING_SCRIPT.new() as RuntimeAudioTuning
	add_child(runtime_audio_tuning)
	runtime_tweak_layer = CanvasLayer.new()
	runtime_tweak_layer.name = "RuntimeTweakLayer"
	runtime_tweak_layer.layer = 200
	add_child(runtime_tweak_layer)
	runtime_tweak_panel = RUNTIME_TWEAK_PANEL_SCENE.instantiate() as RuntimeTweakPanel
	runtime_tweak_layer.add_child(runtime_tweak_panel)
	runtime_tweak_panel.configure(self, runtime_tweak_service)
	_show_title()
	_publish_title_transition_phase("idle")
	if not background_music_player.tree_exiting.is_connected(_release_background_music):
		background_music_player.tree_exiting.connect(_release_background_music)


func _exit_tree() -> void:
	_release_gameplay_settings_pause()
	_cancel_title_music_sync("main-exit")
	_release_background_music()


func _unhandled_input(event: InputEvent) -> void:
	if template_runtime != null:
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if gameplay_settings_screen != null and gameplay_settings_screen.settings_open:
		return
	if open_gameplay_settings():
		get_viewport().set_input_as_handled()


func _release_background_music() -> void:
	if not is_instance_valid(background_music_player):
		return
	background_music_player.stop()
	background_music_player.stream = null
	_title_web_window = null
	_title_music_commit_callback = null
	_title_music_calibration_callback = null


func background_music_output_available() -> bool:
	return _background_music_output_available_for_environment(
		AudioServer.get_driver_name(),
		OS.has_feature("web")
	)


func _background_music_output_available_for_environment(
	driver_name: String,
	is_web: bool
) -> bool:
	return is_web or driver_name != DUMMY_AUDIO_DRIVER_NAME


func _start_background_music() -> void:
	_start_background_music_for_environment(OS.has_feature("web"))


func _start_background_music_for_environment(is_web: bool) -> void:
	if not _background_music_output_available_for_environment(
		AudioServer.get_driver_name(),
		is_web
	):
		return
	if background_music_player.stream != null and not background_music_player.playing:
		background_music_player.play(0.0)


func _begin_title_music_sync() -> bool:
	if not OS.has_feature("web"):
		_start_background_music()
		_title_music_committed = background_music_player.playing
		_title_music_commit_msec = Time.get_ticks_msec()
		return false
	if _title_music_sync_pending or _title_music_committed:
		return _title_music_sync_pending
	if not background_music_output_available() or background_music_player.stream == null:
		return false
	_title_music_sync_pending = true
	_title_music_commit_msec = 0
	_title_music_commit_callback = JavaScriptBridge.create_callback(
		_on_title_music_commit_callback
	)
	_title_music_calibration_callback = JavaScriptBridge.create_callback(
		_on_title_music_calibration_callback
	)
	_title_web_window = JavaScriptBridge.get_interface("window")
	if _title_web_window == null:
		_commit_title_music_fallback("scheduler-unavailable")
		return false
	var accepted: bool = bool(_title_web_window.protoScrollerScheduleTitleBeatCommit(
		_title_music_commit_callback,
		_title_music_calibration_callback
	))
	if not accepted:
		_commit_title_music_fallback("scheduler-rejected")
	return accepted


func _on_title_music_calibration_callback(arguments: Array) -> void:
	if not _title_music_sync_pending or arguments.is_empty():
		return
	var phase: String = str(arguments[0])
	if phase == "prewarm":
		_prewarm_title_music_decoder()
	elif phase == "scheduled" and arguments.size() >= 2:
		var seconds_until_rendered: float = clampf(float(arguments[1]), 0.0, 1.0)
		_title_music_commit_msec = (
			Time.get_ticks_msec() + int(seconds_until_rendered * 1000.0)
		)


func _prewarm_title_music_decoder() -> void:
	if background_music_player.stream == null or background_music_player.playing:
		_mark_title_music_prewarm("restored")
		return
	var music_bus_index: int = AudioServer.get_bus_index(background_music_player.bus)
	var was_muted: bool = AudioServer.is_bus_mute(music_bus_index)
	AudioServer.set_bus_mute(music_bus_index, true)
	background_music_player.play(TITLE_PREWARM_POSITION_SECONDS)
	background_music_player.stop()
	AudioServer.set_bus_mute(music_bus_index, was_muted)
	_mark_title_music_prewarm("restored")


func _mark_title_music_prewarm(status: String) -> void:
	if not OS.has_feature("web"):
		return
	if _title_web_window == null:
		_title_web_window = JavaScriptBridge.get_interface("window")
	if _title_web_window != null:
		_title_web_window.protoScrollerMarkTitleMusicPrewarm(status)


func _on_title_music_commit_callback(_arguments: Array) -> void:
	if not _title_music_sync_pending or _title_music_committed:
		return
	# The production non-silent start occurs only inside the browser scheduler callback.
	background_music_player.play(0.0)
	_title_music_sync_pending = false
	_title_music_committed = true
	if _title_music_commit_msec <= Time.get_ticks_msec():
		_title_music_commit_msec = Time.get_ticks_msec()


func _commit_title_music_fallback(_reason: String) -> void:
	if _title_music_committed:
		return
	_start_background_music()
	_title_music_sync_pending = false
	_title_music_committed = background_music_player.playing
	_title_music_commit_msec = Time.get_ticks_msec()


func _cancel_title_music_sync(reason: String) -> void:
	if OS.has_feature("web"):
		if _title_web_window == null:
			_title_web_window = JavaScriptBridge.get_interface("window")
		if _title_web_window != null:
			_title_web_window.protoScrollerCancelTitleBeatCommit(reason)
	_title_music_sync_pending = false
	_title_music_commit_callback = null
	_title_music_calibration_callback = null


func _title_sync_fallback_delay_seconds() -> float:
	return TITLE_SYNC_FALLBACK_SECONDS


func _activate_title_music_from_interaction() -> void:
	if OS.has_feature("web") and background_music_player.playing:
		if _title_web_window == null:
			_title_web_window = JavaScriptBridge.get_interface("window")
		if _title_web_window != null:
			_title_web_window.protoScrollerResumeTitleAudio()
		_title_music_sync_pending = false
		_title_music_committed = true
		_title_music_commit_msec = Time.get_ticks_msec()
		return
	_begin_title_music_sync()


func start_game() -> void:
	_start_background_music()
	_cancel_title_music_sync("title-exit")
	if city_slice != null:
		return
	if title_screen != null:
		title_screen.queue_free()
		title_screen = null
	_spawn_city_slice()


func start_game_with_transition() -> void:
	if city_slice != null or title_transition_active:
		return
	_begin_title_music_sync()
	if OS.has_feature("web"):
		var deadline_msec: int = Time.get_ticks_msec() + int(
			_title_sync_fallback_delay_seconds() * 1000.0
		)
		while not _title_music_committed and Time.get_ticks_msec() < deadline_msec:
			await get_tree().process_frame
		if not _title_music_committed:
			_commit_title_music_fallback("godot-timeout")
		else:
			await get_tree().process_frame
		var visible_until_msec: int = _title_music_commit_msec + int(
			TITLE_IMPACT_HOLD_SECONDS * 1000.0
		)
		while Time.get_ticks_msec() < visible_until_msec:
			await get_tree().process_frame
	await _run_full_black_transition(&"start_game", start_game)


func present_defeat_with_transition() -> void:
	if city_slice == null or city_slice.game_over_active or title_transition_active:
		return
	await _run_full_black_transition(&"defeat", city_slice.present_defeat)


func return_to_title_with_transition() -> void:
	if city_slice == null or title_screen != null or title_transition_active:
		return
	_cancel_title_music_sync("return-to-title")
	await _run_full_black_transition(&"return_title", _return_to_title)


func _run_full_black_transition(kind: StringName, swap_action: Callable) -> void:
	title_transition_active = true
	transition_kind = kind
	_transition_sequence_id += 1
	_title_transition_started_msec = Time.get_ticks_msec()
	transition_overlay.visible = true
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_overlay.modulate.a = 0.0
	_publish_title_transition_phase("fade_out")
	await _fade_transition_overlay(1.0, FADE_TO_BLACK_SECONDS)
	_play_transition_boom()
	_publish_title_transition_phase("black")
	swap_action.call()
	await get_tree().process_frame
	_publish_title_transition_phase("black_ready")
	await _await_web_transition_capture_release()
	_publish_title_transition_phase("fade_in")
	await _fade_transition_overlay(0.0, FADE_FROM_BLACK_SECONDS)
	transition_overlay.visible = false
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_transition_active = false
	_publish_title_transition_phase("complete")


func retry_game() -> void:
	if city_slice != null:
		_teardown_gameplay_settings()
		forced_next_district_index = (
			city_slice.world_stream.unlocked_district_index
			if city_slice.world_stream != null
			else 0
		)
		if runtime_tweak_service != null:
			runtime_tweak_service.end_run()
		var previous_city: CitySlice = city_slice
		city_slice = null
		remove_child(previous_city)
		previous_city.queue_free()
		_spawn_city_slice()


func retry_game_with_tuning_seed(seed: int) -> void:
	forced_next_run_seed = maxi(seed, 0)
	if runtime_tweak_service != null:
		runtime_tweak_service.mark_next_run_sandbox(&"restart_seed")
	retry_game()


func _return_to_title() -> void:
	if city_slice != null:
		_teardown_gameplay_settings()
		if runtime_tweak_service != null:
			runtime_tweak_service.end_run()
		var previous_city: CitySlice = city_slice
		city_slice = null
		remove_child(previous_city)
		previous_city.queue_free()
	_show_title(true)


func _spawn_city_slice() -> void:
	city_slice = CITY_SCENE.instantiate() as CitySlice
	city_slice.name = "CitySlice"
	var run_seed: int = forced_next_run_seed
	if run_seed < 0:
		run_seed = CityWorldBuilder.initial_run_seed(
			city_slice._web_gameplay_smoke_requested()
		)
	forced_next_run_seed = -1
	city_slice.launch_run_seed = run_seed
	city_slice.launch_district_index = maxi(forced_next_district_index, 0)
	forced_next_district_index = -1
	if runtime_tweak_service != null:
		runtime_tweak_service.freeze_run(run_seed)
		var tuned_transition_scale: float = float(runtime_tweak_service.run_value(
			&"interface.title_transition_duration_scale",
			1.0
		))
		if is_equal_approx(
			title_transition_duration_scale,
			_last_tuned_transition_duration_scale
		):
			title_transition_duration_scale = tuned_transition_scale
		_last_tuned_transition_duration_scale = tuned_transition_scale
	city_slice.campaign_progress = campaign_progress
	city_slice.combat_profile = combat_profile
	city_slice.retry_requested.connect(retry_game)
	city_slice.defeat_requested.connect(present_defeat_with_transition)
	city_slice.title_requested.connect(return_to_title_with_transition)
	add_child(city_slice)
	city_slice.gameplay_hud.tweak_controls_requested.connect(
		runtime_tweak_panel.open
	)
	if runtime_tweak_service != null:
		runtime_tweak_service.bind_city(city_slice)
		city_slice.gameplay_hud.bind_runtime_tweak_service(runtime_tweak_service)


func open_gameplay_settings() -> bool:
	if (
		city_slice == null
		or city_slice.game_over_active
		or title_transition_active
		or city_slice.urban_siege == null
		or city_slice.urban_siege.pause_coordinator == null
		or city_slice.urban_siege.pause_coordinator.is_paused()
	):
		return false
	_ensure_gameplay_settings()
	if gameplay_settings_screen == null or gameplay_settings_screen.settings_open:
		return false
	var coordinator: RunPauseCoordinator = city_slice.urban_siege.pause_coordinator
	_gameplay_settings_pause_token = coordinator.acquire(
		GAMEPLAY_SETTINGS_PAUSE_REASON
	)
	if _gameplay_settings_pause_token == 0:
		return false
	_settings_robot_physics_was_enabled = city_slice.robot.is_physics_processing()
	_settings_mobile_controls_were_enabled = (
		city_slice.mobile_controls.controls_enabled()
	)
	city_slice.robot.set_virtual_move_axis(0.0)
	city_slice.robot.set_physics_process(false)
	city_slice.mobile_controls.set_controls_enabled(false)
	if gameplay_settings_screen.open_settings():
		return true
	_release_gameplay_settings_pause()
	return false


func close_gameplay_settings() -> bool:
	if gameplay_settings_screen == null:
		return false
	return gameplay_settings_screen.close_settings(false)


func gameplay_settings_open() -> bool:
	return (
		gameplay_settings_screen != null
		and gameplay_settings_screen.settings_open
	)


func _ensure_gameplay_settings() -> void:
	if gameplay_settings_layer != null:
		return
	gameplay_settings_layer = CanvasLayer.new()
	gameplay_settings_layer.name = "GameplaySettingsLayer"
	gameplay_settings_layer.layer = GAMEPLAY_SETTINGS_LAYER
	gameplay_settings_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(gameplay_settings_layer)
	gameplay_settings_screen = TITLE_SCENE.instantiate() as TitleScreen
	gameplay_settings_screen.name = "GameplaySettingsScreen"
	gameplay_settings_screen.configure_settings_only()
	gameplay_settings_screen.settings_closed.connect(
		_on_gameplay_settings_closed
	)
	gameplay_settings_layer.add_child(gameplay_settings_screen)


func _on_gameplay_settings_closed() -> void:
	_release_gameplay_settings_pause()


func _release_gameplay_settings_pause() -> void:
	if city_slice == null or _gameplay_settings_pause_token == 0:
		_gameplay_settings_pause_token = 0
		return
	var coordinator: RunPauseCoordinator = null
	if (
		city_slice.urban_siege != null
		and city_slice.urban_siege.pause_coordinator != null
	):
		coordinator = city_slice.urban_siege.pause_coordinator
		coordinator.release(_gameplay_settings_pause_token)
	_gameplay_settings_pause_token = 0
	if coordinator != null and coordinator.is_paused():
		return
	if city_slice.robot != null:
		city_slice.robot.set_physics_process(
			_settings_robot_physics_was_enabled
		)
	if city_slice.mobile_controls != null:
		city_slice.mobile_controls.set_controls_enabled(
			_settings_mobile_controls_were_enabled
		)


func _teardown_gameplay_settings() -> void:
	if gameplay_settings_screen != null and gameplay_settings_screen.settings_open:
		gameplay_settings_screen.close_settings(false)
	else:
		_release_gameplay_settings_pause()
	if gameplay_settings_layer != null:
		gameplay_settings_layer.queue_free()
	gameplay_settings_layer = null
	gameplay_settings_screen = null


func _show_title(restart_music: bool = false) -> void:
	_cancel_title_music_sync("show-title")
	if restart_music:
		_restart_title_music_for_environment(OS.has_feature("web"))
	else:
		var music_was_playing: bool = background_music_player.playing
		_start_background_music()
		_title_music_committed = music_was_playing or (
			not OS.has_feature("web") and background_music_player.playing
		)
	title_screen = TITLE_SCENE.instantiate() as TitleScreen
	title_screen.configure_leaderboard(combat_profile)
	title_screen.audio_activation_requested.connect(
		_activate_title_music_from_interaction
	)
	title_screen.start_requested.connect(start_game_with_transition)
	add_child(title_screen)


func _restart_title_music_for_environment(is_web: bool) -> void:
	background_music_player.stop()
	_title_music_committed = false
	_title_music_commit_msec = 0
	if is_web:
		if _title_web_window == null:
			_title_web_window = JavaScriptBridge.get_interface("window")
		if _title_web_window != null:
			_title_web_window.protoScrollerResumeTitleAudio()
	_start_background_music_for_environment(is_web)
	_title_music_committed = background_music_player.playing
	_title_music_commit_msec = Time.get_ticks_msec()
	title_music_restart_count += 1


func _play_transition_boom() -> void:
	transition_boom_last_alpha = transition_overlay.modulate.a
	transition_boom_player.stop()
	transition_boom_player.play()
	transition_boom_play_count += 1


func _fade_transition_overlay(target_alpha: float, duration_seconds: float) -> void:
	var scaled_duration: float = maxf(
		duration_seconds * title_transition_duration_scale,
		0.001
	)
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(transition_overlay, "modulate:a", target_alpha, scaled_duration)
	await tween.finished


func _await_web_transition_capture_release() -> void:
	if not OS.has_feature("web"):
		return
	while bool(JavaScriptBridge.eval("Boolean(window.__PROTO_SCROLLER_HOLD_TITLE_TRANSITION__)")):
		await get_tree().process_frame


func _publish_title_transition_phase(phase: String) -> void:
	if not OS.has_feature("web"):
		return
	var elapsed_msec: int = (
		0
		if _title_transition_started_msec == 0
		else Time.get_ticks_msec() - _title_transition_started_msec
	)
	var payload: String = JSON.stringify({
		"boomCount": transition_boom_play_count,
		"elapsedMs": elapsed_msec,
		"kind": String(transition_kind),
		"overlayAlpha": transition_overlay.modulate.a,
		"phase": phase,
		"sequenceId": _transition_sequence_id,
	})
	JavaScriptBridge.eval(
		"window.__PROTO_SCROLLER_TITLE_TRANSITION__ ??= {phases: [], history: []};"
		+ "const t = window.__PROTO_SCROLLER_TITLE_TRANSITION__;"
		+ "const p = %s;" % payload
		+ "if (t.sequenceId !== p.sequenceId) t.phases = [];"
		+ "Object.assign(t, p);"
		+ "t.phases.push(p);"
		+ "t.history.push(p);"
	)
