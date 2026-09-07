class_name DestructionUpgradeRuntime
extends UpgradeRuntime

const MAX_DEDUPE_RECORDS: int = 128
const DEBRIS_PARTICLES_PER_RANK: int = 2

var field: CosmeticDebrisField2D
var run_generation: int = 1
var seen_events: Dictionary[StringName, bool] = {}
var seen_order: Array[StringName] = []
var visual_spawn_count: int = 0


func _init() -> void:
	setup(&"DESTRUCTION", 1)
	field = CosmeticDebrisField2D.new()
	add_child(field)


func setup_events(event_hub: GameplayEventHub, generation: int) -> void:
	run_generation = generation
	if event_hub != null:
		event_hub.event_published.connect(_on_event_published)


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	return true


func set_paused(value: bool) -> void:
	super.set_paused(value)
	field.set_paused(value)


func continue_cycle() -> void:
	super.continue_cycle()
	field.set_paused(false)


func stop_and_release() -> void:
	super.stop_and_release()
	field.reset_field()
	field.set_paused(true)


func reset_run() -> void:
	super.reset_run()
	seen_events.clear()
	seen_order.clear()
	visual_spawn_count = 0
	field.reset_field()


func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	data.merge({
		"capacity": CosmeticDebrisField2D.CAPACITY,
		"active": field.active_count(),
		"peak": field.peak_active_count,
		"recycled": field.recycle_count,
		"spawned": visual_spawn_count,
		"dedupe_records": seen_events.size(),
	}, true)
	return data


func _on_event_published(event: GameplayEvent) -> void:
	if current_rank <= 0 or paused or stopped or event == null or event.event_id <= 0:
		return
	if event.debris_units <= 0:
		return
	var key: StringName = StringName("%d:%d" % [run_generation, event.event_id])
	if seen_events.has(key):
		return
	seen_events[key] = true
	seen_order.append(key)
	if seen_order.size() > MAX_DEDUPE_RECORDS:
		seen_events.erase(seen_order.pop_front())
	visual_spawn_count += field.spawn_counterparts(
		event,
		DEBRIS_PARTICLES_PER_RANK * current_rank
	)
