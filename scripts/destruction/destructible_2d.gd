class_name Destructible2D
extends Node2D

signal damaged(current_health: float, maximum_health: float)
signal damage_applied(amount: float, event: DamageEvent)
signal destroyed(event: DamageEvent)

@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0
@export_range(0.0, 1.0, 0.05) var damaged_stage_ratio: float = 0.5
@export_range(0, 8, 1) var gameplay_chunk_count: int = 3
@export var chunk_spread_degrees: float = 38.0
@export var chunk_impulse_scale: float = 1.0
@export var debris_pool_path: NodePath
@export var section_burst_pool_path: NodePath
@export var intact_visual_path: NodePath
@export var damaged_visual_path: NodePath
@export var intact_collision_path: NodePath
@export var hurtbox_collision_path: NodePath

var current_health: float
var material_profile: StructuralMaterialProfile
var _destroyed: bool = false
var _seen_attacks: Dictionary[int, bool] = {}

@onready var _debris_pool: DebrisPool = get_node_or_null(debris_pool_path) as DebrisPool
@onready var _section_burst_pool: BuildingSectionBurstPool = (
	get_node_or_null(section_burst_pool_path) as BuildingSectionBurstPool
)
@onready var _intact_visual: CanvasItem = get_node_or_null(intact_visual_path) as CanvasItem
@onready var _damaged_visual: CanvasItem = get_node_or_null(damaged_visual_path) as CanvasItem
@onready var _intact_collision: CollisionShape2D = (
	get_node_or_null(intact_collision_path) as CollisionShape2D
)
@onready var _hurtbox_collision: CollisionShape2D = (
	get_node_or_null(hurtbox_collision_path) as CollisionShape2D
)


func _ready() -> void:
	if material_profile != null:
		_apply_material_profile()
	current_health = max_health
	_apply_stage(false, false)


func receive_damage(event: DamageEvent) -> bool:
	if _destroyed or event == null or event.amount <= 0.0:
		return false
	if get_parent() is StructuralBuilding2D:
		var tuning: Dictionary = (get_parent() as StructuralBuilding2D).tuning_snapshot_for_event(
			event
		)
		damaged_stage_ratio = float(tuning.get(
			"damaged_stage_ratio", damaged_stage_ratio
		))
	if event.attack_id != 0 and _seen_attacks.has(event.attack_id):
		return false
	if event.attack_id != 0:
		_seen_attacks[event.attack_id] = true
	var previous_health: float = current_health
	current_health = maxf(current_health - event.amount, 0.0)
	var accepted_damage: float = previous_health - current_health
	damaged.emit(current_health, max_health)
	damage_applied.emit(accepted_damage, event)
	var damage_pattern: BuildingDamagePattern2D = (
		_damaged_visual as BuildingDamagePattern2D
	)
	if damage_pattern != null:
		damage_pattern.record_damage(event, current_health / maxf(max_health, 1.0))
	if current_health <= 0.0:
		_break(event)
	else:
		_apply_stage(current_health <= max_health * damaged_stage_ratio, false)
	return true


func is_destroyed() -> bool:
	return _destroyed


func capture_stream_state() -> Dictionary:
	var state: Dictionary = {
		"health": current_health,
		"destroyed": _destroyed,
		"damaged_stage_ratio": damaged_stage_ratio,
		"pristine": not _destroyed and is_equal_approx(current_health, max_health),
	}
	var damage_pattern: BuildingDamagePattern2D = _damaged_visual as BuildingDamagePattern2D
	if damage_pattern != null and not bool(state.pristine):
		state.pattern = damage_pattern.capture_stream_state()
	return state


func restore_stream_state(state: Dictionary) -> void:
	_seen_attacks.clear()
	_destroyed = bool(state.get("destroyed", false))
	damaged_stage_ratio = float(state.get("damaged_stage_ratio", damaged_stage_ratio))
	current_health = clampf(float(state.get("health", max_health)), 0.0, max_health)
	if _destroyed:
		current_health = 0.0
	var damage_pattern: BuildingDamagePattern2D = _damaged_visual as BuildingDamagePattern2D
	if damage_pattern != null:
		damage_pattern.restore_stream_state(state.get("pattern", {}) as Dictionary)
		damage_pattern._set_damage_progress(
			1.0 - current_health / maxf(max_health, 1.0)
		)
		if _destroyed:
			damage_pattern.ensure_destroyed_pattern()
	_apply_stage(
		current_health <= max_health * damaged_stage_ratio and not _destroyed,
		_destroyed
	)


func _break(event: DamageEvent) -> void:
	if _destroyed:
		return
	_destroyed = true
	_apply_stage(false, true)
	_release_section_burst(event)
	_release_chunks(event)
	destroyed.emit(event)


func _apply_stage(show_damaged: bool, show_destroyed: bool) -> void:
	if _intact_visual != null:
		_intact_visual.visible = true
	if _damaged_visual != null:
		_damaged_visual.visible = show_damaged or show_destroyed
		var damage_pattern: BuildingDamagePattern2D = (
			_damaged_visual as BuildingDamagePattern2D
		)
		if damage_pattern != null:
			damage_pattern.set_destroyed_stage(show_destroyed)
			if show_destroyed or not show_damaged:
				damage_pattern.cull_damage_details()
	if _intact_collision != null:
		_intact_collision.set_deferred("disabled", show_destroyed)
	if _hurtbox_collision != null:
		_hurtbox_collision.set_deferred("disabled", show_destroyed)


func _release_chunks(event: DamageEvent) -> void:
	if _debris_pool == null or gameplay_chunk_count <= 0:
		return
	var is_jab_cross: bool = event.damage_type == &"jab_cross"
	var base_direction: Vector2 = event.direction
	var forward_sign: float = signf(base_direction.x)
	if is_jab_cross:
		if is_zero_approx(forward_sign):
			forward_sign = 1.0
		base_direction = Vector2(forward_sign, -0.70).normalized()
	if base_direction.is_zero_approx():
		base_direction = (global_position - event.hit_position).normalized()
	if base_direction.is_zero_approx():
		base_direction = Vector2.UP
	var requested_count: int = gameplay_chunk_count + (2 if is_jab_cross else 0)
	var count: int = mini(requested_count, _debris_pool.available_count())
	for chunk_index: int in range(count):
		var weight: float = (float(chunk_index) + 0.5) / float(maxi(count, 1))
		var spread_degrees: float = (
			minf(chunk_spread_degrees, 28.0)
			if is_jab_cross
			else chunk_spread_degrees
		)
		var angle: float = deg_to_rad(lerpf(-spread_degrees, spread_degrees, weight))
		var direction: Vector2 = base_direction.rotated(angle)
		if not is_jab_cross:
			direction.y -= 0.35
		direction = direction.normalized()
		var mass_min: float = 1.5
		var mass_max: float = 12.0
		var size_min: Vector2 = Vector2(18.0, 12.0)
		var size_max: Vector2 = Vector2(58.0, 34.0)
		var speed_min: float = 0.48
		var speed_max: float = 1.25
		var primary_color: Color = Color("4f4a46")
		var facet_color: Color = Color("786d65")
		var material_id: StringName = &"concrete"
		if material_profile != null:
			mass_min = material_profile.chunk_mass_min
			mass_max = material_profile.chunk_mass_max
			size_min = material_profile.chunk_size_min
			size_max = material_profile.chunk_size_max
			speed_min = material_profile.chunk_speed_min
			speed_max = material_profile.chunk_speed_max
			primary_color = material_profile.debris_primary_color
			facet_color = material_profile.debris_facet_color
			material_id = material_profile.material_id
		var body_mass: float = lerpf(mass_min, mass_max, weight)
		var body_size: Vector2 = size_min.lerp(size_max, weight)
		var speed_scale: float = lerpf(speed_max, speed_min, weight)
		var speed_delta: float = event.impulse_per_mass * chunk_impulse_scale * speed_scale
		var transform_offset: Vector2 = direction * (12.0 + 8.0 * float(chunk_index))
		if is_jab_cross:
			transform_offset = Vector2(
				forward_sign * (28.0 + 6.0 * float(chunk_index)),
				-128.0 - 4.0 * float(chunk_index)
			)
		var spawn_position: Vector2 = event.hit_position + transform_offset
		var spawn_transform: Transform2D = Transform2D(
			0.0,
			spawn_position
		)
		var debris: DebrisBody2D = _debris_pool.acquire(
			spawn_transform,
			direction * speed_delta * body_mass,
			lerpf(-4.0, 4.0, weight) * body_mass,
			body_mass,
			body_size,
			material_id,
			primary_color,
			facet_color
		)
		_debris_pool.arm_kinetic_debris(debris, event)


func _release_section_burst(event: DamageEvent) -> void:
	if _section_burst_pool == null or event == null:
		return
	var profile: StructuralMaterialProfile = material_profile
	if profile == null:
		profile = StructuralMaterialProfile.concrete()
	var origin: Vector2 = event.hit_position
	if event.damage_type in [&"floor_chain", &"steel_support_chain", &"support_failure"]:
		origin = global_position
	_section_burst_pool.spawn(
		origin,
		event.direction,
		maxf(event.impulse_per_mass, 260.0),
		profile,
		StringName(get_meta(&"district_id", &"BUSINESS"))
	)


func configure_material_profile(profile: StructuralMaterialProfile) -> void:
	assert(profile != null, "Destructible2D requires a material profile")
	material_profile = profile
	_apply_material_profile()


func get_material_profile() -> StructuralMaterialProfile:
	return material_profile


func _apply_material_profile() -> void:
	max_health = material_profile.max_health
	gameplay_chunk_count = material_profile.chunk_count
	chunk_spread_degrees = material_profile.chunk_spread_degrees
