class_name SoldierDefeatPool
extends Node2D

@export_range(1, 24, 1) var capacity: int = RuntimeBudget.SOLDIER_DEFEATS

var recycle_count: int = 0
var peak_active_count: int = 0
var _free: Array[SoldierDefeatBody2D] = []
var _active: Array[SoldierDefeatBody2D] = []


func _ready() -> void:
	for index: int in range(capacity):
		var body: SoldierDefeatBody2D = SoldierDefeatBody2D.new()
		body.name = "SoldierDefeatBody_%02d" % index
		body.recycle_requested.connect(_on_recycle_requested)
		add_child(body)
		_free.append(body)


func acquire(
	world_position: Vector2,
	facing: int,
	impact_event: DamageEvent,
	texture: Texture2D = SoldierDefeatBody2D.SOLDIER_TEXTURE,
	display_size: Vector2 = Vector2(68.0, 108.0)
) -> SoldierDefeatBody2D:
	if _free.is_empty():
		release(_active.front())
		recycle_count += 1
	var body: SoldierDefeatBody2D = _free.pop_back()
	_active.append(body)
	peak_active_count = maxi(peak_active_count, _active.size())
	body.activate(world_position, facing, impact_event, texture, display_size)
	return body


func release(body: SoldierDefeatBody2D) -> void:
	if body == null or not _active.has(body):
		return
	_active.erase(body)
	body.deactivate()
	_free.append(body)


func release_all() -> void:
	for body: SoldierDefeatBody2D in _active.duplicate():
		release(body)


func active_count() -> int:
	return _active.size()


func available_count() -> int:
	return _free.size()


func total_count() -> int:
	return _active.size() + _free.size()


func _on_recycle_requested(body: SoldierDefeatBody2D) -> void:
	release(body)
