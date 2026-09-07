class_name EnemyTraitProfile
extends Resource

@export var trait_id: StringName = &""
@export var display_name: String = ""
@export_range(0.5, 2.0, 0.05) var health_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var movement_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var attack_interval_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var projectile_damage_multiplier: float = 1.0
@export_range(0.5, 1.5, 0.05) var telegraph_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.05) var first_hit_damage_ratio: float = 1.0
@export_range(0.0, 300.0, 5.0) var death_pulse_damage: float = 0.0
@export_range(0.0, 400.0, 10.0) var death_pulse_radius: float = 0.0
@export var badge_shape: StringName = &"diamond"
@export var badge_color: Color = Color("ff815c")
