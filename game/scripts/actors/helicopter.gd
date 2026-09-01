class_name HelicopterEnemy
extends EnemyActor2D

enum State {
	APPROACH,
	STRAFE,
	ANTICIPATE,
	BREAK,
}

@export var maximum_speed: float = 205.0
@export var acceleration: float = 320.0
@export var standoff_x: float = 520.0
@export var portrait_standoff_x: float = 280.0
@export var lane_y: float = 180.0
@export var fire_interval: float = 1.75
@export var rocket_speed: float = 440.0
@export var rocket_damage: float = 16.0
@export var anticipation_duration: float = 0.78

var state: State = State.APPROACH
var _cooldown: float = 1.0
var _state_time: float = 0.0
var _attack_side: int = 1


func _ready() -> void:
	max_health = 95.0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(AerialDebrisLauncher.AIRBORNE_GROUP)
	super._ready()


func _physics_process(delta: float) -> void:
	if dead or not active or target == null:
		return
	if state == State.ANTICIPATE:
		velocity = velocity.move_toward(
			Vector2.ZERO, acceleration * acceleration_multiplier * delta
		)
		if advance_telegraph(delta):
			_fire_snapshot()
			state = State.STRAFE
			_cooldown = fire_interval * attack_interval_multiplier \
				* external_attack_interval_multiplier * aura_attack_interval_multiplier
		move_and_slide()
		return
	_update_facing()
	_state_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var desired_point: Vector2 = Vector2(
		target.global_position.x + float(_attack_side) * effective_standoff_x(),
		lane_y
	)
	if state == State.APPROACH and global_position.distance_to(desired_point) < 70.0:
		state = State.STRAFE
		_state_time = 0.0
	elif state == State.STRAFE and _state_time > 4.0:
		state = State.BREAK
		_state_time = 0.0
	elif state == State.BREAK and _state_time > 1.4:
		_attack_side *= -1
		state = State.APPROACH
		_state_time = 0.0
	var desired_velocity: Vector2
	if state == State.BREAK:
		desired_velocity = Vector2(
			float(_attack_side) * maximum_speed * movement_multiplier,
			-35.0
		)
	else:
		desired_velocity = (
			global_position.direction_to(desired_point)
			* maximum_speed
			* movement_multiplier
		)
	velocity = velocity.move_toward(
		desired_velocity, acceleration * acceleration_multiplier * delta
	)
	if state == State.STRAFE and _cooldown <= 0.0:
		_begin_rocket()
	move_and_slide()


func _begin_rocket() -> void:
	var origin: Vector2 = global_position + Vector2(float(facing) * 62.0, 18.0)
	var damage_output: float = rocket_damage * projectile_damage_multiplier * aura_damage_multiplier
	if begin_telegraph(
		&"rocket",
		anticipation_duration,
		origin,
		target.global_position,
		damage_output
	):
		state = State.ANTICIPATE
	else:
		_cooldown = 0.25


func effective_standoff_x() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	return portrait_standoff_x if viewport_size.y > viewport_size.x else standoff_x


func _fire_snapshot() -> void:
	fire_telegraphed_projectile(
		rocket_speed,
		rocket_damage * projectile_damage_multiplier * aura_damage_multiplier
	)


func _reset_archetype_state() -> void:
	state = State.APPROACH
	_cooldown = 1.0
	_state_time = 0.0
	_attack_side = 1
