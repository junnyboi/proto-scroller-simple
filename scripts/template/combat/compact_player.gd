class_name CompactPlayer
extends CharacterBody2D

signal health_changed(current_health: float, maximum_health: float)
signal defeated
signal attack_released(
	origin: Vector2,
	radius: float,
	damage: float,
	facing: int,
	charge_ratio: float
)

@export_group("Movement")
@export var move_speed: float = 260.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var gravity: float = 1400.0
@export var world_bounds: Vector2 = Vector2(72.0, 1208.0)

@export_group("Durability")
@export var max_health: float = 120.0

@export_group("Attack")
@export var base_attack_damage: float = 45.0
@export var charged_attack_damage: float = 110.0
@export var base_attack_radius: float = 128.0
@export var charged_attack_radius: float = 190.0
@export var full_charge_seconds: float = 0.75
@export var attack_cooldown_seconds: float = 0.28

@export_group("Dodge")
@export var dodge_speed: float = 900.0
@export var dodge_duration: float = 0.16
@export var dodge_invulnerability_seconds: float = 0.26
@export var dodge_cooldown_seconds: float = 1.0

var current_health: float = 0.0
var facing: int = 1
var disabled: bool = false
var charging: bool = false
var charge_elapsed: float = 0.0
var attack_cooldown_remaining: float = 0.0
var dodge_cooldown_remaining: float = 0.0
var dodge_remaining: float = 0.0
var invulnerability_remaining: float = 0.0

@onready var visual: Sprite2D = %Visual


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	up_direction = Vector2.UP
	floor_snap_length = 6.0
	current_health = max_health
	health_changed.emit(current_health, max_health)
	_apply_facing()


func _physics_process(delta: float) -> void:
	if disabled:
		return
	var input_axis: float = Input.get_axis(&"move_left", &"move_right")
	if Input.is_action_just_pressed(&"stomp"):
		begin_attack_charge()
	if Input.is_action_just_released(&"stomp"):
		release_attack_charge()
	if Input.is_action_just_pressed(&"dodge"):
		request_dodge(_axis_facing(input_axis))
	physics_step(input_axis, delta)


func physics_step(input_axis: float, delta: float) -> void:
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	dodge_cooldown_remaining = maxf(dodge_cooldown_remaining - delta, 0.0)
	invulnerability_remaining = maxf(invulnerability_remaining - delta, 0.0)
	if charging:
		charge_elapsed = minf(charge_elapsed + delta, full_charge_seconds)
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	elif dodge_remaining > 0.0:
		dodge_remaining = maxf(dodge_remaining - delta, 0.0)
		velocity.x = float(facing) * dodge_speed
	else:
		var axis: float = clampf(input_axis, -1.0, 1.0)
		if not is_zero_approx(axis):
			var next_facing: int = _axis_facing(axis)
			if next_facing != facing:
				facing = next_facing
				_apply_facing()
		velocity.x = move_toward(
			velocity.x,
			axis * move_speed,
			(acceleration if not is_zero_approx(axis) else deceleration) * delta
		)
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 900.0)
	move_and_slide()
	global_position.x = clampf(global_position.x, world_bounds.x, world_bounds.y)


func begin_attack_charge() -> bool:
	if disabled or charging or dodge_remaining > 0.0 or attack_cooldown_remaining > 0.0:
		return false
	charging = true
	charge_elapsed = 0.0
	return true


func release_attack_charge() -> bool:
	if not charging or disabled:
		return false
	charging = false
	var ratio: float = clampf(charge_elapsed / maxf(full_charge_seconds, 0.01), 0.0, 1.0)
	charge_elapsed = 0.0
	attack_cooldown_remaining = attack_cooldown_seconds
	attack_released.emit(
		global_position + Vector2(float(facing) * 58.0, -58.0),
		lerpf(base_attack_radius, charged_attack_radius, ratio),
		lerpf(base_attack_damage, charged_attack_damage, ratio),
		facing,
		ratio
	)
	return true


func request_dodge(direction: int = 0) -> bool:
	if disabled or charging or dodge_remaining > 0.0 or dodge_cooldown_remaining > 0.0:
		return false
	var selected: int = clampi(direction, -1, 1)
	if selected == 0:
		selected = facing
	facing = selected
	_apply_facing()
	dodge_remaining = dodge_duration
	invulnerability_remaining = dodge_invulnerability_seconds
	dodge_cooldown_remaining = dodge_cooldown_seconds
	velocity.x = float(facing) * dodge_speed
	return true


func receive_damage(amount: float) -> bool:
	if disabled or amount <= 0.0 or invulnerability_remaining > 0.0:
		return false
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		disabled = true
		charging = false
		velocity = Vector2.ZERO
		defeated.emit()
	return true


func set_combat_disabled(value: bool) -> void:
	disabled = value
	if disabled:
		charging = false
		velocity = Vector2.ZERO


func _axis_facing(axis: float) -> int:
	if axis < 0.0:
		return -1
	if axis > 0.0:
		return 1
	return 0


func _apply_facing() -> void:
	if visual != null:
		visual.flip_h = facing < 0
