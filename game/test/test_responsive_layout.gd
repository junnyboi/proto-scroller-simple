extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TITLE_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const BREACH: DirectiveProfile = preload(
	"res://resources/directives/demolition_breach.tres"
)
const PORTRAIT_SIZE: Vector2i = Vector2i(720, 1280)
const LANDSCAPE_SIZE: Vector2i = Vector2i(1280, 720)
const ULTRAWIDE_SIZE: Vector2i = Vector2i(2048, 825)


func after_each() -> void:
	_set_viewport(LANDSCAPE_SIZE)
	await get_tree().process_frame


func test_orientation_manager_expands_design_size_without_distortion() -> void:
	var responsive: ResponsiveViewport = ResponsiveViewport.new()
	add_child_autofree(responsive)
	responsive.setup()
	responsive.apply_window_size(PORTRAIT_SIZE)
	assert_true(responsive.portrait_mode)
	assert_eq(responsive.design_size, PORTRAIT_SIZE)
	assert_eq(get_window().content_scale_size, PORTRAIT_SIZE)
	assert_eq(get_window().content_scale_aspect, Window.CONTENT_SCALE_ASPECT_EXPAND)
	responsive.apply_window_size(LANDSCAPE_SIZE)
	assert_false(responsive.portrait_mode)
	assert_eq(responsive.design_size, LANDSCAPE_SIZE)
	assert_eq(get_window().content_scale_size, LANDSCAPE_SIZE)
	responsive.apply_window_size(ULTRAWIDE_SIZE)
	assert_eq(responsive.design_size, LANDSCAPE_SIZE)
	assert_eq(get_window().content_scale_size, LANDSCAPE_SIZE)
	assert_eq(get_window().content_scale_aspect, Window.CONTENT_SCALE_ASPECT_EXPAND)


func test_ultrawide_layout_uses_full_available_width() -> void:
	var screen: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._apply_landscape_layout(Vector2(ULTRAWIDE_SIZE))
	assert_eq((screen.get_node("%SettingsButton") as Control).get_rect().end.x, 2032.0)
	assert_eq((screen.get_node("%BriefingToggle") as Control).get_rect().end.x, 2016.0)
	assert_eq((screen.get_node("%SettingsPanel") as Control).position.x, 714.0)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.gameplay_hud._apply_landscape_layout(Vector2(ULTRAWIDE_SIZE))
	assert_eq(city.gameplay_hud.score_panel.get_rect().end.x, 2024.0)
	assert_eq(city.gameplay_hud.momentum_panel.position.x, 774.0)
	assert_eq(city.gameplay_hud.terminal_panel.position.x, 699.0)


func test_title_reflows_inside_portrait_and_returns_to_landscape() -> void:
	_set_viewport(PORTRAIT_SIZE)
	var screen: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(screen.is_portrait_layout())
	var background: TextureRect = screen.get_node("%BackgroundArt") as TextureRect
	var instruction_label: Label = screen.get_node("%InstructionLabel") as Label
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	var briefing_toggle: Button = screen.get_node("%BriefingToggle") as Button
	var settings_button: Button = screen.get_node("%SettingsButton") as Button
	var settings_panel: PanelContainer = screen.get_node("%SettingsPanel") as PanelContainer
	assert_eq(background.texture.resource_path, "res://art/ui/title_screen/command_deck_portrait.jpg")
	assert_true(_inside_viewport(background, PORTRAIT_SIZE))
	assert_true(_inside_viewport(screen.get_node("%TitleLabel") as Control, PORTRAIT_SIZE))
	assert_eq(instruction_label.get_visible_line_count(), instruction_label.get_line_count())
	assert_null(screen.get_node_or_null("StatusRail"))
	assert_null(screen.get_node_or_null("%ControlsLabel"))
	assert_true(_inside_viewport(initialize_button, PORTRAIT_SIZE))
	assert_true(_inside_viewport(briefing_toggle, PORTRAIT_SIZE))
	assert_true(_inside_viewport(settings_button, PORTRAIT_SIZE))
	assert_eq(settings_button.position, Vector2(504.0, 20.0))
	assert_eq(settings_button.get_rect().end.x, 704.0)
	assert_true(
		_inside_viewport(settings_panel, PORTRAIT_SIZE),
		"Portrait settings panel escaped viewport: %s" % settings_panel.get_global_rect()
	)
	for control_name: StringName in [
		&"MasterVolumeSlider",
		&"MusicVolumeSlider",
		&"SfxVolumeSlider",
		&"VoiceVolumeSlider",
		&"MasterMuteButton",
		&"MusicMuteButton",
		&"SfxMuteButton",
		&"VoiceMuteButton",
	]:
		assert_true(
			settings_panel.get_global_rect().encloses(
				(screen.get_node("%%%s" % control_name) as Control).get_global_rect()
			),
			"Portrait %s escaped the settings panel." % control_name
		)
	assert_false(
		initialize_button.get_global_rect().intersects(briefing_toggle.get_global_rect())
	)
	assert_gte(
		(screen.get_node("%LanguageSelector") as Control).position.y,
		initialize_button.get_rect().end.y + 16.0
	)
	_set_viewport(LANDSCAPE_SIZE)
	await get_tree().process_frame
	assert_false(screen.is_portrait_layout())
	assert_null(screen.get_node_or_null("StatusRail"))
	assert_eq(instruction_label.get_visible_line_count(), instruction_label.get_line_count())
	assert_eq(background.texture.resource_path, "res://art/ui/title_screen/command_deck_landscape.jpg")
	assert_true(_inside_viewport(briefing_toggle, LANDSCAPE_SIZE))
	assert_true(_inside_viewport(settings_button, LANDSCAPE_SIZE))
	assert_eq(settings_button.position, Vector2(1068.0, 16.0))
	assert_eq(settings_button.get_rect().end.x, 1264.0)
	assert_true(
		_inside_viewport(settings_panel, LANDSCAPE_SIZE),
		"Landscape settings panel escaped viewport: %s" % settings_panel.get_global_rect()
	)
	for control_name: StringName in [
		&"MasterVolumeSlider",
		&"MusicVolumeSlider",
		&"SfxVolumeSlider",
		&"VoiceVolumeSlider",
		&"MasterMuteButton",
		&"MusicMuteButton",
		&"SfxMuteButton",
		&"VoiceMuteButton",
	]:
		assert_true(
			settings_panel.get_global_rect().encloses(
				(screen.get_node("%%%s" % control_name) as Control).get_global_rect()
			),
			"Landscape %s escaped the settings panel." % control_name
		)


func test_city_portrait_hud_camera_and_mobile_controls_use_safe_zones() -> void:
	_set_viewport(PORTRAIT_SIZE)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	await get_tree().physics_frame
	var camera_rig: CameraRig = city.get_node("CameraRig") as CameraRig
	assert_true(camera_rig.is_portrait_framing())
	assert_gte(camera_rig.visible_world_size().x, 479.0)
	assert_gte(camera_rig.visible_world_size().y, 853.0)
	assert_eq(city.gameplay_hud.status_panel.position, Vector2.ZERO)
	assert_eq(city.gameplay_hud.status_panel.size, Vector2(300.0, 48.0))
	assert_lte(city.gameplay_hud.score_panel.get_rect().end.y, 172.0)
	assert_null(city.gameplay_hud.get_node_or_null(^"DodgeCooldownIndicator"))
	var hud_footprint: Rect2 = Rect2(Vector2.ZERO, Vector2(300.0, 172.0))
	assert_lt(
		hud_footprint.get_area() / (float(PORTRAIT_SIZE.x) * float(PORTRAIT_SIZE.y)),
		0.08
	)
	assert_eq(city.gameplay_hud.siege_progress.segments.size(), 6)
	assert_true(_inside_viewport(city.gameplay_hud.status_panel, PORTRAIT_SIZE))
	assert_true(_inside_viewport(city.gameplay_hud.score_panel, PORTRAIT_SIZE))
	assert_true(_inside_viewport(city.gameplay_hud.directive_card, PORTRAIT_SIZE))
	city.gameplay_hud.show_directive(
		BREACH,
		1,
		BREACH.target_count,
		25,
		city.urban_siege.directives
	)
	var directive_card: DirectiveCard = city.gameplay_hud.directive_card
	var card_bounds: Rect2 = Rect2(Vector2.ZERO, directive_card.size)
	for control: Control in [
		directive_card.title_label,
		directive_card.timer_label,
		directive_card.detail_label,
		directive_card.progress_label,
		directive_card.bank_label,
		directive_card.progress_track,
		directive_card.timer_track,
	]:
		assert_true(card_bounds.encloses(control.get_rect()), control.name)
	assert_true(_inside_viewport(city.mobile_controls.smash_button, PORTRAIT_SIZE))
	assert_true(_inside_viewport(city.mobile_controls.dash_button, PORTRAIT_SIZE))
	assert_false(
		city.mobile_controls.dash_bounds().intersects(
			city.mobile_controls.smash_bounds()
		)
	)
	assert_false(
		city.gameplay_hud.directive_card.get_global_rect().intersects(
			city.mobile_controls.smash_bounds()
		)
	)
	assert_false(
		city.gameplay_hud.directive_card.get_global_rect().intersects(
			city.mobile_controls.dash_bounds()
		)
	)
	city.encounter_runtime.release_all()
	var helicopter: HelicopterEnemy = city.encounter_runtime.acquire(
		&"helicopter",
		Vector2(city.robot.global_position.x, 180.0)
	) as HelicopterEnemy
	assert_not_null(helicopter)
	assert_eq(helicopter.effective_standoff_x(), 280.0)
	var visible_world: Vector2 = camera_rig.visible_world_size()
	var world_view: Rect2 = Rect2(
		camera_rig.global_position - visible_world * 0.5,
		visible_world
	)
	assert_true(world_view.has_point(helicopter.global_position))
	var screen_scale: Vector2 = Vector2(PORTRAIT_SIZE) / visible_world
	var helicopter_screen_position: Vector2 = (
		helicopter.global_position - world_view.position
	) * screen_scale
	assert_false(hud_footprint.has_point(helicopter_screen_position))
	assert_eq(city.gameplay_hud.directive_choice_overlay.buttons.size(), 3)
	for button: Button in city.gameplay_hud.directive_choice_overlay.buttons:
		assert_true(_inside_viewport(button, PORTRAIT_SIZE))


func test_landscape_hud_excludes_visual_dodge_cooldown_indicator() -> void:
	_set_viewport(LANDSCAPE_SIZE)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	assert_null(city.gameplay_hud.get_node_or_null(^"DodgeCooldownIndicator"))


func test_resize_preserves_touch_ownership_and_runtime_node_count() -> void:
	_set_viewport(LANDSCAPE_SIZE)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	var controls: MobileControls = city.mobile_controls
	controls.handle_touch_input(_screen_touch(3, Vector2(220.0, 520.0), true))
	var smash_position: Vector2 = controls.smash_bounds().get_center()
	controls.handle_touch_input(_screen_touch(8, smash_position, true))
	var dash_position: Vector2 = controls.dash_bounds().get_center()
	controls.handle_touch_input(_screen_touch(9, dash_position, true))
	var node_count: int = RuntimeBudget.snapshot(city).node_count
	_set_viewport(PORTRAIT_SIZE)
	await get_tree().process_frame
	assert_eq(controls.joystick_touch_index(), 3)
	assert_eq(controls.smash_touch_index(), 8)
	assert_eq(controls.dash_touch_index(), 9)
	assert_true(controls.joystick_active)
	assert_eq(RuntimeBudget.snapshot(city).node_count, node_count)
	_set_viewport(LANDSCAPE_SIZE)
	await get_tree().process_frame
	assert_eq(controls.joystick_touch_index(), 3)
	assert_eq(controls.smash_touch_index(), 8)
	assert_eq(controls.dash_touch_index(), 9)
	assert_eq(RuntimeBudget.snapshot(city).node_count, node_count)
	controls.handle_touch_input(_screen_touch(9, controls.dash_bounds().get_center(), false))
	controls.handle_touch_input(_screen_touch(8, controls.smash_bounds().get_center(), false))
	controls.handle_touch_input(_screen_touch(3, Vector2(220.0, 520.0), false))


func _inside_viewport(control: Control, viewport_size: Vector2) -> bool:
	return Rect2(Vector2.ZERO, viewport_size).encloses(control.get_global_rect())


func _set_viewport(viewport_size: Vector2i) -> void:
	get_window().content_scale_size = viewport_size
	get_tree().root.size = viewport_size


func _screen_touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event
