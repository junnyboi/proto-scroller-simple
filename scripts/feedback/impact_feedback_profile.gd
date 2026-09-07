class_name ImpactFeedbackProfile
extends RefCounted

var priority: int
var hit_stop_ms: int
var camera_impulse: float
var haptic_ms: int


func _init(
	p_priority: int,
	p_hit_stop_ms: int,
	p_camera_impulse: float,
	p_haptic_ms: int
) -> void:
	priority = p_priority
	hit_stop_ms = clampi(p_hit_stop_ms, 25, 110)
	camera_impulse = clampf(p_camera_impulse, 0.0, 24.0)
	haptic_ms = clampi(p_haptic_ms, 1, 100)
