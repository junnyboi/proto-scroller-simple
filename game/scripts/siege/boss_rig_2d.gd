class_name BossRig2D
extends Node2D

const HURTBOX_LAYER: int = 1 << 6
const PART_CAPACITY: int = 6
const SOCKET_CAPACITY: int = 8
const HURT_REGION_CAPACITY: int = 3
const DEFAULT_DISPLAY_SIZE: Vector2 = Vector2(520.0, 390.0)
const CAMPAIGN_PRESENTATION_SCALE: float = 1.5
const SETTLEMENT_PRESENTATION_SCALE: float = CAMPAIGN_PRESENTATION_SCALE
const SETTLEMENT_VISIBLE_BOTTOM_LOCAL_Y: float = 38.84
const SETTLEMENT_ROAD_CONTACT_Y: float = (
	CityStreetChunk.ROAD_DIVIDER_Y
	- SETTLEMENT_VISIBLE_BOTTOM_LOCAL_Y * SETTLEMENT_PRESENTATION_SCALE
)
const SAMARITAN_VISIBLE_BOTTOM_LOCAL_Y: float = 34.289
const STATE_MOVING: StringName = &"MOVING"
const STATE_ATTACKING: StringName = &"ATTACKING"
const DIRECTION_EAST: StringName = &"E"
const DIRECTION_WEST: StringName = &"W"
const DEFEATED_MODULATE: Color = Color("625d58")
const SOCKET_NAMES: Array[StringName] = [
	&"CORE",
	&"WEAK_POINT",
	&"LEFT_EMITTER",
	&"RIGHT_EMITTER",
	&"UPPER",
	&"LOWER",
	&"SUPPORT_LEFT",
	&"SUPPORT_RIGHT",
]
const WEAK_POINT_TEXTURE: Texture2D = preload("res://art/player/vfx/photon_core_orb.png")

var parts: Array[Sprite2D] = []
var sockets: Array[Marker2D] = []
var hurt_regions: Array[Area2D] = []
var host: EnemyActor2D
var active_definition: BossEncounterDefinition
var portrait: bool = false
var active_part_count: int = 0
var active_hurt_region_count: int = 0
var animation_state: StringName = STATE_MOVING
var animation_direction: StringName = DIRECTION_EAST
var animation_stage: StringName = &"TELEGRAPH"
var animation_frame: int = 0
var animation_elapsed: float = 0.0
var defeated_pose: bool = false
var damage_flash_count: int = 0

var _presentation_root: Node2D
var _socket_root: Node2D
var _socket_indices: Dictionary[StringName, int] = {}
var _damage_flash_tween: Tween


func _init() -> void:
	_prewarm()


func configure(
	definition: BossEncounterDefinition,
	p_host: EnemyActor2D,
	use_portrait: bool = false
) -> bool:
	deactivate()
	if definition == null or p_host == null:
		return false
	active_definition = definition
	host = p_host
	portrait = use_portrait
	scale = Vector2.ONE * presentation_scale_for_preset(definition.rig_preset)
	global_position = host.global_position
	_configure_art(definition.rig_preset)
	_configure_sockets(definition.rig_preset, definition.portrait_socket_overrides)
	_configure_hurt_regions(definition.rig_preset)
	set_armor_target_active(host.boss_armor > 0.0)
	visible = true
	return true


static func presentation_scale_for_preset(preset: StringName) -> float:
	return CAMPAIGN_PRESENTATION_SCALE if preset in [
		&"SETTLEMENT_ENGINE",
		&"SAMARITAN",
	] else 1.0


static func visible_bottom_local_y(preset: StringName) -> float:
	match preset:
		&"SETTLEMENT_ENGINE":
			return SETTLEMENT_VISIBLE_BOTTOM_LOCAL_Y
		&"SAMARITAN":
			return SAMARITAN_VISIBLE_BOTTOM_LOCAL_Y
	return 0.0


static func road_contact_y_for_preset(preset: StringName) -> float:
	return (
		CityStreetChunk.ROAD_DIVIDER_Y
		- visible_bottom_local_y(preset) * presentation_scale_for_preset(preset)
	)


func deactivate() -> void:
	active_definition = null
	host = null
	portrait = false
	scale = Vector2.ONE
	active_part_count = 0
	active_hurt_region_count = 0
	animation_state = STATE_MOVING
	animation_direction = DIRECTION_EAST
	animation_stage = &"TELEGRAPH"
	animation_frame = 0
	animation_elapsed = 0.0
	defeated_pose = false
	_cancel_damage_flash()
	visible = false
	for part: Sprite2D in parts:
		part.visible = false
		part.texture = null
		part.region_enabled = false
		part.position = Vector2.ZERO
		part.scale = Vector2.ONE
		part.rotation = 0.0
	for socket: Marker2D in sockets:
		socket.position = Vector2.ZERO
	for area: Area2D in hurt_regions:
		_set_hurt_region_active(area, false)


func receive_damage(event: DamageEvent) -> bool:
	if host == null or not is_instance_valid(host):
		return false
	var accepted: bool = host.receive_damage(event)
	if accepted:
		_flash_damage()
	return accepted


func configure_part(
	index: int,
	texture: Texture2D,
	position_value: Vector2,
	display_size: Vector2,
	modulate_value: Color = Color.WHITE
) -> bool:
	if index < 0 or index >= parts.size() or texture == null:
		return false
	var part: Sprite2D = parts[index]
	part.texture = texture
	part.position = position_value
	part.modulate = modulate_value
	var texture_size: Vector2 = texture.get_size()
	var fit: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	part.scale = Vector2.ONE * fit
	part.visible = true
	active_part_count = maxi(active_part_count, index + 1)
	return true


func socket(socket_name: StringName) -> Marker2D:
	var index: int = int(_socket_indices.get(socket_name, -1))
	return sockets[index] if index >= 0 and index < sockets.size() else null


func attack_telegraph_origin() -> Vector2:
	var core: Marker2D = socket(&"CORE")
	return core.global_position if core != null else global_position


func configure_orientation(use_portrait: bool) -> void:
	portrait = use_portrait
	if active_definition == null:
		return
	_configure_sockets(
		active_definition.rig_preset,
		active_definition.portrait_socket_overrides
	)


func play_moving(direction: StringName = animation_direction) -> void:
	if defeated_pose:
		return
	set_facing(direction)
	if animation_state == STATE_MOVING:
		return
	animation_state = STATE_MOVING
	animation_stage = &"TELEGRAPH"
	animation_elapsed = 0.0
	animation_frame = 0
	_apply_animation_frame()


func play_attacking(stage: StringName, direction: StringName = animation_direction) -> void:
	if defeated_pose:
		return
	set_facing(direction)
	var stage_changed: bool = animation_state != STATE_ATTACKING or animation_stage != stage
	animation_state = STATE_ATTACKING
	animation_stage = stage
	if stage_changed:
		animation_elapsed = 0.0
		animation_frame = BossAnimationCatalog.frame_range_for_stage(stage).x
		_apply_animation_frame()


func set_facing(direction: StringName) -> void:
	if defeated_pose:
		return
	var normalized: StringName = DIRECTION_WEST if direction == DIRECTION_WEST else DIRECTION_EAST
	if animation_direction == normalized:
		return
	animation_direction = normalized
	_apply_animation_frame()


func advance_animation(delta: float) -> void:
	if defeated_pose or not visible or active_definition == null or delta <= 0.0:
		return
	animation_elapsed += delta
	if animation_state == STATE_MOVING:
		var moving_fps: float = float(RuntimeTweakAccess.live_value(
			&"boss.animation_moving_fps", BossAnimationCatalog.MOVING_FPS
		))
		animation_frame = int(floor(animation_elapsed * moving_fps)) % (
			BossAnimationCatalog.FRAME_COUNT
		)
	else:
		var frame_range: Vector2i = BossAnimationCatalog.frame_range_for_stage(animation_stage)
		var frame_count: int = frame_range.y - frame_range.x
		var duration: float = BossAnimationCatalog.stage_duration(animation_stage)
		var progress: float = clampf(animation_elapsed / maxf(duration, 0.001), 0.0, 0.999)
		animation_frame = frame_range.x + mini(
			int(floor(progress * float(frame_count))), frame_count - 1
		)
	_apply_animation_frame()


func freeze_defeated(world_position: Vector2, direction: StringName) -> void:
	if active_definition == null:
		return
	_cancel_damage_flash()
	global_position = world_position
	animation_direction = DIRECTION_WEST if direction == DIRECTION_WEST else DIRECTION_EAST
	animation_state = STATE_ATTACKING
	animation_stage = &"RECOVERY"
	animation_frame = BossAnimationCatalog.FRAME_COUNT - 1
	animation_elapsed = 0.0
	defeated_pose = true
	for area: Area2D in hurt_regions:
		_set_hurt_region_active(area, false)
	active_hurt_region_count = 0
	if parts.size() > 1:
		parts[1].visible = false
	_presentation_root.modulate = DEFEATED_MODULATE
	visible = true
	_apply_animation_frame()


func animation_signature() -> Dictionary:
	return {
		"state": animation_state,
		"direction": animation_direction,
		"stage": animation_stage,
		"frame": animation_frame,
		"defeated": defeated_pose,
		"modulate": _presentation_root.modulate,
		"sequence_row": BossAnimationCatalog.sequence_row(
			animation_direction, animation_state
		),
	}


func mechanical_signature() -> Dictionary:
	var regions: Array[Dictionary] = []
	for area: Area2D in hurt_regions:
		var collision: CollisionShape2D = area.get_node(^"Collision") as CollisionShape2D
		var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
		regions.append({
			"position": area.position,
			"size": rectangle.size,
			"enabled": not collision.disabled,
		})
	return {
		"hurt_regions": regions,
		"active_hurt_regions": active_hurt_region_count,
	}


func presentation_signature() -> Dictionary:
	var socket_positions: Dictionary[StringName, Vector2] = {}
	for index: int in range(sockets.size()):
		socket_positions[SOCKET_NAMES[index]] = sockets[index].position
	return {
		"portrait": portrait,
		"scale": _presentation_root.scale,
		"sockets": socket_positions,
		"animation": animation_signature(),
	}


func _prewarm() -> void:
	name = "BossRig2D"
	z_index = 31
	_presentation_root = Node2D.new()
	_presentation_root.name = "Presentation"
	add_child(_presentation_root)
	for index: int in range(PART_CAPACITY):
		var part: Sprite2D = Sprite2D.new()
		part.name = "Part%02d" % index
		part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_presentation_root.add_child(part)
		parts.append(part)
	_socket_root = Node2D.new()
	_socket_root.name = "PresentationSockets"
	_presentation_root.add_child(_socket_root)
	for index: int in range(SOCKET_CAPACITY):
		var marker: Marker2D = Marker2D.new()
		marker.name = String(SOCKET_NAMES[index]).to_pascal_case()
		_socket_root.add_child(marker)
		sockets.append(marker)
		_socket_indices[SOCKET_NAMES[index]] = index
	for index: int in range(HURT_REGION_CAPACITY):
		var area: Area2D = Area2D.new()
		area.name = "HurtRegion%02d" % index
		area.collision_layer = 0
		area.collision_mask = 0
		area.monitoring = false
		area.monitorable = false
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.name = "Collision"
		collision.shape = RectangleShape2D.new()
		collision.disabled = true
		area.add_child(collision)
		add_child(area)
		hurt_regions.append(area)
	deactivate()


func _configure_art(preset: StringName) -> void:
	var texture: Texture2D = BossAnimationCatalog.texture_for_preset(preset)
	configure_part(0, texture, Vector2(0.0, -116.0), DEFAULT_DISPLAY_SIZE)
	parts[0].region_enabled = true
	parts[0].region_filter_clip_enabled = true
	animation_state = STATE_MOVING
	animation_direction = DIRECTION_EAST
	animation_stage = &"TELEGRAPH"
	animation_frame = 0
	animation_elapsed = 0.0
	_apply_animation_frame()
	configure_part(
		1,
		WEAK_POINT_TEXTURE,
		_socket_position_for(preset, &"WEAK_POINT"),
		Vector2(72.0, 72.0),
		Color(1.0, 1.0, 1.0, 0.94)
	)


func _configure_sockets(preset: StringName, portrait_overrides: Dictionary) -> void:
	_presentation_root.scale = Vector2.ONE
	for index: int in range(sockets.size()):
		sockets[index].position = _socket_position_for(preset, SOCKET_NAMES[index])
	if not portrait:
		return
	var presentation_scale: Vector2 = portrait_overrides.get(
		&"presentation_scale",
		Vector2(0.82, 1.0)
	) as Vector2
	_presentation_root.scale = presentation_scale
	var socket_overrides: Dictionary = portrait_overrides.get(&"sockets", {}) as Dictionary
	for key_value: Variant in socket_overrides:
		var marker: Marker2D = socket(StringName(key_value))
		if marker != null:
			marker.position = socket_overrides[key_value] as Vector2


func set_armor_target_active(active: bool) -> void:
	if parts.size() < 2:
		return
	var weak_point: Sprite2D = parts[1]
	weak_point.visible = active
	weak_point.modulate = Color(1.0, 0.78, 0.18, 1.0) if active else Color.WHITE


func _flash_damage() -> void:
	_cancel_damage_flash()
	damage_flash_count += 1
	_presentation_root.modulate = Color(4.0, 4.0, 4.0, 1.0)
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(
		_presentation_root,
		"modulate",
		Color.WHITE,
		0.11
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_damage_flash_tween.finished.connect(_on_damage_flash_finished)


func _cancel_damage_flash() -> void:
	if _damage_flash_tween != null and _damage_flash_tween.is_valid():
		_damage_flash_tween.kill()
	_damage_flash_tween = null
	if _presentation_root != null:
		_presentation_root.modulate = Color.WHITE


func _on_damage_flash_finished() -> void:
	_damage_flash_tween = null


func _configure_hurt_regions(preset: StringName) -> void:
	var positions: Array[Vector2] = [
		Vector2(0.0, -112.0),
		Vector2(-172.0, -72.0),
		Vector2(172.0, -72.0),
	]
	var sizes: Array[Vector2] = [
		Vector2(292.0, 210.0),
		Vector2(150.0, 118.0),
		Vector2(150.0, 118.0),
	]
	if preset == &"SAMARITAN":
		positions = [
			Vector2(0.0, -78.0),
			Vector2(-188.0, -48.0),
			Vector2(188.0, -48.0),
		]
		sizes = [
			Vector2(150.0, 120.0),
			Vector2(112.0, 90.0),
			Vector2(112.0, 90.0),
		]
	for index: int in range(hurt_regions.size()):
		var area: Area2D = hurt_regions[index]
		area.position = positions[index]
		var collision: CollisionShape2D = area.get_node(^"Collision") as CollisionShape2D
		(collision.shape as RectangleShape2D).size = sizes[index]
		_set_hurt_region_active(area, true)
	active_hurt_region_count = hurt_regions.size()


func _set_hurt_region_active(area: Area2D, enabled: bool) -> void:
	area.collision_layer = HURTBOX_LAYER if enabled else 0
	area.monitorable = enabled
	area.monitoring = false
	var collision: CollisionShape2D = area.get_node(^"Collision") as CollisionShape2D
	collision.disabled = not enabled


func _apply_animation_frame() -> void:
	if parts.is_empty() or active_definition == null:
		return
	var sprite: Sprite2D = parts[0]
	if sprite.texture == null:
		return
	var texture_size: Vector2 = sprite.texture.get_size()
	var cell_size: Vector2 = Vector2(
		texture_size.x / float(BossAnimationCatalog.COLUMN_COUNT),
		texture_size.y / float(BossAnimationCatalog.ROW_COUNT)
	)
	var row: int = BossAnimationCatalog.sequence_row(animation_direction, animation_state)
	var column: int = clampi(animation_frame, 0, BossAnimationCatalog.FRAME_COUNT - 1)
	sprite.region_rect = Rect2(
		Vector2(float(column) * cell_size.x, float(row) * cell_size.y),
		cell_size
	)
	var fit: float = minf(
		DEFAULT_DISPLAY_SIZE.x / maxf(cell_size.x, 1.0),
		DEFAULT_DISPLAY_SIZE.y / maxf(cell_size.y, 1.0)
	)
	sprite.scale = Vector2.ONE * fit


func _socket_position_for(preset: StringName, socket_name: StringName) -> Vector2:
	var horizontal_scale: float = 1.0
	var vertical_shift: float = 0.0
	match preset:
		&"SAMARITAN":
			horizontal_scale = 0.92
			vertical_shift = -12.0
	var base_positions: Dictionary[StringName, Vector2] = {
		&"CORE": Vector2(0.0, -116.0),
		&"WEAK_POINT": Vector2(0.0, -138.0),
		&"LEFT_EMITTER": Vector2(-196.0, -116.0),
		&"RIGHT_EMITTER": Vector2(196.0, -116.0),
		&"UPPER": Vector2(0.0, -280.0),
		&"LOWER": Vector2(0.0, -22.0),
		&"SUPPORT_LEFT": Vector2(-270.0, -8.0),
		&"SUPPORT_RIGHT": Vector2(270.0, -8.0),
	}
	var position_value: Vector2 = base_positions.get(socket_name, Vector2.ZERO) as Vector2
	position_value.x *= horizontal_scale
	position_value.y += vertical_shift
	return position_value
