class_name FlameVisualSlot2D
extends Node2D

const PLUME_TEXTURE: Texture2D = preload(
	"res://assets/presentation/flame_plume.png"
)
const IGNITION_TEXTURE: Texture2D = preload(
	"res://assets/presentation/flame_ignition.png"
)

var active: bool = false
var paused: bool = false
var age: float = 0.0
var lifetime: float = 0.24
var flame_range: float = 220.0
var half_angle: float = deg_to_rad(32.0)


func _ready() -> void:
	z_index = 74
	visible = false
	set_process(false)


func activate(
	origin: Vector2,
	direction: Vector2,
	p_range: float,
	p_half_angle: float
) -> void:
	global_position = origin
	rotation = direction.angle()
	flame_range = p_range
	half_angle = p_half_angle
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
	var half_width: float = minf(tan(half_angle) * flame_range, flame_range * 0.42)
	draw_texture_rect(
		PLUME_TEXTURE,
		Rect2(Vector2(0.0, -half_width), Vector2(flame_range, half_width * 2.0)),
		false,
		Color(1.0, 1.0, 1.0, alpha * 0.90)
	)
	var ignition_alpha: float = alpha * clampf(1.0 - age / 0.12, 0.0, 1.0)
	draw_texture_rect(
		IGNITION_TEXTURE,
		Rect2(Vector2(-10.0, -24.0), Vector2(54.0, 48.0)),
		false,
		Color(1.0, 1.0, 1.0, ignition_alpha)
	)
