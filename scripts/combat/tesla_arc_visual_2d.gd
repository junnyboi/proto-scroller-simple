class_name TeslaArcVisual2D
extends Node2D

const ARC_TEXTURE: Texture2D = preload(
	"res://assets/player/upgrades/tesla_arc.png"
)
const DISPLAY_SECONDS: float = 0.18
const MIN_LENGTH: float = 8.0

var active: bool = false
var paused: bool = false
var remaining: float = 0.0
var endpoint: Vector2 = Vector2.ZERO
var sprite: Sprite2D


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.name = "ArcSprite"
	sprite.texture = ARC_TEXTURE
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = 41
	add_child(sprite)
	deactivate()


func activate(start: Vector2, finish: Vector2) -> void:
	var span: Vector2 = finish - start
	var length: float = maxf(span.length(), MIN_LENGTH)
	global_position = start
	rotation = span.angle()
	endpoint = finish
	remaining = DISPLAY_SECONDS
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	var texture_size: Vector2 = ARC_TEXTURE.get_size()
	sprite.position = Vector2(length * 0.5, 0.0)
	sprite.scale = Vector2(
		length / maxf(texture_size.x, 1.0),
		0.62
	)
	sprite.modulate = Color.WHITE


func deactivate() -> void:
	active = false
	remaining = 0.0
	visible = false
	set_process(false)


func set_paused(value: bool) -> void:
	paused = value


func _process(delta: float) -> void:
	if not active or paused:
		return
	remaining = maxf(remaining - maxf(delta, 0.0), 0.0)
	var color: Color = Color.WHITE
	color.a = clampf(remaining / DISPLAY_SECONDS, 0.0, 1.0)
	sprite.modulate = color
	if remaining <= 0.0:
		deactivate()
