class_name LaserBeamVisual2D
extends Node2D

const BEAM_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/anti_air_beam_core.png"
)

var active: bool = false
var paused: bool = false
var age: float = 0.0
var lifetime: float = 0.10
var beam_length: float = 1100.0


func _ready() -> void:
	z_index = 75
	visible = false
	set_process(false)


func activate(origin: Vector2, direction: Vector2, length: float) -> void:
	global_position = origin
	rotation = direction.angle()
	beam_length = length
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
	var alpha: float = clampf(1.0 - age / lifetime, 0.0, 1.0)
	draw_texture_rect(
		BEAM_TEXTURE,
		Rect2(Vector2(0.0, -9.0), Vector2(beam_length, 18.0)),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)
	draw_circle(Vector2.ZERO, 8.0, Color(0.86, 1.0, 1.0, alpha))
