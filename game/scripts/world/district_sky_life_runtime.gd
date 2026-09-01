class_name DistrictSkyLifeRuntime
extends Node2D

const BUSINESS: StringName = &"BUSINESS"
const DAY_CYCLE_SECONDS: float = 360.0
const START_PHASE: float = 0.70
const TRAFFIC_REPEAT_WIDTH: float = 2048.0
const TRAFFIC_SCROLL_SCALE: Vector2 = Vector2(0.12, 1.0)
const COURIER_TEXTURE: Texture2D = preload(
	"res://art/city/parallax/living/courier_shuttle.webp"
)
const CARRIER_TEXTURE: Texture2D = preload(
	"res://art/city/parallax/living/state_carrier.webp"
)
const PROFILES: Dictionary = {
	&"BUSINESS": {
		"grade": Color("e9f7ff"),
		"saturation": 0.92,
		"traffic_tint": Color("a9e4ea"),
		"traffic_alpha": 0.44,
		"traffic_speed": 34.0,
		"carrier_mix": 0.20,
	},
	&"RESIDENTIAL": {
		"grade": Color("dcf3ef"),
		"saturation": 0.86,
		"traffic_tint": Color("b6d3ce"),
		"traffic_alpha": 0.30,
		"traffic_speed": 24.0,
		"carrier_mix": 0.18,
	},
}
const TIME_KEYS: Array[Dictionary] = [
	{
		"phase": 0.0,
		"name": &"night",
		"tint": Color("657aa2"),
		"brightness": 0.58,
		"saturation": 0.76,
	},
	{
		"phase": 0.22,
		"name": &"pre_dawn",
		"tint": Color("8b83a3"),
		"brightness": 0.68,
		"saturation": 0.82,
	},
	{
		"phase": 0.36,
		"name": &"dawn",
		"tint": Color("d3a58f"),
		"brightness": 0.84,
		"saturation": 0.90,
	},
	{
		"phase": 0.53,
		"name": &"day",
		"tint": Color("e0eced"),
		"brightness": 0.98,
		"saturation": 0.88,
	},
	{
		"phase": 0.72,
		"name": &"dusk",
		"tint": Color("cf8d82"),
		"brightness": 0.80,
		"saturation": 1.02,
	},
	{
		"phase": 0.88,
		"name": &"late_dusk",
		"tint": Color("8a6d88"),
		"brightness": 0.66,
		"saturation": 0.88,
	},
	{
		"phase": 1.0,
		"name": &"night",
		"tint": Color("657aa2"),
		"brightness": 0.58,
		"saturation": 0.76,
	},
]

var current_district_id: StringName = BUSINESS
var target_district_id: StringName = BUSINESS
var time_phase: float = START_PHASE
var post_warm_creation_count: int = 0
var _district_weight: float = 1.0
var _current_profile: Dictionary = PROFILES[BUSINESS] as Dictionary
var _target_profile: Dictionary = PROFILES[BUSINESS] as Dictionary
var _traffic_band: Parallax2D
var _courier_sprite: Sprite2D
var _carrier_sprite: Sprite2D
var _cycle_tint: Color = Color.WHITE
var _cycle_brightness: float = 1.0
var _cycle_saturation: float = 1.0
var _time_name: StringName = &"dusk"


func _ready() -> void:
	_build_fixed_bands()
	apply_district(BUSINESS)
	time_phase = float(RuntimeTweakAccess.district_value(
		&"environment.sky.start_phase", time_phase
	))
	_sample_time()
	_apply_life_style()
	set_process(false)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	var cycle_seconds: float = float(RuntimeTweakAccess.live_value(
		&"world.sky.day_night_cycle_seconds", DAY_CYCLE_SECONDS
	))
	time_phase = fposmod(time_phase + delta / cycle_seconds, 1.0)
	_sample_time()
	var traffic_speed: float = _profile_value(&"traffic_speed")
	_traffic_band.scroll_offset.x = fposmod(
		_traffic_band.scroll_offset.x
			+ traffic_speed
			* float(RuntimeTweakAccess.live_value(
				&"world.sky.traffic_speed_multiplier", 1.0
			))
			* delta,
		TRAFFIC_REPEAT_WIDTH
	)
	_apply_life_style()


func begin_district_transition(from_id: StringName, to_id: StringName) -> bool:
	if not PROFILES.has(from_id) or not PROFILES.has(to_id):
		return false
	current_district_id = from_id
	target_district_id = to_id
	_current_profile = PROFILES[from_id] as Dictionary
	_target_profile = PROFILES[to_id] as Dictionary
	time_phase = float(RuntimeTweakAccess.district_value(
		&"environment.sky.start_phase", time_phase
	))
	_district_weight = 0.0
	_apply_life_style()
	return true


func set_district_transition_weight(weight: float) -> void:
	_district_weight = clampf(weight, 0.0, 1.0)
	_apply_life_style()


func finish_district_transition() -> void:
	apply_district(target_district_id)


func apply_district(district_id: StringName) -> bool:
	if not PROFILES.has(district_id):
		return false
	current_district_id = district_id
	target_district_id = district_id
	_current_profile = PROFILES[district_id] as Dictionary
	_target_profile = _current_profile
	_district_weight = 1.0
	_apply_life_style()
	return true


func reset_to_business() -> void:
	_traffic_band.scroll_offset = Vector2.ZERO
	apply_district(BUSINESS)


func set_time_phase(phase: float) -> void:
	time_phase = fposmod(phase, 1.0)
	_sample_time()
	_apply_life_style()


func compensate_origin(offset: Vector2) -> void:
	_traffic_band.scroll_offset += offset * TRAFFIC_SCROLL_SCALE


func cycle_tint() -> Color:
	return _cycle_tint


func cycle_brightness() -> float:
	return _cycle_brightness


func cycle_saturation() -> float:
	return _cycle_saturation


func district_grade() -> Color:
	return _profile_color(&"grade")


func district_saturation() -> float:
	return _profile_value(&"saturation")


func time_name() -> StringName:
	return _time_name


func profile_for(district_id: StringName) -> Dictionary:
	return PROFILES.get(district_id, {}) as Dictionary


func _profile_value(key: StringName) -> float:
	return lerpf(
		float(_current_profile[key]),
		float(_target_profile[key]),
		_district_weight
	)


func _profile_color(key: StringName) -> Color:
	return (_current_profile[key] as Color).lerp(
		_target_profile[key] as Color,
		_district_weight
	)


func band_count() -> int:
	return int(_traffic_band != null)


func sprite_count() -> int:
	return (
		int(_courier_sprite != null)
		+ int(_carrier_sprite != null)
	)


func traffic_offset() -> float:
	return _traffic_band.scroll_offset.x


func _build_fixed_bands() -> void:
	_traffic_band = _create_band(
		"AirTraffic",
		TRAFFIC_SCROLL_SCALE,
		-42,
		Vector2(TRAFFIC_REPEAT_WIDTH, 0.0)
	)
	_courier_sprite = _create_sprite(
		COURIER_TEXTURE,
		Vector2(360.0, 145.0),
		Vector2.ONE * 0.34
	)
	_courier_sprite.name = "CourierShuttle"
	_traffic_band.add_child(_courier_sprite)
	_carrier_sprite = _create_sprite(
		CARRIER_TEXTURE,
		Vector2(1390.0, 208.0),
		Vector2.ONE * 0.40
	)
	_carrier_sprite.name = "StateCarrier"
	_traffic_band.add_child(_carrier_sprite)


func _create_band(
	band_name: String,
	scroll_scale: Vector2,
	z_value: int,
	repeat_size: Vector2
) -> Parallax2D:
	var band: Parallax2D = Parallax2D.new()
	band.name = band_name
	band.scroll_scale = scroll_scale
	band.repeat_size = repeat_size
	band.repeat_times = 3
	band.z_index = z_value
	add_child(band)
	return band


func _create_sprite(
	texture: Texture2D,
	position_value: Vector2,
	scale_value: Vector2
) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = position_value
	sprite.scale = scale_value
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sprite


func _sample_time() -> void:
	for index: int in range(TIME_KEYS.size() - 1):
		var from_key: Dictionary = TIME_KEYS[index]
		var to_key: Dictionary = TIME_KEYS[index + 1]
		var from_phase: float = float(from_key.phase)
		var to_phase: float = float(to_key.phase)
		if time_phase < from_phase or time_phase > to_phase:
			continue
		var weight: float = inverse_lerp(from_phase, to_phase, time_phase)
		var eased: float = weight * weight * (3.0 - 2.0 * weight)
		_cycle_tint = (from_key.tint as Color).lerp(to_key.tint as Color, eased)
		_cycle_brightness = lerpf(
			float(from_key.brightness),
			float(to_key.brightness),
			eased
		)
		_cycle_saturation = lerpf(
			float(from_key.saturation),
			float(to_key.saturation),
			eased
		)
		_time_name = (
			StringName(to_key.name) if weight >= 0.5 else StringName(from_key.name)
		)
		return


func _apply_life_style() -> void:
	if _courier_sprite == null or _carrier_sprite == null:
		return
	var traffic_color: Color = _profile_color(&"traffic_tint") * _cycle_tint
	var traffic_alpha: float = _profile_value(&"traffic_alpha")
	var carrier_mix: float = _profile_value(&"carrier_mix")
	_courier_sprite.modulate = traffic_color
	_courier_sprite.modulate.a = traffic_alpha * (1.0 - carrier_mix * 0.58)
	_carrier_sprite.modulate = traffic_color
	_carrier_sprite.modulate.a = traffic_alpha * lerpf(0.34, 1.0, carrier_mix)
