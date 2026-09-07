class_name DistrictRecipe
extends Resource

@export var recipe_id: StringName = &"FORWARD_PRESSURE"
@export_range(0, 4, 1) var beat_rotation: int = 0
@export var reverse_alternate_acts: bool = false
@export var transformer_position: Vector2 = Vector2(1880.0, 590.0)
@export var gas_main_position: Vector2 = Vector2(1340.0, 610.0)
