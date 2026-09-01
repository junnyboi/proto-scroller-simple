class_name CameraRig
extends Node2D

@export var look_ahead: float = 180.0
@export var look_ahead_speed: float = 700.0
@export var follow_speed: float = 850.0
@export var fixed_y: float = 360.0
@export var portrait_fixed_y: float = 427.0
@export var horizontal_limits_enabled: bool = false
@export var minimum_x: float = 640.0
@export var maximum_x: float = 2560.0
@export var impact_spring_strength: float = 145.0
@export var impact_spring_damping: float = 24.0
@export var maximum_impact_offset: float = 32.0
@export var portrait_visible_world_height: float = 854.0

@export_group("Boss Path Reveal")
@export var path_clear_max_distance: float = 220.0
@export var path_clear_pan_speed: float = 260.0
@export var path_clear_return_speed: float = 520.0
@export var path_clear_min_hold_seconds: float = 0.75
@export var path_clear_movement_threshold: float = 18.0

var target: GiantRobotController
var impact_offset: Vector2 = Vector2.ZERO
var impact_velocity: Vector2 = Vector2.ZERO
var _current_look_ahead: float = 0.0
var _look_ahead_scale: float = 1.0
var _path_clear_active: bool = false
var _path_clear_returning: bool = false
var _path_clear_focus_x: float = 0.0
var _path_clear_player_anchor_x: float = 0.0
var _path_clear_elapsed: float = 0.0
@onready var _camera: Camera2D = get_node_or_null(^"Camera2D") as Camera2D


func _ready() -> void:
	get_viewport().size_changed.connect(_apply_responsive_framing)
	_apply_responsive_framing()


func _physics_process(delta: float) -> void:
	_update_impact_spring(delta)
	if target == null:
		return
	var desired_look_ahead: float = (
		look_ahead * _look_ahead_scale * float(target.facing)
	)
	_current_look_ahead = move_toward(
		_current_look_ahead,
		desired_look_ahead,
		look_ahead_speed * delta
	)
	var desired_x: float = target.global_position.x + _current_look_ahead
	var active_follow_speed: float = follow_speed
	if _path_clear_active:
		_path_clear_elapsed += delta
		if (
			not _path_clear_returning
			and _path_clear_elapsed >= path_clear_min_hold_seconds
			and absf(target.global_position.x - _path_clear_player_anchor_x)
			>= path_clear_movement_threshold
		):
			_path_clear_returning = true
		if _path_clear_returning:
			active_follow_speed = path_clear_return_speed
			if absf(global_position.x - desired_x) <= 1.0:
				_cancel_path_clear_reveal()
		else:
			var maximum_focus_x: float = (
				desired_x + path_clear_max_distance * _look_ahead_scale
			)
			desired_x = clampf(_path_clear_focus_x, desired_x, maximum_focus_x)
			active_follow_speed = path_clear_pan_speed
	if horizontal_limits_enabled:
		desired_x = clampf(desired_x, minimum_x, maximum_x)
	global_position.x = move_toward(
		global_position.x,
		desired_x,
		active_follow_speed * delta
	)
	global_position.y = portrait_fixed_y if is_portrait_framing() else fixed_y


func add_impact_impulse(impulse: Vector2) -> void:
	var shake_scale: float = float(RuntimeTweakAccess.live_value(
		&"interface.screen_shake_scale", 1.0
	))
	impact_velocity += impulse * 42.0 * shake_scale
	impact_velocity = impact_velocity.limit_length(maximum_impact_offset * 30.0)


func begin_path_clear_reveal(focus_world_x: float) -> bool:
	if target == null:
		return false
	_path_clear_active = true
	_path_clear_returning = false
	_path_clear_focus_x = maxf(focus_world_x, target.global_position.x)
	_path_clear_player_anchor_x = target.global_position.x
	_path_clear_elapsed = 0.0
	return true


func path_clear_reveal_active() -> bool:
	return _path_clear_active


func path_clear_reveal_returning() -> bool:
	return _path_clear_returning


func path_clear_focus_world_x() -> float:
	return _path_clear_focus_x


func reset_presentation() -> void:
	impact_offset = Vector2.ZERO
	impact_velocity = Vector2.ZERO
	_cancel_path_clear_reveal()
	if _camera != null:
		_camera.offset = Vector2.ZERO


func reset_after_origin_shift(offset: Vector2 = Vector2.ZERO) -> void:
	if _path_clear_active:
		_path_clear_focus_x += offset.x
		_path_clear_player_anchor_x += offset.x
	if _camera != null:
		_camera.reset_smoothing()


func is_portrait_framing() -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	return viewport_size.y > viewport_size.x


func visible_world_size() -> Vector2:
	if _camera == null:
		return get_viewport_rect().size
	return get_viewport_rect().size / _camera.zoom


func visible_world_rect(margin: Vector2 = Vector2.ZERO) -> Rect2:
	var clamped_margin: Vector2 = Vector2(
		maxf(margin.x, 0.0),
		maxf(margin.y, 0.0)
	)
	var size: Vector2 = visible_world_size() + clamped_margin * 2.0
	var center: Vector2 = global_position
	if _camera != null:
		center += _camera.offset
	return Rect2(center - size * 0.5, size)


func _apply_responsive_framing() -> void:
	if _camera == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.y > viewport_size.x:
		var portrait_zoom: float = clampf(
			viewport_size.y / portrait_visible_world_height,
			1.35,
			1.60
		)
		_camera.zoom = Vector2.ONE * portrait_zoom
		_look_ahead_scale = 0.78
	else:
		_camera.zoom = Vector2.ONE
		_look_ahead_scale = 1.0


func _update_impact_spring(delta: float) -> void:
	impact_velocity += -impact_offset * impact_spring_strength * delta
	impact_velocity *= exp(-impact_spring_damping * delta)
	impact_offset += impact_velocity * delta
	impact_offset = impact_offset.limit_length(maximum_impact_offset)
	if impact_offset.length_squared() < 0.0025 and impact_velocity.length_squared() < 0.04:
		impact_offset = Vector2.ZERO
		impact_velocity = Vector2.ZERO
	if _camera != null:
		_camera.offset = impact_offset


func _cancel_path_clear_reveal() -> void:
	_path_clear_active = false
	_path_clear_returning = false
	_path_clear_focus_x = 0.0
	_path_clear_player_anchor_x = 0.0
	_path_clear_elapsed = 0.0
