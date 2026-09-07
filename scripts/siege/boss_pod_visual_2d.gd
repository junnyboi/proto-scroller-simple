class_name BossPodVisual2D
extends Node2D

enum PodState {
	SEALED,
	OCCUPIED,
	TARGETED,
	LOST,
	RESCUED,
}

const GLASS_SIZE: Vector2 = Vector2(74.0, 116.0)

var pod_index: int = 0
var state: PodState = PodState.SEALED


func configure(index: int, state_value: PodState, local_position: Vector2) -> void:
	pod_index = index
	state = state_value
	position = local_position
	visible = true
	queue_redraw()


func set_state(state_value: PodState) -> void:
	state = state_value
	visible = true
	queue_redraw()


func glass_rect() -> Rect2:
	return Rect2(global_position - GLASS_SIZE * 0.5, GLASS_SIZE)


func uses_procedural_rendering() -> bool:
	return false
