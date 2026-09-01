class_name Catalyst2D
extends DestructibleProp2D

signal triggered(catalyst: Catalyst2D, event: DamageEvent)
signal resolved(catalyst: Catalyst2D, affected_count: int)

const INTACT_TEXTURE: Texture2D = preload(
	"res://art/city/catalysts/transformer_intact.png"
)
const SPENT_TEXTURE: Texture2D = preload(
	"res://art/city/catalysts/transformer_spent.png"
)
const OBLITERATION_DELAY_SECONDS: float = 0.16
const DISCHARGE_ARC_COUNT: int = 7
const DISCHARGE_SEGMENT_COUNT: int = 4

var profile: CatalystProfile
var armed: bool = false
var spent: bool = false
var discharging: bool = false
var trigger_count: int = 0
var discharge_count: int = 0
var last_event: DamageEvent
var _catalyst_seen_attacks: Dictionary[int, bool] = {}
var _discharge_elapsed: float = 0.0
var _activation_generation: int = 0


func _ready() -> void:
	intact_texture = INTACT_TEXTURE
	destroyed_texture = SPENT_TEXTURE
	intact_display_size = Vector2(128.0, 128.0)
	destroyed_display_size = Vector2(112.0, 128.0)
	visual_ground_offset = 35.0
	super._ready()
	freeze = true
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if not discharging:
		return
	_discharge_elapsed = minf(_discharge_elapsed + delta, OBLITERATION_DELAY_SECONDS)
	queue_redraw()


func arm(
	p_profile: CatalystProfile,
	world_position: Vector2,
	district_id: StringName = &"BUSINESS"
) -> void:
	profile = p_profile
	configure_terminal_district(district_id)
	global_position = world_position
	set_meta(&"street_destructible_kind", &"power_box")
	max_health = profile.max_health
	current_health = max_health
	armed = true
	spent = false
	discharging = false
	is_broken = false
	is_fully_destroyed = false
	_discharge_elapsed = 0.0
	_activation_generation += 1
	visible = true
	visual.visible = true
	collision_layer = 1 << 7
	collision_mask = (1 << 0) | (1 << 1)
	collision_shape.set_deferred("disabled", false)
	freeze = true
	set_process(false)
	_catalyst_seen_attacks.clear()
	visual.texture = intact_texture
	visual.modulate = Color.WHITE
	_fit_visual(intact_display_size)
	_configure_terminal_rubble()
	terminal_rubble.set_active(false)
	queue_redraw()


func reset_catalyst() -> void:
	armed = false
	spent = false
	discharging = false
	is_broken = false
	is_fully_destroyed = false
	_discharge_elapsed = 0.0
	_activation_generation += 1
	visible = false
	visual.visible = false
	if terminal_rubble != null:
		terminal_rubble.set_active(false)
	collision_layer = 0
	collision_mask = 0
	collision_shape.set_deferred("disabled", true)
	set_process(false)
	current_health = 0.0
	last_event = null
	_catalyst_seen_attacks.clear()
	global_position = Vector2(-4096.0, -4096.0)
	queue_redraw()


func receive_damage(event: DamageEvent) -> bool:
	if not armed or is_fully_destroyed or event == null or event.amount <= 0.0:
		return false
	if spent and event.source == self:
		return false
	if event.attack_id != 0 and _catalyst_seen_attacks.has(event.attack_id):
		return false
	if event.attack_id != 0:
		_catalyst_seen_attacks[event.attack_id] = true
	if spent:
		_start_obliteration(event)
		return true
	current_health = maxf(current_health - event.amount, 0.0)
	last_event = event
	if current_health <= 0.0:
		trigger(event)
	queue_redraw()
	return true


func trigger(event: DamageEvent) -> bool:
	if not armed or spent or event == null:
		return false
	spent = true
	is_broken = true
	visual.texture = destroyed_texture
	_fit_visual(destroyed_display_size)
	trigger_count += 1
	last_event = event
	triggered.emit(self, event)
	queue_redraw()
	return true


func mark_resolved(affected_count: int) -> void:
	resolved.emit(self, affected_count)
	queue_redraw()


func _start_obliteration(event: DamageEvent) -> void:
	armed = false
	discharging = true
	discharge_count += 1
	_discharge_elapsed = 0.0
	last_event = event
	set_process(true)
	queue_redraw()
	_finish_obliteration_after_delay(event, _activation_generation)


func _finish_obliteration_after_delay(event: DamageEvent, generation: int) -> void:
	await get_tree().create_timer(OBLITERATION_DELAY_SECONDS, false).timeout
	if generation != _activation_generation or not discharging or is_fully_destroyed:
		return
	discharging = false
	set_process(false)
	_fully_destroy_prop(event)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	if armed and not spent:
		var coil_color: Color = Color("f4a64d")
		draw_arc(Vector2(0.0, -30.0), 72.0, 0.0, TAU, 40, Color("f4a64d80"), 3.0)
		var ratio: float = clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
		draw_rect(Rect2(-52.0, 37.0, 104.0, 5.0), Color("1a2227"), true)
		draw_rect(Rect2(-52.0, 37.0, 104.0 * ratio, 5.0), coil_color, true)
	if discharging:
		_draw_discharge()


func _draw_discharge() -> void:
	var progress: float = clampf(_discharge_elapsed / OBLITERATION_DELAY_SECONDS, 0.0, 1.0)
	var intensity: float = sin(progress * PI)
	var center: Vector2 = Vector2(0.0, -28.0)
	var glow: Color = Color("8cecff")
	glow.a = 0.22 + intensity * 0.48
	draw_circle(center, 38.0 + intensity * 18.0, glow)
	for arc_index: int in range(DISCHARGE_ARC_COUNT):
		var points: PackedVector2Array = PackedVector2Array([center])
		var base_angle: float = (
			TAU * float(arc_index) / float(DISCHARGE_ARC_COUNT)
			+ float(discharge_count % 5) * 0.13
		)
		for segment: int in range(1, DISCHARGE_SEGMENT_COUNT + 1):
			var weight: float = float(segment) / float(DISCHARGE_SEGMENT_COUNT)
			var jitter: float = sin(float(arc_index * 11 + segment * 7)) * 0.16
			points.append(center + Vector2.from_angle(base_angle + jitter) * 68.0 * weight)
		var arc_color: Color = Color("d9fbff")
		arc_color.a = 0.45 + intensity * 0.55
		draw_polyline(points, arc_color, 2.0 + intensity * 2.0, true)
