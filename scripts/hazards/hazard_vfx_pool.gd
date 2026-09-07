class_name HazardVfxPool
extends Node2D

const IMPACT_SPARK: Texture2D = preload("res://assets/presentation/impact_spark.png")
const RING_POINT_COUNT: int = 40

@export_range(1, 16, 1) var capacity: int = RuntimeBudget.HAZARD_VFX_SLOTS

var play_count: int = 0
var recycle_count: int = 0
var last_hazard_id: StringName = &""
var _cursor: int = 0
var _slots: Array[Node2D] = []


func _ready() -> void:
	for index: int in range(capacity):
		var slot: Node2D = _build_slot(index)
		add_child(slot)
		_slots.append(slot)


func play(hazard_id: StringName, world_position: Vector2, direction: Vector2) -> void:
	if _slots.is_empty() or not EnvironmentalHazardCatalog.has(hazard_id):
		return
	var profile: Dictionary = EnvironmentalHazardCatalog.profile(hazard_id)
	var slot: Node2D = _slots[_cursor]
	_cursor = (_cursor + 1) % _slots.size()
	if slot.visible:
		recycle_count += 1
	_reset_slot(slot)
	slot.visible = true
	slot.global_position = world_position
	slot.set_meta(&"hazard_id", hazard_id)
	var particles: CPUParticles2D = slot.get_node(^"Particles") as CPUParticles2D
	particles.amount = mini(int(profile.particles), 72)
	particles.lifetime = float(profile.particle_lifetime)
	particles.direction = direction.normalized() if not direction.is_zero_approx() else Vector2.UP
	particles.spread = float(profile.spread)
	particles.gravity = profile.gravity as Vector2
	var speed: Vector2 = profile.particle_speed as Vector2
	particles.initial_velocity_min = speed.x
	particles.initial_velocity_max = speed.y
	var scale_range: Vector2 = profile.particle_scale as Vector2
	particles.scale_amount_min = scale_range.x
	particles.scale_amount_max = scale_range.y
	particles.color = profile.impact as Color
	particles.restart()
	var impact_color: Color = profile.impact as Color
	var warning_color: Color = profile.get("warning", impact_color) as Color
	_configure_ring(slot.get_node(^"OuterRing") as Line2D, impact_color, 2.7, 0.62)
	_configure_ring(slot.get_node(^"InnerRing") as Line2D, warning_color, 1.75, 0.42)
	var duration: float = maxf(float(profile.particle_lifetime), 0.65)
	var tween: Tween = slot.create_tween()
	tween.set_parallel(true)
	tween.tween_property(slot.get_node(^"OuterRing"), "scale", Vector2.ONE * 2.7, 0.62)
	tween.tween_property(slot.get_node(^"OuterRing"), "modulate:a", 0.0, 0.62)
	tween.tween_property(slot.get_node(^"InnerRing"), "scale", Vector2.ONE * 1.75, 0.42)
	tween.tween_property(slot.get_node(^"InnerRing"), "modulate:a", 0.0, 0.42)
	tween.chain().tween_callback(_reset_slot.bind(slot)).set_delay(maxf(duration - 0.62, 0.0))
	slot.set_meta(&"vfx_tween", tween)
	play_count += 1
	last_hazard_id = hazard_id


func reset_all() -> void:
	for slot: Node2D in _slots:
		_reset_slot(slot)
	_cursor = 0


func slot_count() -> int:
	return _slots.size()


func active_count() -> int:
	var count: int = 0
	for slot: Node2D in _slots:
		count += 1 if slot.visible else 0
	return count


func _build_slot(index: int) -> Node2D:
	var slot: Node2D = Node2D.new()
	slot.name = "HazardVfx%02d" % index
	slot.z_index = 48
	slot.visible = false
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = "Particles"
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.local_coords = false
	particles.emitting = false
	particles.texture = IMPACT_SPARK
	particles.angular_velocity_min = -520.0
	particles.angular_velocity_max = 520.0
	particles.damping_min = 18.0
	particles.damping_max = 64.0
	slot.add_child(particles)
	var outer: Line2D = _build_ring("OuterRing", 72.0, 8.0)
	var inner: Line2D = _build_ring("InnerRing", 42.0, 5.0)
	slot.add_child(outer)
	slot.add_child(inner)
	return slot


func _build_ring(node_name: String, radius: float, width: float) -> Line2D:
	var ring: Line2D = Line2D.new()
	ring.name = node_name
	ring.width = width
	ring.closed = true
	ring.antialiased = true
	for point_index: int in range(RING_POINT_COUNT):
		var angle: float = TAU * float(point_index) / float(RING_POINT_COUNT)
		ring.add_point(Vector2.from_angle(angle) * radius)
	return ring


func _configure_ring(ring: Line2D, color: Color, start_scale: float, alpha: float) -> void:
	ring.default_color = color
	ring.scale = Vector2.ONE * start_scale * 0.32
	ring.modulate = Color(1.0, 1.0, 1.0, alpha)


func _reset_slot(slot: Node2D) -> void:
	if not is_instance_valid(slot):
		return
	if slot.has_meta(&"vfx_tween"):
		var tween_value: Variant = slot.get_meta(&"vfx_tween")
		if tween_value is Tween and (tween_value as Tween).is_valid():
			(tween_value as Tween).kill()
		slot.remove_meta(&"vfx_tween")
	(slot.get_node(^"Particles") as CPUParticles2D).emitting = false
	slot.visible = false
	slot.global_position = Vector2(-4096.0, -4096.0)
	slot.remove_meta(&"hazard_id")
