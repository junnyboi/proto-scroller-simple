class_name StructuralMaterialProfile
extends Resource

const FACADE_HEALTH_MULTIPLIER: float = 0.75

@export var material_id: StringName = &"concrete"
@export var display_name: String = "material.concrete"
@export var max_health: float = 95.0 * FACADE_HEALTH_MULTIPLIER
@export_range(1, 8, 1) var chunk_count: int = 3
@export var chunk_mass_min: float = 2.0
@export var chunk_mass_max: float = 12.0
@export var chunk_size_min: Vector2 = Vector2(18.0, 12.0)
@export var chunk_size_max: Vector2 = Vector2(58.0, 34.0)
@export var chunk_speed_min: float = 0.48
@export var chunk_speed_max: float = 1.25
@export var chunk_spread_degrees: float = 38.0
@export var debris_primary_color: Color = Color("4f4a46")
@export var debris_facet_color: Color = Color("786d65")
@export var visual_tint: Color = Color.WHITE
@export var particle_color: Color = Color("bca58f")
@export var particle_amount_scale: float = 0.14
@export var particle_speed_min: float = 0.35
@export var particle_speed_max: float = 0.95
@export var particle_spread: float = 72.0
@export var particle_gravity: float = 560.0
@export var particle_scale_min: float = 3.0
@export var particle_scale_max: float = 8.0


static func concrete() -> StructuralMaterialProfile:
	var profile: StructuralMaterialProfile = StructuralMaterialProfile.new()
	return profile


static func glass() -> StructuralMaterialProfile:
	var profile: StructuralMaterialProfile = StructuralMaterialProfile.new()
	profile.material_id = &"glass"
	profile.display_name = "material.glass"
	profile.max_health = 45.0 * FACADE_HEALTH_MULTIPLIER
	profile.chunk_count = 5
	profile.chunk_mass_min = 0.25
	profile.chunk_mass_max = 1.3
	profile.chunk_size_min = Vector2(7.0, 16.0)
	profile.chunk_size_max = Vector2(16.0, 34.0)
	profile.chunk_speed_min = 1.15
	profile.chunk_speed_max = 1.85
	profile.chunk_spread_degrees = 52.0
	profile.debris_primary_color = Color("6ba6b5")
	profile.debris_facet_color = Color("bde7ee")
	profile.visual_tint = Color("b6dae0")
	profile.particle_color = Color("a9e8f2")
	profile.particle_amount_scale = 0.22
	profile.particle_speed_min = 0.70
	profile.particle_speed_max = 1.45
	profile.particle_spread = 88.0
	profile.particle_gravity = 420.0
	profile.particle_scale_min = 1.5
	profile.particle_scale_max = 4.0
	return profile


static func steel() -> StructuralMaterialProfile:
	var profile: StructuralMaterialProfile = StructuralMaterialProfile.new()
	profile.material_id = &"steel"
	profile.display_name = "material.steel"
	profile.max_health = 155.0 * FACADE_HEALTH_MULTIPLIER
	profile.chunk_count = 2
	profile.chunk_mass_min = 9.0
	profile.chunk_mass_max = 24.0
	profile.chunk_size_min = Vector2(14.0, 42.0)
	profile.chunk_size_max = Vector2(22.0, 84.0)
	profile.chunk_speed_min = 0.28
	profile.chunk_speed_max = 0.58
	profile.chunk_spread_degrees = 24.0
	profile.debris_primary_color = Color("3f4a50")
	profile.debris_facet_color = Color("82939b")
	profile.visual_tint = Color("aeb9bd")
	profile.particle_color = Color("f6ae58")
	profile.particle_amount_scale = 0.10
	profile.particle_speed_min = 0.45
	profile.particle_speed_max = 1.10
	profile.particle_spread = 38.0
	profile.particle_gravity = 760.0
	profile.particle_scale_min = 2.0
	profile.particle_scale_max = 5.0
	return profile
