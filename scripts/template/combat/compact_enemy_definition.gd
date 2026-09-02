class_name CompactEnemyDefinition
extends Resource

@export var enemy_id: StringName = &""
@export var texture: Texture2D
@export var max_health: float = 60.0
@export var move_speed: float = 90.0
@export var attack_range: float = 110.0
@export var attack_interval: float = 1.0
@export var contact_damage: float = 8.0
@export var score_value: int = 100
@export var collision_size: Vector2 = Vector2(48.0, 96.0)
@export var visual_scale: Vector2 = Vector2(0.5, 0.5)


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if enemy_id.is_empty():
		errors.append("enemy_id is required")
	if texture == null:
		errors.append("texture is required")
	if max_health <= 0.0:
		errors.append("max_health must be positive")
	if move_speed <= 0.0:
		errors.append("move_speed must be positive")
	if attack_range <= 0.0 or attack_interval <= 0.0:
		errors.append("attack range and interval must be positive")
	if contact_damage <= 0.0 or score_value <= 0:
		errors.append("damage and score must be positive")
	if collision_size.x <= 0.0 or collision_size.y <= 0.0:
		errors.append("collision_size must be positive")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
