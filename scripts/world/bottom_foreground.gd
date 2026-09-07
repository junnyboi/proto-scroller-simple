class_name BottomForeground
extends Node2D
## A screen-bottom strip in the world canvas, above actors and below CanvasLayer UI.
## Mirrored neighboring tiles share identical edges; no texture or node allocation per frame.

const TEXTURE: Texture2D = preload("res://assets/city/parallax/business_bottom_foreground.png")
const DRAW_Z: int = 200
const SCROLL_FACTOR: float = 1.18
const STRIP_HEIGHT: float = 240.0
const BOTTOM_OVERSCAN: float = 12.0

var _origin_x: float = 0.0
var _phase: float = 0.0
var _viewport_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	z_as_relative = false
	z_index = DRAW_Z
	top_level = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	process_priority = 100
	_update_presentation()


func _process(_delta: float) -> void:
	_update_presentation()


func compensate_origin(offset: Vector2) -> void:
	_origin_x -= offset.x


func reset_origin() -> void:
	_origin_x = 0.0


func tile_width() -> float:
	return TEXTURE.get_width() * STRIP_HEIGHT / float(TEXTURE.get_height())


func _update_presentation() -> void:
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	global_transform = canvas.affine_inverse()
	_viewport_size = get_viewport_rect().size
	var multiplier: float = float(RuntimeTweakAccess.live_value(
		&"world.parallax.motion_multiplier", 1.0
	))
	if PresentationSettings.reduced_motion():
		multiplier = 0.0
	_phase = (-canvas.origin.x + _origin_x * canvas.x.length()) * SCROLL_FACTOR * multiplier
	queue_redraw()


func _draw() -> void:
	var width: float = tile_width()
	var first_tile: int = floori(_phase / width)
	var start: float = -fposmod(_phase, width)
	var y: float = _viewport_size.y - STRIP_HEIGHT + BOTTOM_OVERSCAN
	for index: int in range(ceili(_viewport_size.x / width) + 1):
		var x: float = start + index * width
		var mirrored: bool = posmod(first_tile + index, 2) == 1
		draw_set_transform(Vector2(x + width if mirrored else x, y),
			0.0, Vector2(-1.0 if mirrored else 1.0, 1.0))
		draw_texture_rect(TEXTURE, Rect2(0.0, 0.0, width, STRIP_HEIGHT), false)
	draw_set_transform(Vector2.ZERO)
