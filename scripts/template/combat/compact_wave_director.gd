class_name CompactWaveDirector
extends Node

signal wave_started(current_wave: int, total_waves: int)
signal wave_cleared(cleared_waves: int, total_waves: int)
signal score_awarded(points: int, world_position: Vector2)
signal victory
signal configuration_failed(errors: PackedStringArray)

const COMPACT_ENEMY_SCENE: PackedScene = preload(
	"res://scenes/template/combat/compact_enemy.tscn"
)
const SOLDIER_DEFINITION: CompactEnemyDefinition = preload(
	"res://resources/template/enemies/soldier.tres"
)
const TANK_DEFINITION: CompactEnemyDefinition = preload(
	"res://resources/template/enemies/tank.tres"
)

@export_range(1, 16, 1) var pool_size: int = 8
@export var enemy_container_path: NodePath = ^"../EnemyContainer"

var stage_definition: StageDefinition
var player: CompactPlayer
var marker_positions: Dictionary = {}
var current_wave_index: int = -1
var completed_waves: int = 0
var started: bool = false
var spawned_count: int = 0
var pool_exhaustion_count: int = 0
var configuration_errors: PackedStringArray = PackedStringArray()

var _pool: Array[CompactEnemy] = []
var _wave_delay_remaining: float = 0.0
var _record_index: int = 0
var _remaining_in_record: int = 0
var _spawn_timer: float = 0.0
var _spawning_done: bool = false
@onready var _enemy_container: Node2D = get_node(enemy_container_path) as Node2D


func _ready() -> void:
	_warm_pool()
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	simulation_step(delta)


func configure(
	p_stage_definition: StageDefinition,
	p_player: CompactPlayer,
	p_marker_positions: Dictionary
) -> bool:
	stop()
	configuration_errors = _configuration_validation_errors(
		p_stage_definition,
		p_player,
		p_marker_positions
	)
	if not configuration_errors.is_empty():
		stage_definition = null
		player = null
		marker_positions.clear()
		_report_configuration_failure(configuration_errors)
		return false
	stage_definition = p_stage_definition
	player = p_player
	marker_positions = p_marker_positions.duplicate()
	current_wave_index = -1
	completed_waves = 0
	spawned_count = 0
	pool_exhaustion_count = 0
	return true


func start() -> bool:
	if (
		not configuration_errors.is_empty()
		or stage_definition == null
		or player == null
		or stage_definition.waves.is_empty()
	):
		return false
	started = true
	current_wave_index = 0
	_prepare_current_wave()
	set_physics_process(true)
	return true


func stop() -> void:
	started = false
	set_physics_process(false)
	for enemy: CompactEnemy in _pool:
		enemy.deactivate()


func simulation_step(delta: float) -> void:
	if not started:
		return
	if _wave_delay_remaining > 0.0:
		_wave_delay_remaining = maxf(_wave_delay_remaining - delta, 0.0)
		return
	if not _spawning_done:
		_step_spawning(delta)
		return
	if active_enemy_count() > 0:
		return
	completed_waves += 1
	wave_cleared.emit(completed_waves, stage_definition.waves.size())
	if completed_waves >= stage_definition.waves.size():
		started = false
		set_physics_process(false)
		victory.emit()
		return
	current_wave_index += 1
	_prepare_current_wave()


func definition(enemy_id: StringName) -> CompactEnemyDefinition:
	match enemy_id:
		&"soldier":
			return SOLDIER_DEFINITION
		&"tank":
			return TANK_DEFINITION
	return null


func active_enemies() -> Array[CompactEnemy]:
	var enemies: Array[CompactEnemy] = []
	for enemy: CompactEnemy in _pool:
		if enemy.active:
			enemies.append(enemy)
	return enemies


func active_enemy_count() -> int:
	var count: int = 0
	for enemy: CompactEnemy in _pool:
		if enemy.active:
			count += 1
	return count


func pool_node_count() -> int:
	return _pool.size()


func _warm_pool() -> void:
	for index: int in range(pool_size):
		var enemy: CompactEnemy = COMPACT_ENEMY_SCENE.instantiate() as CompactEnemy
		enemy.name = "EnemySlot%02d" % [index]
		_enemy_container.add_child(enemy)
		enemy.defeated.connect(_on_enemy_defeated)
		enemy.damage_requested.connect(_on_damage_requested)
		_pool.append(enemy)


func _prepare_current_wave() -> void:
	var wave: CompactWaveDefinition = _current_wave()
	_wave_delay_remaining = wave.start_delay_seconds
	_record_index = 0
	_remaining_in_record = 0
	_spawn_timer = 0.0
	_spawning_done = false
	wave_started.emit(current_wave_index + 1, stage_definition.waves.size())


func _step_spawning(delta: float) -> void:
	var wave: CompactWaveDefinition = _current_wave()
	if _record_index >= wave.spawns.size():
		_spawning_done = true
		return
	var record: CompactSpawnRecord = wave.spawns[_record_index]
	if _remaining_in_record <= 0:
		_remaining_in_record = record.count
		_spawn_timer = 0.0
	_spawn_timer = maxf(_spawn_timer - delta, 0.0)
	if _spawn_timer > 0.0:
		return
	if not _spawn_enemy(record):
		if started:
			pool_exhaustion_count += 1
		return
	_remaining_in_record -= 1
	_spawn_timer = record.interval_seconds
	if _remaining_in_record <= 0:
		_record_index += 1


func _spawn_enemy(record: CompactSpawnRecord) -> bool:
	var selected_definition: CompactEnemyDefinition = definition(record.enemy_id)
	if selected_definition == null:
		_fail_runtime_configuration(
			"enemy_id '%s' no longer resolves to a runtime definition" % [record.enemy_id]
		)
		return false
	if not stage_definition.allowed_enemy_ids.has(String(record.enemy_id)):
		_fail_runtime_configuration(
			"enemy_id '%s' is no longer allowlisted" % [record.enemy_id]
		)
		return false
	if not marker_positions.has(record.marker_id):
		_fail_runtime_configuration(
			"marker_id '%s' is no longer configured" % [record.marker_id]
		)
		return false
	var marker_value: Variant = marker_positions[record.marker_id]
	if typeof(marker_value) != TYPE_VECTOR2:
		_fail_runtime_configuration(
			"marker_id '%s' no longer resolves to Vector2" % [record.marker_id]
		)
		return false
	var marker: Vector2 = marker_value
	if not marker.is_finite():
		_fail_runtime_configuration(
			"marker_id '%s' no longer resolves to a finite Vector2" % [record.marker_id]
		)
		return false
	var slot: CompactEnemy
	for enemy: CompactEnemy in _pool:
		if not enemy.active:
			slot = enemy
			break
	if slot == null:
		return false
	var deterministic_offset: float = float(spawned_count % 3) * 24.0
	if not slot.activate(
		selected_definition,
		player,
		marker + Vector2(deterministic_offset, 0.0)
	):
		_fail_runtime_configuration(
			"enemy_id '%s' failed activation after successful preflight" % [record.enemy_id]
		)
		return false
	spawned_count += 1
	return true


func _configuration_validation_errors(
	p_stage_definition: StageDefinition,
	p_player: CompactPlayer,
	p_marker_positions: Dictionary
) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if p_stage_definition == null:
		errors.append("stage definition is required")
		return errors
	for error: String in p_stage_definition.validation_errors():
		errors.append(error)
	if p_player == null:
		errors.append("player is required")
	if not errors.is_empty():
		return errors
	for wave_index: int in range(p_stage_definition.waves.size()):
		var wave: CompactWaveDefinition = (
			p_stage_definition.waves[wave_index] as CompactWaveDefinition
		)
		for record_index: int in range(wave.spawns.size()):
			var record: CompactSpawnRecord = wave.spawns[record_index]
			var context: String = "wave %d spawn %d" % [wave_index + 1, record_index + 1]
			var selected_definition: CompactEnemyDefinition = definition(record.enemy_id)
			if selected_definition == null:
				errors.append(
					"%s: enemy_id '%s' has no runtime definition" % [context, record.enemy_id]
				)
			elif not selected_definition.is_valid():
				errors.append(
					"%s: enemy_id '%s' resolves to an invalid definition: %s" % [
						context,
						record.enemy_id,
						", ".join(selected_definition.validation_errors()),
					]
				)
			if not p_marker_positions.has(record.marker_id):
				errors.append(
					"%s: marker_id '%s' is not configured" % [context, record.marker_id]
				)
				continue
			var marker_value: Variant = p_marker_positions[record.marker_id]
			if typeof(marker_value) != TYPE_VECTOR2:
				errors.append(
					"%s: marker_id '%s' must resolve to Vector2, got %s" % [
						context,
						record.marker_id,
						type_string(typeof(marker_value)),
					]
				)
			else:
				var marker_position: Vector2 = marker_value
				if not marker_position.is_finite():
					errors.append(
						"%s: marker_id '%s' must resolve to a finite Vector2" % [
							context,
							record.marker_id,
						]
					)
	return errors


func _fail_runtime_configuration(error: String) -> void:
	configuration_errors = PackedStringArray([error])
	stop()
	_report_configuration_failure(configuration_errors)


func _report_configuration_failure(errors: PackedStringArray) -> void:
	configuration_failed.emit(errors.duplicate())
	push_error("CompactWaveDirector configuration failed: %s" % ["; ".join(errors)])


func _current_wave() -> CompactWaveDefinition:
	return stage_definition.waves[current_wave_index] as CompactWaveDefinition


func _on_enemy_defeated(
	enemy: CompactEnemy,
	score_value: int,
	world_position: Vector2
) -> void:
	enemy.deactivate()
	score_awarded.emit(score_value, world_position)


func _on_damage_requested(amount: float) -> void:
	if player != null:
		player.receive_damage(amount)
