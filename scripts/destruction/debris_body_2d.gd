class_name DebrisBody2D
extends RigidBody2D

signal recycle_requested(body: DebrisBody2D)
signal aerial_impact_accepted(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D
)
signal ground_impact_accepted(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D,
	impact_speed: float
)
signal crucible_detonated(body: DebrisBody2D, event: DamageEvent)

const CONCRETE_DEBRIS_TEXTURE: Texture2D = preload(
	"res://assets/city/destructibles/debris/concrete_chunk.png"
)
const GLASS_DEBRIS_TEXTURE: Texture2D = preload(
	"res://assets/city/destructibles/debris/glass_shard.png"
)
const STEEL_DEBRIS_TEXTURE: Texture2D = preload(
	"res://assets/city/destructibles/debris/steel_fragment.png"
)

const ACTIVE_COLLISION_LAYER: int = 1 << 8
const ACTIVE_COLLISION_MASK: int = (1 << 0) | (1 << 2)
const ACTIVE_CONTACT_LIMIT: int = 4
const MIN_GROUND_IMPACT_SPEED: float = 240.0
const MAX_GROUND_IMPACT_DAMAGE: float = 42.0
const GROUND_IMPACT_DAMAGE_SCALE: float = 0.035

@export_range(0.5, 30.0, 0.5) var hard_lifetime: float = 10.0
@export_range(0.0, 5.0, 0.1) var sleeping_recycle_delay: float = 1.5
@export var max_linear_speed: float = 1500.0
@export var max_angular_speed: float = 14.0

var aerial_impact_armed: bool = false
var aerial_hit_count: int = 0
var ground_hit_count: int = 0
var _age: float = 0.0
var _sleeping_age: float = 0.0
var _active: bool = false
var _body_size: Vector2 = Vector2(36.0, 22.0)
var _material_id: StringName = &"concrete"
var _primary_color: Color = Color("4f4a46")
var _facet_color: Color = Color("786d65")
var _aerial_source: Node
var _aerial_attack_id: int = 0
var _aerial_root_attack_id: int = 0
var _aerial_damage: float = 0.0
var _aerial_target: EnemyActor2D
var _kinetic_armed: bool = false
var _kinetic_source: Node
var _kinetic_root_attack_id: int = 0
var _kinetic_delivery_id: int = 0
var _kinetic_bonus_damage: float = 0.0
var _kinetic_effect_flags: int = DamageEvent.FLAG_NONE
var _ground_hit_generations: Dictionary[int, int] = {}
var _last_motion_velocity: Vector2 = Vector2.ZERO
var _last_motion_age: float = INF
var _generated_visual: Sprite2D
var _crucible_captured: bool = false
var _crucible_armed: bool = false
var _crucible_source: Node
var _crucible_root_attack_id: int = 0
var _crucible_delivery_id: int = 0
var _crucible_damage: float = 0.0
var _crucible_effect_flags: int = DamageEvent.FLAG_NONE
var _crucible_kinetic_bonus: float = 0.0
var _crucible_gravity_restore_delay: float = 0.0
var _capture_linear_velocity: Vector2 = Vector2.ZERO
var _capture_angular_velocity: float = 0.0
var _capture_collision_layer: int = 0
var _capture_collision_mask: int = 0
var _capture_gravity_scale: float = 1.0
var _capture_contact_monitor: bool = false
var _capture_max_contacts: int = 0
var _capture_can_sleep: bool = true
var _capture_shape_disabled: bool = false
var _capture_max_linear_speed: float = 1500.0


func _ready() -> void:
	can_sleep = true
	gravity_scale = 1.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	body_entered.connect(_on_body_entered)
	_ensure_fallback_shape()
	_ensure_generated_visual()
	_set_collision_participation(false)
	set_physics_process(false)


func activate(
	spawn_transform: Transform2D,
	linear_impulse: Vector2,
	angular_impulse: float = 0.0,
	body_mass: float = 4.0,
	body_size: Vector2 = Vector2(36.0, 22.0),
	material_kind: StringName = &"concrete",
	primary_color: Color = Color("4f4a46"),
	facet_color: Color = Color("786d65"),
	use_generated_visual: bool = true
) -> void:
	mass = maxf(body_mass, 0.1)
	_body_size = Vector2(maxf(body_size.x, 4.0), maxf(body_size.y, 4.0))
	_material_id = material_kind
	_primary_color = primary_color
	_facet_color = facet_color
	set_meta(&"structural_material", _material_id)
	_apply_body_size()
	_apply_generated_visual(use_generated_visual)
	_set_collision_participation(true)
	global_transform = spawn_transform
	linear_velocity = Vector2.ZERO
	_last_motion_velocity = Vector2.ZERO
	_last_motion_age = INF
	angular_velocity = 0.0
	constant_force = Vector2.ZERO
	constant_torque = 0.0
	freeze = false
	sleeping = false
	_age = 0.0
	_sleeping_age = 0.0
	ground_hit_count = 0
	_ground_hit_generations.clear()
	_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	queue_redraw()
	reset_physics_interpolation()
	apply_central_impulse(linear_impulse)
	if not is_zero_approx(angular_impulse):
		apply_torque_impulse(angular_impulse)


func arm_aerial_impact(
	source: Node,
	attack_id: int,
	damage: float,
	target: EnemyActor2D,
	root_attack_id: int = 0
) -> void:
	_aerial_source = source
	_aerial_attack_id = attack_id
	_aerial_root_attack_id = root_attack_id if root_attack_id != 0 else attack_id
	_aerial_damage = maxf(damage, 0.0)
	_aerial_target = target
	aerial_impact_armed = _aerial_damage > 0.0 and target != null
	aerial_hit_count = 0


func arm_kinetic_impact(
	source: Node,
	root_attack_id: int,
	delivery_id: int,
	bonus_damage: float,
	effect_flags: int
) -> void:
	_kinetic_source = source
	_kinetic_root_attack_id = root_attack_id
	_kinetic_delivery_id = delivery_id
	_kinetic_bonus_damage = maxf(bonus_damage, 0.0)
	_kinetic_effect_flags = effect_flags | DamageEvent.FLAG_KINETIC_FIELD
	_kinetic_armed = delivery_id < 0 and root_attack_id > 0


func kinetic_delivery_id() -> int:
	return _kinetic_delivery_id


func material_id() -> StringName:
	return _material_id


func is_active() -> bool:
	return _active


func is_crucible_captured() -> bool:
	return _crucible_captured


func is_crucible_eligible() -> bool:
	return (
		_active
		and visible
		and not _crucible_captured
		and not aerial_impact_armed
		and not _kinetic_armed
		and not bool(get_meta(&"demolition_plate", false))
	)


func begin_crucible_capture() -> bool:
	if not is_crucible_eligible():
		return false
	_clear_crucible_delivery()
	var shape_node: CollisionShape2D = _collision_shape()
	_capture_linear_velocity = linear_velocity
	_capture_angular_velocity = angular_velocity
	_capture_collision_layer = collision_layer
	_capture_collision_mask = collision_mask
	_capture_gravity_scale = gravity_scale
	_capture_contact_monitor = contact_monitor
	_capture_max_contacts = max_contacts_reported
	_capture_can_sleep = can_sleep
	_capture_shape_disabled = shape_node.disabled if shape_node != null else false
	_capture_max_linear_speed = max_linear_speed
	_crucible_captured = true
	_crucible_armed = false
	set_physics_process(false)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	gravity_scale = 0.0
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0
	contact_monitor = false
	max_contacts_reported = 0
	if shape_node != null:
		shape_node.set_deferred(&"disabled", true)
	return true


func update_crucible_capture(position_value: Vector2, rotation_value: float) -> void:
	if not _crucible_captured:
		return
	global_position = position_value
	rotation = rotation_value


func cancel_crucible_capture() -> void:
	if not _crucible_captured:
		return
	_restore_after_crucible(_capture_linear_velocity, _capture_angular_velocity)
	_clear_crucible_delivery()


func release_from_crucible(
	launch_velocity: Vector2,
	launch_angular_velocity: float,
	source_event: DamageEvent,
	damage: float,
	delivery_id: int,
	gravity_multiplier: float = 1.0,
	gravity_restore_delay: float = 0.0
) -> bool:
	if not _crucible_captured or source_event == null:
		return false
	_restore_after_crucible(launch_velocity, launch_angular_velocity)
	max_linear_speed = maxf(_capture_max_linear_speed, launch_velocity.length())
	_crucible_source = source_event.source
	_crucible_root_attack_id = source_event.root_attack_id
	_crucible_delivery_id = delivery_id
	_crucible_damage = maxf(damage, 0.0)
	_crucible_effect_flags = (
		source_event.effect_flags | DamageEvent.FLAG_GRAVITY_CRUCIBLE
	)
	_crucible_kinetic_bonus = source_event.kinetic_debris_bonus
	_crucible_armed = _crucible_damage > 0.0 and delivery_id != 0
	if _crucible_armed:
		gravity_scale = _capture_gravity_scale * maxf(gravity_multiplier, 0.0)
		_crucible_gravity_restore_delay = maxf(gravity_restore_delay, 0.0)
	return _crucible_armed


func is_aerial_shrapnel_for_attack(root_attack_id: int) -> bool:
	return (
		aerial_impact_armed
		and root_attack_id > 0
		and _aerial_root_attack_id == root_attack_id
	)


func deactivate() -> void:
	_crucible_captured = false
	_clear_crucible_delivery()
	_set_collision_participation(false)
	aerial_impact_armed = false
	_aerial_source = null
	_aerial_target = null
	_aerial_root_attack_id = 0
	_aerial_damage = 0.0
	_kinetic_armed = false
	_kinetic_source = null
	_kinetic_root_attack_id = 0
	_kinetic_delivery_id = 0
	_kinetic_bonus_damage = 0.0
	_kinetic_effect_flags = DamageEvent.FLAG_NONE
	_active = false
	set_physics_process(false)
	linear_velocity = Vector2.ZERO
	_last_motion_velocity = Vector2.ZERO
	_last_motion_age = INF
	angular_velocity = 0.0
	constant_force = Vector2.ZERO
	constant_torque = 0.0
	freeze = true
	sleeping = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_advance_crucible_gravity(delta)
	_age += delta
	_last_motion_age += delta
	if linear_velocity.length() >= MIN_GROUND_IMPACT_SPEED:
		_last_motion_velocity = linear_velocity
		_last_motion_age = 0.0
	elif _last_motion_age > 0.12:
		_last_motion_velocity = Vector2.ZERO
	_sleeping_age = _sleeping_age + delta if sleeping else 0.0
	if _age >= hard_lifetime or _sleeping_age >= sleeping_recycle_delay:
		recycle_requested.emit(self)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not _active:
		return
	if state.linear_velocity.length() > max_linear_speed:
		state.linear_velocity = state.linear_velocity.limit_length(max_linear_speed)
	state.angular_velocity = clampf(
		state.angular_velocity,
		-max_angular_speed,
		max_angular_speed
	)


func _on_body_entered(body: Node) -> void:
	if _crucible_armed:
		_resolve_crucible_impact(body)
		return
	if aerial_impact_armed and body == _aerial_target:
		_resolve_aerial_impact()
		return
	if not _kinetic_armed:
		_resolve_ground_enemy_impact(body)
		return
	var receiver: Node = _find_damage_receiver(body)
	if receiver == null or receiver == _kinetic_source:
		return
	_kinetic_armed = false
	var target_velocity: Vector2 = (
		(receiver as EnemyActor2D).velocity if receiver is EnemyActor2D else Vector2.ZERO
	)
	var impact_velocity: Vector2 = _impact_relative_velocity(target_velocity)
	var direction: Vector2 = impact_velocity.normalized()
	var event: DamageEvent = DamageEvent.new(
		_kinetic_delivery_id,
		_kinetic_source,
		4.0 + _kinetic_bonus_damage,
		&"debris_impact",
		global_position,
		direction,
		impact_velocity.length(),
		_kinetic_root_attack_id,
		1,
		_kinetic_effect_flags
	)
	var accepted: bool = bool(receiver.call("receive_damage", event))
	var enemy: EnemyActor2D = receiver as EnemyActor2D
	if (
		accepted
		and enemy != null
		and not enemy.is_in_group(AerialDebrisLauncher.AIRBORNE_GROUP)
	):
		ground_hit_count += 1
		ground_impact_accepted.emit(self, event, enemy, impact_velocity.length())


func _resolve_ground_enemy_impact(body: Node) -> void:
	var target: EnemyActor2D = _find_damage_receiver(body) as EnemyActor2D
	if (
		target == null
		or not target.active
		or target.dead
		or target.is_in_group(AerialDebrisLauncher.AIRBORNE_GROUP)
	):
		return
	var relative_velocity: Vector2 = _impact_relative_velocity(target.velocity)
	var impact_speed: float = relative_velocity.length()
	if impact_speed < MIN_GROUND_IMPACT_SPEED:
		return
	var target_id: int = target.get_instance_id()
	if _ground_hit_generations.get(target_id, -1) == target.activation_generation:
		return
	var mass_scale: float = clampf(sqrt(mass / 4.0), 0.65, 2.2)
	var impact_energy: float = impact_speed * mass_scale
	var damage: float = clampf(
		5.0
		+ maxf(impact_energy - MIN_GROUND_IMPACT_SPEED, 0.0)
		* GROUND_IMPACT_DAMAGE_SCALE,
		5.0,
		MAX_GROUND_IMPACT_DAMAGE
	)
	var direction: Vector2 = relative_velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	var event: DamageEvent = DamageEvent.new(
		0,
		self,
		damage,
		&"debris_impact",
		global_position,
		direction,
		impact_speed * 0.45
	)
	if target.receive_damage(event):
		_ground_hit_generations[target_id] = target.activation_generation
		ground_hit_count += 1
		ground_impact_accepted.emit(self, event, target, impact_speed)


func _resolve_crucible_impact(body: Node) -> void:
	if not _crucible_armed:
		return
	var target: EnemyActor2D = _find_damage_receiver(body) as EnemyActor2D
	if target != null and (not target.active or target.dead):
		target = null
	var target_velocity: Vector2 = target.velocity if target != null else Vector2.ZERO
	var relative_velocity: Vector2 = _impact_relative_velocity(target_velocity)
	var impact_speed: float = relative_velocity.length()
	if impact_speed < MIN_GROUND_IMPACT_SPEED:
		return
	var direction: Vector2 = relative_velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var event: DamageEvent = DamageEvent.new(
		_crucible_delivery_id,
		_crucible_source,
		_crucible_damage + _crucible_kinetic_bonus,
		&"debris_impact",
		global_position,
		direction,
		impact_speed * 0.45,
		_crucible_root_attack_id,
		1,
		_crucible_effect_flags,
		_crucible_kinetic_bonus
	)
	_clear_crucible_delivery()
	if target != null:
		var target_id: int = target.get_instance_id()
		if target.receive_damage(event):
			_ground_hit_generations[target_id] = target.activation_generation
			ground_hit_count += 1
			ground_impact_accepted.emit(self, event, target, impact_speed)
	crucible_detonated.emit(self, event)
	recycle_requested.emit(self)


func _impact_relative_velocity(target_velocity: Vector2) -> Vector2:
	var relative_velocity: Vector2 = linear_velocity - target_velocity
	var previous_relative: Vector2 = _last_motion_velocity - target_velocity
	if (
		_last_motion_age <= 0.12
		and previous_relative.length_squared() > relative_velocity.length_squared()
	):
		return previous_relative
	return relative_velocity


func _resolve_aerial_impact() -> void:
	aerial_impact_armed = false
	var direction: Vector2 = linear_velocity.normalized()
	var event: DamageEvent = DamageEvent.new(
		_kinetic_delivery_id if _kinetic_armed else _aerial_attack_id,
		_kinetic_source if _kinetic_armed else _aerial_source,
		_aerial_damage + _kinetic_bonus_damage,
		&"debris_impact",
		global_position,
		direction,
		linear_velocity.length(),
		_kinetic_root_attack_id if _kinetic_armed else _aerial_root_attack_id,
		1 if _kinetic_armed else 0,
		_kinetic_effect_flags if _kinetic_armed else DamageEvent.FLAG_NONE
	)
	_kinetic_armed = false
	if _aerial_target.receive_damage(event):
		aerial_hit_count += 1
		aerial_impact_accepted.emit(self, event, _aerial_target)


func _find_damage_receiver(start_node: Node) -> Node:
	var receiver: Node = start_node
	while receiver != null:
		if receiver.has_method("receive_damage"):
			return receiver
		receiver = receiver.get_parent()
	return null


func _draw() -> void:
	if _generated_visual != null and _generated_visual.visible:
		return
	if _material_id == &"glass":
		_draw_glass_shard()
		return
	if _material_id == &"steel":
		_draw_steel_beam()
		return
	_draw_concrete_chunk()


func _draw_concrete_chunk() -> void:
	var half_size: Vector2 = _body_size * 0.5
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y * 0.45),
		Vector2(-half_size.x * 0.38, -half_size.y),
		Vector2(half_size.x * 0.62, -half_size.y * 0.82),
		Vector2(half_size.x, -half_size.y * 0.22),
		Vector2(half_size.x * 0.74, half_size.y),
		Vector2(-half_size.x * 0.20, half_size.y * 0.78),
		Vector2(-half_size.x, half_size.y * 0.34),
	])
	draw_colored_polygon(outline, _primary_color)
	var facet: PackedVector2Array = PackedVector2Array([
		Vector2(-half_size.x * 0.38, -half_size.y * 0.72),
		Vector2(half_size.x * 0.48, -half_size.y * 0.60),
		Vector2(half_size.x * 0.20, -half_size.y * 0.08),
		Vector2(-half_size.x * 0.62, half_size.y * 0.12),
	])
	draw_colored_polygon(facet, _facet_color)
	draw_line(
		Vector2(-half_size.x * 0.72, half_size.y * 0.22),
		Vector2(half_size.x * 0.62, -half_size.y * 0.38),
		Color("302c2a"),
		maxf(2.0, _body_size.y * 0.12)
	)


func _draw_glass_shard() -> void:
	var half_size: Vector2 = _body_size * 0.5
	var shard: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -half_size.y),
		Vector2(half_size.x, half_size.y * 0.72),
		Vector2(-half_size.x * 0.58, half_size.y),
	])
	draw_colored_polygon(shard, _primary_color)
	draw_polyline(shard, _facet_color, 2.0)
	draw_line(
		Vector2(0.0, -half_size.y * 0.72),
		Vector2(half_size.x * 0.32, half_size.y * 0.48),
		_facet_color,
		1.5
	)


func _draw_steel_beam() -> void:
	var half_size: Vector2 = _body_size * 0.5
	draw_rect(Rect2(-half_size, _body_size), _primary_color, true)
	draw_rect(
		Rect2(
			Vector2(-half_size.x + 3.0, -half_size.y + 3.0),
			Vector2(maxf(_body_size.x - 6.0, 2.0), maxf(_body_size.y - 6.0, 2.0))
		),
		Color("1d2428"),
		true
	)
	draw_line(
		Vector2(-half_size.x, 0.0),
		Vector2(half_size.x, 0.0),
		_facet_color,
		maxf(3.0, _body_size.x * 0.22)
	)


func _ensure_fallback_shape() -> void:
	if get_child_count() > 0:
		return
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(36.0, 22.0)
	shape_node.shape = shape
	add_child(shape_node)
	queue_redraw()


func _ensure_generated_visual() -> void:
	if _generated_visual != null:
		return
	_generated_visual = Sprite2D.new()
	_generated_visual.name = "GeneratedDebrisVisual"
	_generated_visual.centered = true
	_generated_visual.visible = false
	_generated_visual.z_index = 1
	add_child(_generated_visual)


func _apply_generated_visual(use_generated_visual: bool) -> void:
	if _generated_visual == null:
		return
	var texture: Texture2D
	if use_generated_visual:
		match _material_id:
			&"glass":
				texture = GLASS_DEBRIS_TEXTURE
			&"steel":
				texture = STEEL_DEBRIS_TEXTURE
			&"concrete":
				texture = CONCRETE_DEBRIS_TEXTURE
	_generated_visual.texture = texture
	_generated_visual.visible = texture != null
	if texture != null:
		_generated_visual.scale = Vector2(
			_body_size.x / float(texture.get_width()),
			_body_size.y / float(texture.get_height())
		)
	queue_redraw()


func _apply_body_size() -> void:
	var shape_node: CollisionShape2D = _collision_shape()
	if shape_node == null:
		return
	var rectangle: RectangleShape2D = shape_node.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = _body_size


func _set_collision_participation(enabled: bool) -> void:
	collision_layer = ACTIVE_COLLISION_LAYER if enabled else 0
	collision_mask = ACTIVE_COLLISION_MASK if enabled else 0
	contact_monitor = enabled
	max_contacts_reported = ACTIVE_CONTACT_LIMIT if enabled else 0
	var shape_node: CollisionShape2D = _collision_shape()
	if shape_node != null:
		shape_node.disabled = not enabled


func _collision_shape() -> CollisionShape2D:
	var shape_node: CollisionShape2D = get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node == null and get_child_count() > 0:
		shape_node = get_child(0) as CollisionShape2D
	return shape_node


func _restore_after_crucible(
	restored_velocity: Vector2,
	restored_angular_velocity: float
) -> void:
	_crucible_captured = false
	freeze = false
	sleeping = false
	gravity_scale = _capture_gravity_scale
	can_sleep = _capture_can_sleep
	collision_layer = _capture_collision_layer
	collision_mask = _capture_collision_mask
	contact_monitor = _capture_contact_monitor
	max_contacts_reported = _capture_max_contacts
	var shape_node: CollisionShape2D = _collision_shape()
	if shape_node != null:
		shape_node.set_deferred(&"disabled", _capture_shape_disabled)
	linear_velocity = restored_velocity
	angular_velocity = restored_angular_velocity
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	reset_physics_interpolation()


func _clear_crucible_delivery() -> void:
	max_linear_speed = _capture_max_linear_speed
	if not _crucible_captured:
		gravity_scale = _capture_gravity_scale
	_crucible_armed = false
	_crucible_source = null
	_crucible_root_attack_id = 0
	_crucible_delivery_id = 0
	_crucible_damage = 0.0
	_crucible_effect_flags = DamageEvent.FLAG_NONE
	_crucible_kinetic_bonus = 0.0
	_crucible_gravity_restore_delay = 0.0


func _advance_crucible_gravity(delta: float) -> void:
	if not _crucible_armed or _crucible_gravity_restore_delay <= 0.0:
		return
	_crucible_gravity_restore_delay = maxf(
		_crucible_gravity_restore_delay - maxf(delta, 0.0),
		0.0
	)
	if is_zero_approx(_crucible_gravity_restore_delay):
		gravity_scale = _capture_gravity_scale
