class_name EnemyRemainsFactory
extends Node

signal wreck_scrapped(wreck: EnemyWreck2D, event: DamageEvent, points: int)
signal wreck_spawned(enemy: EnemyActor2D, wreck: EnemyWreck2D)
signal crucible_detonated(wreck: EnemyWreck2D, event: DamageEvent)

const ENEMY_WRECK_SCRIPT: Script = preload("res://scripts/actors/enemy_wreck_2d.gd")
const REMAINS_LAYER: int = 1 << 9
const REMAINS_GROUND_LAYER: int = 1 << 10

@export_range(1, 12, 1) var wreck_capacity: int = RuntimeBudget.WRECKS

var peak_active_count: int = 0

var _wreck_root: Node2D
var _scrap_pool: DebrisPool
var _tank_texture: Texture2D
var _helicopter_texture: Texture2D
var _player: GiantRobotController
var _free_wrecks: Array[EnemyWreck2D] = []
var _active_wrecks: Array[EnemyWreck2D] = []


func setup(
	wreck_root: Node2D,
	scrap_pool: DebrisPool,
	tank_texture: Texture2D,
	helicopter_texture: Texture2D
) -> void:
	_wreck_root = wreck_root
	_scrap_pool = scrap_pool
	_tank_texture = tank_texture
	_helicopter_texture = helicopter_texture


func _ready() -> void:
	if _wreck_root == null:
		return
	for index: int in range(wreck_capacity):
		var wreck: EnemyWreck2D = ENEMY_WRECK_SCRIPT.new() as EnemyWreck2D
		wreck.name = "MachineWreck_%02d" % index
		wreck.scrapped.connect(_on_wreck_scrapped)
		wreck.crucible_detonated.connect(_on_crucible_detonated)
		_wreck_root.add_child(wreck)
		wreck.deactivate()
		_free_wrecks.append(wreck)


func set_player(player: GiantRobotController) -> void:
	_player = player


func spawn_wreck(enemy: EnemyActor2D, event: DamageEvent) -> EnemyWreck2D:
	if enemy == null:
		return null
	if _free_wrecks.is_empty():
		var recyclable: EnemyWreck2D = _oldest_recyclable_wreck()
		if recyclable == null:
			return null
		_release_wreck(recyclable)
	var wreck: EnemyWreck2D = _free_wrecks.pop_back()
	_active_wrecks.append(wreck)
	peak_active_count = maxi(peak_active_count, _active_wrecks.size())
	wreck.configure_visual_content_rect(_visual_content_rect(enemy))
	if enemy is ProceduralEnemy:
		var procedural: ProceduralEnemy = enemy as ProceduralEnemy
		var display_size: Vector2 = procedural.profile.get("display", Vector2(235.0, 100.0)) as Vector2
		var collision_size: Vector2 = procedural.profile.get("collision", Vector2(210.0, 78.0)) as Vector2
		var presentation_scale: float = EnemyArchetypeCatalog.presentation_scale(
			procedural.archetype_id
		)
		display_size *= presentation_scale
		collision_size *= presentation_scale
		wreck.activate(
			procedural.archetype_id,
			procedural.visual.texture,
			display_size,
			collision_size,
			clampf(procedural.threat_cost * 34.0, 48.0, 260.0),
			clampf(procedural.max_health * 0.32, 38.0, 240.0),
			enemy.global_position,
			event,
			procedural.airborne
		)
	elif enemy is TankEnemy:
		wreck.activate(
			&"tank",
			_tank_texture,
			Vector2(235.0, 100.0) * EnemyArchetypeCatalog.GROUND_VEHICLE_SCALE,
			Vector2(220.0, 78.0) * EnemyArchetypeCatalog.GROUND_VEHICLE_SCALE,
			65.0,
			110.0,
			enemy.global_position,
			event,
			false,
			enemy.boss_mode
		)
	else:
		wreck.activate(
			&"helicopter",
			_helicopter_texture,
			Vector2(235.0, 72.0),
			Vector2(210.0, 58.0),
			38.0,
			85.0,
			enemy.global_position,
			event,
			true
		)
	wreck.eject_from_player_if_overlapping(_player)
	wreck_spawned.emit(enemy, wreck)
	return wreck


func active_count() -> int:
	return _active_wrecks.size()


func active_wreck_at(index: int) -> EnemyWreck2D:
	if index < 0 or index >= _active_wrecks.size():
		return null
	return _active_wrecks[index]


func release_all() -> void:
	for wreck: EnemyWreck2D in _active_wrecks.duplicate():
		_release_wreck(wreck)


func total_count() -> int:
	return _active_wrecks.size() + _free_wrecks.size()


func _visual_content_rect(enemy: EnemyActor2D) -> Rect2:
	if enemy == null or enemy.visual == null or enemy.visual.texture == null:
		return Rect2()
	return enemy.visual.get_meta(
		EnemyActor2D.VISUAL_CONTENT_RECT_META,
		Rect2(-enemy.visual.texture.get_size() * 0.5, enemy.visual.texture.get_size())
	)


func release_wreck(wreck: EnemyWreck2D) -> void:
	_release_wreck(wreck)


func _on_wreck_scrapped(wreck: EnemyWreck2D, event: DamageEvent) -> void:
	spawn_scrap(wreck, event)
	var points: int = 300 if wreck.airborne_crash else 400
	wreck_scrapped.emit(wreck, event, points)
	_release_wreck(wreck, true)


func _on_crucible_detonated(wreck: EnemyWreck2D, event: DamageEvent) -> void:
	crucible_detonated.emit(wreck, event)


func spawn_scrap(wreck: EnemyWreck2D, event: DamageEvent) -> void:
	if wreck == null or event == null or _scrap_pool == null:
		return
	var piece_count: int = 8 if wreck.wreck_kind == &"tank" else 6
	var direction: Vector2 = event.direction
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	for piece_index: int in range(piece_count):
		var fraction: float = float(piece_index) / maxf(float(piece_count - 1), 1.0)
		var spread_direction: Vector2 = direction.rotated(lerpf(-0.78, 0.78, fraction))
		var body_mass: float = lerpf(3.5, 13.0, fraction)
		var body_size: Vector2 = Vector2(
			lerpf(24.0, 65.0, fraction),
			lerpf(12.0, 28.0, 1.0 - fraction)
		)
		var impulse: Vector2 = (
			spread_direction * maxf(event.impulse_per_mass, 220.0) * body_mass * 0.38
			+ Vector2.UP * lerpf(75.0, 150.0, 1.0 - fraction) * body_mass
		)
		var scrap: DebrisBody2D = _scrap_pool.acquire(
			Transform2D(
				fraction * 0.6,
				wreck.global_position + Vector2(lerpf(-45.0, 45.0, fraction), -12.0)
			),
			impulse,
			lerpf(-850.0, 850.0, fraction),
			body_mass,
			body_size,
			&"steel",
			Color("343b40"),
			Color("8b5a38")
		)
		if scrap != null:
			scrap.collision_layer = REMAINS_LAYER
			scrap.collision_mask = REMAINS_GROUND_LAYER
			scrap.set_meta(&"enemy_remains", &"scrap")


func _oldest_recyclable_wreck() -> EnemyWreck2D:
	for wreck: EnemyWreck2D in _active_wrecks:
		if not wreck.is_crucible_captured():
			return wreck
	return null


func _release_wreck(wreck: EnemyWreck2D, preserve_scrapped: bool = false) -> void:
	if wreck == null or not _active_wrecks.has(wreck):
		return
	_active_wrecks.erase(wreck)
	wreck.deactivate(preserve_scrapped)
	_free_wrecks.append(wreck)
