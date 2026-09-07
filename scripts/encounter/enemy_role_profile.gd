class_name EnemyRoleProfile
extends Resource

@export var role_id: StringName = &"BASE"
@export var display_name: String = "role.base"
@export_range(0.5, 2.0, 0.05) var health_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var movement_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var attack_interval_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var damage_multiplier: float = 1.0
@export var badge_shape: StringName = &"circle"
@export var badge_color: Color = Color("d7dde0")
