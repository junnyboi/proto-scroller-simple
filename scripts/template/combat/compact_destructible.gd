class_name CompactDestructible
extends Node2D

signal destroyed(score_value: int, world_position: Vector2)

@export var max_health: float = 90.0
@export var score_value: int = 50

var current_health: float = 0.0
var is_destroyed: bool = false

@onready var intact_visual: Sprite2D = %IntactVisual
@onready var wreck_visual: Sprite2D = %WreckVisual


func _ready() -> void:
	reset()


func reset() -> void:
	current_health = max_health
	is_destroyed = false
	intact_visual.visible = true
	wreck_visual.visible = false


func receive_damage(amount: float) -> bool:
	if is_destroyed or amount <= 0.0:
		return false
	current_health = maxf(current_health - amount, 0.0)
	if current_health > 0.0:
		return true
	is_destroyed = true
	intact_visual.visible = false
	wreck_visual.visible = true
	destroyed.emit(score_value, global_position)
	return true
