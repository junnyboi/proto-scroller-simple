class_name EnvironmentalHazard2D
extends Area2D

signal triggered(hazard: EnvironmentalHazard2D, hazard_id: StringName)
signal finished(hazard: EnvironmentalHazard2D)

const PROP_LAYER: int = 1 << 7
const STATE_INACTIVE: int = 0
const STATE_ARMED: int = 1
const STATE_TELEGRAPH: int = 2
const STATE_ACTIVE: int = 3
const STATE_AFTERMATH: int = 4
const AUTO_TRIGGER_DELAY: float = 0.32

var runtime: HazardRuntime
var hazard_id: StringName = &""
var profile: Dictionary = {}
var active: bool = false
var state: int = STATE_INACTIVE
var facing: int = 1
var current_health: float = 0.0
var trigger_count: int = 0
var impact_count: int = 0
var last_root_attack_id: int = 0
var _state_remaining: float = 0.0
var _pulse_remaining: float = 0.0
var _activation_event: DamageEvent
var _visual_tween: Tween
var _phase: float = 0.0
var _rest_visual_position: Vector2 = Vector2.ZERO
var _auto_trigger: bool = true

@onready var visual: Sprite2D = get_node(^"Visual") as Sprite2D
@onready var collision_shape: CollisionShape2D = (
	get_node(^"CollisionShape2D") as CollisionShape2D
)


func _process(delta: float) -> void:
	if not active:
		return
	_phase += delta
	_state_remaining = maxf(_state_remaining - delta, 0.0)
	match state:
		STATE_ARMED:
			if _auto_trigger and is_zero_approx(_state_remaining):
				_begin_telegraph(null)
		STATE_TELEGRAPH:
			queue_redraw()
			if is_zero_approx(_state_remaining):
				_begin_impact()
		STATE_ACTIVE:
			_process_active_pulses(delta)
			if is_zero_approx(_state_remaining):
				_begin_aftermath()
		STATE_AFTERMATH:
			if is_zero_approx(_state_remaining):
				finished.emit(self)


func activate(
	p_hazard_id: StringName,
	p_profile: Dictionary,
	world_position: Vector2,
	p_facing: int = 1,
	p_auto_trigger: bool = true
) -> void:
	hazard_id = p_hazard_id
	profile = p_profile
	global_position = world_position
	set_meta(&"street_destructible_kind", hazard_id)
	facing = 1 if p_facing >= 0 else -1
	active = true
	state = STATE_ARMED
	_auto_trigger = p_auto_trigger
	current_health = 45.0
	_state_remaining = AUTO_TRIGGER_DELAY
	_pulse_remaining = 0.0
	_activation_event = null
	last_root_attack_id = 0
	visible = true
	monitorable = true
	collision_layer = PROP_LAYER
	collision_mask = 0
	rotation = 0.0
	visual.rotation = 0.0
	visual.modulate = Color.WHITE
	visual.texture = load(String(profile.texture)) as Texture2D
	_configure_geometry()
	queue_redraw()


func reset_hazard() -> void:
	_cancel_visual_tween()
	active = false
	state = STATE_INACTIVE
	hazard_id = &""
	profile = {}
	current_health = 0.0
	_state_remaining = 0.0
	_pulse_remaining = 0.0
	_activation_event = null
	last_root_attack_id = 0
	visible = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	rotation = 0.0
	global_position = Vector2(-4096.0, -4096.0)
	queue_redraw()


func receive_damage(event: DamageEvent) -> bool:
	if not active or state != STATE_ARMED or event == null or event.amount <= 0.0:
		return false
	current_health = maxf(current_health - event.amount, 0.0)
	if current_health <= 0.0:
		_begin_telegraph(event)
	return true


func impact_origin() -> Vector2:
	var offset: Vector2 = Vector2(0.0, -16.0)
	match StringName(profile.get("behavior", &"")):
		&"collapse":
			offset = Vector2(150.0 * float(facing), -24.0)
		&"electric":
			offset = Vector2(72.0 * float(facing), -12.0)
		&"fireline":
			offset = Vector2(90.0 * float(facing), -12.0)
		&"shear":
			offset = Vector2(82.0 * float(facing), -28.0)
		&"metro_crash":
			offset = Vector2(90.0 * float(facing), -34.0)
		&"skybridge":
			offset = Vector2(0.0, -42.0)
		&"convoy":
			offset = Vector2(110.0 * float(facing), -20.0)
	return global_position + offset


func rebase_cached_world_state(offset: Vector2) -> void:
	if _activation_event != null:
		_activation_event.hit_position += offset


func _begin_telegraph(event: DamageEvent) -> void:
	if state == STATE_TELEGRAPH or state == STATE_ACTIVE:
		return
	_activation_event = event
	last_root_attack_id = event.root_attack_id if event != null else 0
	state = STATE_TELEGRAPH
	_state_remaining = float(profile.telegraph)
	current_health = 0.0
	trigger_count += 1
	if runtime != null:
		runtime.resolve_telegraph(self)
	triggered.emit(self, hazard_id)
	queue_redraw()


func _begin_impact() -> void:
	state = STATE_ACTIVE
	_state_remaining = float(profile.active)
	_pulse_remaining = _pulse_interval(StringName(profile.behavior))
	impact_count += 1
	collision_layer = 0
	monitorable = false
	_play_procedural_animation()
	if runtime != null:
		runtime.resolve_impact(self, _activation_event, true)
	queue_redraw()


func _process_active_pulses(delta: float) -> void:
	var behavior: StringName = StringName(profile.behavior)
	if behavior not in [&"steam", &"electric", &"fireline", &"vent", &"flood", &"convoy"]:
		return
	_pulse_remaining = maxf(_pulse_remaining - delta, 0.0)
	if not is_zero_approx(_pulse_remaining):
		return
	_pulse_remaining = _pulse_interval(behavior)
	if runtime != null:
		runtime.resolve_impact(self, _activation_event, false)
	queue_redraw()


func _pulse_interval(behavior: StringName) -> float:
	if behavior not in [&"steam", &"electric", &"fireline", &"vent", &"flood", &"convoy"]:
		return 0.0
	var fallback_interval: float = 0.36 if behavior == &"steam" else 0.48
	return float(profile.get("pulse_interval", fallback_interval))


func _begin_aftermath() -> void:
	state = STATE_AFTERMATH
	_state_remaining = float(profile.aftermath)
	queue_redraw()


func _configure_geometry() -> void:
	if visual.texture == null:
		return
	var display: Vector2 = profile.display as Vector2
	var texture_size: Vector2 = visual.texture.get_size()
	var fit_scale: float = minf(
		display.x / maxf(texture_size.x, 1.0),
		display.y / maxf(texture_size.y, 1.0)
	)
	visual.scale = Vector2.ONE * fit_scale
	var behavior: StringName = StringName(profile.behavior)
	visual.position = Vector2(0.0, -texture_size.y * fit_scale * 0.5)
	if behavior == &"collapse":
		visual.position.x = display.x * 0.5 - 18.0
	elif behavior == &"drop":
		visual.position.y -= 250.0
	elif behavior == &"shear":
		visual.position.x = 42.0 * float(facing)
	elif behavior == &"metro_crash":
		visual.position += Vector2(-display.x * 0.78 * float(facing), -125.0)
	elif behavior == &"skybridge":
		visual.position.y -= 285.0
	_rest_visual_position = visual.position
	var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = profile.collision as Vector2
	collision_shape.position = visual.position


func _play_procedural_animation() -> void:
	_cancel_visual_tween()
	var behavior: StringName = StringName(profile.behavior)
	_visual_tween = create_tween()
	match behavior:
		&"collapse":
			_visual_tween.tween_property(visual, "rotation", float(facing) * 1.34, 0.28)
			_visual_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		&"electric":
			_visual_tween.tween_property(visual, "rotation", float(facing) * 1.42, 0.30)
			_visual_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		&"ramp":
			_visual_tween.tween_property(visual, "rotation", -float(facing) * 0.38, 0.16)
			_visual_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		&"steam":
			_visual_tween.set_loops(4)
			_visual_tween.tween_property(visual, "position:x", 5.0, 0.05)
			_visual_tween.tween_property(visual, "position:x", -5.0, 0.05)
			_visual_tween.tween_property(visual, "position:x", 0.0, 0.04)
		&"drop":
			_visual_tween.tween_property(
				visual,
				"position:y",
				_rest_visual_position.y + 250.0,
				0.22
			)
			_visual_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		&"fireline":
			_visual_tween.set_loops(10)
			_visual_tween.tween_property(visual, "position:x", 7.0, 0.06)
			_visual_tween.tween_property(visual, "position:x", -7.0, 0.06)
			_visual_tween.tween_property(visual, "position:x", 0.0, 0.04)
		&"shear":
			_visual_tween.set_parallel(true)
			_visual_tween.tween_property(
				visual,
				"rotation",
				-float(facing) * 1.18,
				0.48
			)
			_visual_tween.tween_property(
				visual,
				"position:y",
				_rest_visual_position.y + 105.0,
				0.48
			)
			_visual_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		&"vent":
			_visual_tween.set_loops(3)
			_visual_tween.tween_property(
				visual,
				"position:y",
				_rest_visual_position.y - 12.0,
				0.08
			)
			_visual_tween.tween_property(visual, "position:y", _rest_visual_position.y, 0.10)
		&"metro_crash":
			_visual_tween.set_parallel(true)
			_visual_tween.tween_property(
				visual,
				"position:x",
				_rest_visual_position.x + 420.0 * float(facing),
				0.62
			)
			_visual_tween.tween_property(
				visual,
				"position:y",
				_rest_visual_position.y + 125.0,
				0.62
			)
			_visual_tween.tween_property(visual, "rotation", float(facing) * 0.22, 0.62)
			_visual_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		&"flood":
			_visual_tween.set_loops(6)
			_visual_tween.set_parallel(true)
			_visual_tween.tween_property(visual, "modulate", Color("bdefff"), 0.08)
			_visual_tween.tween_property(
				visual,
				"position:y",
				_rest_visual_position.y - 3.0,
				0.08
			)
			_visual_tween.chain().tween_property(visual, "modulate", Color.WHITE, 0.12)
			_visual_tween.tween_property(
				visual,
				"position:y",
				_rest_visual_position.y,
				0.12
			)
		&"skybridge":
			_visual_tween.set_parallel(true)
			_visual_tween.tween_property(
				visual,
				"position:y",
				_rest_visual_position.y + 285.0,
				0.58
			)
			_visual_tween.tween_property(visual, "rotation", -float(facing) * 0.18, 0.58)
			_visual_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		&"convoy":
			_visual_tween.set_loops(6)
			_visual_tween.tween_property(
				visual,
				"position:x",
				_rest_visual_position.x + 9.0 * float(facing),
				0.08
			)
			_visual_tween.tween_property(
				visual,
				"position:x",
				_rest_visual_position.x - 7.0 * float(facing),
				0.10
			)


func _cancel_visual_tween() -> void:
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	_visual_tween = null


func _draw() -> void:
	if not active or profile.is_empty():
		return
	var impact_color: Color = profile.impact as Color
	var warning_color: Color = profile.get("warning", impact_color) as Color
	var radius: float = float(profile.radius)
	if state == STATE_ARMED:
		draw_arc(Vector2(0.0, -10.0), 24.0, 0.0, TAU, 24, warning_color, 3.0)
	elif state == STATE_TELEGRAPH:
		var pulse: float = 0.40 + 0.22 * sin(_phase * 18.0)
		var band: Color = Color(warning_color, pulse)
		draw_rect(Rect2(-radius, -14.0, radius * 2.0, 28.0), band, true)
		draw_line(Vector2(-radius, -18.0), Vector2(radius, -18.0), warning_color, 4.0)
		draw_line(Vector2(-radius, 18.0), Vector2(radius, 18.0), warning_color, 4.0)
	elif state == STATE_ACTIVE:
		var behavior: StringName = StringName(profile.behavior)
		if behavior in [&"steam", &"electric", &"fireline", &"vent", &"flood", &"convoy"]:
			var active_color: Color = Color(impact_color, 0.20 + 0.08 * sin(_phase * 24.0))
			var band_height: float = 40.0
			if behavior in [&"fireline", &"convoy"]:
				band_height = 68.0
			elif behavior == &"flood":
				band_height = 54.0
			draw_rect(
				Rect2(-radius, -band_height * 0.5, radius * 2.0, band_height),
				active_color,
				true
			)
	elif state == STATE_AFTERMATH:
		draw_line(
			Vector2(-radius * 0.55, 0.0),
			Vector2(radius * 0.55, 0.0),
			Color(impact_color, 0.36),
			6.0
		)
