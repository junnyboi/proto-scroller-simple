class_name DestructibleProp2D
extends RigidBody2D

signal destroyed(prop: DestructibleProp2D, event: DamageEvent)
signal fully_destroyed(prop: DestructibleProp2D, event: DamageEvent)

const REMAINS_LAYER: int = 1 << 9
const WORLD_LAYER: int = 1 << 0
const TERMINAL_RUBBLE_PIECE_COUNT: int = 3
const TERMINAL_RUBBLE_HEIGHT: float = 34.0

@export var max_health: float = 60.0
@export var wreck_health: float = 45.0
@export_range(1, 8, 1) var gameplay_chunk_count: int = 4
@export var debris_pool_path: NodePath
@export var rubble_dust_pool_path: NodePath
@export var intact_texture: Texture2D
@export var destroyed_texture: Texture2D
@export var intact_display_size: Vector2 = Vector2(150.0, 80.0)
@export var destroyed_display_size: Vector2 = Vector2(160.0, 80.0)
@export var destroyed_collision_size: Vector2 = Vector2(130.0, 50.0)
@export var visual_ground_offset: float = 0.0
@export var ground_smash_breaks_immediately: bool = false
@export var wreck_next_hit_fully_destroys: bool = false
@export var terminal_rubble_material_id: StringName = &"steel"
@export var terminal_rubble_district_id: StringName = &"BUSINESS"

var current_health: float
var is_broken: bool = false
var is_fully_destroyed: bool = false
var terminal_rubble: PersistentRubbleBed2D
var _seen_attacks: Dictionary[int, bool] = {}
var _base_collision_layer: int = 0
var _base_collision_mask: int = 0
var _base_collision_size: Vector2 = Vector2.ZERO
var _rubble_dust_pool: BuildingSectionBurstPool

@onready var visual: Sprite2D = get_node(^"Visual") as Sprite2D
@onready var collision_shape: CollisionShape2D = get_node(^"CollisionShape2D") as CollisionShape2D
@onready var _debris_pool: DebrisPool = get_node_or_null(debris_pool_path) as DebrisPool


func _ready() -> void:
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask
	var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle != null:
		_base_collision_size = rectangle.size
	current_health = max_health
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	can_sleep = true
	visual.texture = intact_texture
	_fit_visual(intact_display_size)
	_ensure_terminal_rubble()
	_configure_terminal_rubble()


func receive_damage(event: DamageEvent) -> bool:
	if is_fully_destroyed or event == null or event.amount <= 0.0:
		return false
	if event.attack_id != 0 and _seen_attacks.has(event.attack_id):
		return false
	if event.attack_id != 0:
		_seen_attacks[event.attack_id] = true
	if ground_smash_breaks_immediately and event.damage_type == &"ground_smash" and not is_broken:
		_break_prop(event)
		return true
	if is_broken and wreck_next_hit_fully_destroys:
		_fully_destroy_prop(event)
		return true
	current_health = maxf(current_health - event.amount, 0.0)
	if current_health > 0.0:
		return true
	if is_broken:
		_fully_destroy_prop(event)
	else:
		_break_prop(event)
	return true


func is_destroyed() -> bool:
	return is_fully_destroyed


func terminal_rubble_active() -> bool:
	return terminal_rubble != null and terminal_rubble.is_active()


func terminal_rubble_piece_count() -> int:
	return terminal_rubble.active_piece_count() if terminal_rubble != null else 0


func configure_terminal_district(district_id: StringName) -> void:
	terminal_rubble_district_id = district_id if not district_id.is_empty() else &"BUSINESS"
	set_meta(&"district_id", terminal_rubble_district_id)
	if terminal_rubble != null:
		_configure_terminal_rubble()


func capture_stream_state() -> Dictionary:
	return {
		"health": current_health,
		"broken": is_broken,
		"fully_destroyed": is_fully_destroyed,
		"pristine": (
			not is_broken
			and not is_fully_destroyed
			and is_equal_approx(current_health, max_health)
		),
	}


func restore_stream_state(spawn_position: Vector2, state: Dictionary) -> void:
	freeze = true
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	position = spawn_position
	_seen_attacks.clear()
	_ensure_terminal_rubble()
	_configure_terminal_rubble()
	is_broken = bool(state.get("broken", false))
	is_fully_destroyed = bool(state.get("fully_destroyed", false))
	current_health = clampf(float(state.get("health", max_health)), 0.0, max_health)
	visual.visible = not is_fully_destroyed
	terminal_rubble.set_active(is_fully_destroyed)
	collision_shape.set_deferred("disabled", is_fully_destroyed)
	if is_fully_destroyed:
		current_health = 0.0
		collision_layer = 0
		collision_mask = 0
		return
	if is_broken:
		visual.texture = destroyed_texture
		_fit_visual(destroyed_display_size)
		terminal_rubble.set_active(false)
		collision_layer = REMAINS_LAYER
		collision_mask = WORLD_LAYER
		set_meta(&"enemy_remains", &"destroyed_prop")
		_apply_collision_size(destroyed_collision_size)
		return
	visual.texture = intact_texture
	_fit_visual(intact_display_size)
	terminal_rubble.set_active(false)
	collision_layer = _base_collision_layer
	collision_mask = _base_collision_mask
	remove_meta(&"enemy_remains")
	_apply_collision_size(_base_collision_size)


func _break_prop(event: DamageEvent) -> void:
	is_broken = true
	current_health = maxf(wreck_health, 1.0)
	terminal_rubble.set_active(false)
	visual.texture = destroyed_texture
	_fit_visual(destroyed_display_size)
	collision_layer = REMAINS_LAYER
	collision_mask = WORLD_LAYER
	set_meta(&"enemy_remains", &"destroyed_prop")
	freeze = false
	sleeping = false
	call_deferred("_apply_destroyed_collision")
	destroyed.emit(self, event)


func _fully_destroy_prop(event: DamageEvent) -> void:
	is_fully_destroyed = true
	current_health = 0.0
	_release_fragments(event)
	visual.visible = false
	_configure_terminal_rubble()
	terminal_rubble.set_active(true)
	_release_rubble_dust()
	collision_layer = 0
	collision_mask = 0
	collision_shape.set_deferred("disabled", true)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	sleeping = true
	fully_destroyed.emit(self, event)


func _release_fragments(event: DamageEvent) -> void:
	if _debris_pool == null or gameplay_chunk_count <= 0:
		return
	var count: int = mini(gameplay_chunk_count, _debris_pool.available_count())
	if count <= 0:
		return
	var fragment_origin: Vector2 = visual.to_global(Vector2.ZERO)
	var base_direction: Vector2 = event.direction
	if base_direction.is_zero_approx():
		base_direction = (fragment_origin - event.hit_position).normalized()
	if base_direction.is_zero_approx():
		base_direction = Vector2.UP
	var impulse_per_mass: float = maxf(event.impulse_per_mass, 220.0)
	for fragment_index: int in range(count):
		var weight: float = (float(fragment_index) + 0.5) / float(count)
		var angle: float = deg_to_rad(lerpf(-42.0, 42.0, weight))
		var direction: Vector2 = base_direction.rotated(angle)
		direction.y -= 0.45
		direction = direction.normalized()
		var body_mass: float = maxf(mass * lerpf(0.5, 0.9, weight) / float(count), 0.6)
		var body_size: Vector2 = Vector2(
			lerpf(14.0, minf(destroyed_display_size.x * 0.26, 52.0), weight),
			lerpf(10.0, minf(destroyed_display_size.y * 0.34, 32.0), 1.0 - weight)
		)
		var debris: DebrisBody2D = _debris_pool.acquire(
			Transform2D(0.0, fragment_origin + direction * (8.0 + fragment_index * 5.0)),
			direction * impulse_per_mass * body_mass * lerpf(0.45, 0.75, weight),
			lerpf(-3.5, 3.5, weight) * body_mass,
			body_mass,
			body_size,
			&"steel",
			Color("3f4a50"),
			Color("82939b")
		)
		_debris_pool.arm_kinetic_debris(debris, event)


func _apply_destroyed_collision() -> void:
	if is_fully_destroyed:
		return
	_apply_collision_size(destroyed_collision_size)


func _apply_collision_size(size: Vector2) -> void:
	var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = size


func _ensure_terminal_rubble() -> void:
	if terminal_rubble != null:
		return
	terminal_rubble = PersistentRubbleBed2D.new()
	terminal_rubble.name = "TerminalRubbleBed"
	terminal_rubble.z_index = 2
	add_child(terminal_rubble)


func _configure_terminal_rubble() -> void:
	if terminal_rubble == null:
		return
	var footprint: Vector2 = destroyed_display_size
	var seed_key: String = "%s:%s" % [
		name,
		String(get_meta(&"street_destructible_kind", &"prop")),
	]
	terminal_rubble.configure(
		footprint,
		terminal_rubble_material_id,
		visual.modulate,
		posmod(hash(seed_key), 2_000_000_000) + 1,
		visual_ground_offset,
		minf(TERMINAL_RUBBLE_HEIGHT, maxf(footprint.y * 0.42, 18.0)),
		TERMINAL_RUBBLE_PIECE_COUNT,
		terminal_rubble_district_id
	)


func _release_rubble_dust() -> void:
	if terminal_rubble == null:
		return
	if _rubble_dust_pool == null and not rubble_dust_pool_path.is_empty():
		_rubble_dust_pool = get_node_or_null(rubble_dust_pool_path) as BuildingSectionBurstPool
	if _rubble_dust_pool == null:
		return
	var dust_origin: Vector2 = terminal_rubble.to_global(
		Vector2(0.0, terminal_rubble.baseline_y() - 4.0)
	)
	_rubble_dust_pool.spawn_rubble_dust(
		dust_origin,
		destroyed_display_size.x,
		terminal_rubble_district_id
	)


func _fit_visual(display_size: Vector2) -> void:
	if visual.texture == null:
		return
	var texture_size: Vector2 = visual.texture.get_size()
	var fit_scale: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	visual.scale = Vector2.ONE * fit_scale
	visual.position.y = visual_ground_offset - texture_size.y * fit_scale * 0.5
