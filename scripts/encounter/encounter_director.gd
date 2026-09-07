class_name EncounterDirector
extends Node

signal phase_changed(index: int, display_name: String)
signal district_completed

var runtime: EncounterRuntime
var waves: Array[EnemyWave] = []
var phase_index: int = -1
var running: bool = false
var completed: bool = false
var _pending: Array[Dictionary] = []
var _respite_remaining: float = 0.0


func setup(p_runtime: EncounterRuntime, p_waves: Array[EnemyWave]) -> void:
	runtime = p_runtime
	waves = p_waves


func start() -> void:
	completed = false
	running = true
	phase_index = -1
	_pending.clear()
	_respite_remaining = 0.0
	_advance_phase()


func stop() -> void:
	running = false
	_pending.clear()
	_respite_remaining = 0.0


func reset_to_contact() -> void:
	stop()
	if runtime != null:
		runtime.release_all()
	start()


func _process(delta: float) -> void:
	if not running or runtime == null or completed:
		return
	_process_pending(delta)
	if not _pending.is_empty() or runtime.active_count() > 0:
		return
	if _respite_remaining <= 0.0:
		_respite_remaining = EnemySpawnTuning.scaled_interval(
			waves[phase_index].minimum_respite
		)
	_respite_remaining = maxf(_respite_remaining - delta, 0.0)
	if not is_zero_approx(_respite_remaining):
		return
	if phase_index >= waves.size() - 1:
		completed = true
		running = false
		district_completed.emit()
	else:
		_advance_phase()


func current_phase_name() -> String:
	if phase_index < 0 or phase_index >= waves.size():
		return ""
	return waves[phase_index].display_name


func pending_count() -> int:
	return _pending.size()


func _advance_phase() -> void:
	phase_index += 1
	_respite_remaining = 0.0
	var wave: EnemyWave = waves[phase_index]
	for spawn: EnemySpawnEntry in wave.spawns:
		var kind: StringName = StringName(spawn.kind)
		var spawn_count: int = EnemySpawnTuning.scaled_count(
			EnemyArchetypeCatalog.spawn_multiplier(kind)
		)
		for copy_index: int in range(spawn_count):
			_pending.append({
				"entry": spawn,
				"remaining": EnemySpawnTuning.scaled_interval(
					wave.opening_delay + spawn.delay + float(copy_index) * 0.14
				),
				"offset": Vector2(float(copy_index) * 52.0, 0.0),
			})
	phase_changed.emit(phase_index, wave.display_name)


func _process_pending(delta: float) -> void:
	for index: int in range(_pending.size() - 1, -1, -1):
		var record: Dictionary = _pending[index]
		record.remaining = maxf(float(record.remaining) - delta, 0.0)
		if not is_zero_approx(float(record.remaining)):
			continue
		var entry: EnemySpawnEntry = record.entry
		var spawn_position: Vector2 = runtime.resolve_spawn_position(
			entry.position,
			StringName(entry.spawn_anchor),
			record.offset as Vector2
		)
		if runtime.acquire(
			StringName(entry.kind),
			spawn_position
		) != null:
			_pending.remove_at(index)
