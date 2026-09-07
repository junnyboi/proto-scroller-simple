class_name EliteSpawnEffectPool
extends Node2D

const IMPACT_SPARK: Texture2D = preload("res://assets/presentation/impact_spark.png")
const EFFECT_SECONDS: float = 0.68
const COLORS: Dictionary[StringName, Color] = {
	&"BLITZ": Color("ffd044"),
	&"BRUTAL": Color("ff402f"),
	&"PHASED": Color("a86cff"),
}

@export_range(1, 12, 1) var capacity: int = RuntimeBudget.ELITE_SPAWN_EFFECT_SLOTS

var play_count: int = 0
var recycle_count: int = 0
var last_trait_id: StringName = &""
var _slots: Array[Node2D] = []
var _generations: Dictionary[int, int] = {}
var _tweens: Dictionary[int, Tween] = {}


func _ready() -> void:
	z_index = 44
	for slot_index: int in range(capacity):
		_slots.append(_create_slot(slot_index))


func play(origin: Vector2, trait_id: StringName) -> Node2D:
	if not COLORS.has(trait_id) or _slots.is_empty():
		return null
	var slot: Node2D = _acquire_slot()
	var slot_id: int = slot.get_instance_id()
	var generation: int = _generations.get(slot_id, 0) + 1
	_generations[slot_id] = generation
	var previous_tween: Tween = _tweens.get(slot_id) as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	var color: Color = COLORS[trait_id]
	var particles: CPUParticles2D = slot.get_node(^"Particles") as CPUParticles2D
	var ring: Line2D = slot.get_node(^"Ring") as Line2D
	var core: Polygon2D = slot.get_node(^"Core") as Polygon2D
	slot.global_position = origin
	slot.visible = true
	slot.set_meta(&"started_msec", Time.get_ticks_msec())
	slot.set_meta(&"trait_id", trait_id)
	ring.default_color = color
	ring.modulate = Color.WHITE
	ring.scale = Vector2.ONE * 0.35
	core.color = Color(color, 0.72)
	core.modulate = Color.WHITE
	core.scale = Vector2.ONE * 1.35
	particles.color = color
	particles.restart()
	var tween: Tween = create_tween()
	_tweens[slot_id] = tween
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 2.2, 0.50).set_trans(
		Tween.TRANS_EXPO
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.50)
	tween.tween_property(core, "scale", Vector2.ONE * 0.18, 0.34).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_IN)
	tween.tween_property(core, "modulate:a", 0.0, 0.34)
	tween.chain().tween_interval(EFFECT_SECONDS - 0.50)
	tween.chain().tween_callback(_finish_slot.bind(slot, generation))
	play_count += 1
	last_trait_id = trait_id
	return slot


func slot_count() -> int:
	return _slots.size()


func active_count() -> int:
	var count: int = 0
	for slot: Node2D in _slots:
		count += 1 if slot.visible else 0
	return count


func _acquire_slot() -> Node2D:
	for slot: Node2D in _slots:
		if not slot.visible:
			return slot
	var oldest: Node2D = _slots[0]
	for slot: Node2D in _slots:
		if int(slot.get_meta(&"started_msec", 0)) < int(
			oldest.get_meta(&"started_msec", 0)
		):
			oldest = slot
	recycle_count += 1
	return oldest


func _finish_slot(slot: Node2D, generation: int) -> void:
	if _generations.get(slot.get_instance_id(), 0) != generation:
		return
	slot.visible = false
	(slot.get_node(^"Particles") as CPUParticles2D).emitting = false


func _create_slot(slot_index: int) -> Node2D:
	var slot: Node2D = Node2D.new()
	slot.name = "EliteSpawnEffect%02d" % slot_index
	slot.visible = false
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = "Particles"
	particles.amount = 26
	particles.lifetime = 0.62
	particles.one_shot = true
	particles.explosiveness = 0.94
	particles.local_coords = false
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 520.0)
	particles.initial_velocity_min = 130.0
	particles.initial_velocity_max = 330.0
	particles.scale_amount_min = 0.035
	particles.scale_amount_max = 0.095
	particles.angular_velocity_min = -540.0
	particles.angular_velocity_max = 540.0
	particles.texture = IMPACT_SPARK
	slot.add_child(particles)
	var ring: Line2D = Line2D.new()
	ring.name = "Ring"
	ring.width = 4.0
	ring.antialiased = true
	var ring_points: PackedVector2Array = PackedVector2Array()
	for point_index: int in range(25):
		var angle: float = TAU * float(point_index) / 24.0
		ring_points.append(Vector2.from_angle(angle) * 34.0)
	ring.points = ring_points
	slot.add_child(ring)
	var core: Polygon2D = Polygon2D.new()
	core.name = "Core"
	core.polygon = PackedVector2Array([
		Vector2(0.0, -30.0),
		Vector2(23.0, 0.0),
		Vector2(0.0, 30.0),
		Vector2(-23.0, 0.0),
	])
	slot.add_child(core)
	add_child(slot)
	return slot
