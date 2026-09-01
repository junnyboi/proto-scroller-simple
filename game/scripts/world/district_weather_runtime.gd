class_name DistrictWeatherRuntime
extends CanvasLayer

const BUSINESS: StringName = &"BUSINESS"
const TRANSITION_SECONDS: float = 0.85
const WEATHER_LAYER: int = 10
const SURFACE_SCRIPT: Script = preload(
	"res://scripts/world/district_weather_surface.gd"
)
const PROFILES: Dictionary = {
	&"BUSINESS": {
		"effect": &"acid_drizzle",
		"particle_count": 72,
		"color": Color("8db4ba"),
		"accent": Color("c7dca4"),
		"wind": 0.34,
		"speed": 0.46,
		"opacity": 0.27,
		"fog_bands": 1,
		"fog_color": Color("52666b"),
		"fog_opacity": 0.13,
		"fog_speed": 0.20,
	},
	&"RESIDENTIAL": {
		"effect": &"utility_rain",
		"particle_count": 112,
		"color": Color("7fa9ad"),
		"accent": Color("c6d4cc"),
		"wind": 0.16,
		"speed": 0.62,
		"opacity": 0.38,
		"fog_bands": 3,
		"fog_color": Color("526d6f"),
		"fog_opacity": 0.24,
		"fog_speed": 0.13,
	},
}

var current_district_id: StringName = BUSINESS
var target_district_id: StringName = BUSINESS
var transition_count: int = 0
var post_warm_creation_count: int = 0
var surface: DistrictWeatherSurface
var _transition_elapsed: float = 0.0
var _transitioning: bool = false


func _ready() -> void:
	layer = WEATHER_LAYER
	surface = SURFACE_SCRIPT.new() as DistrictWeatherSurface
	surface.name = "WeatherSurface"
	add_child(surface)
	_resize_surface()
	get_viewport().size_changed.connect(_resize_surface)
	_apply_immediate(BUSINESS)
	set_process(false)


func _process(delta: float) -> void:
	if not _transitioning:
		set_process(false)
		return
	_transition_elapsed += delta
	var weight: float = clampf(_transition_elapsed / TRANSITION_SECONDS, 0.0, 1.0)
	var eased: float = weight * weight * (3.0 - 2.0 * weight)
	surface.set_transition_weight(eased)
	if weight >= 1.0:
		current_district_id = target_district_id
		_transitioning = false
		surface.finish_transition()
		set_process(false)


func transition_to(district_id: StringName, immediate: bool = false) -> bool:
	if not PROFILES.has(district_id):
		return false
	if immediate:
		_apply_immediate(district_id)
		return true
	if district_id == target_district_id and _transitioning:
		return false
	if district_id == current_district_id and not _transitioning:
		return false
	if _transitioning:
		current_district_id = (
			target_district_id if _transition_elapsed >= TRANSITION_SECONDS * 0.5
			else current_district_id
		)
	target_district_id = district_id
	surface.begin_transition(
		PROFILES[current_district_id] as Dictionary,
		PROFILES[target_district_id] as Dictionary
	)
	_transition_elapsed = 0.0
	_transitioning = true
	transition_count += 1
	set_process(true)
	return true


func reset_to_business() -> void:
	_apply_immediate(BUSINESS)


func is_transitioning() -> bool:
	return _transitioning


func active_effect() -> StringName:
	return StringName(surface.profile_value(&"effect"))


func active_particle_count() -> int:
	return surface.active_particle_count()


func profile_for(district_id: StringName) -> Dictionary:
	return PROFILES.get(district_id, {}) as Dictionary


func particle_count_for_viewport(district_id: StringName, viewport_size: Vector2) -> int:
	if not PROFILES.has(district_id):
		return 0
	var profile: Dictionary = PROFILES[district_id] as Dictionary
	return surface.particle_count_for_profile(
		float(profile.particle_count),
		viewport_size
	)


func surface_count() -> int:
	return 1 if surface != null else 0


func _apply_immediate(district_id: StringName) -> void:
	current_district_id = district_id
	target_district_id = district_id
	_transition_elapsed = 0.0
	_transitioning = false
	surface.apply_profile(PROFILES[district_id] as Dictionary)
	set_process(false)


func _resize_surface() -> void:
	if surface == null:
		return
	surface.position = Vector2.ZERO
	surface.size = get_viewport().get_visible_rect().size
	surface.queue_redraw()
