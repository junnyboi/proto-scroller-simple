class_name DirectionalShockwave2D
extends Node2D

const ENEMY_LAYER: int = 1 << 2
const HURTBOX_LAYER: int = 1 << 6
const PROP_LAYER: int = 1 << 7
const DEBRIS_LAYER: int = 1 << 8
const REMAINS_LAYER: int = 1 << 9
const TARGET_MASK: int = ENEMY_LAYER | HURTBOX_LAYER | PROP_LAYER | DEBRIS_LAYER | REMAINS_LAYER
const FIST_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/directional_punch_fist.png"
)
const FIST_DISPLAY_SIZE: Vector2 = Vector2(168.0, 94.5)
const HIT_SIZE: Vector2 = Vector2(112.0, 82.0)
const MAX_RESULTS: int = 24

var active: bool = false
var paused: bool = false
var age: float = 0.0
var delay_seconds: float = 0.0
var lifetime: float = 0.72
var speed: float = 1280.0
var facing: int = 1
var delivery_id: int = 0
var root_attack_id: int = 0
var damage: float = 0.0
var impulse_per_mass: float = 0.0
var effect_flags: int = DamageEvent.FLAG_NONE
var source: Node
var accepted_hit_count: int = 0
var _launched: bool = false
var _seen_targets: Dictionary[int, bool] = {}
var _shape: RectangleShape2D = RectangleShape2D.new()
var _parameters: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()


func _init() -> void:
	_shape.size = HIT_SIZE
	_parameters.shape = _shape


func _ready() -> void:
	z_index = 72
	visible = false
	set_process(false)


func activate(
	world_position: Vector2,
	p_facing: int,
	p_delivery_id: int,
	p_root_attack_id: int,
	p_source: Node,
	p_rank: int,
	p_effect_flags: int,
	p_delay_seconds: float = 0.0
) -> void:
	global_position = world_position
	facing = 1 if p_facing >= 0 else -1
	delivery_id = p_delivery_id
	root_attack_id = p_root_attack_id
	source = p_source
	damage = 10.0 + float(maxi(p_rank - 1, 0)) * 4.0
	impulse_per_mass = 420.0 + float(maxi(p_rank - 1, 0)) * 80.0
	effect_flags = p_effect_flags
	delay_seconds = maxf(p_delay_seconds, 0.0)
	age = 0.0
	accepted_hit_count = 0
	_launched = false
	_seen_targets.clear()
	active = true
	visible = delay_seconds <= 0.0
	set_process(true)
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)
	source = null
	_seen_targets.clear()


func _process(delta: float) -> void:
	if not active or paused:
		return
	age += delta
	if age < delay_seconds:
		return
	if not _launched:
		_launched = true
		visible = true
	global_position.x += float(facing) * speed * delta
	_resolve_hits()
	if age - delay_seconds >= lifetime:
		deactivate()
		return
	queue_redraw()


func _resolve_hits() -> void:
	_parameters.transform = Transform2D(0.0, global_position)
	_parameters.collision_mask = TARGET_MASK
	_parameters.collide_with_areas = true
	_parameters.collide_with_bodies = true
	_parameters.exclude = []
	if source is CollisionObject2D:
		_parameters.exclude = [(source as CollisionObject2D).get_rid()]
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(
		_parameters,
		MAX_RESULTS
	)
	for result: Dictionary in results:
		var collider: Node2D = result.get("collider") as Node2D
		if collider == null or collider == source:
			continue
		if source != null and source.is_ancestor_of(collider):
			continue
		var receiver: Node = DamageReceiverLookup.find(collider)
		var target: Node = receiver if receiver != null else collider
		var target_id: int = target.get_instance_id()
		if _seen_targets.has(target_id):
			continue
		_seen_targets[target_id] = true
		var event: DamageEvent = DamageEvent.new(
			delivery_id,
			source,
			damage,
			&"punch_shockwave",
			collider.global_position,
			Vector2(float(facing), -0.04).normalized(),
			impulse_per_mass,
			root_attack_id,
			1,
			effect_flags
		)
		var accepted: bool = false
		if receiver != null:
			accepted = bool(receiver.call("receive_damage", event))
		accepted = _apply_rigid_impulse(target, collider, event) or accepted
		if accepted:
			accepted_hit_count += 1


func _apply_rigid_impulse(target: Node, collider: Node, event: DamageEvent) -> bool:
	var body: RigidBody2D = target as RigidBody2D
	if body == null:
		body = collider as RigidBody2D
	if body == null:
		body = collider.get_parent() as RigidBody2D
	if body == null or event.impulse_per_mass <= 0.0:
		return false
	if body.freeze:
		body.freeze = false
		body.sleeping = false
	body.apply_central_impulse(event.direction * event.impulse_per_mass * body.mass)
	return true


func _draw() -> void:
	if not active or not _launched:
		return
	var ratio: float = clampf((age - delay_seconds) / lifetime, 0.0, 1.0)
	var alpha: float = 1.0 - pow(ratio, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(facing), 1.0))
	draw_texture_rect(
		FIST_TEXTURE,
		Rect2(-FIST_DISPLAY_SIZE * 0.5, FIST_DISPLAY_SIZE),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
