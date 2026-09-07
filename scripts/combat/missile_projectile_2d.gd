class_name MissileProjectile2D
extends CharacterBody2D

signal explosion_requested(
	missile: MissileProjectile2D,
	world_position: Vector2,
	attack_id: int,
	root_attack_id: int
)

const SPEED: float = 560.0
const LIFETIME: float = 1.65
const TURN_SPEED: float = 5.5
const FUSE_RADIUS: float = 24.0
const BODY_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/player_missile_body.png"
)
const EXHAUST_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/missile_exhaust.png"
)

var active: bool = false
var paused: bool = false
var target: EnemyActor2D
var target_generation: int = 0
var last_known_point: Vector2 = Vector2.ZERO
var attack_id: int = 0
var root_attack_id: int = 0
var remaining_lifetime: float = LIFETIME
var using_last_known: bool = false
var _detonation_requested: bool = false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 0
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 7.0
	collision.shape = circle
	add_child(collision)
	z_index = 68
	deactivate()


func activate(
	origin: Vector2,
	p_target: EnemyActor2D,
	generation: int,
	fallback_point: Vector2,
	p_attack_id: int,
	p_root_attack_id: int
) -> void:
	global_position = origin
	target = p_target
	target_generation = generation
	last_known_point = fallback_point
	attack_id = p_attack_id
	root_attack_id = p_root_attack_id
	remaining_lifetime = LIFETIME
	using_last_known = false
	_detonation_requested = false
	active = true
	visible = true
	set_physics_process(true)
	collision_mask = (1 << 0) | (1 << 2) | (1 << 3) | (1 << 6)
	var initial_direction: Vector2 = global_position.direction_to(last_known_point)
	if initial_direction.is_zero_approx():
		initial_direction = Vector2.RIGHT
	velocity = initial_direction * SPEED
	rotation = velocity.angle()
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)
	collision_mask = 0
	velocity = Vector2.ZERO
	target = null
	target_generation = 0
	remaining_lifetime = LIFETIME
	using_last_known = false
	_detonation_requested = false


func request_explosion() -> bool:
	if not active or _detonation_requested:
		return false
	_detonation_requested = true
	explosion_requested.emit(self, global_position, attack_id, root_attack_id)
	return true


func rebase_cached_world_state(offset: Vector2) -> void:
	if active:
		last_known_point += offset


func _physics_process(delta: float) -> void:
	if not active or paused:
		return
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		request_explosion()
		return
	_update_target_point()
	var desired_direction: Vector2 = global_position.direction_to(last_known_point)
	if not desired_direction.is_zero_approx():
		var desired_angle: float = desired_direction.angle()
		rotation = rotate_toward(rotation, desired_angle, TURN_SPEED * delta)
		velocity = Vector2.RIGHT.rotated(rotation) * SPEED
	if global_position.distance_squared_to(last_known_point) <= FUSE_RADIUS * FUSE_RADIUS:
		request_explosion()
		return
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision != null:
		request_explosion()


func _draw() -> void:
	draw_texture_rect(
		EXHAUST_TEXTURE,
		Rect2(Vector2(-36.0, -9.0), Vector2(20.0, 18.0)),
		false
	)
	draw_texture_rect(
		BODY_TEXTURE,
		Rect2(Vector2(-22.0, -10.0), Vector2(44.0, 20.0)),
		false
	)


func _update_target_point() -> void:
	if (
		target != null
		and target.active
		and not target.dead
		and target.activation_generation == target_generation
	):
		last_known_point = target.global_position
		using_last_known = false
		return
	target = null
	using_last_known = true
