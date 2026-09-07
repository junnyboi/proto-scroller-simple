class_name EnemyWreck2D
extends RigidBody2D

signal scrapped(wreck: EnemyWreck2D, event: DamageEvent)
signal crash_landed(wreck: EnemyWreck2D)
signal crash_impact_accepted(wreck: EnemyWreck2D, event: DamageEvent, target: Node)
signal crucible_detonated(wreck: EnemyWreck2D, event: DamageEvent)

const ENEMY_LAYER: int = 1 << 2
const BUILDING_LAYER: int = 1 << 3
const PROP_LAYER: int = 1 << 7
const ROBOT_LAYER: int = 1 << 1
const REMAINS_LAYER: int = 1 << 9
const REMAINS_GROUND_LAYER: int = 1 << 10
const MIN_CRASH_IMPACT_SPEED: float = 220.0
const MAX_CRASH_IMPACT_DAMAGE: float = 180.0
const CRASH_IMPACT_DAMAGE_SCALE: float = 0.12
const PLAYER_ATTACK_KNOCKBACK_SCALE: float = 1.10
const NON_PLAYER_KNOCKBACK_SCALE: float = 0.32
const ROAD_SETTLE_BASELINE_Y: float = CityStreetChunk.LAND_ENEMY_VISUAL_BASELINE_Y
const ROAD_SETTLE_TIMEOUT_SECONDS: float = 2.5
const ROAD_SETTLE_TOLERANCE: float = 2.0
const PLAYER_OVERLAP_EJECTION_UPWARD_SPEED: float = 820.0
const PLAYER_OVERLAP_EJECTION_OUTWARD_SPEED: float = 540.0
const PLAYER_OVERLAP_EJECTION_ANGULAR_SPEED: float = 10.0

static var _next_crash_attack_id: int = 2_000_000

@export var scrap_health: float = 120.0
@export var wreck_kind: StringName = &"machinery"

var current_scrap_health: float
var scrapped_state: bool = false
var display_size: Vector2 = Vector2(220.0, 90.0)
var collision_size: Vector2 = Vector2(205.0, 72.0)
var wreck_texture: Texture2D
var visual_content_rect: Rect2 = Rect2()
var fatal_event: DamageEvent
var airborne_crash: bool = false
var settling_to_road: bool = false
var crash_landing_count: int = 0
var crash_impact_count: int = 0
var player_overlap_ejection_count: int = 0
var finisher_requires_ground_smash: bool = false
var finisher_damage_types: PackedStringArray = PackedStringArray()
var _seen_attacks: Dictionary[int, bool] = {}
var _seen_root_attacks: Dictionary[int, bool] = {}
var _finisher_receiver_active: bool = true
var _crash_attack_id: int = 0
var _crash_impact_targets: Dictionary[int, bool] = {}
var _last_crash_velocity: Vector2 = Vector2.ZERO
var _steel_profile: StructuralMaterialProfile
var _settle_elapsed: float = 0.0
var _crucible_captured: bool = false
var _crucible_armed: bool = false
var _crucible_source: Node
var _crucible_root_attack_id: int = 0
var _crucible_delivery_id: int = 0
var _crucible_damage: float = 0.0
var _crucible_effect_flags: int = DamageEvent.FLAG_NONE
var _crucible_launch_velocity: Vector2 = Vector2.ZERO
var _crucible_gravity_restore_delay: float = 0.0
var _capture_linear_velocity: Vector2 = Vector2.ZERO
var _capture_angular_velocity: float = 0.0
var _capture_collision_layer: int = 0
var _capture_collision_mask: int = 0
var _capture_gravity_scale: float = 1.0
var _capture_linear_damp: float = 0.0
var _capture_angular_damp: float = 0.0
var _capture_can_sleep: bool = true
var _capture_shape_disabled: bool = false
var _player_overlap_ejection_target: GiantRobotController


func _ready() -> void:
	_steel_profile = StructuralMaterialProfile.steel()
	gravity_scale = 1.0
	linear_damp = 0.9
	angular_damp = 1.5
	can_sleep = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	z_as_relative = false
	z_index = 20
	_build_collision()
	_build_visual()
	deactivate()


func activate(
	p_wreck_kind: StringName,
	p_wreck_texture: Texture2D,
	p_display_size: Vector2,
	p_collision_size: Vector2,
	p_mass: float,
	p_scrap_health: float,
	spawn_position: Vector2,
	p_fatal_event: DamageEvent,
	p_airborne_crash: bool = false,
	p_finisher_requires_ground_smash: bool = false
) -> void:
	wreck_kind = p_wreck_kind
	wreck_texture = p_wreck_texture
	display_size = p_display_size
	collision_size = p_collision_size
	mass = p_mass
	scrap_health = p_scrap_health
	current_scrap_health = scrap_health
	fatal_event = p_fatal_event
	airborne_crash = p_airborne_crash
	settling_to_road = true
	visual_content_rect = _resolved_content_rect(visual_content_rect)
	_settle_elapsed = 0.0
	crash_landing_count = 0
	crash_impact_count = 0
	player_overlap_ejection_count = 0
	_player_overlap_ejection_target = null
	configure_finisher_policy(p_finisher_requires_ground_smash, p_fatal_event)
	_crash_impact_targets.clear()
	_crash_attack_id = _allocate_crash_attack_id() if airborne_crash else 0
	_last_crash_velocity = Vector2.ZERO
	scrapped_state = false
	visible = true
	freeze = false
	sleeping = false
	gravity_scale = 1.45 if airborne_crash else 1.0
	linear_damp = 0.25 if airborne_crash else 0.9
	angular_damp = 0.45 if airborne_crash else 1.5
	can_sleep = not airborne_crash
	global_position = spawn_position
	rotation = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_layer = REMAINS_LAYER
	collision_mask = REMAINS_GROUND_LAYER | ROBOT_LAYER
	if airborne_crash:
		collision_mask |= ENEMY_LAYER
	set_meta(&"enemy_remains", wreck_kind)
	var collision: CollisionShape2D = get_node(^"WreckCollision") as CollisionShape2D
	(collision.shape as RectangleShape2D).size = collision_size
	collision.set_deferred(&"disabled", false)
	_update_visual()
	_apply_fatal_impact()


func deactivate(preserve_scrapped: bool = false) -> void:
	_crucible_captured = false
	_clear_crucible_delivery()
	visible = false
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	airborne_crash = false
	settling_to_road = false
	crash_impact_count = 0
	player_overlap_ejection_count = 0
	_player_overlap_ejection_target = null
	finisher_requires_ground_smash = false
	finisher_damage_types = PackedStringArray()
	_finisher_receiver_active = false
	_seen_attacks.clear()
	_seen_root_attacks.clear()
	_crash_attack_id = 0
	_crash_impact_targets.clear()
	_last_crash_velocity = Vector2.ZERO
	_settle_elapsed = 0.0
	visual_content_rect = Rect2()
	gravity_scale = 1.0
	linear_damp = 0.9
	angular_damp = 1.5
	can_sleep = true
	if not preserve_scrapped:
		scrapped_state = false
	var collision: CollisionShape2D = get_node_or_null(^"WreckCollision") as CollisionShape2D
	if collision != null:
		collision.set_deferred(&"disabled", true)
	_apply_fatal_impact()


func receive_damage(event: DamageEvent) -> bool:
	if (
		scrapped_state
		or not _finisher_receiver_active
		or event == null
		or event.amount <= 0.0
	):
		return false
	if finisher_requires_ground_smash and event.damage_type != &"ground_smash":
		return false
	if not finisher_damage_types.is_empty() and not finisher_damage_types.has(event.damage_type):
		return false
	if event.attack_id != 0 and _seen_attacks.has(event.attack_id):
		return false
	if event.root_attack_id != 0 and _seen_root_attacks.has(event.root_attack_id):
		return false
	if event.attack_id != 0:
		_seen_attacks[event.attack_id] = true
	if event.root_attack_id != 0:
		_seen_root_attacks[event.root_attack_id] = true
	current_scrap_health = maxf(current_scrap_health - event.amount, 0.0)
	var direction: Vector2 = event.direction
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var knockback_scale: float = (
		PLAYER_ATTACK_KNOCKBACK_SCALE
		if event.source is GiantRobotController
		else NON_PLAYER_KNOCKBACK_SCALE
	)
	apply_central_impulse(direction * event.impulse_per_mass * mass * knockback_scale)
	apply_torque_impulse(
		direction.x * event.impulse_per_mass * mass * knockback_scale * 0.5
	)
	if current_scrap_health <= 0.0:
		_turn_to_scrap(event)
	return true


func reduce_to_rubble(event: DamageEvent) -> bool:
	if event == null or event.amount <= 0.0:
		return false
	var finisher_event: DamageEvent = DamageEvent.new(
		event.attack_id,
		event.source,
		maxf(event.amount, current_scrap_health),
		event.damage_type,
		event.hit_position,
		event.direction,
		event.impulse_per_mass,
		event.root_attack_id,
		event.causal_depth,
		event.effect_flags,
		event.kinetic_debris_bonus
	)
	return receive_damage(finisher_event)


func configure_finisher_policy(
	requires_ground_smash: bool,
	p_fatal_event: DamageEvent = fatal_event,
	allowed_damage_types: PackedStringArray = PackedStringArray()
) -> void:
	finisher_requires_ground_smash = requires_ground_smash
	finisher_damage_types = allowed_damage_types.duplicate()
	_seen_attacks.clear()
	_seen_root_attacks.clear()
	if p_fatal_event != null:
		if p_fatal_event.attack_id != 0:
			_seen_attacks[p_fatal_event.attack_id] = true
		if p_fatal_event.root_attack_id != 0:
			_seen_root_attacks[p_fatal_event.root_attack_id] = true
	_finisher_receiver_active = true


func configure_one_hit_melee_finisher(p_fatal_event: DamageEvent = fatal_event) -> void:
	scrap_health = 1.0
	current_scrap_health = 1.0
	configure_finisher_policy(
		false,
		p_fatal_event,
		PackedStringArray(["jab_cross", "ground_smash"])
	)


func configure_visual_content_rect(content_rect: Rect2) -> void:
	visual_content_rect = content_rect


func configure_automatic_scrap() -> void:
	finisher_requires_ground_smash = false
	finisher_damage_types = PackedStringArray()
	_seen_attacks.clear()
	_seen_root_attacks.clear()
	_finisher_receiver_active = false
	collision_layer = 0


func scrap_automatically(event: DamageEvent) -> bool:
	if scrapped_state or event == null:
		return false
	_finisher_receiver_active = false
	current_scrap_health = 0.0
	_turn_to_scrap(event)
	return true


func set_wreck_visual_visible(visible_value: bool) -> void:
	var visual: Sprite2D = get_node_or_null(^"WreckVisual") as Sprite2D
	if visual != null:
		visual.visible = visible_value


func get_material_profile() -> StructuralMaterialProfile:
	return _steel_profile


func is_scrapped() -> bool:
	return scrapped_state


func is_crashing() -> bool:
	return airborne_crash


func is_settling_to_road() -> bool:
	return settling_to_road


func visible_bottom_y() -> float:
	var visual: Sprite2D = get_node_or_null(^"WreckVisual") as Sprite2D
	if visual == null or visual.texture == null:
		return global_position.y + collision_size.y * 0.5
	var local_bottom: Vector2 = Vector2(
		visual_content_rect.get_center().x,
		visual_content_rect.end.y
	)
	return visual.to_global(local_bottom).y


func eject_from_player_if_overlapping(player: GiantRobotController) -> bool:
	if player == null or not _overlaps_player(player):
		return false
	var outward_sign: float = _player_ejection_direction(player)
	linear_velocity = Vector2(
		outward_sign * maxf(
			absf(linear_velocity.x),
			PLAYER_OVERLAP_EJECTION_OUTWARD_SPEED
		),
		minf(linear_velocity.y, -PLAYER_OVERLAP_EJECTION_UPWARD_SPEED)
	)
	angular_velocity = outward_sign * PLAYER_OVERLAP_EJECTION_ANGULAR_SPEED
	linear_damp = 0.25
	angular_damp = 0.45
	can_sleep = false
	sleeping = false
	collision_mask &= ~ROBOT_LAYER
	_player_overlap_ejection_target = player
	player_overlap_ejection_count += 1
	reset_physics_interpolation()
	return true


func is_player_overlap_ejecting() -> bool:
	return _player_overlap_ejection_target != null


func _physics_process(delta: float) -> void:
	_advance_player_overlap_ejection()
	_advance_crucible_gravity(delta)
	if not settling_to_road or scrapped_state or freeze:
		return
	_settle_elapsed += delta
	if _settle_elapsed >= ROAD_SETTLE_TIMEOUT_SECONDS:
		_snap_to_road_baseline()


func is_crucible_captured() -> bool:
	return _crucible_captured


func is_crucible_eligible() -> bool:
	return (
		visible
		and not scrapped_state
		and not airborne_crash
		and not _crucible_captured
		and collision_layer != 0
		and not bool(get_meta(&"boss_wreck", false))
	)


func begin_crucible_capture() -> bool:
	if not is_crucible_eligible():
		return false
	var collision: CollisionShape2D = get_node_or_null(^"WreckCollision") as CollisionShape2D
	_capture_linear_velocity = linear_velocity
	_capture_angular_velocity = angular_velocity
	_capture_collision_layer = collision_layer
	_capture_collision_mask = collision_mask
	_capture_gravity_scale = gravity_scale
	_capture_linear_damp = linear_damp
	_capture_angular_damp = angular_damp
	_capture_can_sleep = can_sleep
	_capture_shape_disabled = collision.disabled if collision != null else false
	_crucible_captured = true
	_clear_crucible_delivery()
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	gravity_scale = 0.0
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0
	if collision != null:
		collision.set_deferred(&"disabled", true)
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
	_crucible_source = source_event.source
	_crucible_root_attack_id = source_event.root_attack_id
	_crucible_delivery_id = delivery_id
	_crucible_damage = maxf(damage, 0.0)
	_crucible_effect_flags = (
		source_event.effect_flags | DamageEvent.FLAG_GRAVITY_CRUCIBLE
	)
	_crucible_launch_velocity = launch_velocity
	_crucible_armed = _crucible_damage > 0.0 and delivery_id != 0
	if _crucible_armed:
		gravity_scale = _capture_gravity_scale * maxf(gravity_multiplier, 0.0)
		_crucible_gravity_restore_delay = maxf(gravity_restore_delay, 0.0)
		collision_mask = _capture_collision_mask | ENEMY_LAYER
	return _crucible_armed


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if airborne_crash and state.linear_velocity.length() >= MIN_CRASH_IMPACT_SPEED:
		_last_crash_velocity = state.linear_velocity


func _build_collision() -> void:
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "WreckCollision"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = collision_size
	collision.shape = rectangle
	add_child(collision)


func _build_visual() -> void:
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "WreckVisual"
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(visual)
	_update_visual()


func _update_visual() -> void:
	var visual: Sprite2D = get_node_or_null(^"WreckVisual") as Sprite2D
	if visual == null:
		return
	visual.texture = wreck_texture
	if wreck_texture != null:
		var texture_size: Vector2 = wreck_texture.get_size()
		var fit_scale: float = minf(
			display_size.x / maxf(texture_size.x, 1.0),
			display_size.y / maxf(texture_size.y, 1.0)
		)
		visual.scale = Vector2.ONE * fit_scale
		visual.modulate = Color("625d58")
		if airborne_crash:
			visual.position.y = 0.0
		else:
			visual.position.y = (
				ROAD_SETTLE_BASELINE_Y
				- global_position.y
				- visual_content_rect.end.y * absf(visual.scale.y)
			)
		visual.visible = true


func _apply_fatal_impact() -> void:
	var direction: Vector2 = Vector2.RIGHT
	var impulse_per_mass: float = 150.0
	if fatal_event != null:
		direction = fatal_event.direction
		impulse_per_mass = maxf(fatal_event.impulse_per_mass, 150.0)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	if airborne_crash:
		linear_velocity = Vector2(
			direction.x * impulse_per_mass * 0.34,
			maxf(185.0, absf(direction.y) * impulse_per_mass + 120.0)
		)
		angular_velocity = direction.x * clampf(impulse_per_mass / 28.0, 5.0, 11.0)
		return
	var impulse: Vector2 = (
		direction * impulse_per_mass * mass * 0.24
		+ Vector2.UP * mass * impulse_per_mass * 0.10
	)
	linear_velocity = impulse / mass
	angular_velocity = direction.x * clampf(impulse_per_mass / 40.0, 3.0, 8.0)


func _on_body_entered(body: Node) -> void:
	if _crucible_armed:
		_resolve_crucible_impact(body)
		return
	if not settling_to_road or not body is CollisionObject2D:
		return
	var collision_body: CollisionObject2D = body as CollisionObject2D
	if collision_body.collision_layer & REMAINS_GROUND_LAYER != 0:
		if linear_velocity.y < -5.0:
			return
		_finish_road_settling(_road_surface_y(collision_body))
		return
	if airborne_crash and collision_body.collision_layer & ENEMY_LAYER != 0:
		_queue_crash_damage(body)


func _queue_crash_damage(body: Node) -> void:
	var receiver: Node = _find_damage_receiver(body)
	if receiver == null or receiver == self:
		return
	var target_id: int = receiver.get_instance_id()
	if _crash_impact_targets.has(target_id):
		return
	var target_velocity: Vector2 = (
		(receiver as EnemyActor2D).velocity if receiver is EnemyActor2D else Vector2.ZERO
	)
	var impact_velocity: Vector2 = _last_crash_velocity - target_velocity
	var impact_speed: float = impact_velocity.length()
	if impact_speed < MIN_CRASH_IMPACT_SPEED:
		return
	_crash_impact_targets[target_id] = true
	call_deferred("_apply_crash_damage", receiver, impact_velocity)


func _apply_crash_damage(receiver: Node, impact_velocity: Vector2) -> void:
	if not is_instance_valid(receiver):
		return
	var impact_speed: float = impact_velocity.length()
	var mass_scale: float = clampf(sqrt(mass / 38.0), 0.7, 2.3)
	var damage: float = clampf(
		35.0
		+ (impact_speed - MIN_CRASH_IMPACT_SPEED)
		* CRASH_IMPACT_DAMAGE_SCALE
		* mass_scale,
		35.0,
		MAX_CRASH_IMPACT_DAMAGE
	)
	var direction: Vector2 = impact_velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector2.DOWN
	var root_attack_id: int = (
		fatal_event.root_attack_id if fatal_event != null else _crash_attack_id
	)
	var causal_depth: int = (
		mini(fatal_event.causal_depth + 1, DamageEvent.MAX_CAUSAL_DEPTH)
		if fatal_event != null
		else 1
	)
	var event: DamageEvent = DamageEvent.new(
		_crash_attack_id,
		self,
		damage,
		&"crash_impact",
		global_position,
		direction,
		impact_speed * 0.55,
		root_attack_id,
		causal_depth,
		DamageEvent.FLAG_HAZARD
	)
	if bool(receiver.call("receive_damage", event)):
		crash_impact_count += 1
		crash_impact_accepted.emit(self, event, receiver)


func _finish_road_settling(road_surface_y: float = ROAD_SETTLE_BASELINE_Y) -> void:
	var was_airborne_crash: bool = airborne_crash
	airborne_crash = false
	settling_to_road = false
	if was_airborne_crash:
		crash_landing_count += 1
	rotation = 0.0
	global_position.y = road_surface_y - collision_size.y * 0.5
	linear_velocity.y = 0.0
	angular_velocity = 0.0
	gravity_scale = 1.0
	linear_damp = 1.1
	angular_damp = 1.8
	can_sleep = true
	collision_mask = REMAINS_GROUND_LAYER | ROBOT_LAYER
	_player_overlap_ejection_target = null
	_last_crash_velocity = Vector2.ZERO
	_settle_elapsed = 0.0
	_align_visual_to_road_contact(road_surface_y)
	if was_airborne_crash:
		crash_landed.emit(self)


func _snap_to_road_baseline() -> void:
	rotation = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position.y = ROAD_SETTLE_BASELINE_Y - collision_size.y * 0.5
	_finish_road_settling()


func _align_visual_to_road_contact(road_surface_y: float) -> void:
	var visual: Sprite2D = get_node_or_null(^"WreckVisual") as Sprite2D
	if visual == null or visual.texture == null:
		return
	visual.position.y += road_surface_y - visible_bottom_y()
	if absf(visible_bottom_y() - road_surface_y) > ROAD_SETTLE_TOLERANCE:
		visual.position.y = (
			road_surface_y
			- global_position.y
			- visual_content_rect.end.y * absf(visual.scale.y)
		)


func _road_surface_y(ground_body: CollisionObject2D) -> float:
	for child: Node in ground_body.get_children():
		var collision: CollisionShape2D = child as CollisionShape2D
		if collision == null or collision.disabled or not collision.shape is RectangleShape2D:
			continue
		var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
		return collision.to_global(Vector2(0.0, -rectangle.size.y * 0.5)).y
	return ROAD_SETTLE_BASELINE_Y


func _advance_player_overlap_ejection() -> void:
	if _player_overlap_ejection_target == null:
		return
	if (
		is_instance_valid(_player_overlap_ejection_target)
		and _overlaps_player(_player_overlap_ejection_target)
	):
		return
	_player_overlap_ejection_target = null
	if _crucible_captured:
		_capture_collision_mask |= ROBOT_LAYER
	elif collision_layer != 0:
		collision_mask |= ROBOT_LAYER


func _overlaps_player(player: GiantRobotController) -> bool:
	var wreck_collision: CollisionShape2D = (
		get_node_or_null(^"WreckCollision") as CollisionShape2D
	)
	var player_collision: CollisionShape2D = (
		player.get_node_or_null(^"BodyCollision") as CollisionShape2D
	)
	if (
		wreck_collision == null
		or wreck_collision.shape == null
		or player_collision == null
		or player_collision.shape == null
	):
		var fallback_half_size: Vector2 = collision_size * 0.5 + Vector2(46.0, 102.5)
		var fallback_delta: Vector2 = global_position - player.global_position
		return (
			absf(fallback_delta.x) < fallback_half_size.x
			and absf(fallback_delta.y) < fallback_half_size.y
		)
	return _collision_world_bounds(wreck_collision).intersects(
		_collision_world_bounds(player_collision),
		true
	)


func _collision_world_bounds(collision: CollisionShape2D) -> Rect2:
	var local_bounds: Rect2 = collision.shape.get_rect()
	var corners: Array[Vector2] = [
		local_bounds.position,
		Vector2(local_bounds.end.x, local_bounds.position.y),
		local_bounds.end,
		Vector2(local_bounds.position.x, local_bounds.end.y),
	]
	var world_bounds: Rect2 = Rect2(collision.to_global(corners[0]), Vector2.ZERO)
	for corner_index: int in range(1, corners.size()):
		world_bounds = world_bounds.expand(collision.to_global(corners[corner_index]))
	return world_bounds


func _player_ejection_direction(player: GiantRobotController) -> float:
	var horizontal_delta: float = global_position.x - player.global_position.x
	if absf(horizontal_delta) > 1.0:
		return signf(horizontal_delta)
	if fatal_event != null and absf(fatal_event.direction.x) > 0.05:
		return signf(fatal_event.direction.x)
	return -1.0 if player.facing < 0 else 1.0


func _resolved_content_rect(requested_rect: Rect2) -> Rect2:
	if requested_rect.has_area():
		return requested_rect
	if wreck_texture == null:
		return Rect2(-display_size * 0.5, display_size)
	var texture_size: Vector2 = wreck_texture.get_size()
	return Rect2(-texture_size * 0.5, texture_size)


func _resolve_crucible_impact(body: Node) -> void:
	if not _crucible_armed:
		return
	var receiver: EnemyActor2D = _find_damage_receiver(body) as EnemyActor2D
	if receiver != null and (not receiver.active or receiver.dead):
		receiver = null
	var receiver_velocity: Vector2 = (
		receiver.velocity if receiver != null else Vector2.ZERO
	)
	var relative_velocity: Vector2 = linear_velocity - receiver_velocity
	var launched_relative: Vector2 = _crucible_launch_velocity - receiver_velocity
	if launched_relative.length_squared() > relative_velocity.length_squared():
		relative_velocity = launched_relative
	if relative_velocity.length() < MIN_CRASH_IMPACT_SPEED:
		return
	var direction: Vector2 = relative_velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var event: DamageEvent = DamageEvent.new(
		_crucible_delivery_id,
		_crucible_source,
		_crucible_damage,
		&"debris_impact",
		global_position,
		direction,
		relative_velocity.length() * 0.45,
		_crucible_root_attack_id,
		1,
		_crucible_effect_flags
	)
	_clear_crucible_delivery()
	if receiver != null and receiver.receive_damage(event):
		crash_impact_count += 1
		crash_impact_accepted.emit(self, event, receiver)
	crucible_detonated.emit(self, event)
	_turn_to_scrap(event)


func _find_damage_receiver(start_node: Node) -> Node:
	var receiver: Node = start_node
	while receiver != null:
		if receiver.has_method("receive_damage"):
			return receiver
		receiver = receiver.get_parent()
	return null


func _restore_after_crucible(
	restored_velocity: Vector2,
	restored_angular_velocity: float
) -> void:
	_crucible_captured = false
	freeze = false
	sleeping = false
	gravity_scale = _capture_gravity_scale
	linear_damp = _capture_linear_damp
	angular_damp = _capture_angular_damp
	can_sleep = _capture_can_sleep
	collision_layer = _capture_collision_layer
	collision_mask = _capture_collision_mask
	var collision: CollisionShape2D = get_node_or_null(^"WreckCollision") as CollisionShape2D
	if collision != null:
		collision.set_deferred(&"disabled", _capture_shape_disabled)
	linear_velocity = restored_velocity
	angular_velocity = restored_angular_velocity
	reset_physics_interpolation()


func _clear_crucible_delivery() -> void:
	if not _crucible_captured:
		gravity_scale = _capture_gravity_scale
	_crucible_armed = false
	_crucible_source = null
	_crucible_root_attack_id = 0
	_crucible_delivery_id = 0
	_crucible_damage = 0.0
	_crucible_effect_flags = DamageEvent.FLAG_NONE
	_crucible_launch_velocity = Vector2.ZERO
	_crucible_gravity_restore_delay = 0.0
	if not _crucible_captured and collision_layer != 0:
		collision_mask = _capture_collision_mask


func _advance_crucible_gravity(delta: float) -> void:
	if not _crucible_armed or _crucible_gravity_restore_delay <= 0.0:
		return
	_crucible_gravity_restore_delay = maxf(
		_crucible_gravity_restore_delay - maxf(delta, 0.0),
		0.0
	)
	if is_zero_approx(_crucible_gravity_restore_delay):
		gravity_scale = _capture_gravity_scale


static func _allocate_crash_attack_id() -> int:
	_next_crash_attack_id += 1
	return _next_crash_attack_id


func _turn_to_scrap(event: DamageEvent) -> void:
	scrapped_state = true
	_player_overlap_ejection_target = null
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var collision: CollisionShape2D = get_node(^"WreckCollision") as CollisionShape2D
	collision.set_deferred(&"disabled", true)
	var visual: Sprite2D = get_node(^"WreckVisual") as Sprite2D
	visual.visible = false
	scrapped.emit(self, event)
