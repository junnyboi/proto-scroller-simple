class_name ScorchVisualSlot2D
extends Node2D

const CONTACT_TEXTURE: Texture2D = preload(
	"res://assets/presentation/flame_contact.png"
)
const SCORCH_TEXTURE: Texture2D = preload(
	"res://assets/presentation/scorch_decal.png"
)

var active: bool = false
var paused: bool = false
var age: float = 0.0
var lifetime: float = 0.8


func _ready() -> void:
	z_index = 29
	visible = false
	set_process(false)


func activate(world_position: Vector2) -> void:
	global_position = world_position
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
		SCORCH_TEXTURE,
		Rect2(Vector2(-34.0, -13.0), Vector2(68.0, 26.0)),
		false,
		Color(1.0, 1.0, 1.0, alpha * 0.68)
	)
	var contact_alpha: float = clampf(1.0 - age / 0.36, 0.0, 1.0)
	draw_texture_rect(
		CONTACT_TEXTURE,
		Rect2(Vector2(-22.0, -48.0), Vector2(44.0, 48.0)),
		false,
		Color(1.0, 1.0, 1.0, contact_alpha)
	)
