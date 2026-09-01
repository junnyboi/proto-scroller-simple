# gdlint: disable=max-public-methods
class_name BossUtilityPool
extends Node

enum UtilityPresentationRole {
	NONE,
	ARCHIVE_TREASURY,
	EVACUATION_CRADLE,
	EXTRACTION_CLAMP,
	SHOW_CONTROL_CABINET,
	RUBBLE_BED,
	FREIGHT_RECLAMATION_ANCHOR,
	SERAPH_PROJECTION,
}

const MARKER_CAPACITY: int = 8
const LANE_DAMAGE_AREA_CAPACITY: int = 3
const LINE_AREA_CAPACITY: int = 2
const RADIAL_SHOCKWAVE_CAPACITY: int = 1
const COLLAPSE_LISTENER_CAPACITY: int = 2
const POD_VISUAL_CAPACITY: int = 4
const RECLAMATION_ANCHOR_CAPACITY: int = 3
const PYLON_PRESENTATION_CAPACITY: int = 5
const PROJECTION_SLOT_CAPACITY: int = 4
const WRECK_RECEIVER_CAPACITY: int = 2
const BOSS_RUBBLE_DISPLAY_SIZE: Vector2 = Vector2(460.0, 150.0)
const ATTACK_PRESENTATION_Z_INDEX: int = 72
const MIMESIS_AFTERIMAGE_TEXTURE: Texture2D = preload(
	"res://art/presentation/impact_spark.png"
)
const ARCHIVE_TREASURY_TEXTURE: Texture2D = preload(
	"res://art/bosses/utilities/boss-archive-treasury-bracket.png"
)
const EVACUATION_CRADLE_TEXTURE: Texture2D = preload(
	"res://art/bosses/utilities/boss-evacuation-cradle.png"
)
const EXTRACTION_CLAMP_TEXTURE: Texture2D = preload(
	"res://art/bosses/utilities/boss-extraction-clamp.png"
)
const SHOW_CONTROL_CABINET_TEXTURE: Texture2D = preload(
	"res://art/bosses/utilities/boss-archive-treasury-bracket.png"
)
const RUBBLE_BED_TEXTURE: Texture2D = preload(
	"res://art/bosses/utilities/boss-rubble-bed.png"
)
const FREIGHT_RECLAMATION_ANCHOR_TEXTURE: Texture2D = preload(
	"res://art/bosses/utilities/boss-extraction-clamp.png"
)
const SERAPH_PROJECTION_TEXTURE: Texture2D = preload(
	"res://art/player/vfx/photon_core_orb.png"
)
const CHOIR_PYLON_TEXTURE: Texture2D = preload("res://art/player/vfx/photon_core_orb.png")
const CHOIR_PYLON_OFFSETS: Array[Vector2] = [
	Vector2(-360.0, -160.0), Vector2(-180.0, -245.0), Vector2(0.0, -280.0),
	Vector2(180.0, -245.0), Vector2(360.0, -160.0),
]

var rig: BossRig2D
var defeat_spectacle: BossDefeatSpectacle2D
var controller: BossPhaseRuntime
var vertical_slice: BossVerticalSliceController
var escalation: BossEscalationController
var motion_echo_recorder: MotionEchoRecorder
var arena_adapter: BossStructuralAdapter
var attack_presentation_root: Node2D
var attack_particle_pool: BossAttackParticlePool2D
var markers: Array[Marker2D] = []
var marker_presentations: Array[Sprite2D] = []
var lane_damage_areas: Array[BossAttackArea2D] = []
var line_areas: Array[BossAttackArea2D] = []
var radial_shockwave: BossAttackArea2D
var collapse_listeners: Array[Node] = []
var pod_visuals: Array[BossPodVisual2D] = []
var reclamation_anchor_records: Array[Node2D] = []
var pylon_presentations: Array[Node2D] = []
var projection_slots: Array[Node2D] = []
var wreck_receivers: Array[BossWreckReceiver2D] = []
var default_wreck_receiver: BossWreckReceiver2D
var royal_outcome_receiver: BossWreckReceiver2D
var boss_rubble_record: Node2D
var generation_token: int = 0
var post_warm_creation_count: int = 0
var warmed: bool = false
var denial_count: int = 0
var peak_reservations: int = 0

var _reservations: Dictionary[int, Dictionary] = {}
var _cleanup_callbacks: Array[Callable] = []
var _next_reservation_id: int = 1



func _init() -> void:
	_prewarm()


static func utility_capacities() -> Dictionary[StringName, int]:
	return {
		&"markers": MARKER_CAPACITY,
		&"lane_damage_areas": LANE_DAMAGE_AREA_CAPACITY,
		&"line_areas": LINE_AREA_CAPACITY,
		&"radial_shockwaves": RADIAL_SHOCKWAVE_CAPACITY,
		&"collapse_listeners": COLLAPSE_LISTENER_CAPACITY,
		&"pod_visuals": POD_VISUAL_CAPACITY,
		&"reclamation_anchors": RECLAMATION_ANCHOR_CAPACITY,
		&"pylon_presentations": PYLON_PRESENTATION_CAPACITY,
		&"projection_slots": PROJECTION_SLOT_CAPACITY,
		&"wreck_receivers": WRECK_RECEIVER_CAPACITY,
	}


func begin_generation() -> int:
	_cleanup_current_generation()
	generation_token += 1
	return generation_token


func begin_wreck_generation() -> int:
	_cleanup_current_generation(true)
	generation_token += 1
	return generation_token


func cleanup_generation(token: int) -> bool:
	if token != generation_token:
		return false
	_cleanup_current_generation()
	return true


func is_current_generation(token: int) -> bool:
	return token == generation_token


func register_generation_cleanup(callback: Callable, token: int = -1) -> bool:
	var requested_generation: int = generation_token if token < 0 else token
	if not is_current_generation(requested_generation) or not callback.is_valid():
		return false
	_cleanup_callbacks.append(callback)
	return true


func reserve_requirements(requirements: Dictionary, token: int = -1) -> int:
	var requested_generation: int = generation_token if token < 0 else token
	if not is_current_generation(requested_generation):
		denial_count += 1
		return 0
	if requirements.is_empty() or not _can_reserve(requirements):
		denial_count += 1
		return 0
	var reservation_id: int = _next_reservation_id
	_next_reservation_id += 1
	_reservations[reservation_id] = {
		"generation": requested_generation,
		"remaining": requirements.duplicate(),
	}
	peak_reservations = maxi(peak_reservations, reservation_count())
	return reservation_id


func consume_reservation(reservation_id: int, key: StringName, count: int = 1) -> bool:
	if not _reservations.has(reservation_id) or count <= 0:
		return false
	var record: Dictionary = _reservations[reservation_id]
	if int(record.generation) != generation_token:
		return false
	var remaining: Dictionary = record.remaining
	if int(remaining.get(key, 0)) < count:
		return false
	remaining[key] = int(remaining[key]) - count
	if _dictionary_total(remaining) == 0:
		_reservations.erase(reservation_id)
	return true


func cancel_reservation(reservation_id: int) -> void:
	_reservations.erase(reservation_id)


func cancel_all_reservations() -> void:
	_reservations.clear()


func reservation_count() -> int:
	return _reservations.size()


func reserved_units(key: StringName = &"") -> int:
	var total: int = 0
	for record: Dictionary in _reservations.values():
		var remaining: Dictionary = record.remaining
		total += _dictionary_total(remaining) if key.is_empty() else int(remaining.get(key, 0))
	return total


func capture_reservation_state() -> Dictionary:
	return {
		"generation": generation_token,
		"next_id": _next_reservation_id,
		"reservations": _reservations.duplicate(true),
	}


func restore_reservation_state(state: Dictionary) -> void:
	_cleanup_current_generation()
	generation_token = int(state.get("generation", generation_token))
	_next_reservation_id = int(state.get("next_id", _next_reservation_id))
	_reservations = state.get("reservations", {}).duplicate(true)


func area_count() -> int:
	return (
		lane_damage_areas.size()
		+ line_areas.size()
		+ int(radial_shockwave != null)
		+ wreck_receivers.size()
	)


func marker_count() -> int:
	return markers.size()


func pylon_count() -> int:
	return pylon_presentations.size()


func present_royal_pylons(center: Vector2) -> void:
	rig.visible = true
	for index: int in range(pylon_presentations.size()):
		var pylon: Node2D = pylon_presentations[index]
		pylon.global_position = center + CHOIR_PYLON_OFFSETS[index]
		pylon.visible = true


func configure_royal_pylon(index: int, pylon_id: StringName) -> bool:
	if index < 0 or index >= pylon_presentations.size() or pylon_id.is_empty():
		return false
	var pylon: Node2D = pylon_presentations[index]
	pylon.set_meta(&"pylon_id", pylon_id)
	pylon.name = "Pylon%s" % String(pylon_id).to_pascal_case()
	set_royal_pylon_active(index, false)
	return true


func set_royal_pylon_visible(index: int, visible_value: bool) -> bool:
	if index < 0 or index >= pylon_presentations.size():
		return false
	pylon_presentations[index].visible = visible_value
	return true


func set_royal_pylon_active(index: int, active: bool) -> bool:
	if index < 0 or index >= pylon_presentations.size():
		return false
	var pylon: Node2D = pylon_presentations[index]
	var sprite: Sprite2D = pylon.get_child(0) as Sprite2D
	if sprite != null:
		sprite.modulate = (
			Color(1.0, 0.78, 0.28, 1.0)
			if active
			else Color(0.72, 1.0, 0.95, 0.96)
		)
		sprite.scale = Vector2.ONE * (0.80 if active else 0.68)
	return true


func configure_royal_echo_presentation(
	index: int,
	texture: Texture2D,
	world_position: Vector2,
	display_size: Vector2
) -> bool:
	if index < 0 or index >= marker_presentations.size() or texture == null:
		return false
	var presentation: Sprite2D = marker_presentations[index]
	presentation.texture = texture
	presentation.global_position = world_position
	var texture_size: Vector2 = texture.get_size()
	var fit: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	presentation.scale = Vector2.ONE * fit
	presentation.modulate = Color(0.35, 0.98, 1.0, 0.42)
	presentation.visible = true
	markers[index].visible = true
	return true


func hide_royal_echo_presentations() -> void:
	for index: int in range(marker_presentations.size()):
		_reset_marker_presentation(marker_presentations[index])
		markers[index].visible = false


func configure_utility_presentation(
	record: Node2D,
	role: UtilityPresentationRole
) -> bool:
	if record == null or record.get_child_count() != 1:
		return false
	var sprite: Sprite2D = record.get_child(0) as Sprite2D
	if sprite == null:
		return false
	_reset_utility_presentation(record)
	var texture: Texture2D = _utility_texture(role)
	var display_size: Vector2 = _utility_display_size(role)
	if texture == null or display_size == Vector2.ZERO:
		return role == UtilityPresentationRole.NONE
	var texture_size: Vector2 = texture.get_size()
	sprite.texture = texture
	sprite.scale = Vector2(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	sprite.position.y = -display_size.y * 0.5
	sprite.visible = true
	record.set_meta(&"presentation_role", role)
	return true


func projection_count() -> int:
	return projection_slots.size()


func pod_visual_count() -> int:
	return pod_visuals.size()


func reclamation_anchor_count() -> int:
	return reclamation_anchor_records.size()


func collapse_listener_count() -> int:
	return collapse_listeners.size()


func wreck_receiver_count() -> int:
	return wreck_receivers.size()


func boss_rubble_count() -> int:
	return 1 if boss_rubble_record != null else 0


func present_boss_rubble(world_position: Vector2) -> bool:
	if boss_rubble_record == null:
		return false
	boss_rubble_record.global_position = Vector2(
		world_position.x,
		CityStreetChunk.ROAD_DIVIDER_Y
	)
	if not configure_utility_presentation(
		boss_rubble_record,
		UtilityPresentationRole.RUBBLE_BED
	):
		return false
	var sprite: Sprite2D = boss_rubble_record.get_child(0) as Sprite2D
	var texture_size: Vector2 = sprite.texture.get_size()
	sprite.scale = Vector2(
		BOSS_RUBBLE_DISPLAY_SIZE.x / maxf(texture_size.x, 1.0),
		BOSS_RUBBLE_DISPLAY_SIZE.y / maxf(texture_size.y, 1.0)
	)
	sprite.position.y = -BOSS_RUBBLE_DISPLAY_SIZE.y * 0.5
	sprite.modulate = BossRig2D.DEFEATED_MODULATE
	boss_rubble_record.visible = true
	return true


func configure_runtime(
	encounter_runtime: EncounterRuntime,
	projectile_pool: ProjectilePool
) -> void:
	controller.setup(self, encounter_runtime, projectile_pool)
	vertical_slice.setup(self, encounter_runtime)
	escalation.setup(self, encounter_runtime)
	for area: BossAttackArea2D in lane_damage_areas + line_areas:
		area.setup_damage_target(encounter_runtime.robot)
	if radial_shockwave != null:
		radial_shockwave.setup_damage_target(encounter_runtime.robot)


func configure_wreck_receivers(
	wreck: EnemyWreck2D,
	definition: BossEncounterDefinition,
	receiver_callback: Callable = Callable()
) -> void:
	for receiver: BossWreckReceiver2D in wreck_receivers:
		receiver.deactivate()
	if wreck == null or definition == null:
		return
	var offsets: PackedVector2Array = definition.wreck_receiver_offsets
	default_wreck_receiver.configure(
		wreck,
		BossOutcome.PURGE,
		wreck.global_position + offsets[0],
		receiver_callback
	)
	var default_label: String = (
		L10n.t("finale.receiver.purge_label")
		if offsets.size() > 1
		else L10n.t("boss.receiver.finish_label")
	)
	var default_color: Color = (
		Color(1.0, 0.30, 0.20, 1.0)
		if offsets.size() > 1
		else Color(1.0, 0.78, 0.18, 1.0)
	)
	default_wreck_receiver.configure_presentation(
		default_label,
		default_color
	)
	if offsets.size() > 1:
		royal_outcome_receiver.configure(
			wreck,
			BossOutcome.DISENTANGLE,
			wreck.global_position + offsets[1],
			receiver_callback
		)
		royal_outcome_receiver.configure_presentation(
			L10n.t("finale.receiver.disentangle_label"),
			Color(0.24, 0.94, 1.0, 1.0)
		)
	# Campaign finishers are reachable only through the authored receiver areas.
	wreck.collision_layer = 0


func rig_count() -> int:
	return 1 if rig != null else 0


func defeat_spectacle_count() -> int:
	return 1 if defeat_spectacle != null else 0


func defeat_visual_slot_count() -> int:
	return defeat_spectacle.visual_slot_count() if defeat_spectacle != null else 0


func defeat_particle_emitter_count() -> int:
	return defeat_spectacle.particle_emitter_count() if defeat_spectacle != null else 0


func defeat_particle_capacity() -> int:
	return defeat_spectacle.particle_capacity() if defeat_spectacle != null else 0


func defeat_audio_player_count() -> int:
	return defeat_spectacle.audio_player_count() if defeat_spectacle != null else 0


func controller_count() -> int:
	return 1 if controller != null else 0


func arena_adapter_count() -> int:
	return 1 if arena_adapter != null else 0


func _prewarm() -> void:
	if warmed:
		return
	rig = BossRig2D.new()
	add_child(rig)
	defeat_spectacle = BossDefeatSpectacle2D.new()
	add_child(defeat_spectacle)
	controller = BossPhaseRuntime.new()
	controller.name = "BossBehaviorController"
	add_child(controller)
	vertical_slice = BossVerticalSliceController.new()
	vertical_slice.name = "BossVerticalSliceController"
	add_child(vertical_slice)
	escalation = BossEscalationController.new()
	escalation.name = "BossEscalationController"
	add_child(escalation)
	arena_adapter = BossStructuralAdapter.new()
	add_child(arena_adapter)
	attack_presentation_root = Node2D.new()
	attack_presentation_root.name = "BossAttackPresentationRoot"
	attack_presentation_root.z_as_relative = false
	attack_presentation_root.z_index = ATTACK_PRESENTATION_Z_INDEX
	add_child(attack_presentation_root)
	attack_particle_pool = BossAttackParticlePool2D.new()
	attack_particle_pool.name = "BossAttackParticlePool"
	attack_presentation_root.add_child(attack_particle_pool)
	attack_particle_pool.setup()
	for index: int in range(PYLON_PRESENTATION_CAPACITY):
		var pylon: Node2D = _make_record("PylonPresentation%02d" % index, rig)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = CHOIR_PYLON_TEXTURE
		sprite.scale = Vector2(0.68, 0.68)
		sprite.modulate = Color(0.72, 1.0, 0.95, 0.96)
		pylon.add_child(sprite)
		pylon_presentations.append(pylon)
	for index: int in range(PROJECTION_SLOT_CAPACITY):
		var projection: Node2D = _make_visual_record("ProjectionSlot%02d" % index, rig)
		projection_slots.append(projection)
	for index: int in range(MARKER_CAPACITY):
		var marker: Marker2D = Marker2D.new()
		marker.name = "AttackMarker%02d" % index
		arena_adapter.add_child(marker)
		markers.append(marker)
		var presentation: Sprite2D = Sprite2D.new()
		presentation.name = "MarkerPresentation%02d" % index
		presentation.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		presentation.z_index = 5
		marker.add_child(presentation)
		_reset_marker_presentation(presentation)
		marker_presentations.append(presentation)
	for index: int in range(LANE_DAMAGE_AREA_CAPACITY):
		lane_damage_areas.append(_make_area(
			"LaneDamageArea%02d" % index,
			BossAttackArea2D.PresentationRole.LANE_PLATE
		))
	for index: int in range(LINE_AREA_CAPACITY):
		line_areas.append(_make_area(
			"LineArea%02d" % index,
			BossAttackArea2D.PresentationRole.LINE_BEAM
		))
	radial_shockwave = _make_area(
		"RadialShockwave",
		BossAttackArea2D.PresentationRole.RADIAL_SHOCKWAVE
	)
	for index: int in range(COLLAPSE_LISTENER_CAPACITY):
		var listener: Node = Node.new()
		listener.name = "CollapseListener%02d" % index
		arena_adapter.add_child(listener)
		collapse_listeners.append(listener)
	for index: int in range(POD_VISUAL_CAPACITY):
		var pod: BossPodVisual2D = BossPodVisual2D.new()
		pod.name = "ProtectedPodVisual%02d" % index
		rig.add_child(pod)
		pod_visuals.append(pod)
	for index: int in range(RECLAMATION_ANCHOR_CAPACITY):
		var anchor: Node2D = _make_visual_record(
			"ReclamationAnchor%02d" % index, arena_adapter
		)
		reclamation_anchor_records.append(anchor)
	motion_echo_recorder = MotionEchoRecorder.new()
	motion_echo_recorder.name = "MotionEchoRecorder"
	arena_adapter.add_child(motion_echo_recorder)
	motion_echo_recorder.setup(markers, lane_damage_areas[2])
	escalation.attach_recorder(motion_echo_recorder)
	default_wreck_receiver = _make_wreck_receiver("DefaultWreckReceiver")
	royal_outcome_receiver = _make_wreck_receiver("RoyalOutcomeReceiver")
	wreck_receivers.assign([default_wreck_receiver, royal_outcome_receiver])
	boss_rubble_record = _make_visual_record("BossRubblePresentation", self)
	boss_rubble_record.z_index = 25
	warmed = true
	_deactivate_records()


func _make_record(record_name: String, parent: Node) -> Node2D:
	var record: Node2D = Node2D.new()
	record.name = record_name
	parent.add_child(record)
	return record


func _make_visual_record(record_name: String, parent: Node) -> Node2D:
	var record: Node2D = _make_record(record_name, parent)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Presentation"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = 4
	record.add_child(sprite)
	_reset_utility_presentation(record)
	return record


func _make_area(
	area_name: String,
	role: BossAttackArea2D.PresentationRole
) -> BossAttackArea2D:
	var area: BossAttackArea2D = BossAttackArea2D.new()
	area.name = area_name
	area.set_presentation_role(role)
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "Collision"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(192.0, 96.0)
	collision.shape = shape
	collision.disabled = true
	area.add_child(collision)
	attack_presentation_root.add_child(area)
	area.prewarm_attack_particles()
	area.deactivate()
	return area


func _make_wreck_receiver(area_name: String) -> BossWreckReceiver2D:
	var receiver: BossWreckReceiver2D = BossWreckReceiver2D.new()
	receiver.name = area_name
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "Collision"
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = BossEncounterDefinition.DEFAULT_GROUND_SMASH_RADIUS * 0.42
	collision.shape = shape
	receiver.add_child(collision)
	arena_adapter.add_child(receiver)
	receiver.deactivate()
	return receiver


func _cleanup_current_generation(preserve_rig: bool = false) -> void:
	for callback: Callable in _cleanup_callbacks:
		if callback.is_valid():
			callback.call()
	_cleanup_callbacks.clear()
	cancel_all_reservations()
	_deactivate_records(preserve_rig)


func _deactivate_records(preserve_rig: bool = false) -> void:
	if not preserve_rig:
		rig.deactivate()
	motion_echo_recorder.deactivate()
	arena_adapter.unbind()
	for record: Node2D in pylon_presentations:
		record.visible = false
	hide_royal_echo_presentations()
	for record: Node2D in projection_slots:
		_reset_utility_presentation(record)
	for record: Node2D in pod_visuals:
		record.visible = false
	for record: Node2D in reclamation_anchor_records:
		_reset_utility_presentation(record)
	if boss_rubble_record != null:
		_reset_utility_presentation(boss_rubble_record)
	for receiver: BossWreckReceiver2D in wreck_receivers:
		receiver.deactivate()
	if attack_particle_pool != null:
		attack_particle_pool.stop_all()
	for area: BossAttackArea2D in lane_damage_areas + line_areas:
		area.deactivate()
	for area: BossAttackArea2D in lane_damage_areas:
		area.set_presentation_role(BossAttackArea2D.PresentationRole.LANE_PLATE)
	for area: BossAttackArea2D in line_areas:
		area.set_presentation_role(BossAttackArea2D.PresentationRole.LINE_BEAM)


func _reset_marker_presentation(presentation: Sprite2D) -> void:
	presentation.texture = MIMESIS_AFTERIMAGE_TEXTURE
	presentation.position = Vector2.ZERO
	presentation.rotation = 0.0
	var texture_size: Vector2 = MIMESIS_AFTERIMAGE_TEXTURE.get_size()
	presentation.scale = Vector2(48.0 / texture_size.x, 32.0 / texture_size.y)
	presentation.modulate = Color(0.35, 0.98, 1.0, 0.42)
	presentation.visible = false


func _reset_utility_presentation(record: Node2D) -> void:
	var sprite: Sprite2D = record.get_child(0) as Sprite2D
	sprite.texture = null
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	sprite.visible = false
	record.visible = false
	record.set_meta(&"presentation_role", UtilityPresentationRole.NONE)


func _utility_texture(role: UtilityPresentationRole) -> Texture2D:
	var texture: Texture2D
	match role:
		UtilityPresentationRole.ARCHIVE_TREASURY:
			texture = ARCHIVE_TREASURY_TEXTURE
		UtilityPresentationRole.EVACUATION_CRADLE:
			texture = EVACUATION_CRADLE_TEXTURE
		UtilityPresentationRole.EXTRACTION_CLAMP:
			texture = EXTRACTION_CLAMP_TEXTURE
		UtilityPresentationRole.SHOW_CONTROL_CABINET:
			texture = SHOW_CONTROL_CABINET_TEXTURE
		UtilityPresentationRole.RUBBLE_BED:
			texture = RUBBLE_BED_TEXTURE
		UtilityPresentationRole.FREIGHT_RECLAMATION_ANCHOR:
			texture = FREIGHT_RECLAMATION_ANCHOR_TEXTURE
		UtilityPresentationRole.SERAPH_PROJECTION:
			texture = SERAPH_PROJECTION_TEXTURE
	return texture


func _utility_display_size(role: UtilityPresentationRole) -> Vector2:
	var display_size: Vector2 = Vector2.ZERO
	match role:
		UtilityPresentationRole.ARCHIVE_TREASURY:
			display_size = Vector2(128.0, 112.0)
		UtilityPresentationRole.EVACUATION_CRADLE:
			display_size = Vector2(152.0, 112.0)
		UtilityPresentationRole.EXTRACTION_CLAMP:
			display_size = Vector2(144.0, 64.0)
		UtilityPresentationRole.SHOW_CONTROL_CABINET:
			display_size = Vector2(104.0, 136.0)
		UtilityPresentationRole.RUBBLE_BED:
			display_size = Vector2(184.0, 64.0)
		UtilityPresentationRole.FREIGHT_RECLAMATION_ANCHOR:
			display_size = Vector2(104.0, 80.0)
		UtilityPresentationRole.SERAPH_PROJECTION:
			display_size = Vector2(176.0, 112.0)
	return display_size


func _can_reserve(requirements: Dictionary) -> bool:
	for key_value: Variant in requirements:
		var key: StringName = StringName(key_value)
		var requested: int = int(requirements[key_value])
		var capacity: int = _capacity_for(key)
		if requested <= 0 or capacity <= 0 or reserved_units(key) + requested > capacity:
			return false
	return true


func _capacity_for(key: StringName) -> int:
	var utility_capacity: int = int(utility_capacities().get(key, 0))
	if utility_capacity > 0:
		return utility_capacity
	match key:
		&"procedural_infantry":
			return 12
		&"procedural_light":
			return 3
		&"procedural_heavy", &"procedural_air":
			return 4
		&"procedural_siege":
			return 2
	return 0


func _dictionary_total(values: Dictionary) -> int:
	var total: int = 0
	for value: Variant in values.values():
		total += int(value)
	return total
