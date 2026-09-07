class_name AirTargetReticle2D
extends Node2D

const OUTER_RADIUS: float = 30.0
const INNER_RADIUS: float = 21.0
const BRACKET_HALF_ANGLE: float = 0.34
const TRACK_COLOR: Color = Color("74e8ff")
const CORE_COLOR: Color = Color("d7fbff")
const SHADOW_COLOR: Color = Color(0.01, 0.07, 0.10, 0.78)
const IMMINENT_START_PROGRESS: float = 0.68
const MIN_PULSE_HZ: float = 2.4
const MAX_PULSE_HZ: float = 4.2

var _target: EnemyActor2D
var _telegraph_progress: float = 0.0
var _pulse_phase: float = 0.0


func _ready() -> void:
	z_index = 92
	visible = false
	set_process(false)


func acquire(target: EnemyActor2D) -> void:
	_target = target
	_telegraph_progress = 0.0
	_pulse_phase = 0.0
	visible = target != null
	set_process(visible)
	if visible:
		global_position = target.global_position
		queue_redraw()


func clear_lock() -> void:
	_target = null
	_telegraph_progress = 0.0
	_pulse_phase = 0.0
	visible = false
	set_process(false)


func current_target() -> EnemyActor2D:
	return _target


func set_telegraph_progress(progress: float) -> void:
	var was_imminent: bool = is_release_imminent()
	_telegraph_progress = clampf(progress, 0.0, 1.0)
	if not was_imminent and is_release_imminent():
		_pulse_phase = 0.0
		queue_redraw()


func telegraph_progress() -> float:
	return _telegraph_progress


func is_release_imminent() -> bool:
	return _telegraph_progress >= IMMINENT_START_PROGRESS


func pulse_strength() -> float:
	if not is_release_imminent():
		return 0.0
	var urgency: float = inverse_lerp(
		IMMINENT_START_PROGRESS,
		1.0,
		_telegraph_progress
	)
	var wave: float = 0.5 - 0.5 * cos(_pulse_phase * TAU)
	return wave * lerpf(0.65, 1.0, urgency)


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		clear_lock()
		return
	global_position = _target.global_position
	if is_release_imminent():
		var urgency: float = inverse_lerp(
			IMMINENT_START_PROGRESS,
			1.0,
			_telegraph_progress
		)
		_pulse_phase = fmod(
			_pulse_phase + delta * lerpf(MIN_PULSE_HZ, MAX_PULSE_HZ, urgency),
			1.0
		)
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var pulse: float = pulse_strength()
	var radius: float = OUTER_RADIUS + pulse * 4.0
	var alpha: float = 0.82 + pulse * 0.18
	for quadrant: int in range(4):
		var center_angle: float = float(quadrant) * TAU * 0.25
		var start_angle: float = center_angle - BRACKET_HALF_ANGLE
		var end_angle: float = center_angle + BRACKET_HALF_ANGLE
		draw_arc(
			Vector2.ZERO,
			radius,
			start_angle,
			end_angle,
			8,
			SHADOW_COLOR,
			5.0,
			true
		)
		draw_arc(
			Vector2.ZERO,
			radius,
			start_angle,
			end_angle,
			8,
			Color(TRACK_COLOR, alpha),
			2.5,
			true
		)
		var direction: Vector2 = Vector2.from_angle(center_angle)
		draw_line(
			direction * INNER_RADIUS,
			direction * (INNER_RADIUS - 6.0),
			SHADOW_COLOR,
			5.0,
			true
		)
		draw_line(
			direction * INNER_RADIUS,
			direction * (INNER_RADIUS - 6.0),
			Color(TRACK_COLOR, alpha),
			2.5,
			true
		)
	draw_circle(Vector2.ZERO, 4.0 + pulse * 1.5, SHADOW_COLOR)
	draw_circle(Vector2.ZERO, 2.0 + pulse, Color(CORE_COLOR, alpha))
