class_name Projectile2D
extends CharacterBody2D

signal recycle_requested(projectile: Projectile2D)
signal impact_requested(
	projectile: Projectile2D,
	world_position: Vector2,
	direction: Vector2,
	kind: StringName,
	impact_key: StringName,
	damage_value: float
)

const MACHINE_GUN_ROUND_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/machine_gun_round.png"
)

static var _next_attack_id: int = 10000

var damage: float = 10.0
var source: Node
var lifetime: float = 2.5
var projectile_color: Color = Color("ffb45e")
var projectile_radius: float = 5.0
var presentation_scale: float = 1.0
var damage_type: StringName = &"projectile"
var visual_key: StringName = &""
var impact_key: StringName = &""
var active: bool = false
var _attack_id: int
var _root_attack_id: int


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_build_collision()
	queue_redraw()


func setup(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	p_damage: float,
	p_source: Node,
	target_mask: int,
	kind: StringName = &"bullet",
	p_visual_key: StringName = &"",
	p_presentation_scale: float = 1.0,
	p_delivery_lifetime: float = 2.5
) -> void:
	activate(
		origin,
		direction,
		speed,
		p_damage,
		p_source,
		target_mask,
		kind,
		p_visual_key,
		p_presentation_scale,
		p_delivery_lifetime
	)


func activate(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	p_damage: float,
	p_source: Node,
	target_mask: int,
	kind: StringName = &"bullet",
	p_visual_key: StringName = &"",
	p_presentation_scale: float = 1.0,
	p_delivery_lifetime: float = 2.5
) -> void:
	_next_attack_id += 1
	_attack_id = _next_attack_id
	_root_attack_id = _attack_id
	active = true
	visible = true
	set_physics_process(true)
	lifetime = maxf(p_delivery_lifetime, 0.01)
	global_position = origin
	velocity = direction.normalized() * speed
	damage = p_damage
	source = p_source
	collision_layer = 0
	collision_mask = target_mask
	damage_type = kind
	presentation_scale = maxf(p_presentation_scale, 0.01)
	visual_key = (
		p_visual_key
		if not p_visual_key.is_empty()
		else ProjectileVisualCatalog.default_key(kind)
	)
	impact_key = StringName(
		ProjectileVisualCatalog.spec(visual_key).get("impact_key", &"")
	)
	if kind == &"shell":
		projectile_radius = 9.0
		projectile_color = Color("ff7d3e")
	elif kind == &"rocket":
		projectile_radius = 7.0
		projectile_color = Color("ff9d52")
	elif kind == &"machine_gun":
		projectile_radius = 4.0
		projectile_color = Color("78e7ff")
	else:
		projectile_radius = 5.0
		projectile_color = Color("ffb45e")
	var visual_spec: Dictionary = ProjectileVisualCatalog.spec(visual_key)
	projectile_radius = float(
		visual_spec.get("collision_radius_contract", projectile_radius)
	)
	var collision: CollisionShape2D = get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = maxf(
			projectile_radius * presentation_scale,
			5.0
		)
	queue_redraw()


func set_delivery_identity(
	p_attack_id: int,
	p_root_attack_id: int,
	delivery_lifetime: float
) -> void:
	_attack_id = p_attack_id
	_root_attack_id = p_root_attack_id if p_root_attack_id != 0 else p_attack_id
	lifetime = maxf(delivery_lifetime, 0.01)


func attack_id() -> int:
	return _attack_id


func root_attack_id() -> int:
	return _root_attack_id


func deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	source = null
	lifetime = 2.5
	visual_key = &""
	impact_key = &""
	projectile_color = Color("ffb45e")
	projectile_radius = 5.0
	presentation_scale = 1.0
	damage_type = &"projectile"
	modulate = Color.WHITE
	var collision: CollisionShape2D = get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = 5.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not active:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		recycle_requested.emit(self)
		return
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision == null:
		return
	var hit_position: Vector2 = collision.get_position()
	_deliver_damage(collision.get_collider() as Object, hit_position)
	impact_requested.emit(
		self,
		hit_position,
		velocity.normalized(),
		damage_type,
		impact_key,
		damage
	)
	recycle_requested.emit(self)


func _draw() -> void:
	if damage_type == &"machine_gun":
		draw_set_transform(
			Vector2.ZERO,
			velocity.angle(),
			Vector2.ONE * presentation_scale
		)
		draw_texture_rect(
			MACHINE_GUN_ROUND_TEXTURE,
			Rect2(Vector2(-18.0, -6.0), Vector2(36.0, 12.0)),
			false
		)
		return
	var visual_spec: Dictionary = ProjectileVisualCatalog.spec(visual_key)
	if not visual_spec.is_empty():
		var texture: Texture2D = visual_spec.get("texture") as Texture2D
		var display_size: Vector2 = visual_spec.get("display_size", Vector2.ZERO)
		var region: Rect2i = visual_spec.get("region", Rect2i())
		if texture != null and display_size.x > 0.0 and display_size.y > 0.0:
			var visible_center_offset: Vector2 = _rendered_visible_center_offset(
				visual_spec
			)
			var destination: Rect2 = Rect2(
				-display_size * 0.5 - visible_center_offset,
				display_size
			)
			draw_set_transform(
				Vector2.ZERO,
				visual_angle(),
				Vector2.ONE * presentation_scale
			)
			if region.size == Vector2i.ZERO:
				draw_texture_rect(
					texture,
					destination,
					false
				)
			else:
				draw_texture_rect_region(
					texture,
					destination,
					Rect2(region)
				)
			return
	var scaled_radius: float = projectile_radius * presentation_scale
	var trail: float = maxf(14.0 * presentation_scale, scaled_radius * 3.0)
	var backward: Vector2 = -velocity.normalized() * trail
	draw_line(Vector2.ZERO, backward, projectile_color.darkened(0.35), scaled_radius)
	draw_circle(Vector2.ZERO, scaled_radius, projectile_color)


func visual_angle() -> float:
	var visual_spec: Dictionary = ProjectileVisualCatalog.spec(visual_key)
	return velocity.angle() + float(visual_spec.get("canonical_angle", 0.0))


func rendered_display_size() -> Vector2:
	var visual_spec: Dictionary = ProjectileVisualCatalog.spec(visual_key)
	return (visual_spec.get("display_size", Vector2.ZERO) as Vector2) * presentation_scale


func rendered_visible_center_offset() -> Vector2:
	return _rendered_visible_center_offset(
		ProjectileVisualCatalog.spec(visual_key)
	) * presentation_scale


func _rendered_visible_center_offset(visual_spec: Dictionary) -> Vector2:
	var source_offset: Vector2 = visual_spec.get(
		"visible_center_offset",
		Vector2.ZERO
	) as Vector2
	var display_size: Vector2 = visual_spec.get("display_size", Vector2.ZERO) as Vector2
	var region: Rect2i = visual_spec.get("region", Rect2i()) as Rect2i
	var source_size: Vector2 = Vector2(region.size)
	if source_size == Vector2.ZERO:
		source_size = Vector2(visual_spec.get("source_size", Vector2i.ONE) as Vector2i)
	return Vector2(
		source_offset.x * display_size.x / maxf(source_size.x, 1.0),
		source_offset.y * display_size.y / maxf(source_size.y, 1.0)
	)


func _build_collision() -> void:
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = maxf(projectile_radius, 5.0)
	shape_node.shape = shape
	add_child(shape_node)


func _deliver_damage(collider: Object, hit_position: Vector2) -> void:
	var receiver: Node = collider as Node
	while receiver != null:
		if receiver.has_method("receive_damage"):
			var event: DamageEvent = DamageEvent.new(
				_attack_id,
				source,
				damage,
				damage_type,
				hit_position,
				velocity.normalized(),
					0.0,
					_root_attack_id
				)
			receiver.call("receive_damage", event)
			return
		receiver = receiver.get_parent()
