extends GutTest

const BASIC_TITLE_SCENE: PackedScene = preload(
	"res://scenes/template/basic_title.tscn"
)
const BASIC_HUD_SCENE: PackedScene = preload(
	"res://scenes/template/basic_hud.tscn"
)
const COMPACT_DEBRIEF_SCENE: PackedScene = preload(
	"res://scenes/template/compact_debrief.tscn"
)


func test_signal_glass_assets_are_runtime_safe() -> void:
	var textures: Array[Texture2D] = [
		CursorSystem.NAVIGATE_TEXTURE,
		CursorSystem.COMMAND_TEXTURE,
		CursorSystem.INSPECT_TEXTURE,
		CursorSystem.BLOCKED_TEXTURE,
	]
	for texture: Texture2D in textures:
		assert_not_null(texture)
		assert_eq(texture.get_size(), Vector2(64.0, 64.0))


func test_semantic_roles_map_to_distinct_native_cursor_channels() -> void:
	assert_eq(CursorSystem.shape_for_role(&"navigate"), Control.CURSOR_ARROW)
	assert_eq(CursorSystem.shape_for_role(&"command"), Control.CURSOR_POINTING_HAND)
	assert_eq(CursorSystem.shape_for_role(&"inspect"), Control.CURSOR_HELP)
	assert_eq(CursorSystem.shape_for_role(&"blocked"), Control.CURSOR_FORBIDDEN)
	assert_eq(CursorSystem.shape_for_role(&"unknown"), Control.CURSOR_ARROW)


func test_ui_screens_declare_command_and_inspect_roles() -> void:
	var title: BasicTitle = BASIC_TITLE_SCENE.instantiate() as BasicTitle
	var hud: BasicHud = BASIC_HUD_SCENE.instantiate() as BasicHud
	var debrief: CompactDebrief = COMPACT_DEBRIEF_SCENE.instantiate() as CompactDebrief
	add_child_autofree(title)
	add_child_autofree(hud)
	add_child_autofree(debrief)
	await get_tree().process_frame

	assert_eq(
		title.start_button.mouse_default_cursor_shape,
		Control.CURSOR_POINTING_HAND
	)
	assert_eq(
		debrief.retry_button.mouse_default_cursor_shape,
		Control.CURSOR_POINTING_HAND
	)
	assert_eq(
		debrief.title_button.mouse_default_cursor_shape,
		Control.CURSOR_POINTING_HAND
	)
	var telemetry: Array[Control] = [
		hud.stage_label,
		hud.status_label,
		hud.health_label,
		hud.health_bar,
		hud.wave_label,
		hud.score_label,
	]
	for control: Control in telemetry:
		assert_eq(control.mouse_default_cursor_shape, Control.CURSOR_HELP)
		assert_false(control.tooltip_text.is_empty())


func test_blocked_role_can_be_applied_to_unavailable_controls() -> void:
	var button: Button = Button.new()
	button.disabled = true
	CursorSystem.apply_role(button, &"blocked")
	assert_eq(button.mouse_default_cursor_shape, Control.CURSOR_FORBIDDEN)
	button.free()


func test_window_exit_and_focus_loss_release_custom_cursors() -> void:
	var cursor_system: CursorSystem = CursorSystem.new()
	cursor_system._custom_cursors_active = true
	cursor_system.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	assert_false(cursor_system._custom_cursors_active)
	assert_false(cursor_system._mouse_inside_window)

	cursor_system._custom_cursors_active = true
	cursor_system.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(cursor_system._custom_cursors_active)
	cursor_system.free()


func test_mouse_enter_tracks_window_reentry() -> void:
	var cursor_system: CursorSystem = CursorSystem.new()
	cursor_system._mouse_inside_window = false
	cursor_system.notification(Node.NOTIFICATION_WM_MOUSE_ENTER)
	assert_true(cursor_system._mouse_inside_window)
	cursor_system.free()
