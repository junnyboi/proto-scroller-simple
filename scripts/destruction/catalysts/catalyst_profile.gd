class_name CatalystProfile
extends Resource

@export var catalyst_id: StringName = &"TRANSFORMER"
@export var display_name: String = "catalyst.transformer"
@export var max_health: float = 90.0
@export_range(0.1, 2.0, 0.05) var delay_seconds: float = 0.45
@export_range(32.0, 400.0, 1.0) var pulse_radius: float = 230.0
@export var pulse_damage: float = 120.0
@export var structure_damage: float = 55.0
@export var impulse_per_mass: float = 720.0
@export_range(1, 24, 1) var max_results: int = 12
@export_range(0, 4, 1) var max_structural_cells: int = 1
@export_range(0, 8, 1) var max_debris: int = 2
@export_range(0, 4, 1) var maximum_causal_depth: int = 1
