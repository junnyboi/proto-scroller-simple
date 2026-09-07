class_name EnemyTraitRuntime
extends Node

const COMMAND_INTERVAL_MULTIPLIER: float = 0.78
const VOLATILE_IMPULSE: float = 820.0

var dependencies: UrbanSiegeDependencies
var command_source: EnemyActor2D
var command_break_count: int = 0
var volatile_pulse_count: int = 0


func setup(p_dependencies: UrbanSiegeDependencies) -> void:
	dependencies = p_dependencies
	dependencies.encounter_runtime.enemy_acquired.connect(_on_enemy_acquired)
	dependencies.encounter_runtime.enemy_died.connect(_on_enemy_died)


func reset_all() -> void:
	command_source = null
	for enemy: EnemyActor2D in dependencies.encounter_runtime.all_actors():
		enemy.external_attack_interval_multiplier = 1.0


func _on_enemy_acquired(enemy: EnemyActor2D) -> void:
	if enemy.trait_id == &"COMMAND":
		command_source = enemy
		_apply_command_aura()
	elif command_source != null and command_source.active and not command_source.dead:
		enemy.external_attack_interval_multiplier = COMMAND_INTERVAL_MULTIPLIER


func _on_enemy_died(enemy: EnemyActor2D, event: DamageEvent, _points: int) -> void:
	if enemy == command_source:
		command_source = null
		command_break_count += 1
		for actor: EnemyActor2D in dependencies.encounter_runtime.all_actors():
			actor.external_attack_interval_multiplier = 1.0
	if enemy.trait_id == &"VOLATILE":
		_queue_volatile_pulse(enemy.global_position, event)


func _apply_command_aura() -> void:
	for enemy: EnemyActor2D in dependencies.encounter_runtime.all_actors():
		if enemy.active and enemy != command_source:
			enemy.external_attack_interval_multiplier = COMMAND_INTERVAL_MULTIPLIER


func _queue_volatile_pulse(origin: Vector2, event: DamageEvent) -> void:
	if event.causal_depth >= DamageEvent.MAX_CAUSAL_DEPTH:
		return
	volatile_pulse_count += 1
	var options: DamageQueryOptions = DamageQueryOptions.new()
	options.root_attack_id = event.root_attack_id
	options.causal_depth = event.causal_depth + 1
	options.effect_flags = DamageEvent.FLAG_VOLATILE
	options.result_limit = 10
	options.structural_limit = 1
	options.debris_limit = 2
	options.damage_type = &"volatile_pulse"
	dependencies.destruction_director.queue_explosion(
		origin,
		220.0,
		70.0,
		VOLATILE_IMPULSE,
		event.attack_id,
		null,
		options
	)
