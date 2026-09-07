class_name ComboDecayRing
extends Control

const TRACK_COLOR: Color = Color(0.20, 0.25, 0.28, 0.90)
const FILL_COLOR: Color = Color("f1b36f")
const LINE_WIDTH: float = 4.0

var ratio: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(44.0, 44.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_ratio(next_ratio: float) -> void:
	ratio = clampf(next_ratio, 0.0, 1.0)
	visible = ratio > 0.0
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = maxf(minf(size.x, size.y) * 0.5 - LINE_WIDTH, 2.0)
	draw_arc(center, radius, -PI * 0.5, TAU - PI * 0.5, 48, TRACK_COLOR, LINE_WIDTH, true)
	if ratio <= 0.0:
		return
	draw_arc(
		center,
		radius,
		-PI * 0.5,
		-PI * 0.5 + TAU * ratio,
		48,
		FILL_COLOR,
		LINE_WIDTH,
		true
	)
