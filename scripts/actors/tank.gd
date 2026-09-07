class_name TankEnemy
extends EnemyActor2D

enum State {
	ADVANCE,
	AIM,
	ANTICIPATE,
	REVERSE,
}

@export var move_speed: float = 70.0
@export var acceleration: float = 260.0
@export var preferred_range: float = 610.0
@export var minimum_range: float = 390.0
@export var fire_interval: float = 2.30
@export var shell_speed: float = 560.0
@export var shell_damage: float = 24.0
@export var anticipation_duration: float = 0.68
@export var gravity: float = 1400.0

var state: State = State.ADVANCE
var _cooldown: float = 1.25


func _ready() -> void:
	max_health = 170.0 * EnemyArchetypeCatalog.GROUND_VEHICLE_HEALTH_MULTIPLIER
	super._ready()


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
	velocity.y = minf(velocity.y + gravity * delta, 900.0)
	if target == null:
		move_and_slide()
		update_movement_bounce(delta)
		return
	_update_facing()
	var distance_x: float = absf(target.global_position.x - global_position.x)
	if distance_x > preferred_range + 70.0:
		state = State.ADVANCE
	elif distance_x < minimum_range:
		state = State.REVERSE
	else:
		state = State.AIM
	var desired_speed: float = 0.0
	if state == State.ADVANCE:
		desired_speed = float(facing) * move_speed * movement_multiplier
	elif state == State.REVERSE:
		desired_speed = -float(facing) * move_speed * movement_multiplier
	velocity.x = move_toward(velocity.x, desired_speed, acceleration * delta)
	_cooldown = maxf(_cooldown - delta, 0.0)
	if state == State.AIM and _cooldown <= 0.0:
		_begin_shell()
	move_and_slide()
	update_movement_bounce(delta)


func _begin_shell() -> void:
	var origin: Vector2 = attack_telegraph_origin()
	var target_point: Vector2 = target.global_position + Vector2(0.0, 35.0)
	if role_id == &"SUPPORT_BREAKER" and structural_target != null:
		var cell: Destructible2D = structural_target.get_cell(1, 1)
		if cell != null and not cell.is_destroyed():
			target_point = cell.global_position
	var damage_output: float = shell_damage * projectile_damage_multiplier * aura_damage_multiplier
	if begin_telegraph(&"shell", anticipation_duration, origin, target_point, damage_output):
		state = State.ANTICIPATE
	else:
		_cooldown = 0.20


func _fire_snapshot() -> void:
	fire_telegraphed_projectile(
		shell_speed,
		shell_damage * projectile_damage_multiplier * aura_damage_multiplier
	)


func _reset_archetype_state() -> void:
	state = State.ADVANCE
	_cooldown = 1.25
