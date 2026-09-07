class_name SoldierEnemy
extends EnemyActor2D

enum State {
	APPROACH,
	AIM,
	ANTICIPATE,
	RETREAT,
}

@export var move_speed: float = 108.0
@export var acceleration: float = 520.0
@export var preferred_range: float = 430.0
@export var minimum_range: float = 250.0
@export var fire_interval: float = 0.95
@export var projectile_speed: float = 720.0
@export var projectile_damage: float = 8.0
@export var anticipation_duration: float = 0.38
@export var gravity: float = 1400.0

var state: State = State.APPROACH
var _cooldown: float = 0.35


func _physics_process(delta: float) -> void:
	if dead or not active:
		return
	if state == State.ANTICIPATE:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		if advance_telegraph(delta):
			_fire_snapshot()
			state = State.AIM
			_cooldown = fire_interval * attack_interval_multiplier \
				* external_attack_interval_multiplier * aura_attack_interval_multiplier
		move_and_slide()
		update_movement_bounce(delta)
		return
	_update_facing()
	velocity.y = minf(velocity.y + gravity * delta, 900.0)
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		move_and_slide()
		update_movement_bounce(delta)
		return
	var distance_x: float = absf(target.global_position.x - global_position.x)
	if distance_x > preferred_range + 45.0:
		state = State.APPROACH
	elif distance_x < minimum_range:
		state = State.RETREAT
	else:
		state = State.AIM
	var desired_speed: float = 0.0
	if state == State.APPROACH:
		desired_speed = float(facing) * move_speed * movement_multiplier
	elif state == State.RETREAT:
		desired_speed = -float(facing) * move_speed * movement_multiplier
	velocity.x = move_toward(velocity.x, desired_speed, acceleration * delta)
	_cooldown = maxf(_cooldown - delta, 0.0)
	if state == State.AIM and _cooldown <= 0.0:
		_begin_fire()
	move_and_slide()
	update_movement_bounce(delta)


func _begin_fire() -> void:
	var origin: Vector2 = attack_telegraph_origin()
	var target_point: Vector2 = target.global_position + Vector2(0.0, 45.0)
	if (
		role_id == &"CATALYST_MARKER"
		and catalyst_target != null
		and catalyst_target.armed
		and not catalyst_target.spent
	):
		target_point = catalyst_target.global_position
	var damage_output: float = (
		projectile_damage * projectile_damage_multiplier * aura_damage_multiplier
	)
	if begin_telegraph(&"bullet", anticipation_duration, origin, target_point, damage_output):
		state = State.ANTICIPATE
	else:
		_cooldown = 0.15


func _fire_snapshot() -> void:
	fire_telegraphed_projectile(
		projectile_speed,
		projectile_damage * projectile_damage_multiplier * aura_damage_multiplier
	)


func _reset_archetype_state() -> void:
	state = State.APPROACH
	_cooldown = 0.35
