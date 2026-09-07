class_name CatalystRuntime
extends Node2D

signal catalyst_triggered(catalyst: Catalyst2D, event: DamageEvent)
signal catalyst_resolved(catalyst: Catalyst2D, affected_count: int)
signal repair_pickup_spawned(pickup: ChassisRepairPickup2D)
signal repair_pickup_collected(repaired_health: float)
signal power_box_obliterated(catalyst: Catalyst2D, awarded_score: int)

const SLOT_COUNT: int = 2
const REPAIR_PICKUP_CAPACITY: int = SLOT_COUNT + 3
const POWER_BOX_SCRAP_PIECES: int = 6
const POWER_BOX_FINISH_POINTS: int = 150
const POWER_BOX_SCRAP_IMPULSE: float = 980.0
const CATALYST_SCRIPT: Script = preload("res://scripts/destruction/catalysts/catalyst_2d.gd")
const REPAIR_PICKUP_SCRIPT: Script = preload(
	"res://scripts/destruction/catalysts/chassis_repair_pickup_2d.gd"
)

var dependencies: UrbanSiegeDependencies
var slots: Array[Catalyst2D] = []
var repair_pickups: Array[ChassisRepairPickup2D] = []
var pulse_count: int = 0
var power_box_scrap_burst_count: int = 0
var power_box_scrap_piece_count: int = 0
var power_box_finish_score_count: int = 0
var power_box_detonation_sfx_count: int = 0
var _next_pulse_attack_id: int = 1_000_000


func setup(p_dependencies: UrbanSiegeDependencies) -> void:
	dependencies = p_dependencies


func _ready() -> void:
	for index: int in range(SLOT_COUNT):
		var catalyst: Catalyst2D = CATALYST_SCRIPT.new() as Catalyst2D
		catalyst.name = "CatalystSlot%d" % index
		catalyst.z_index = 24
		var visual: Sprite2D = Sprite2D.new()
		visual.name = "Visual"
		catalyst.add_child(visual)
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(74.0, 70.0)
		collision.shape = shape
		catalyst.add_child(collision)
		catalyst.triggered.connect(_on_catalyst_triggered)
		catalyst.fully_destroyed.connect(_on_catalyst_fully_destroyed)
		add_child(catalyst)
		if dependencies != null and dependencies.building_section_burst_pool != null:
			catalyst.rubble_dust_pool_path = catalyst.get_path_to(
				dependencies.building_section_burst_pool
			)
		catalyst.reset_catalyst()
		slots.append(catalyst)
	for index: int in range(REPAIR_PICKUP_CAPACITY):
		var pickup: ChassisRepairPickup2D = REPAIR_PICKUP_SCRIPT.new()
		pickup.name = "ChassisRepairPickupSlot%d" % index
		pickup.z_index = 40
		pickup.collected.connect(_on_repair_pickup_collected)
		add_child(pickup)
		repair_pickups.append(pickup)


func activate(
	slot: int,
	profile: CatalystProfile,
	world_position: Vector2,
	district_id: StringName = &"BUSINESS"
) -> Catalyst2D:
	if slot < 0 or slot >= slots.size() or profile == null:
		return null
	var catalyst: Catalyst2D = slots[slot]
	catalyst.arm(profile, world_position, district_id)
	return catalyst


func deactivate_all() -> void:
	for catalyst: Catalyst2D in slots:
		catalyst.reset_catalyst()
	for pickup: ChassisRepairPickup2D in repair_pickups:
		pickup.reset_pickup()


func active_count() -> int:
	var count: int = 0
	for catalyst: Catalyst2D in slots:
		if catalyst.armed:
			count += 1
	return count


func total_count() -> int:
	return slots.size()


func active_repair_pickup_count() -> int:
	var count: int = 0
	for pickup: ChassisRepairPickup2D in repair_pickups:
		count += 1 if pickup.active else 0
	return count


func repair_pickup_count() -> int:
	return repair_pickups.size()


func _on_catalyst_triggered(catalyst: Catalyst2D, event: DamageEvent) -> void:
	catalyst_triggered.emit(catalyst, event)
	if catalyst.profile != null and catalyst.profile.catalyst_id == &"TRANSFORMER":
		spawn_repair_pickup(catalyst.global_position + Vector2(0.0, -96.0))
	_resolve_after_delay(catalyst, event)


func spawn_repair_pickup(
	world_position: Vector2,
	repair_amount: float = ChassisRepairPickup2D.REPAIR_AMOUNT
) -> ChassisRepairPickup2D:
	var selected: ChassisRepairPickup2D
	for pickup: ChassisRepairPickup2D in repair_pickups:
		if not pickup.active:
			selected = pickup
			break
	if selected == null:
		return null
	var tuned_amount: float = float(RuntimeTweakAccess.next_spawn_value(
		&"world.repair_drop.amount", ChassisRepairPickup2D.REPAIR_AMOUNT
	))
	var tuned_lifetime: float = float(RuntimeTweakAccess.next_spawn_value(
		&"world.repair_drop.lifetime_seconds", ChassisRepairPickup2D.LIFETIME_SECONDS
	))
	selected.activate(
		world_position,
		repair_amount * tuned_amount / ChassisRepairPickup2D.REPAIR_AMOUNT,
		tuned_lifetime
	)
	repair_pickup_spawned.emit(selected)
	return selected


func _on_repair_pickup_collected(
	_pickup: ChassisRepairPickup2D,
	repaired_health: float
) -> void:
	repair_pickup_collected.emit(repaired_health)


func _on_catalyst_fully_destroyed(prop: DestructibleProp2D, event: DamageEvent) -> void:
	var catalyst: Catalyst2D = prop as Catalyst2D
	if catalyst == null or catalyst.profile == null:
		return
	if catalyst.profile.catalyst_id != &"TRANSFORMER":
		return
	_play_power_box_detonation(catalyst.global_position)
	_release_power_box_scrap(catalyst, event)
	var awarded_score: int = _award_power_box_finish(catalyst, event)
	power_box_obliterated.emit(catalyst, awarded_score)


func _play_power_box_detonation(origin: Vector2) -> void:
	if dependencies == null or dependencies.impact_feedback_pool == null:
		return
	var player: AudioStreamPlayer2D = dependencies.impact_feedback_pool.play_cue(
		AudioCueRegistry.Cue.POWER_BOX_DETONATION,
		origin
	)
	if player != null:
		power_box_detonation_sfx_count += 1


func _release_power_box_scrap(catalyst: Catalyst2D, event: DamageEvent) -> void:
	if dependencies == null or dependencies.debris_pool == null:
		return
	power_box_scrap_burst_count += 1
	var origin: Vector2 = catalyst.global_position + Vector2(0.0, -30.0)
	for index: int in range(POWER_BOX_SCRAP_PIECES):
		var weight: float = (float(index) + 0.5) / float(POWER_BOX_SCRAP_PIECES)
		var direction: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(lerpf(-160.0, -20.0, weight)))
		var body_mass: float = lerpf(0.8, 1.6, weight)
		var body_size: Vector2 = Vector2(lerpf(13.0, 28.0, weight), lerpf(11.0, 20.0, 1.0 - weight))
		var debris: DebrisBody2D = dependencies.debris_pool.acquire(
			Transform2D(0.0, origin + direction * lerpf(8.0, 24.0, weight)),
			direction * POWER_BOX_SCRAP_IMPULSE * body_mass,
			lerpf(-7.0, 7.0, weight) * body_mass,
			body_mass,
			body_size,
			&"steel",
			Color("29383e"),
			Color("80ecf4")
		)
		dependencies.debris_pool.arm_kinetic_debris(debris, event)
		power_box_scrap_piece_count += 1


func _award_power_box_finish(catalyst: Catalyst2D, event: DamageEvent) -> int:
	if dependencies == null or dependencies.rampage_session == null:
		return 0
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		StringName(
			"power_box:%d:%d" % [catalyst.get_instance_id(), catalyst.trigger_count]
		),
		event.attack_id,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.POWER_BOX_SCRAP,
		POWER_BOX_FINISH_POINTS,
		4.0,
		false,
		catalyst.global_position,
		&"steel",
		event.source.get_instance_id() if event.source != null else 0,
		catalyst.get_instance_id(),
		&"power_box_finish"
	)
	gameplay_event.root_attack_id = event.root_attack_id
	gameplay_event.causal_depth = event.causal_depth
	if not dependencies.rampage_session.publish(gameplay_event):
		return 0
	power_box_finish_score_count += POWER_BOX_FINISH_POINTS
	return POWER_BOX_FINISH_POINTS


func _resolve_after_delay(catalyst: Catalyst2D, event: DamageEvent) -> void:
	await get_tree().create_timer(catalyst.profile.delay_seconds, false).timeout
	if not is_instance_valid(catalyst) or not catalyst.spent or dependencies == null:
		return
	var pulse_attack_id: int = event.root_attack_id
	if pulse_attack_id == 0:
		pulse_attack_id = _next_pulse_attack_id
		_next_pulse_attack_id += 1
	pulse_count += 1
	var options: DamageQueryOptions = DamageQueryOptions.new()
	options.root_attack_id = event.root_attack_id
	options.causal_depth = event.causal_depth + 1
	options.effect_flags = DamageEvent.FLAG_CATALYST
	options.result_limit = catalyst.profile.max_results
	options.structural_limit = catalyst.profile.max_structural_cells
	options.debris_limit = catalyst.profile.max_debris
	dependencies.destruction_director.queue_explosion(
		catalyst.global_position,
		catalyst.profile.pulse_radius,
		catalyst.profile.pulse_damage,
		catalyst.profile.impulse_per_mass,
		pulse_attack_id,
		catalyst,
		options
	)
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		StringName("catalyst:%d:%d" % [catalyst.get_instance_id(), catalyst.trigger_count]),
		pulse_attack_id,
		GameplayEvent.Kind.CATALYST_TRIGGERED,
		&"CATALYST_TRIGGER",
		600,
		12.0,
		true,
		catalyst.global_position,
		&"steel",
		catalyst.get_instance_id(),
		0,
			catalyst.profile.catalyst_id.to_lower()
	)
	gameplay_event.root_attack_id = event.root_attack_id
	gameplay_event.causal_depth = event.causal_depth + 1
	dependencies.rampage_session.publish(gameplay_event)
	catalyst.mark_resolved(0)
	catalyst_resolved.emit(catalyst, 0)
