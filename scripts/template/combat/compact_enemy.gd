class_name CompactEnemy
extends CharacterBody2D

signal defeated(enemy: CompactEnemy, score_value: int, world_position: Vector2)
signal damage_requested(amount: float)

@export var acceleration: float = 520.0
@export var gravity: float = 1400.0

var definition: CompactEnemyDefinition
var target: CompactPlayer
var current_health: float = 0.0
var active: bool = false
var attack_cooldown_remaining: float = 0.0

@onready var visual: Sprite2D = %Visual
@onready var collision_shape: CollisionShape2D = %CollisionShape


func _ready() -> void:
	deactivate()


func _physics_process(delta: float) -> void:
	simulation_step(delta)


func configure(p_definition: CompactEnemyDefinition) -> bool:
	if p_definition == null or not p_definition.is_valid():
		return false
	definition = p_definition
	visual.texture = definition.texture
	visual.scale = definition.visual_scale
	visual.position.y = -definition.collision_size.y * 0.5
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = definition.collision_size
	collision_shape.shape = shape
	collision_shape.position.y = -definition.collision_size.y * 0.5
	return true


func activate(
	p_definition: CompactEnemyDefinition,
	p_target: CompactPlayer,
	world_position: Vector2
) -> bool:
	if not configure(p_definition):
		return false
	target = p_target
	global_position = world_position
	current_health = definition.max_health
	attack_cooldown_remaining = definition.attack_interval * 0.5
	velocity = Vector2.ZERO
	active = true
	visible = true
	set_physics_process(true)
	return true


func deactivate() -> void:
	active = false
	target = null
	velocity = Vector2.ZERO
	visible = false
	set_physics_process(false)


func simulation_step(delta: float) -> void:
	if not active or definition == null or target == null or target.disabled:
		return
	var delta_x: float = target.global_position.x - global_position.x
	var distance: float = absf(delta_x)
	var facing: int = -1 if delta_x < 0.0 else 1
	visual.flip_h = facing < 0
	if distance > definition.attack_range:
		velocity.x = move_toward(
			velocity.x,
			float(facing) * definition.move_speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
		if is_zero_approx(attack_cooldown_remaining):
			damage_requested.emit(definition.contact_damage)
			attack_cooldown_remaining = definition.attack_interval
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 900.0)
	move_and_slide()


func receive_damage(amount: float) -> bool:
	if not active or amount <= 0.0:
		return false
	current_health = maxf(current_health - amount, 0.0)
	if current_health > 0.0:
		return true
	var defeated_position: Vector2 = global_position
	var score_value: int = definition.score_value
	active = false
	visible = false
	set_physics_process(false)
	velocity = Vector2.ZERO
	defeated.emit(self, score_value, defeated_position)
	return true
