class_name CompactCameraImpulse
extends Camera2D

@export var decay_per_second: float = 28.0

var impulse_strength: float = 0.0
var impulse_direction: int = 1
var _phase: float = 0.0


func kick(strength: float, direction: int = 1) -> void:
	impulse_strength = maxf(impulse_strength, clampf(strength, 0.0, 18.0))
	impulse_direction = -1 if direction < 0 else 1


func _process(delta: float) -> void:
	if impulse_strength <= 0.0:
		offset = Vector2.ZERO
		return
	_phase += delta * 52.0
	offset = Vector2(
		sin(_phase) * impulse_strength * float(impulse_direction),
		cos(_phase * 1.37) * impulse_strength * 0.35
	)
	impulse_strength = move_toward(impulse_strength, 0.0, decay_per_second * delta)
