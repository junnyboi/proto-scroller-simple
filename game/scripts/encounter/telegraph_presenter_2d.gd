class_name TelegraphPresenter2D
extends Node2D

const TELEGRAPH_BADGE: Texture2D = preload(
	"res://art/presentation/telegraph_badge.png"
)
const TARGET_MARK_SUPPORT: Texture2D = preload(
	"res://art/presentation/target_mark_support.png"
)
const JAMMER_PULSE: Texture2D = preload(
	"res://art/presentation/target_mark_support.png"
)
const SHIELD_PULSE: Texture2D = preload(
	"res://art/presentation/target_mark_support.png"
)
const FIRING_PULSE_MINIMUM_AMPLITUDE: float = 0.04
const FIRING_PULSE_MAXIMUM_AMPLITUDE: float = 0.32
const EXTREME_THREAT_START: float = 1.30
const EXTREME_THREAT_COLOR: Color = Color(1.0, 0.90, 0.86, 1.0)
const DARK_BACKGROUND_RGB_GAIN: float = 1.16
const DARK_BACKGROUND_ALPHA_GAIN: float = 1.22
const AUTHORED_TELEGRAPH_STYLE_KEY: StringName = &"authored_telegraph"

@export_range(1, 16, 1) var capacity: int = RuntimeBudget.TELEGRAPH_RECORDS

var denial_count: int = 0
var peak_active_count: int = 0
var _records: Array[Dictionary] = []
var _next_id: int = 1


func _ready() -> void:
	z_index = 80
	set_process(true)


func _process(delta: float) -> void:
	for record: Dictionary in _records:
		record.remaining = maxf(float(record.remaining) - delta, 0.0)
	queue_redraw()


func reserve(
	p_owner: EnemyActor2D,
	kind: StringName,
	origin: Vector2,
	target: Vector2,
	duration: float,
	damage_output: float = 0.0,
	presentation_variant: StringName = &"",
	visual_key: StringName = &"",
	style_data: Dictionary = {}
) -> int:
	if p_owner == null or _records.size() >= capacity:
		denial_count += 1
		return 0
	cancel_owner(p_owner)
	var record_id: int = _next_id
	_next_id += 1
	_records.append({
		"id": record_id,
		"owner": p_owner,
		"kind": kind,
		"origin": origin,
		"target": target,
		"thickness_scale": p_owner.attack_telegraph_thickness_scale(),
		"color_intensity": p_owner.attack_telegraph_color_intensity(damage_output),
		"duration": maxf(duration, 0.01),
		"remaining": maxf(duration, 0.01),
		"presentation_variant": presentation_variant,
		"visual_key": visual_key,
		"style_data": style_data.duplicate(true),
	})
	peak_active_count = maxi(peak_active_count, _records.size())
	queue_redraw()
	return record_id


func cancel(record_id: int) -> void:
	for index: int in range(_records.size() - 1, -1, -1):
		if int(_records[index].id) == record_id:
			_records.remove_at(index)
	queue_redraw()


func cancel_owner(p_owner: EnemyActor2D) -> void:
	for index: int in range(_records.size() - 1, -1, -1):
		if _records[index].owner == p_owner:
			_records.remove_at(index)
	queue_redraw()


func cancel_all() -> void:
	_records.clear()
	queue_redraw()


func active_count() -> int:
	return _records.size()


func available_count() -> int:
	return capacity - _records.size()


func rebase_cached_world_state(offset: Vector2) -> void:
	for record: Dictionary in _records:
		record.origin = (record.origin as Vector2) + offset
		record.target = (record.target as Vector2) + offset
	queue_redraw()


func snapshot(record_id: int) -> Dictionary:
	for record: Dictionary in _records:
		if int(record.id) == record_id:
			return record.duplicate()
	return {}


func uses_procedural_rendering(record_id: int) -> bool:
	var record: Dictionary = snapshot(record_id)
	return not record.is_empty() and not _has_authored_telegraph(record)


func _draw() -> void:
	for record: Dictionary in _records:
		if _has_authored_telegraph(record):
			continue
		var progress: float = 1.0 - float(record.remaining) / float(record.duration)
		var origin: Vector2 = to_local(record.origin)
		var target: Vector2 = to_local(record.target)
		var kind: StringName = record.kind
		var thickness_scale: float = float(record.thickness_scale)
		var color_intensity: float = float(record.color_intensity)
		var pulse_brightness: float = firing_pulse_brightness(progress)
		var base_color: Color = _threat_color(
			Color(1.0, 0.42, 0.16, 0.46 + progress * 0.48),
			color_intensity,
			pulse_brightness
		)
		var presentation_variant: StringName = StringName(
			record.get("presentation_variant", &"")
		)
		if presentation_variant == BossProjectileVolley.TELEGRAPH_PRESENTATION_VARIANT:
			_draw_boss_volley_paths(
				record,
				progress,
				thickness_scale,
				color_intensity,
				pulse_brightness
			)
			continue
		if _draw_support_variant(
			presentation_variant,
			origin,
			target,
			progress,
			thickness_scale,
			color_intensity,
			pulse_brightness
		):
			continue
		if kind in [&"shell", &"rocket"]:
			_draw_projectile_path(
				kind,
				origin,
				target,
				progress,
				thickness_scale,
				color_intensity,
				pulse_brightness
			)
		else:
			draw_line(
				origin,
				target,
					_threat_color(
						Color(1.0, 0.78, 0.42, 0.48 + progress * 0.42),
					color_intensity,
					pulse_brightness
				),
				2.0 * thickness_scale,
				true
			)
			draw_circle(origin, 5.0 + progress * 4.0, base_color)


func _has_authored_telegraph(record: Dictionary) -> bool:
	var style_data: Dictionary = record.get("style_data", {}) as Dictionary
	return bool(style_data.get(AUTHORED_TELEGRAPH_STYLE_KEY, false))


func _draw_boss_volley_paths(
	record: Dictionary,
	progress: float,
	thickness_scale: float,
	color_intensity: float,
	pulse_brightness: float
) -> void:
	var style_data: Dictionary = record.get("style_data", {}) as Dictionary
	var origins: Array = style_data.get(&"origins", []) as Array
	var targets: Array = style_data.get(&"targets", []) as Array
	var path_count: int = mini(origins.size(), targets.size())
	for index: int in range(path_count):
		var origin: Vector2 = to_local(origins[index] as Vector2)
		var target: Vector2 = to_local(targets[index] as Vector2)
		_draw_projectile_path(
			StringName(record.kind),
			origin,
			target,
			progress,
			thickness_scale,
			color_intensity,
			pulse_brightness
		)


func _draw_projectile_path(
	kind: StringName,
	origin: Vector2,
	target: Vector2,
	progress: float,
	thickness_scale: float,
	color_intensity: float,
	pulse_brightness: float
) -> void:
	var base_color: Color = _threat_color(
		Color(1.0, 0.42, 0.16, 0.46 + progress * 0.48),
		color_intensity,
		pulse_brightness
	)
	var badge_size: Vector2 = Vector2.ONE * (38.0 + progress * 10.0)
	draw_texture_rect(
		TELEGRAPH_BADGE,
		Rect2(target - badge_size * 0.5, badge_size),
		false,
			_threat_color(
				Color(1.0, 1.0, 1.0, 0.70 + progress * 0.28),
			color_intensity,
			pulse_brightness
		)
	)
	if kind == &"shell":
		draw_line(origin, target, base_color, 8.0 * thickness_scale, true)
		draw_line(
			origin,
			target,
				_threat_color(
					Color(1.0, 0.88, 0.52, 0.96),
				color_intensity,
				pulse_brightness
			),
			2.0 * thickness_scale,
			true
		)
		draw_circle(
			target,
			26.0 + progress * 10.0,
			_threat_color(
				Color(1.0, 0.34, 0.12, 0.30),
				color_intensity,
				pulse_brightness
			)
		)
		draw_arc(
			target,
			31.0,
			0.0,
			TAU * progress,
			32,
			base_color,
			4.0 * thickness_scale,
			true
		)
	elif kind == &"rocket":
		draw_dashed_line(
			origin,
			target,
			base_color,
			3.0 * thickness_scale,
			12.0,
			true
		)
		draw_arc(
			target,
			42.0,
			0.0,
			TAU * progress,
			36,
			base_color,
			5.0 * thickness_scale,
			true
		)
		draw_line(
			target + Vector2(-18.0, 0.0),
			target + Vector2(18.0, 0.0),
			base_color,
			3.0 * thickness_scale
		)
		draw_line(
			target + Vector2(0.0, -18.0),
			target + Vector2(0.0, 18.0),
			base_color,
			3.0 * thickness_scale
		)


func _draw_support_variant(
	variant: StringName,
	origin: Vector2,
	target: Vector2,
	progress: float,
	thickness_scale: float,
	color_intensity: float,
	pulse_brightness: float
) -> bool:
	if variant in [&"scan", &"choir_ring"]:
		var start_size: float = 46.0 if variant == &"scan" else 92.0
		var end_size: float = 66.0 if variant == &"scan" else 132.0
		var mark_size: Vector2 = Vector2.ONE * lerpf(start_size, end_size, progress)
		draw_line(
			origin,
			target,
				_threat_color(
					Color(1.0, 0.78, 0.42, 0.46 + progress * 0.40),
				color_intensity,
				pulse_brightness
			),
			2.0 * thickness_scale,
			true
		)
		draw_set_transform(target, 0.0, Vector2.ONE)
		draw_texture_rect(
			TARGET_MARK_SUPPORT,
			Rect2(-mark_size * 0.5, mark_size),
			false,
				_threat_color(
					Color(1.0, 1.0, 1.0, 0.62 + progress * 0.34),
				color_intensity,
				pulse_brightness
			)
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return true
	if variant == &"jammer_pulse" or variant == &"shield_pulse":
		var pulse_texture: Texture2D = JAMMER_PULSE if variant == &"jammer_pulse" else SHIELD_PULSE
		var display_size: Vector2 = (
			Vector2(320.0, 184.0)
			if variant == &"jammer_pulse"
			else Vector2(400.0, 256.0)
		)
		var envelope: float = lerpf(0.72, 1.0, progress)
		var pulse_size: Vector2 = display_size * envelope
		draw_texture_rect(
			pulse_texture,
			Rect2(origin - pulse_size * 0.5, pulse_size),
			false,
			_threat_color(
					Color(1.0, 1.0, 1.0, 0.44 + progress * 0.50),
				color_intensity,
				pulse_brightness
			)
		)
		return true
	return false


func firing_pulse_amplitude(progress: float) -> float:
	return lerpf(
		FIRING_PULSE_MINIMUM_AMPLITUDE,
		FIRING_PULSE_MAXIMUM_AMPLITUDE,
		pow(clampf(progress, 0.0, 1.0), 2.0)
	)


func firing_pulse_brightness(progress: float) -> float:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var amplitude: float = firing_pulse_amplitude(clamped_progress)
	var cycles: float = 2.0 * clamped_progress + 2.5 * pow(clamped_progress, 3.0)
	var wave: float = 0.5 + 0.5 * sin(TAU * cycles - PI * 0.5)
	return lerpf(1.0 - amplitude, 1.0 + amplitude, wave)


func threat_color(base_color: Color, intensity: float, progress: float) -> Color:
	return _threat_color(base_color, intensity, firing_pulse_brightness(progress))


func _threat_color(base_color: Color, intensity: float, pulse_brightness: float) -> Color:
	var normalized: float = clampf(
		inverse_lerp(
			EnemyActor2D.TELEGRAPH_MINIMUM_COLOR_INTENSITY,
			EnemyActor2D.TELEGRAPH_MAXIMUM_COLOR_INTENSITY,
			intensity
		),
		0.0,
		1.0
	)
	var extreme_blend: float = smoothstep(
		EXTREME_THREAT_START,
		EnemyActor2D.TELEGRAPH_MAXIMUM_COLOR_INTENSITY,
		intensity
	)
	var threat_rgb: Color = Color(
		clampf(base_color.r * intensity, 0.0, 1.0),
		clampf(base_color.g * intensity, 0.0, 1.0),
		clampf(base_color.b * intensity, 0.0, 1.0),
		1.0
	).lerp(EXTREME_THREAT_COLOR, extreme_blend)
	var pulse_alpha: float = lerpf(
		0.90,
		1.10,
		clampf(inverse_lerp(0.68, 1.32, pulse_brightness), 0.0, 1.0)
	)
	return Color(
		clampf(threat_rgb.r * pulse_brightness * DARK_BACKGROUND_RGB_GAIN, 0.0, 1.0),
		clampf(threat_rgb.g * pulse_brightness * DARK_BACKGROUND_RGB_GAIN, 0.0, 1.0),
		clampf(threat_rgb.b * pulse_brightness * DARK_BACKGROUND_RGB_GAIN, 0.0, 1.0),
		clampf(
			base_color.a
			* lerpf(0.78, 1.15, normalized)
			* pulse_alpha
			* DARK_BACKGROUND_ALPHA_GAIN,
			0.0,
			1.0
		)
	)
