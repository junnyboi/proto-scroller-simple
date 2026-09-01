class_name DistrictWeatherSurface
extends Control

const PARTICLE_CAPACITY: int = 128
const BASE_VIEWPORT_AREA: float = 1280.0 * 720.0
const PORTRAIT_DENSITY_SCALE: float = 0.72

var _seeds: Array[Vector4] = []
var _current_profile: Dictionary = {}
var _target_profile: Dictionary = {}
var _transition_weight: float = 1.0
var _simulation_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_seeds()
	set_process(true)


func _process(delta: float) -> void:
	_simulation_time += delta * float(RuntimeTweakAccess.live_value(
		&"world.weather.motion_multiplier", 1.0
	))
	queue_redraw()


func apply_profile(profile: Dictionary) -> void:
	_current_profile = profile
	_target_profile = profile
	_transition_weight = 1.0
	queue_redraw()


func begin_transition(current_profile: Dictionary, target_profile: Dictionary) -> void:
	_current_profile = current_profile
	_target_profile = target_profile
	_transition_weight = 0.0
	queue_redraw()


func set_transition_weight(weight: float) -> void:
	_transition_weight = clampf(weight, 0.0, 1.0)
	queue_redraw()


func finish_transition() -> void:
	_current_profile = _target_profile
	_transition_weight = 1.0
	queue_redraw()


func active_particle_count() -> int:
	if _current_profile.is_empty():
		return 0
	var base_count: float = lerpf(
		float(_current_profile.particle_count),
		float(_target_profile.particle_count),
		_transition_weight
	)
	return particle_count_for_profile(base_count, size)


func particle_count_for_profile(base_count: float, viewport_size: Vector2) -> int:
	return mini(PARTICLE_CAPACITY, maxi(
		0,
		int(round(
			base_count
			* float(RuntimeTweakAccess.live_value(
				&"world.weather.density_multiplier", 1.0
			))
			* _responsive_density_scale(viewport_size)
		))
	))


func profile_value(key: StringName) -> Variant:
	if _target_profile.has(key):
		return _target_profile[key]
	return null


func _draw() -> void:
	if _current_profile.is_empty() or size.x <= 1.0 or size.y <= 1.0:
		return
	var weight: float = _transition_weight
	var effect: StringName = (
		_target_profile.effect if weight >= 0.5 else _current_profile.effect
	)
	var color: Color = (_current_profile.color as Color).lerp(
		_target_profile.color as Color,
		weight
	)
	var accent: Color = (_current_profile.accent as Color).lerp(
		_target_profile.accent as Color,
		weight
	)
	var wind: float = lerpf(
		float(_current_profile.wind),
		float(_target_profile.wind),
		weight
	)
	var speed: float = lerpf(
		float(_current_profile.speed),
		float(_target_profile.speed),
		weight
	)
	var opacity: float = lerpf(
		float(_current_profile.opacity),
		float(_target_profile.opacity),
		weight
	) * float(RuntimeTweakAccess.live_value(
		&"world.weather.opacity_multiplier", 1.0
	))
	_draw_fog(weight)
	match effect:
		&"acid_drizzle", &"utility_rain", &"neon_drizzle":
			_draw_rain(effect, color, accent, wind, speed, opacity)
		&"wind_ash":
			_draw_ash(color, accent, wind, speed, opacity)
		&"royal_embers":
			_draw_embers(color, accent, wind, speed, opacity)


func _draw_rain(
	effect: StringName,
	color: Color,
	accent: Color,
	wind: float,
	speed: float,
	opacity: float
) -> void:
	var count: int = active_particle_count()
	for index: int in range(count):
		var seed: Vector4 = _seeds[index]
		var phase: float = fposmod(seed.y + _simulation_time * speed * (0.55 + seed.z), 1.0)
		var x: float = fposmod(seed.x * size.x + phase * wind * size.x, size.x + 80.0) - 40.0
		var y: float = phase * (size.y + 100.0) - 50.0
		var length: float = lerpf(11.0, 34.0, seed.w)
		if effect == &"utility_rain":
			length *= 1.35
		elif effect == &"neon_drizzle":
			length *= 0.72
		var streak_color: Color = color.lerp(accent, seed.z * 0.36)
		streak_color.a = opacity * lerpf(0.34, 0.92, seed.w)
		draw_line(
			Vector2(x, y),
			Vector2(x - wind * length * 0.12, y + length),
			streak_color,
			lerpf(0.7, 1.5, seed.z),
			true
		)
	if effect == &"neon_drizzle":
		_draw_charged_motes(accent, opacity)


func _draw_charged_motes(color: Color, opacity: float) -> void:
	for index: int in range(14):
		var seed: Vector4 = _seeds[PARTICLE_CAPACITY - 1 - index]
		var phase: float = fposmod(seed.y + _simulation_time * (0.08 + seed.z * 0.08), 1.0)
		var center: Vector2 = Vector2(
			fposmod(seed.x * size.x + sin(_simulation_time + seed.w * 8.0) * 30.0, size.x),
			phase * size.y
		)
		var mote: Color = color
		mote.a = opacity * lerpf(0.18, 0.62, seed.w)
		draw_circle(center, lerpf(1.0, 2.6, seed.z), mote)


func _draw_ash(
	color: Color,
	accent: Color,
	wind: float,
	speed: float,
	opacity: float
) -> void:
	var count: int = active_particle_count()
	for index: int in range(count):
		var seed: Vector4 = _seeds[index]
		var phase: float = fposmod(seed.y + _simulation_time * speed * (0.25 + seed.z), 1.0)
		var gust: float = sin(_simulation_time * 1.8 + seed.w * 12.0) * 34.0
		var center: Vector2 = Vector2(
			fposmod(seed.x * size.x + phase * wind * size.x + gust, size.x + 60.0) - 30.0,
			phase * (size.y + 50.0) - 25.0
		)
		var ash_color: Color = color.lerp(accent, seed.w * 0.28)
		ash_color.a = opacity * lerpf(0.26, 0.78, seed.z)
		draw_circle(center, lerpf(0.9, 2.8, seed.w), ash_color)
		draw_line(center, center + Vector2(-wind * 4.0, 3.0), ash_color, 0.8, true)


func _draw_embers(
	color: Color,
	accent: Color,
	wind: float,
	speed: float,
	opacity: float
) -> void:
	var count: int = active_particle_count()
	for index: int in range(count):
		var seed: Vector4 = _seeds[index]
		var phase: float = fposmod(seed.y + _simulation_time * speed * (0.35 + seed.z), 1.0)
		var sway: float = sin(_simulation_time * 1.2 + seed.w * 11.0) * 20.0
		var center: Vector2 = Vector2(
			fposmod(seed.x * size.x + phase * wind * size.x + sway, size.x + 60.0) - 30.0,
			size.y + 20.0 - phase * (size.y + 40.0)
		)
		var ember_color: Color = color.lerp(accent, seed.z)
		ember_color.a = opacity * lerpf(0.30, 0.88, seed.w)
		draw_line(center, center + Vector2(-wind * 6.0, 7.0), ember_color, 1.2, true)
		draw_circle(center, lerpf(1.0, 2.4, seed.z), ember_color)


func _draw_fog(weight: float) -> void:
	var band_count: int = int(round(lerpf(
		float(_current_profile.fog_bands),
		float(_target_profile.fog_bands),
		weight
	)))
	if band_count <= 0:
		return
	var fog_color: Color = (_current_profile.fog_color as Color).lerp(
		_target_profile.fog_color as Color,
		weight
	)
	var fog_opacity: float = lerpf(
		float(_current_profile.fog_opacity),
		float(_target_profile.fog_opacity),
		weight
	) * float(RuntimeTweakAccess.live_value(
		&"world.weather.opacity_multiplier", 1.0
	))
	var fog_speed: float = lerpf(
		float(_current_profile.fog_speed),
		float(_target_profile.fog_speed),
		weight
	)
	for band_index: int in range(band_count):
		var seed: Vector4 = _seeds[band_index * 7]
		var band_height: float = size.y * lerpf(0.10, 0.18, seed.z)
		var y: float = size.y * lerpf(0.60, 0.90, float(band_index) / maxf(1.0, band_count - 1.0))
		var drift: float = sin(_simulation_time * fog_speed + seed.w * 6.0) * size.x * 0.08
		for veil_index: int in range(3):
			var veil: Color = fog_color
			veil.a = fog_opacity * float(3 - veil_index) / 9.0
			draw_rect(
				Rect2(
					Vector2(-size.x * 0.12 + drift, y - band_height * veil_index * 0.22),
					Vector2(size.x * 1.24, band_height)
				),
				veil
			)


func _responsive_density_scale(viewport_size: Vector2) -> float:
	var area_scale: float = sqrt(
		maxf(viewport_size.x * viewport_size.y, 1.0) / BASE_VIEWPORT_AREA
	)
	var orientation_scale: float = (
		PORTRAIT_DENSITY_SCALE * float(RuntimeTweakAccess.district_value(
			&"environment.weather.portrait_density_scale", 1.0
		))
		if viewport_size.y > viewport_size.x
		else 1.0
	)
	return clampf(area_scale * orientation_scale, 0.54, 1.25)


func _build_seeds() -> void:
	if not _seeds.is_empty():
		return
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 0x0B3115C
	for _index: int in range(PARTICLE_CAPACITY):
		_seeds.append(Vector4(
			random.randf(),
			random.randf(),
			random.randf(),
			random.randf()
		))
