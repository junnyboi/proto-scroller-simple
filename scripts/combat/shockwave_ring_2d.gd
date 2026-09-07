class_name ShockwaveRing2D
extends Node2D

const START_RADIUS: float = 96.0
const END_RADIUS: float = 260.0

var active: bool = false
var paused: bool = false
var age: float = 0.0
var lifetime: float = 1.0


func _ready() -> void:
	z_index = 70
	visible = false
	set_process(false)


func activate(world_position: Vector2, duration: float) -> void:
	global_position = world_position
	lifetime = clampf(duration, 1.0, 3.0)
	age = 0.0
	active = true
	visible = true
	set_process(true)
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not active or paused:
		return
	age += delta
	if age >= lifetime:
		deactivate()
		return
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var ratio: float = clampf(age / lifetime, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - ratio, 3.0)
	var radius: float = lerpf(START_RADIUS, END_RADIUS, eased)
	var alpha: float = 1.0
	if ratio > 0.55:
		alpha = 1.0 - (ratio - 0.55) / 0.45
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		64,
		Color(0.32, 0.87, 1.0, alpha * 0.78),
		6.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		radius + 8.0,
		0.0,
		TAU,
		64,
		Color(0.95, 0.68, 0.34, alpha * 0.32),
		2.0,
		true
	)
