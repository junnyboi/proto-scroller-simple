class_name BuildingDamagePattern2D
extends Node2D

enum ImpactProfile {
	GENERIC,
	PUNCH,
	MISSILE,
	GROUND_SLAM,
}

const CONTOUR_POINTS: int = 16
const BASE_CRACK_COUNT: int = 2
const EDGE_MARGIN: float = 8.0
const CRACK_SHADOW: Color = Color(0.015, 0.012, 0.012, 0.50)
const CRACK_HIGHLIGHT: Color = Color(0.34, 0.27, 0.22, 0.34)
const FACADE_ALPHA_THRESHOLD: float = 0.08
const DAMAGED_DARKEN_STRENGTH: float = 0.12
const DESTROYED_DARKEN_STRENGTH: float = 0.38
const DESTROYED_HOLLOW_EXTENTS: Vector2 = Vector2(0.37, 0.43)
const HOLLOW_CENTER_Y: float = 0.56
const RUIN_RUBBLE_SPRITE_COUNT: int = 4
const RUIN_SILHOUETTE_VARIANT_COUNT: int = 6
const GROUND_RUBBLE_HEIGHT: float = 50.0
const CAVITY_SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

uniform vec4 visual_tint : source_color = vec4(1.0);
uniform vec4 cavity_tint : source_color = vec4(0.018, 0.014, 0.016, 1.0);
uniform float alpha_threshold = 0.08;
uniform float darken_strength = 0.0;
uniform float hollow_progress = 0.0;
uniform vec2 hollow_center_uv = vec2(0.5, 0.56);
uniform vec2 hollow_extents_uv = vec2(0.0);
uniform float hollow_seed = 0.0;
uniform int impact_profile = 0;
uniform float impact_direction = 1.0;
uniform vec4 region_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool ground_level = false;
uniform int silhouette_variant = 0;

void fragment() {
	vec4 facade = texture(TEXTURE, UV) * visual_tint;
	if (facade.a <= alpha_threshold) {
		discard;
	}
		if (hollow_progress > 0.0001) {
			vec2 cell_uv = (UV - region_uv_rect.xy) / max(region_uv_rect.zw, vec2(0.0001));
			if (ground_level && hollow_progress > 0.98) {
				float top_frequency = 31.0;
				float chip_frequency = 83.0;
				float top_shape = 0.0;
				if (silhouette_variant == 1) {
					top_frequency = 23.0;
					chip_frequency = 67.0;
					top_shape = (1.0 - cell_uv.x) * 0.014;
				} else if (silhouette_variant == 2) {
					top_frequency = 27.0;
					chip_frequency = 79.0;
					top_shape = cell_uv.x * 0.014;
				} else if (silhouette_variant == 3) {
					top_frequency = 19.0;
					chip_frequency = 59.0;
					top_shape = step(0.46, cell_uv.x) * 0.010;
				} else if (silhouette_variant == 4) {
					top_frequency = 37.0;
					chip_frequency = 97.0;
					top_shape = step(
						0.58,
						sin(cell_uv.x * 53.0 + hollow_seed * 29.0)
					) * 0.016;
				} else if (silhouette_variant == 5) {
					top_frequency = 21.0;
					chip_frequency = 73.0;
					top_shape = (
						1.0 - smoothstep(0.0, 0.10, abs(cell_uv.x - 0.31))
						+ 1.0 - smoothstep(0.0, 0.10, abs(cell_uv.x - 0.72))
					) * 0.014;
				}
				float top_coarse = 0.5 + 0.5 * sin(
					cell_uv.x * top_frequency + hollow_seed * 47.0
				);
				float top_chips = step(
					0.66,
					sin(cell_uv.x * chip_frequency - hollow_seed * 71.0)
				);
				float top_break_depth = (
					0.010 + top_coarse * 0.019 + top_chips * 0.013 + top_shape
				);
				if (cell_uv.y < top_break_depth) {
					discard;
				}
			}
			vec2 extents = max(hollow_extents_uv, vec2(0.0001));
			float profile_weight = 1.0 - smoothstep(0.70, 1.0, hollow_progress);
			if (impact_profile == 1) {
				extents *= mix(vec2(1.0), vec2(1.20, 0.72), profile_weight);
			} else if (impact_profile == 2) {
				extents *= mix(vec2(1.0), vec2(0.96, 1.06), profile_weight);
			} else if (impact_profile == 3) {
				extents *= mix(vec2(1.0), vec2(1.28, 0.68), profile_weight);
			}
		vec2 delta = cell_uv - hollow_center_uv;
		float angle = atan(delta.y, delta.x);
		float coarse_frequency = 5.0;
		float chip_frequency = 11.0;
		float notch_frequency = 17.0;
		float silhouette_shape = 0.0;
		if (silhouette_variant == 1) {
			coarse_frequency = 4.0;
			chip_frequency = 9.0;
			notch_frequency = 15.0;
			silhouette_shape = delta.x / extents.x * 0.070;
		} else if (silhouette_variant == 2) {
			coarse_frequency = 6.0;
			chip_frequency = 13.0;
			notch_frequency = 19.0;
			silhouette_shape = -delta.x / extents.x * 0.070;
		} else if (silhouette_variant == 3) {
			coarse_frequency = 3.0;
			chip_frequency = 10.0;
			notch_frequency = 14.0;
			silhouette_shape = sin(angle * 3.0 + hollow_seed * 23.0) * 0.075;
		} else if (silhouette_variant == 4) {
			coarse_frequency = 7.0;
			chip_frequency = 15.0;
			notch_frequency = 23.0;
			silhouette_shape = step(
				0.60,
				sin(angle * 13.0 - hollow_seed * 37.0)
			) * 0.055;
		} else if (silhouette_variant == 5) {
			coarse_frequency = 4.0;
			chip_frequency = 12.0;
			notch_frequency = 21.0;
			silhouette_shape = cos(angle * 2.0 + hollow_seed * 17.0) * 0.060;
		}
		float coarse = sin(angle * coarse_frequency + hollow_seed * 19.0);
		float chips = sin(angle * chip_frequency - hollow_seed * 31.0);
		float notches = step(
			0.70,
			sin(angle * notch_frequency + hollow_seed * 43.0)
		);
		float boundary = (
			1.0 + coarse * 0.075 + chips * 0.035 - notches * 0.055 + silhouette_shape
		);
		if (impact_profile == 1) {
			float side = delta.x / extents.x * impact_direction;
			boundary += smoothstep(-0.18, 0.94, side) * 0.16;
		} else if (impact_profile == 2) {
			boundary += sin(angle * 23.0 + hollow_seed * 67.0) * 0.052;
		} else if (impact_profile == 3) {
			boundary += smoothstep(0.52, 0.94, cell_uv.y) * 0.16;
		}
		float lower_breach = smoothstep(0.72, 1.0, hollow_progress)
			* smoothstep(0.58, 0.92, cell_uv.y)
			* (1.0 - smoothstep(0.68, 0.96, abs(delta.x) / extents.x));
		boundary += lower_breach * 0.18;
			float radial = length(delta / extents);
			float arch_metric = abs(delta.x) / extents.x;
			if (delta.y < 0.0) {
				arch_metric = length(vec2(delta.x / extents.x, delta.y / extents.y));
			}
			float terminal_arch_blend = smoothstep(0.72, 1.0, hollow_progress);
			float opening_metric = mix(radial, arch_metric, terminal_arch_blend);
			float edge_softness = 0.012;
			if (opening_metric < boundary - edge_softness) {
				discard;
			}
			facade.a *= smoothstep(
				boundary - edge_softness,
				boundary + edge_softness,
				opening_metric
			);
	}
	float cavity_mix = clamp(darken_strength, 0.0, 1.0);
	facade.rgb = mix(facade.rgb, cavity_tint.rgb, cavity_mix);
	COLOR = facade;
}
"""

static var _shared_cavity_shader: Shader

var _texture: Texture2D
var _region_rect: Rect2
var _cell_size: Vector2
var _pattern_seed: int = 1
var _material_id: StringName = &"concrete"
var _district_id: StringName = &"BUSINESS"
var _contour: PackedVector2Array = PackedVector2Array()
var _cracks: Array[PackedVector2Array] = []
var _patch: Polygon2D
var _ruin_rubble_root: PersistentRubbleBed2D
var _cavity_material: ShaderMaterial
var _facade_sprite: Sprite2D
var _visual_tint: Color = Color.WHITE
var _destroyed_stage: bool = false
var _hollow_progress: float = 0.0
var _impact_profile: ImpactProfile = ImpactProfile.GENERIC
var _impact_direction: float = 1.0
var _ground_level: bool = false


func configure(
	texture: Texture2D,
	region_rect: Rect2,
	cell_size: Vector2,
	pattern_seed: int,
	material_id: StringName,
	visual_tint: Color,
	district_id: StringName = &"BUSINESS",
	ground_level: bool = false
) -> void:
	_texture = texture
	_region_rect = region_rect
	_cell_size = cell_size
	_pattern_seed = maxi(pattern_seed, 1)
	_material_id = material_id
	_district_id = district_id
	_visual_tint = visual_tint
	_ground_level = ground_level
	z_index = 2
	_patch = Polygon2D.new()
	_patch.name = "HollowGeometry"
	_patch.visible = false
	_cavity_material = ShaderMaterial.new()
	_cavity_material.shader = _get_shared_cavity_shader()
	_configure_cavity_material()
	add_child(_patch)
	_create_ruin_rubble_bed()
	visible = false


func reconfigure(
	texture: Texture2D,
	region_rect: Rect2,
	cell_size: Vector2,
	pattern_seed: int,
	material_id: StringName,
	visual_tint: Color,
	district_id: StringName = &"BUSINESS",
	ground_level: bool = false
) -> void:
	_texture = texture
	_region_rect = region_rect
	_cell_size = cell_size
	_pattern_seed = maxi(pattern_seed, 1)
	_material_id = material_id
	_district_id = district_id
	_visual_tint = visual_tint
	_ground_level = ground_level
	if _patch != null:
		_configure_cavity_material()
	_configure_ruin_rubble_bed()
	reset_pattern()
	visible = false


func _bind_facade_sprite(sprite: Sprite2D) -> void:
	_facade_sprite = sprite
	if _facade_sprite == null:
		return
	_facade_sprite.modulate = Color.WHITE
	_facade_sprite.material = _cavity_material
	_configure_cavity_material()


func record_damage(event: DamageEvent, health_ratio: float) -> void:
	if event == null or _patch == null:
		return
	var local_hit: Vector2 = to_local(event.hit_position)
	var half_size: Vector2 = _cell_size * 0.5
	local_hit.x = clampf(local_hit.x, -half_size.x + EDGE_MARGIN, half_size.x - EDGE_MARGIN)
	local_hit.y = clampf(local_hit.y, -half_size.y + EDGE_MARGIN, half_size.y - EDGE_MARGIN)
	var event_seed: int = (
		_pattern_seed
		^ int(event.attack_id * 1103515245)
		^ int(roundf(event.hit_position.x * 17.0))
		^ int(roundf(event.hit_position.y * 31.0))
	)
	var severity: float = clampf(1.0 - health_ratio, 0.0, 1.0)
	_impact_profile = _impact_profile_for_damage_type(event.damage_type)
	_impact_direction = -1.0 if event.direction.x < 0.0 else 1.0
	_set_hollow_progress(severity)
	_generate(local_hit, severity, event_seed)
	var terminal: bool = health_ratio <= 0.0
	set_destroyed_stage(terminal)
	visible = true
	queue_redraw()


func ensure_destroyed_pattern() -> void:
	if _contour.is_empty():
		var fallback_seed: int = _pattern_seed * 1103515245 + 12345
		_generate(Vector2.ZERO, 1.0, fallback_seed)
	set_destroyed_stage(true)
	visible = true
	queue_redraw()


func set_destroyed_stage(value: bool) -> void:
	_destroyed_stage = value
	if value:
		_set_hollow_progress(1.0)
	_update_hollow_material()
	_update_ruin_rubble_bed()


func is_destroyed_stage() -> bool:
	return _destroyed_stage


func cavity_darken_strength() -> float:
	if _cavity_material == null:
		return 0.0
	return float(_cavity_material.get_shader_parameter("darken_strength"))


func cavity_material() -> ShaderMaterial:
	return _cavity_material


func contour() -> PackedVector2Array:
	return _contour.duplicate()


func crack_count() -> int:
	return _cracks.size()


func _ruin_rubble_sprite_count() -> int:
	return _ruin_rubble_root.active_piece_count() if _ruin_rubble_root != null else 0


func _ruin_rubble_bed() -> PersistentRubbleBed2D:
	return _ruin_rubble_root


func _is_ground_level_ruin() -> bool:
	return _ground_level


func _ruin_silhouette_variant() -> int:
	return posmod(_pattern_seed, RUIN_SILHOUETTE_VARIANT_COUNT)


func _district_style_id() -> StringName:
	return _district_id


func _set_damage_progress(value: float) -> void:
	_set_hollow_progress(value)


func pattern_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for point: Vector2 in _contour:
		parts.append("%d:%d" % [roundi(point.x), roundi(point.y)])
	return "|".join(parts)


func reset_pattern() -> void:
	_contour.clear()
	_cracks.clear()
	_destroyed_stage = false
	_hollow_progress = 0.0
	_impact_profile = ImpactProfile.GENERIC
	_impact_direction = 1.0
	if _patch != null:
		_patch.polygon = PackedVector2Array()
		_patch.uv = PackedVector2Array()
	_update_hollow_material()
	_update_ruin_rubble_bed()
	queue_redraw()


func capture_stream_state() -> Dictionary:
	var cracks: Array[PackedVector2Array] = []
	for crack: PackedVector2Array in _cracks:
		cracks.append(crack.duplicate())
	return {
		"contour": _contour.duplicate(),
		"cracks": cracks,
		"hollow_progress": _hollow_progress,
		"impact_profile": int(_impact_profile),
		"impact_direction": _impact_direction,
	}


func restore_stream_state(state: Dictionary) -> void:
	reset_pattern()
	if state.is_empty() or _patch == null:
		return
	_contour = (state.get("contour", PackedVector2Array()) as PackedVector2Array).duplicate()
	var cracks: Array = state.get("cracks", []) as Array
	for crack_value: Variant in cracks:
		_cracks.append((crack_value as PackedVector2Array).duplicate())
	_patch.polygon = _contour
	_patch.uv = _texture_uvs(_contour)
	_impact_profile = clampi(
		int(state.get("impact_profile", ImpactProfile.GENERIC)),
		ImpactProfile.GENERIC,
		ImpactProfile.GROUND_SLAM
	)
	_impact_direction = -1.0 if float(state.get("impact_direction", 1.0)) < 0.0 else 1.0
	_set_hollow_progress(float(state.get("hollow_progress", 0.0)))
	queue_redraw()


func _generate(impact_center: Vector2, severity: float, event_seed: int) -> void:
	var contour_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	contour_rng.seed = _pattern_seed * 32452843 + 49979687
	var crack_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	crack_rng.seed = event_seed
	var half_size: Vector2 = _cell_size * 0.5
	var center: Vector2 = Vector2(
		clampf(impact_center.x, -half_size.x * 0.32, half_size.x * 0.32),
		clampf(impact_center.y, -half_size.y * 0.28, half_size.y * 0.32)
	)
	var base_radius: float = minf(_cell_size.x, _cell_size.y) * lerpf(
		0.10,
		0.42,
		_smooth_progress(severity)
	)
	var radius_scale: Vector2 = Vector2(1.18, 0.88)
	var crack_total: int = BASE_CRACK_COUNT + floori(severity * 2.0)
	if _material_id == &"glass":
		radius_scale = Vector2(1.02, 1.20)
		crack_total += 1
	elif _material_id == &"steel":
		radius_scale = Vector2(1.42, 0.66)
		crack_total -= 1
	_contour = PackedVector2Array()
	for point_index: int in range(CONTOUR_POINTS):
		var angle: float = TAU * float(point_index) / float(CONTOUR_POINTS)
		angle += contour_rng.randf_range(-0.12, 0.12)
		var notch: float = 0.72 if point_index % 5 == 2 else 1.0
		var radial: float = base_radius * notch * contour_rng.randf_range(0.72, 1.14)
		var point: Vector2 = center + Vector2(
			cos(angle) * radial * radius_scale.x,
			sin(angle) * radial * radius_scale.y
		)
		point.x = clampf(
			point.x,
			-_cell_size.x * 0.5 + EDGE_MARGIN,
			_cell_size.x * 0.5 - EDGE_MARGIN
		)
		point.y = clampf(
			point.y,
			-_cell_size.y * 0.5 + EDGE_MARGIN,
			_cell_size.y * 0.5 - EDGE_MARGIN
		)
		_contour.append(point)
	_patch.polygon = _contour
	_patch.uv = _texture_uvs(_contour)
	_cracks.clear()
	for crack_index: int in range(crack_total):
		var contour_index: int = wrapi(
			roundi(float(crack_index) * float(CONTOUR_POINTS) / float(crack_total))
			+ crack_rng.randi_range(-1, 1),
			0,
			CONTOUR_POINTS
		)
		var edge: Vector2 = _contour[contour_index]
		var direction: Vector2 = center.direction_to(edge)
		var normal: Vector2 = direction.orthogonal()
		var outer: Vector2 = edge + direction * crack_rng.randf_range(8.0, 24.0)
		outer.x = clampf(outer.x, -_cell_size.x * 0.5, _cell_size.x * 0.5)
		outer.y = clampf(outer.y, -_cell_size.y * 0.5, _cell_size.y * 0.5)
		var middle: Vector2 = edge.lerp(outer, crack_rng.randf_range(0.38, 0.62))
		middle += normal * crack_rng.randf_range(-4.0, 4.0)
		var crack: PackedVector2Array = PackedVector2Array([
			edge + normal * crack_rng.randf_range(-2.0, 2.0),
			middle,
			outer,
		])
		_cracks.append(crack)


func _set_hollow_progress(value: float) -> void:
	_hollow_progress = clampf(value, 0.0, 1.0)
	_update_hollow_material()


func _update_hollow_material() -> void:
	if _cavity_material == null:
		return
	var eased_progress: float = _smooth_progress(_hollow_progress)
	var darken_strength: float = lerpf(
		0.0,
		DAMAGED_DARKEN_STRENGTH,
		eased_progress
	)
	if _destroyed_stage or is_equal_approx(_hollow_progress, 1.0):
		darken_strength = DESTROYED_DARKEN_STRENGTH
	_cavity_material.set_shader_parameter("hollow_progress", _hollow_progress)
	_cavity_material.set_shader_parameter(
		"hollow_center_uv",
		_hollow_center_uv()
	)
	_cavity_material.set_shader_parameter(
		"hollow_extents_uv",
		_hollow_extents_for_progress(eased_progress)
	)
	_cavity_material.set_shader_parameter(
		"hollow_seed",
		float(posmod(_pattern_seed, 997)) / 997.0
	)
	_cavity_material.set_shader_parameter("impact_profile", int(_impact_profile))
	_cavity_material.set_shader_parameter("impact_direction", _impact_direction)
	_cavity_material.set_shader_parameter("darken_strength", darken_strength)


func _hollow_extents_for_progress(eased_progress: float) -> Vector2:
	if eased_progress <= 0.0:
		return Vector2.ZERO
	var extents: Vector2 = Vector2(0.035, 0.025).lerp(
		DESTROYED_HOLLOW_EXTENTS,
		eased_progress
	)
	if _material_id == &"glass":
		extents *= Vector2(0.96, 1.05)
	elif _material_id == &"steel":
		extents *= Vector2(1.08, 0.90)
	return extents


func _hollow_center_local() -> Vector2:
	return Vector2(
		0.0,
		(_cell_size.y * _hollow_center_y_for_profile()) - _cell_size.y * 0.5
	)


func _hollow_center_uv() -> Vector2:
	var center: Vector2 = (
		_contour_center() if not _contour.is_empty() else _hollow_center_local()
	)
	return (center + _cell_size * 0.5) / _cell_size


func _hollow_center_y_for_profile() -> float:
	match _impact_profile:
		ImpactProfile.PUNCH:
			return 0.54
		ImpactProfile.MISSILE:
			return 0.52
		ImpactProfile.GROUND_SLAM:
			return 0.68
	return HOLLOW_CENTER_Y


func _impact_profile_for_damage_type(damage_type: StringName) -> ImpactProfile:
	if damage_type in [&"jab_cross", &"punch_shockwave"]:
		return ImpactProfile.PUNCH
	if damage_type in [&"missile", &"rocket"]:
		return ImpactProfile.MISSILE
	if damage_type == &"ground_smash":
		return ImpactProfile.GROUND_SLAM
	return ImpactProfile.GENERIC


func _smooth_progress(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _contour_center() -> Vector2:
	if _contour.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in _contour:
		center += point
	return center / float(_contour.size())


func _texture_uvs(points: PackedVector2Array) -> PackedVector2Array:
	var uvs: PackedVector2Array = PackedVector2Array()
	var half_size: Vector2 = _cell_size * 0.5
	for point: Vector2 in points:
		var normalized: Vector2 = (point + half_size) / _cell_size
		uvs.append(_region_rect.position + normalized * _region_rect.size)
	return uvs


static func _get_shared_cavity_shader() -> Shader:
	if _shared_cavity_shader == null:
		_shared_cavity_shader = Shader.new()
		_shared_cavity_shader.code = CAVITY_SHADER_CODE
	return _shared_cavity_shader


func _configure_cavity_material() -> void:
	if _cavity_material == null:
		return
	_cavity_material.set_shader_parameter("visual_tint", _visual_tint)
	_cavity_material.set_shader_parameter("alpha_threshold", FACADE_ALPHA_THRESHOLD)
	_cavity_material.set_shader_parameter("cavity_tint", _cavity_tint())
	_cavity_material.set_shader_parameter("region_uv_rect", _facade_region_uv_rect())
	_cavity_material.set_shader_parameter("ground_level", _ground_level)
	_cavity_material.set_shader_parameter(
		"silhouette_variant",
		_ruin_silhouette_variant()
	)
	_update_hollow_material()


func _create_ruin_rubble_bed() -> void:
	if not _ground_level:
		return
	_ruin_rubble_root = PersistentRubbleBed2D.new()
	_ruin_rubble_root.name = "RuinRubbleBed"
	_ruin_rubble_root.z_index = 3
	add_child(_ruin_rubble_root)
	_configure_ruin_rubble_bed()


func _configure_ruin_rubble_bed() -> void:
	if _ruin_rubble_root == null:
		return
	_ruin_rubble_root.configure(
		_cell_size,
		_material_id,
		_visual_tint,
		_pattern_seed,
		_cell_size.y * 0.5,
		GROUND_RUBBLE_HEIGHT,
		RUIN_RUBBLE_SPRITE_COUNT,
		_district_id
	)
	_update_ruin_rubble_bed()


func _update_ruin_rubble_bed() -> void:
	if _ruin_rubble_root != null:
		_ruin_rubble_root.set_active(_destroyed_stage and _ground_level)


func _facade_region_uv_rect() -> Vector4:
	var texture: Texture2D = _texture
	var region: Rect2 = _region_rect
	if _facade_sprite != null and _facade_sprite.texture != null:
		texture = _facade_sprite.texture
		region = _facade_sprite.region_rect
	var texture_size: Vector2 = texture.get_size() if texture != null else Vector2.ONE
	return Vector4(
		region.position.x / maxf(texture_size.x, 1.0),
		region.position.y / maxf(texture_size.y, 1.0),
		region.size.x / maxf(texture_size.x, 1.0),
		region.size.y / maxf(texture_size.y, 1.0)
	)


func _cavity_tint() -> Color:
	if _material_id == &"glass":
		return Color(0.012, 0.036, 0.044, 1.0)
	if _material_id == &"steel":
		return Color(0.022, 0.026, 0.030, 1.0)
	return Color(0.018, 0.014, 0.016, 1.0)


func _draw() -> void:
	if _contour.is_empty() or _destroyed_stage:
		return
	var closed_contour: PackedVector2Array = _contour.duplicate()
	closed_contour.append(_contour[0])
	draw_polyline(closed_contour, CRACK_SHADOW, 2.0, true)
	for crack: PackedVector2Array in _cracks:
		draw_polyline(crack, CRACK_SHADOW, 2.25, true)
		draw_polyline(crack, CRACK_HIGHLIGHT, 0.65, true)
