class_name MobileControls
extends Control

signal move_axis_changed(axis: float)
signal move_direction_tapped(direction: int)
signal smash_pressed
signal smash_released
signal dash_pressed(direction: int)

const JOYSTICK_RADIUS: float = 78.0
const KNOB_RADIUS: float = 34.0
const EDGE_PADDING: float = 14.0
const DASH_READY_IDLE_PERIOD: float = 1.40
const DASH_READY_BURST_DURATION: float = 0.90
const DASH_READY_BURST_CYCLES: float = 3.0

@export_range(-1, 1, 1) var detection_override: int = -1
@export_range(0.0, 0.5, 0.01) var deadzone: float = 0.14
@export_range(1.0, 30.0, 0.5) var response_speed: float = 18.0
@export_range(0.1, 1.0, 0.05) var smash_cooldown: float = 0.40

var mobile_device_detected: bool = false
var joystick_active: bool = false
var smash_button: Button
var dash_button: Button
var smash_press_count: int = 0
var smash_release_count: int = 0
var dash_press_count: int = 0
var robot: GiantRobotController
var _controls_enabled: bool = true
var _joystick_touch_index: int = -1
var _smash_touch_index: int = -1
var _dash_touch_index: int = -1
var _touch_anchor: Vector2
var _joystick_origin: Vector2
var _knob_offset: Vector2
var _target_axis: float = 0.0
var _current_axis: float = 0.0
var _smash_cooldown_remaining: float = 0.0
var _preserve_touch_ownership_while_disabled: bool = false
var _smash_press_accepted: bool = false
var _pending_smash_release: bool = false
var _dash_ready_feedback: bool = true
var _dash_ready_phase: float = 0.0
var _dash_ready_burst_remaining: float = 0.0
var _dash_ready_pulse_count: int = 0
var _dash_ready_style: StyleBoxFlat
var _dash_cooldown_style: StyleBoxFlat


func _ready() -> void:
	# Observe finger releases during hit-stop, but defer combat until simulation resumes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_sync_to_viewport()
	get_viewport().size_changed.connect(_sync_to_viewport)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	mobile_device_detected = _detect_mobile_device()
	if robot != null:
		move_axis_changed.connect(robot.set_virtual_move_axis)
		move_direction_tapped.connect(robot._register_move_tap)
		smash_pressed.connect(robot.begin_attack_charge)
		smash_released.connect(robot.release_attack_charge)
		dash_pressed.connect(robot.request_dodge)
		robot.dodge_started.connect(_on_robot_dodge_started)
		robot.dodge_cooldown_ready.connect(_on_robot_dodge_cooldown_ready)
		_dash_ready_feedback = robot.dodge_ready
	_build_smash_button()
	_build_dash_button()
	L10n.apply_locale_font(self)
	_sync_to_viewport()
	visible = mobile_device_detected
	set_process(mobile_device_detected)
	set_process_input(mobile_device_detected)
	_apply_dash_feedback()


func _process(delta: float) -> void:
	process_controls(delta)


func _input(event: InputEvent) -> void:
	handle_touch_input(event)


func process_controls(delta: float) -> void:
	if not mobile_device_detected:
		return
	if get_tree().paused:
		return
	if _pending_smash_release:
		_pending_smash_release = false
		smash_release_count += 1
		smash_released.emit()
	_smash_cooldown_remaining = maxf(
		_smash_cooldown_remaining - delta,
		0.0
	)
	_advance_dash_feedback(delta)
	var previous_axis: float = _current_axis
	_current_axis = move_toward(
		_current_axis,
		_target_axis if _controls_enabled else 0.0,
		float(RuntimeTweakAccess.live_value(
			&"input.mobile_response_speed", response_speed
		)) * delta
	)
	if not is_equal_approx(previous_axis, _current_axis):
		move_axis_changed.emit(_current_axis)
		if joystick_active:
			queue_redraw()


func handle_touch_input(event: InputEvent) -> void:
	if not mobile_device_detected:
		return
	if not _controls_enabled:
		_handle_disabled_release(event)
		return
	if get_tree().paused:
		if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
			_handle_screen_touch(event as InputEventScreenTouch)
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func movement_axis() -> float:
	return _current_axis


func joystick_touch_index() -> int:
	return _joystick_touch_index


func smash_touch_index() -> int:
	return _smash_touch_index


func dash_touch_index() -> int:
	return _dash_touch_index


func dash_ready_feedback_active() -> bool:
	return _dash_ready_feedback


func dash_ready_pulse_count() -> int:
	return _dash_ready_pulse_count


func setup(p_robot: GiantRobotController, p_detection_override: int = -1) -> void:
	robot = p_robot
	detection_override = p_detection_override


func smash_bounds() -> Rect2:
	if smash_button == null:
		return Rect2()
	return smash_button.get_global_rect()


func dash_bounds() -> Rect2:
	if dash_button == null:
		return Rect2()
	return dash_button.get_global_rect()


func set_controls_enabled(enabled: bool, preserve_touch_ownership: bool = false) -> void:
	_controls_enabled = enabled
	_preserve_touch_ownership_while_disabled = not enabled and preserve_touch_ownership
	if smash_button != null:
		smash_button.modulate.a = 1.0 if enabled else 0.35
	if dash_button != null:
		_apply_dash_feedback()
	if not enabled and not preserve_touch_ownership:
		_pending_smash_release = false
		_release_joystick()
		_clear_smash_touch()
		_release_dash()
		_current_axis = 0.0
		move_axis_changed.emit(0.0)
	elif enabled:
		_preserve_touch_ownership_while_disabled = false


func controls_enabled() -> bool:
	return _controls_enabled


func _detect_mobile_device() -> bool:
	if detection_override >= 0:
		return detection_override == 1
	if OS.has_feature("web"):
		var browser_touch: Variant = JavaScriptBridge.eval(
			"(navigator.maxTouchPoints || 0) > 0",
			true
		)
		if bool(browser_touch):
			return true
	return (
		OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
		or DisplayServer.is_touchscreen_available()
	)


func _sync_to_viewport() -> void:
	position = Vector2.ZERO
	var viewport_size: Vector2 = get_viewport_rect().size
	size = viewport_size
	if smash_button != null:
		var portrait: bool = viewport_size.y > viewport_size.x
		smash_button.offset_left = -160.0 if portrait else -168.0
		smash_button.offset_top = -160.0 if portrait else -168.0
		smash_button.offset_right = -24.0 if portrait else -36.0
		smash_button.offset_bottom = -24.0 if portrait else -36.0
	if dash_button != null:
		var portrait: bool = viewport_size.y > viewport_size.x
		dash_button.offset_left = -144.0 if portrait else -154.0
		dash_button.offset_top = -252.0 if portrait else -256.0
		dash_button.offset_right = -40.0 if portrait else -50.0
		dash_button.offset_bottom = -180.0 if portrait else -184.0
		dash_button.pivot_offset = dash_button.size * 0.5
	if joystick_active:
		var previous_origin: Vector2 = _joystick_origin
		_joystick_origin.x = clampf(
			_joystick_origin.x,
			JOYSTICK_RADIUS + EDGE_PADDING,
			viewport_size.x - JOYSTICK_RADIUS - EDGE_PADDING
		)
		_joystick_origin.y = clampf(
			_joystick_origin.y,
			JOYSTICK_RADIUS + EDGE_PADDING,
			viewport_size.y - JOYSTICK_RADIUS - EDGE_PADDING
		)
		if not previous_origin.is_equal_approx(_joystick_origin):
			queue_redraw()


func _build_smash_button() -> void:
	smash_button = Button.new()
	smash_button.name = "SmashButton"
	smash_button.text = L10n.t("mobile.smash")
	smash_button.focus_mode = Control.FOCUS_NONE
	smash_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smash_button.anchor_left = 1.0
	smash_button.anchor_top = 1.0
	smash_button.anchor_right = 1.0
	smash_button.anchor_bottom = 1.0
	smash_button.offset_left = -168.0
	smash_button.offset_top = -168.0
	smash_button.offset_right = -36.0
	smash_button.offset_bottom = -36.0
	smash_button.add_theme_font_size_override(&"font_size", 25)
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.10, 0.15, 0.18, 0.84)
	normal_style.border_color = Color(0.95, 0.47, 0.25, 0.90)
	normal_style.set_border_width_all(4)
	normal_style.corner_radius_top_left = 66
	normal_style.corner_radius_top_right = 66
	normal_style.corner_radius_bottom_left = 66
	normal_style.corner_radius_bottom_right = 66
	smash_button.add_theme_stylebox_override(&"normal", normal_style)
	smash_button.add_theme_stylebox_override(&"hover", normal_style)
	smash_button.add_theme_stylebox_override(&"focus", normal_style)
	add_child(smash_button)


func _build_dash_button() -> void:
	dash_button = Button.new()
	dash_button.name = "DashButton"
	dash_button.text = L10n.t("mobile.dash")
	dash_button.focus_mode = Control.FOCUS_NONE
	dash_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_button.anchor_left = 1.0
	dash_button.anchor_top = 1.0
	dash_button.anchor_right = 1.0
	dash_button.anchor_bottom = 1.0
	dash_button.offset_left = -154.0
	dash_button.offset_top = -256.0
	dash_button.offset_right = -50.0
	dash_button.offset_bottom = -184.0
	dash_button.add_theme_font_size_override(&"font_size", 18)
	_dash_ready_style = StyleBoxFlat.new()
	_dash_ready_style.bg_color = Color(0.06, 0.16, 0.18, 0.92)
	_dash_ready_style.border_color = Color(0.36, 0.82, 0.88, 0.98)
	_dash_ready_style.set_border_width_all(3)
	_dash_ready_style.corner_radius_top_left = 36
	_dash_ready_style.corner_radius_top_right = 36
	_dash_ready_style.corner_radius_bottom_left = 36
	_dash_ready_style.corner_radius_bottom_right = 36
	_dash_cooldown_style = _dash_ready_style.duplicate() as StyleBoxFlat
	_dash_cooldown_style.bg_color = Color(0.05, 0.08, 0.10, 0.84)
	_dash_cooldown_style.border_color = Color(0.20, 0.34, 0.38, 0.74)
	dash_button.add_theme_stylebox_override(&"normal", _dash_ready_style)
	dash_button.add_theme_stylebox_override(&"hover", _dash_ready_style)
	dash_button.add_theme_stylebox_override(&"focus", _dash_ready_style)
	add_child(dash_button)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if smash_bounds().has_point(event.position):
			if event.index != _joystick_touch_index and _smash_touch_index == -1:
				_press_smash(event.index)
		elif dash_bounds().has_point(event.position):
			if event.index != _joystick_touch_index and _dash_touch_index == -1:
				_press_dash(event.index)
		elif _joystick_touch_index == -1:
			if event.index != _smash_touch_index and event.index != _dash_touch_index:
				_press_joystick(event.index, event.position)
	else:
		if event.index == _joystick_touch_index:
			_release_joystick()
		if event.index == _smash_touch_index:
			_release_smash()
		if event.index == _dash_touch_index:
			_release_dash()
	get_viewport().set_input_as_handled()


func _handle_disabled_release(event: InputEvent) -> void:
	if not _preserve_touch_ownership_while_disabled:
		return
	if event is not InputEventScreenTouch:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch.pressed:
		return
	if touch.index == _joystick_touch_index:
		_release_joystick()
	if touch.index == _smash_touch_index:
		_release_smash()
	if touch.index == _dash_touch_index:
		_release_dash()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _joystick_touch_index:
		return
	var displacement: Vector2 = event.position - _touch_anchor
	var next_knob_offset: Vector2 = displacement.limit_length(JOYSTICK_RADIUS)
	var raw_axis: float = clampf(
		displacement.x / JOYSTICK_RADIUS,
		-1.0,
		1.0
	)
	_target_axis = _apply_deadzone(raw_axis)
	if not next_knob_offset.is_equal_approx(_knob_offset):
		_knob_offset = next_knob_offset
		queue_redraw()
	get_viewport().set_input_as_handled()


func _press_joystick(touch_index: int, touch_position: Vector2) -> void:
	_joystick_touch_index = touch_index
	_touch_anchor = touch_position
	var viewport_size: Vector2 = get_viewport_rect().size
	_joystick_origin = Vector2(
		clampf(
			touch_position.x,
			JOYSTICK_RADIUS + EDGE_PADDING,
			viewport_size.x - JOYSTICK_RADIUS - EDGE_PADDING
		),
		clampf(
			touch_position.y,
			JOYSTICK_RADIUS + EDGE_PADDING,
			viewport_size.y - JOYSTICK_RADIUS - EDGE_PADDING
		)
	)
	_knob_offset = Vector2.ZERO
	_target_axis = 0.0
	joystick_active = true
	queue_redraw()


func _release_joystick() -> void:
	var visual_was_active: bool = joystick_active
	var released_direction: int = 0
	if absf(_target_axis) >= 0.50:
		released_direction = 1 if _target_axis > 0.0 else -1
	_joystick_touch_index = -1
	_target_axis = 0.0
	_knob_offset = Vector2.ZERO
	joystick_active = false
	if released_direction != 0 and _controls_enabled and not get_tree().paused:
		move_direction_tapped.emit(released_direction)
	if visual_was_active:
		queue_redraw()


func _press_smash(touch_index: int) -> void:
	_smash_touch_index = touch_index
	_smash_press_accepted = false
	smash_button.scale = Vector2(0.94, 0.94)
	smash_button.pivot_offset = smash_button.size * 0.5
	if _smash_cooldown_remaining > 0.0:
		return
	_smash_cooldown_remaining = float(RuntimeTweakAccess.live_value(
		&"input.mobile_smash_cooldown", smash_cooldown
	))
	_smash_press_accepted = true
	smash_press_count += 1
	smash_pressed.emit()


func _release_smash() -> void:
	var should_release: bool = _smash_press_accepted
	_clear_smash_touch()
	if should_release:
		if get_tree().paused:
			_pending_smash_release = true
		else:
			smash_release_count += 1
			smash_released.emit()


func _clear_smash_touch() -> void:
	_smash_touch_index = -1
	_smash_press_accepted = false
	if smash_button != null:
		smash_button.scale = Vector2.ONE


func _press_dash(touch_index: int) -> void:
	_dash_touch_index = touch_index
	dash_button.scale = Vector2(0.94, 0.94)
	dash_button.pivot_offset = dash_button.size * 0.5
	var direction_axis: float = _target_axis
	var active_deadzone: float = _active_deadzone()
	if absf(direction_axis) <= active_deadzone:
		direction_axis = _current_axis
	var direction: int = 0
	if absf(direction_axis) > active_deadzone:
		direction = 1 if direction_axis > 0.0 else -1
	elif robot != null:
		direction = robot.facing
	dash_press_count += 1
	dash_pressed.emit(direction)


func _release_dash() -> void:
	_dash_touch_index = -1
	if dash_button != null:
		_apply_dash_feedback()


func _on_robot_dodge_started(_facing: int, _duration: float) -> void:
	_dash_ready_feedback = false
	_dash_ready_burst_remaining = 0.0
	_dash_ready_phase = 0.0
	_apply_dash_feedback()


func _on_robot_dodge_cooldown_ready() -> void:
	_dash_ready_feedback = true
	_dash_ready_burst_remaining = DASH_READY_BURST_DURATION
	_dash_ready_phase = 0.0
	_dash_ready_pulse_count += 1
	_apply_dash_feedback()


func _advance_dash_feedback(delta: float) -> void:
	if dash_button == null:
		return
	if _dash_ready_feedback:
		_dash_ready_phase = fmod(
			_dash_ready_phase + maxf(delta, 0.0),
			DASH_READY_IDLE_PERIOD
		)
		_dash_ready_burst_remaining = maxf(
			_dash_ready_burst_remaining - maxf(delta, 0.0),
			0.0
		)
	_apply_dash_feedback()


func _apply_dash_feedback() -> void:
	if dash_button == null:
		return
	var style: StyleBoxFlat = (
		_dash_ready_style if _dash_ready_feedback else _dash_cooldown_style
	)
	dash_button.add_theme_stylebox_override(&"normal", style)
	dash_button.add_theme_stylebox_override(&"hover", style)
	dash_button.add_theme_stylebox_override(&"focus", style)
	if _dash_touch_index >= 0:
		dash_button.scale = Vector2.ONE * 0.94
	else:
		dash_button.scale = Vector2.ONE * _dash_ready_scale()
	var enabled_alpha: float = 1.0 if _controls_enabled else 0.35
	if not _dash_ready_feedback:
		dash_button.modulate = Color(0.62, 0.72, 0.76, 0.56 * enabled_alpha)
		return
	var glow: float = (_dash_ready_scale() - 1.0) / 0.11
	dash_button.modulate = Color(
		lerpf(0.78, 1.0, glow),
		lerpf(0.92, 1.0, glow),
		1.0,
		enabled_alpha
	)


func _dash_ready_scale() -> float:
	if not _dash_ready_feedback:
		return 1.0
	var idle_progress: float = _dash_ready_phase / DASH_READY_IDLE_PERIOD
	var idle_wave: float = (sin(idle_progress * TAU) + 1.0) * 0.5
	var scale_offset: float = lerpf(0.008, 0.028, idle_wave)
	if _dash_ready_burst_remaining > 0.0:
		var burst_progress: float = (
			1.0 - _dash_ready_burst_remaining / DASH_READY_BURST_DURATION
		)
		var burst_wave: float = absf(
			sin(burst_progress * PI * DASH_READY_BURST_CYCLES)
		)
		scale_offset = maxf(scale_offset, burst_wave * 0.11)
	return 1.0 + scale_offset


func _apply_deadzone(raw_axis: float) -> float:
	var active_deadzone: float = _active_deadzone()
	var magnitude: float = absf(raw_axis)
	if magnitude <= active_deadzone:
		return 0.0
	return signf(raw_axis) * (magnitude - active_deadzone) / (1.0 - active_deadzone)


func _active_deadzone() -> float:
	return float(RuntimeTweakAccess.live_value(
		&"input.mobile_deadzone", deadzone
	))


func _draw() -> void:
	if not joystick_active or not mobile_device_detected:
		return
	draw_circle(
		_joystick_origin,
		JOYSTICK_RADIUS,
		Color(0.06, 0.07, 0.08, 0.48)
	)
	draw_arc(
		_joystick_origin,
		JOYSTICK_RADIUS,
		0.0,
		TAU,
		48,
		Color(0.72, 0.74, 0.76, 0.58),
		3.0,
		true
	)
	var knob_center: Vector2 = _joystick_origin + _knob_offset
	draw_circle(
		knob_center,
		KNOB_RADIUS,
		Color(0.80, 0.81, 0.82, 0.94)
	)
