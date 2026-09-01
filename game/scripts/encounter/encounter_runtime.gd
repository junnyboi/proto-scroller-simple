# gdlint: disable=max-public-methods
class_name EncounterRuntime
extends Node2D

signal projectile_requested(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	kind: StringName,
	source: Node
)
signal enemy_died(enemy: EnemyActor2D, event: DamageEvent, points: int)
signal enemy_acquired(enemy: EnemyActor2D)
signal hybrid_event_emitted(event_id: StringName, source: ProceduralEnemy)

const WORLD_LAYER: int = 1 << 0
const ENEMY_LAYER: int = 1 << 2
const ROBOT_LAYER: int = 1 << 1
const BUILDING_LAYER: int = 1 << 3
const HURTBOX_LAYER: int = 1 << 6
const DEBRIS_LAYER: int = 1 << 8
const LAND_ENEMY_VISUAL_BASELINE_Y: float = (
	CityStreetChunk.LAND_ENEMY_VISUAL_BASELINE_Y
)
const SOLDIER_SCRIPT: Script = preload("res://scripts/actors/soldier.gd")
const TANK_SCRIPT: Script = preload("res://scripts/actors/tank.gd")
const HELICOPTER_SCRIPT: Script = preload("res://scripts/actors/helicopter.gd")
const PROCEDURAL_SCRIPT: Script = preload("res://scripts/actors/procedural_enemy.gd")
const ELITE_SPAWN_EFFECT_SCRIPT: Script = preload(
	"res://scripts/encounter/elite_spawn_effect_pool.gd"
)
const SOLDIER_TEXTURE: Texture2D = preload("res://art/city/enemies/soldier.png")
const TANK_TEXTURE: Texture2D = preload("res://art/city/enemies/tank.png")
const HELICOPTER_TEXTURE: Texture2D = preload("res://art/city/enemies/helicopter.png")
const SOLDIER_RENDER_HEIGHT_PIXELS: float = 108.0
const VISIBLE_ALPHA_THRESHOLD: int = 8
const COMMAND_TANK_SLOT: int = RuntimeBudget.TANKS - 1
const MARK_DAMAGE_MULTIPLIER: float = 1.15
const STATIC_INTERVAL_MULTIPLIER: float = 0.82
const AEGIS_DAMAGE_MULTIPLIER: float = 0.65
const AEGIS_RADIUS: float = 560.0
const PROCEDURAL_FAMILY_ORDER: Array[StringName] = [
	&"infantry", &"light", &"heavy", &"air", &"siege",
]
static var _visual_content_rect_cache: Dictionary[String, Rect2] = {}

var robot: GiantRobotController
var telegraphs: TelegraphPresenter2D
var projectile_pool: ProjectilePool
var soldiers: Array[SoldierEnemy] = []
var tanks: Array[TankEnemy] = []
var helicopters: Array[HelicopterEnemy] = []
var procedural_pools: Dictionary[StringName, Array] = {}
var post_warm_creation_count: int = 0
var attack_gate_enabled: bool = true
var structural_target: StructuralBuilding2D
var world_stream: CityWorldStream
var role_profiles: Dictionary[StringName, EnemyRoleProfile] = {}
var trait_profiles: Dictionary[StringName, EnemyTraitProfile] = {}
var target_mark_remaining: float = 0.0
var elite_spawn_effect_pool: EliteSpawnEffectPool
var cycle_health_multiplier: float = 1.0
var cycle_attack_multiplier: float = 1.0


func setup(
	p_robot: GiantRobotController,
	p_telegraphs: TelegraphPresenter2D,
	p_projectile_pool: ProjectilePool,
	p_structural_target: StructuralBuilding2D = null,
	p_world_stream: CityWorldStream = null
) -> void:
	robot = p_robot
	telegraphs = p_telegraphs
	projectile_pool = p_projectile_pool
	structural_target = p_structural_target
	world_stream = p_world_stream


func configure_profiles(
	roles: Array[EnemyRoleProfile],
	traits: Array[EnemyTraitProfile]
) -> void:
	role_profiles.clear()
	trait_profiles.clear()
	for profile: EnemyRoleProfile in roles:
		role_profiles[profile.role_id] = profile
	for profile: EnemyTraitProfile in traits:
		trait_profiles[profile.trait_id] = profile


func _ready() -> void:
	elite_spawn_effect_pool = ELITE_SPAWN_EFFECT_SCRIPT.new() as EliteSpawnEffectPool
	elite_spawn_effect_pool.name = "EliteSpawnEffectPool"
	add_child(elite_spawn_effect_pool)
	for index: int in range(RuntimeBudget.SOLDIERS):
		soldiers.append(_create_enemy(&"soldier", index) as SoldierEnemy)
	for index: int in range(RuntimeBudget.TANKS):
		tanks.append(_create_enemy(&"tank", index) as TankEnemy)
	for index: int in range(RuntimeBudget.HELICOPTERS):
		helicopters.append(_create_enemy(&"helicopter", index) as HelicopterEnemy)
	_prewarm_procedural_family(&"infantry", RuntimeBudget.PROCEDURAL_INFANTRY)
	_prewarm_procedural_family(&"light", RuntimeBudget.PROCEDURAL_LIGHT)
	_prewarm_procedural_family(&"heavy", RuntimeBudget.PROCEDURAL_HEAVY)
	_prewarm_procedural_family(&"air", RuntimeBudget.PROCEDURAL_AIR)
	_prewarm_procedural_family(&"siege", RuntimeBudget.PROCEDURAL_SIEGE)


func _process(delta: float) -> void:
	target_mark_remaining = maxf(target_mark_remaining - delta, 0.0)
	var actors: Array[EnemyActor2D] = all_actors()
	var visual_tint: Color = RuntimeTweakAccess.live_color(
		&"enemy.visual.tint", Color.WHITE
	)
	var visual_scale: float = float(RuntimeTweakAccess.live_value(
		&"enemy.visual.scale", 1.0
	))
	for actor: EnemyActor2D in actors:
		actor.apply_live_visual_tuning(visual_tint, visual_scale)
		actor.aura_attack_interval_multiplier = 1.0
		actor.aura_damage_multiplier = 1.0
		actor.incoming_damage_multiplier = 1.0
	for actor: EnemyActor2D in actors:
		if not actor.active or actor.dead or not actor is ProceduralEnemy:
			continue
		var procedural: ProceduralEnemy = actor as ProceduralEnemy
		if procedural.archetype_id == &"static":
			_apply_static_aura(procedural, actors)
		elif procedural.archetype_id == &"aegis":
			_apply_aegis_aura(procedural, actors)
	if target_mark_remaining > 0.0:
		for actor: EnemyActor2D in actors:
			if actor.active and not actor.dead:
				actor.aura_damage_multiplier = float(RuntimeTweakAccess.live_value(
					&"enemy.target_mark_damage_multiplier", MARK_DAMAGE_MULTIPLIER
				))


func acquire(
	kind: StringName,
	spawn_position: Vector2,
	role_id: StringName = &"",
	trait_id: StringName = &""
) -> EnemyActor2D:
	if not EnemyArchetypeCatalog.is_valid_kind(kind):
		return null
	for enemy: EnemyActor2D in _pool_for_acquisition(kind, role_id, trait_id):
		if enemy.active:
			continue
		if enemy is ProceduralEnemy:
			_configure_procedural_shell(enemy as ProceduralEnemy, kind)
		enemy.activate(_resolve_spawn_lane(enemy, kind, spawn_position), robot)
		var accepted_trait: StringName = trait_id
		if trait_id == &"COMMAND" and _has_active_command():
			accepted_trait = &""
		enemy.apply_profiles(
			role_profiles.get(role_id) as EnemyRoleProfile,
			trait_profiles.get(accepted_trait) as EnemyTraitProfile
		)
		enemy.structural_target = structural_target
		enemy.set_attack_gate(attack_gate_enabled)
		if accepted_trait in EnemyArchetypeCatalog.RANDOM_AFFIXES:
			elite_spawn_effect_pool.play(enemy.global_position, accepted_trait)
		enemy_acquired.emit(enemy)
		return enemy
	return null


func release(enemy: EnemyActor2D) -> void:
	if enemy != null and enemy.active:
		enemy.deactivate()


func release_deferred(enemy: EnemyActor2D) -> void:
	call_deferred("release", enemy)


func release_all() -> void:
	for enemy: EnemyActor2D in all_actors():
		release(enemy)
	target_mark_remaining = 0.0


func cull_behind(_logical_x: float, runtime_x: float) -> int:
	var released: int = 0
	for enemy: EnemyActor2D in all_actors():
		if enemy.active and enemy.global_position.x < runtime_x:
			release(enemy)
			released += 1
	return released


func configure_cycle_difficulty(
	health_multiplier: float,
	attack_multiplier: float
) -> void:
	cycle_health_multiplier = maxf(health_multiplier, 1.0)
	cycle_attack_multiplier = maxf(attack_multiplier, 1.0)
	for enemy: EnemyActor2D in all_actors():
		enemy._configure_cycle_difficulty(
			cycle_health_multiplier,
			cycle_attack_multiplier
		)


func set_attack_gate(enabled: bool) -> void:
	attack_gate_enabled = enabled
	for enemy: EnemyActor2D in all_actors():
		enemy.set_attack_gate(enabled)


func all_actors() -> Array[EnemyActor2D]:
	var actors: Array[EnemyActor2D] = []
	actors.append_array(soldiers)
	actors.append_array(tanks)
	actors.append_array(helicopters)
	for pool: Array in procedural_pools.values():
		for value: Variant in pool:
			actors.append(value as EnemyActor2D)
	return actors


func actor_registry_count() -> int:
	var count: int = soldiers.size() + tanks.size() + helicopters.size()
	for family: StringName in PROCEDURAL_FAMILY_ORDER:
		count += (procedural_pools.get(family, []) as Array).size()
	return count


func actor_at_registry_index(index: int) -> EnemyActor2D:
	if index < 0:
		return null
	var local_index: int = index
	if local_index < soldiers.size():
		return soldiers[local_index]
	local_index -= soldiers.size()
	if local_index < tanks.size():
		return tanks[local_index]
	local_index -= tanks.size()
	if local_index < helicopters.size():
		return helicopters[local_index]
	local_index -= helicopters.size()
	for family: StringName in PROCEDURAL_FAMILY_ORDER:
		var pool: Array = procedural_pools.get(family, []) as Array
		if local_index < pool.size():
			return pool[local_index] as EnemyActor2D
		local_index -= pool.size()
	return null


func active_count(kind: StringName = &"") -> int:
	var count: int = 0
	if kind.is_empty():
		for enemy: EnemyActor2D in all_actors():
			count += 1 if enemy.active and not enemy.dead else 0
		return count
	for enemy: EnemyActor2D in _pool_for_kind(kind):
		if not enemy.active or enemy.dead:
			continue
		if enemy is ProceduralEnemy and (enemy as ProceduralEnemy).archetype_id != kind:
			continue
		count += 1
	return count


func active_family_count(family: StringName) -> int:
	var count: int = 0
	for enemy: EnemyActor2D in _pool_for_family(family):
		count += 1 if enemy.active and not enemy.dead else 0
	return count


func available_count(kind: StringName) -> int:
	var family: StringName = EnemyArchetypeCatalog.family_for(kind)
	if kind in EnemyArchetypeCatalog.BASE_KINDS:
		return _pool_for_kind(kind).size() - active_count(kind)
	return _pool_for_family(family).size() - active_family_count(family)


func available_family_count(family: StringName) -> int:
	return _pool_for_family(family).size() - active_family_count(family)


func available_reservation_capacity(key: StringName) -> int:
	if key in EnemyArchetypeCatalog.BASE_KINDS:
		return available_count(key)
	var prefix: String = "procedural_"
	var key_string: String = String(key)
	if key_string.begins_with(prefix):
		return available_family_count(StringName(key_string.trim_prefix(prefix)))
	return 0


func resolve_spawn_position(
	authored_position: Vector2,
	spawn_anchor: StringName,
	extra_offset: Vector2 = Vector2.ZERO
) -> Vector2:
	if world_stream == null or robot == null:
		return authored_position + extra_offset
	var position_value: Vector2 = authored_position
	match spawn_anchor:
		&"AHEAD":
			position_value.x = robot.global_position.x + 620.0
		&"BEHIND":
			position_value.x = robot.global_position.x - 620.0
		&"CAMERA_RIGHT":
			position_value.x = robot.global_position.x + 720.0
		&"CAMERA_LEFT":
			position_value.x = robot.global_position.x - 720.0
		_:
			position_value.x = robot.global_position.x + authored_position.x - 760.0
	position_value += extra_offset
	var bounds: Vector2 = world_stream.resident_bounds()
	position_value.x = clampf(position_value.x, bounds.x + 100.0, bounds.y - 100.0)
	return position_value


func total_count(kind: StringName = &"") -> int:
	if kind.is_empty():
		return all_actors().size()
	return _pool_for_kind(kind).size()


func family_capacity(family: StringName) -> int:
	return _pool_for_family(family).size()


func apply_target_mark(duration: float) -> void:
	target_mark_remaining = maxf(target_mark_remaining, maxf(duration, 0.0))


func emit_hybrid_event(event_id: StringName, source: ProceduralEnemy) -> void:
	hybrid_event_emitted.emit(event_id, source)


func set_catalyst_target(catalyst: Catalyst2D) -> void:
	for enemy: EnemyActor2D in all_actors():
		enemy.catalyst_target = catalyst


func _apply_static_aura(source: ProceduralEnemy, actors: Array[EnemyActor2D]) -> void:
	for actor: EnemyActor2D in actors:
		if actor != source and actor.active and not actor.dead:
			actor.aura_attack_interval_multiplier = minf(
				actor.aura_attack_interval_multiplier,
				float(RuntimeTweakAccess.live_value(
					&"enemy.static_attack_interval_multiplier",
					STATIC_INTERVAL_MULTIPLIER
				))
			)


func _apply_aegis_aura(source: ProceduralEnemy, actors: Array[EnemyActor2D]) -> void:
	for actor: EnemyActor2D in actors:
		if actor == source or not actor.active or actor.dead:
			continue
		if source.global_position.distance_to(actor.global_position) <= float(
			RuntimeTweakAccess.live_value(&"enemy.aegis_aura_radius", AEGIS_RADIUS)
		):
			actor.incoming_damage_multiplier = minf(
				actor.incoming_damage_multiplier,
				float(RuntimeTweakAccess.live_value(
					&"enemy.aegis_damage_taken_multiplier", AEGIS_DAMAGE_MULTIPLIER
				))
			)


func _has_active_command() -> bool:
	for enemy: EnemyActor2D in all_actors():
		if enemy.active and not enemy.dead and enemy.trait_id == &"COMMAND":
			return true
	return false


func _create_enemy(kind: StringName, index: int) -> EnemyActor2D:
	var enemy: EnemyActor2D
	var texture: Texture2D
	var display_size: Vector2
	var collision_size: Vector2
	if kind == &"soldier":
		enemy = SOLDIER_SCRIPT.new() as SoldierEnemy
		texture = SOLDIER_TEXTURE
		display_size = Vector2(
			texture.get_size().x * SOLDIER_RENDER_HEIGHT_PIXELS / texture.get_size().y,
			SOLDIER_RENDER_HEIGHT_PIXELS
		)
		collision_size = Vector2(42.0, 95.0)
	elif kind == &"tank":
		enemy = TANK_SCRIPT.new() as TankEnemy
		texture = TANK_TEXTURE
		display_size = Vector2(235.0, 100.0) * EnemyArchetypeCatalog.GROUND_VEHICLE_SCALE
		collision_size = Vector2(220.0, 78.0) * EnemyArchetypeCatalog.GROUND_VEHICLE_SCALE
	else:
		enemy = HELICOPTER_SCRIPT.new() as HelicopterEnemy
		texture = HELICOPTER_TEXTURE
		display_size = Vector2(235.0, 72.0)
		collision_size = Vector2(210.0, 58.0)
	_configure_actor_nodes(enemy, kind, texture, display_size, collision_size)
	enemy.name = "%sPool%02d" % [kind.capitalize(), index]
	add_child(enemy)
	enemy.deactivate()
	return enemy


func _prewarm_procedural_family(family: StringName, count: int) -> void:
	var pool: Array[ProceduralEnemy] = []
	for index: int in range(count):
		var enemy: ProceduralEnemy = PROCEDURAL_SCRIPT.new() as ProceduralEnemy
		enemy.name = "%sArchetypePool%02d" % [String(family).capitalize(), index]
		enemy.encounter_runtime = self
		var visual: Sprite2D = Sprite2D.new()
		visual.name = "Visual"
		enemy.add_child(visual)
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		collision.shape = RectangleShape2D.new()
		enemy.add_child(collision)
		var hurtbox: Area2D = Area2D.new()
		hurtbox.name = "Hurtbox"
		hurtbox.collision_layer = HURTBOX_LAYER
		var hurt_shape: CollisionShape2D = CollisionShape2D.new()
		hurt_shape.name = "CollisionShape2D"
		hurt_shape.shape = RectangleShape2D.new()
		hurtbox.add_child(hurt_shape)
		enemy.add_child(hurtbox)
		_configure_actor_contract(enemy)
		add_child(enemy)
		enemy.deactivate()
		pool.append(enemy)
	procedural_pools[family] = pool


func _configure_procedural_shell(enemy: ProceduralEnemy, kind: StringName) -> void:
	var profile: Dictionary = EnemyArchetypeCatalog.profile(kind)
	enemy.configure_archetype(kind, profile)
	var texture: Texture2D = load(String(profile.texture)) as Texture2D
	var display_size: Vector2 = profile.display as Vector2
	if EnemyArchetypeCatalog.is_human_enemy(kind):
			display_size = Vector2(
				texture.get_size().x
				* EnemyArchetypeCatalog.HUMAN_RENDER_HEIGHT_PIXELS
				/ texture.get_size().y,
				EnemyArchetypeCatalog.HUMAN_RENDER_HEIGHT_PIXELS
			)
	var collision_size: Vector2 = profile.collision as Vector2
	var presentation_scale: float = EnemyArchetypeCatalog.presentation_scale(kind)
	display_size *= presentation_scale
	collision_size *= presentation_scale
	var visual: Sprite2D = enemy.get_node(^"Visual") as Sprite2D
	visual.texture = texture
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture_size: Vector2 = texture.get_size()
	var fit: float = minf(display_size.x / texture_size.x, display_size.y / texture_size.y)
	visual.scale = Vector2.ONE * fit
	visual.position = Vector2.ZERO
	_cache_visual_content_rect(visual, texture)
	if not enemy.airborne:
		_align_visual_bottom(
			visual,
			_land_actor_origin_y(collision_size.y),
			LAND_ENEMY_VISUAL_BASELINE_Y
		)
	enemy._visual_rest_position = visual.position
	enemy.set_authored_visual_scale(visual.scale)
	enemy.collision_layer = ENEMY_LAYER
	enemy.collision_mask = 0 if enemy.airborne else WORLD_LAYER | DEBRIS_LAYER
	enemy._base_collision_layer = enemy.collision_layer
	enemy._base_collision_mask = enemy.collision_mask
	var collision: CollisionShape2D = enemy.get_node(^"CollisionShape2D") as CollisionShape2D
	(collision.shape as RectangleShape2D).size = collision_size
	var hurt_shape: CollisionShape2D = enemy.get_node(^"Hurtbox/CollisionShape2D") as CollisionShape2D
	(hurt_shape.shape as RectangleShape2D).size = collision_size * 1.12
	if enemy.role_badge != null:
		enemy.role_badge.position = Vector2(0.0, -display_size.y * 0.62)
	enemy.set_meta(&"enemy_archetype", kind)
	enemy.set_meta(&"enemy_family", enemy.family)


func configure_boss_support_visual(
	enemy: ProceduralEnemy,
	presentation_id: StringName,
	presentation: Dictionary
) -> bool:
	if enemy == null or enemy.visual == null:
		return false
	var texture: Texture2D = load(String(presentation.get("texture", ""))) as Texture2D
	if texture == null:
		return false
	var display_size: Vector2 = (
		presentation.get("display", texture.get_size()) as Vector2
	) * EnemyArchetypeCatalog.presentation_scale(presentation_id)
	var texture_size: Vector2 = texture.get_size()
	var visual: Sprite2D = enemy.visual
	visual.texture = texture
	visual.scale = display_size / Vector2(
		maxf(texture_size.x, 1.0),
		maxf(texture_size.y, 1.0)
	)
	_cache_visual_content_rect(visual, texture)
	if not EnemyArchetypeCatalog.is_airborne(presentation_id):
		_align_visual_bottom(
			visual,
			enemy.global_position.y,
			LAND_ENEMY_VISUAL_BASELINE_Y
		)
	enemy._visual_rest_position = visual.position
	enemy.set_authored_visual_scale(visual.scale)
	return true


func _configure_actor_nodes(
	enemy: EnemyActor2D,
	kind: StringName,
	texture: Texture2D,
	display_size: Vector2,
	collision_size: Vector2
) -> void:
	_configure_actor_contract(enemy)
	enemy.collision_mask = 0 if kind == &"helicopter" else WORLD_LAYER | DEBRIS_LAYER
	var visual: Sprite2D = CityWorldBuilder.fit_sprite(texture, display_size)
	visual.name = "Visual"
	_cache_visual_content_rect(visual, texture)
	if kind != &"helicopter":
		_align_visual_bottom(
			visual,
			_land_actor_origin_y(collision_size.y),
			LAND_ENEMY_VISUAL_BASELINE_Y
		)
		enemy.movement_bounce_enabled = true
		if kind == &"soldier":
			enemy.bounce_height = 5.5
			enemy.bounce_frequency = 3.8
			enemy.bounce_squash = 0.0
			enemy.bounce_speed_reference = 92.0
		else:
			enemy.bounce_height = 2.5
			enemy.bounce_frequency = 2.2
			enemy.bounce_squash = 0.025
			enemy.bounce_speed_reference = 62.0
	enemy.add_child(visual)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = collision_size
	collision.shape = rectangle
	enemy.add_child(collision)
	var hurtbox: Area2D = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = HURTBOX_LAYER
	var hurt_shape: CollisionShape2D = CollisionShape2D.new()
	hurt_shape.name = "CollisionShape2D"
	var hurt_rectangle: RectangleShape2D = RectangleShape2D.new()
	hurt_rectangle.size = collision_size * 1.12
	hurt_shape.shape = hurt_rectangle
	hurtbox.add_child(hurt_shape)
	enemy.add_child(hurtbox)


func _cache_visual_content_rect(visual: Sprite2D, texture: Texture2D) -> void:
	visual.set_meta(
		EnemyActor2D.VISUAL_CONTENT_RECT_META,
		_visible_content_rect(texture)
	)


func _visible_content_rect(texture: Texture2D) -> Rect2:
	var cache_key: String = texture.resource_path
	if cache_key.is_empty():
		cache_key = str(texture.get_instance_id())
	if _visual_content_rect_cache.has(cache_key):
		return _visual_content_rect_cache[cache_key]
	var texture_size: Vector2 = texture.get_size()
	var content_rect: Rect2 = Rect2(-texture_size * 0.5, texture_size)
	var image: Image = texture.get_image()
	if image != null and not image.is_empty():
		image.convert(Image.FORMAT_RGBA8)
		var data: PackedByteArray = image.get_data()
		var width: int = image.get_width()
		var height: int = image.get_height()
		var minimum: Vector2i = Vector2i(width, height)
		var maximum: Vector2i = Vector2i(-1, -1)
		for pixel_index: int in range(width * height):
			if int(data[pixel_index * 4 + 3]) <= VISIBLE_ALPHA_THRESHOLD:
				continue
			var point: Vector2i = Vector2i(
				pixel_index % width,
				floori(float(pixel_index) / float(width))
			)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		if maximum.x >= minimum.x and maximum.y >= minimum.y:
			content_rect = Rect2(
				Vector2(minimum) - texture_size * 0.5,
				Vector2(maximum - minimum + Vector2i.ONE)
			)
	_visual_content_rect_cache[cache_key] = content_rect
	return content_rect


func _align_visual_bottom(visual: Sprite2D, authored_y: float, baseline_y: float) -> void:
	var content_rect: Rect2 = visual.get_meta(
		EnemyActor2D.VISUAL_CONTENT_RECT_META,
		Rect2(-visual.texture.get_size() * 0.5, visual.texture.get_size())
	)
	visual.position.y = baseline_y - authored_y - content_rect.end.y * absf(visual.scale.y)


func _resolve_spawn_lane(
	enemy: EnemyActor2D,
	kind: StringName,
	requested_position: Vector2
) -> Vector2:
	if EnemyArchetypeCatalog.is_airborne(kind):
		return requested_position
	var collision: CollisionShape2D = enemy.get_node_or_null(
		^"CollisionShape2D"
	) as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D:
		return requested_position
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	return Vector2(requested_position.x, _land_actor_origin_y(rectangle.size.y))


func _land_actor_origin_y(collision_height: float) -> float:
	return CityStreetChunk.ROAD_COLLISION_SURFACE_Y - collision_height * 0.5


func _configure_actor_contract(enemy: EnemyActor2D) -> void:
	enemy.collision_layer = ENEMY_LAYER
	enemy.z_index = 30
	enemy.set_meta(&"combat_team", &"enemy")
	enemy.telegraph_presenter = telegraphs
	enemy.projectile_pool = projectile_pool
	enemy.projectile_target_mask = ROBOT_LAYER | BUILDING_LAYER | (1 << 7)
	enemy.projectile_requested.connect(_on_projectile_requested)
	enemy.died.connect(_on_enemy_died)


func _pool_for_kind(kind: StringName) -> Array[EnemyActor2D]:
	var actors: Array[EnemyActor2D] = []
	if kind == &"soldier":
		actors.assign(soldiers)
	elif kind == &"tank":
		actors.assign(tanks)
	elif kind == &"helicopter":
		actors.assign(helicopters)
	else:
		actors = _pool_for_family(EnemyArchetypeCatalog.family_for(kind))
	return actors


func _pool_for_acquisition(
	kind: StringName,
	role_id: StringName,
	trait_id: StringName
) -> Array[EnemyActor2D]:
	var actors: Array[EnemyActor2D] = _pool_for_kind(kind)
	if kind != &"tank":
		return actors
	var command_requested: bool = role_id == &"ANCHOR_TANK" or trait_id == &"COMMAND"
	var candidates: Array[EnemyActor2D] = []
	if command_requested:
		candidates.append(tanks[COMMAND_TANK_SLOT])
		return candidates
	for index: int in range(COMMAND_TANK_SLOT):
		candidates.append(tanks[index])
	return candidates


func _pool_for_family(family: StringName) -> Array[EnemyActor2D]:
	var actors: Array[EnemyActor2D] = []
	var pool: Array = procedural_pools.get(family, []) as Array
	for value: Variant in pool:
		actors.append(value as EnemyActor2D)
	return actors


func _on_projectile_requested(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	kind: StringName,
	source: Node
) -> void:
	projectile_requested.emit(origin, direction, speed, damage, kind, source)


func _on_enemy_died(enemy: EnemyActor2D, event: DamageEvent) -> void:
	var kind: StringName = &"soldier"
	if enemy is ProceduralEnemy:
		kind = (enemy as ProceduralEnemy).archetype_id
	elif enemy is TankEnemy:
		kind = &"tank"
	elif enemy is HelicopterEnemy:
		kind = &"helicopter"
	enemy_died.emit(enemy, event, EnemyArchetypeCatalog.score_value(kind))
