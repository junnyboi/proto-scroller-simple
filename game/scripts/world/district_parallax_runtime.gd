class_name DistrictParallaxRuntime
extends Node2D

const BUSINESS: StringName = &"BUSINESS"
const CROSSFADE_SECONDS: float = 0.85
const DEPTH_REPEAT_SIZE: Vector2 = Vector2(1344.0, 0.0)
const REPEAT_TIMES: int = 3
const SKY_SCROLL_SCALE: Vector2 = Vector2(0.05, 1.0)
const FAR_SCROLL_SCALE: Vector2 = Vector2(0.18, 1.0)
const INFRA_SCROLL_SCALE: Vector2 = Vector2(0.35, 1.0)
const NEAR_SCROLL_SCALE: Vector2 = Vector2(0.60, 1.0)

const BUSINESS_PANORAMA: Texture2D = preload(
	"res://art/city/parallax/districts/business_panorama.webp"
)
const RESIDENTIAL_PANORAMA: Texture2D = preload(
	"res://art/city/parallax/districts/residential_panorama.webp"
)
const FAR_TEXTURE: Texture2D = preload("res://art/city/parallax/far_skyline.png")
const INFRA_TEXTURE: Texture2D = preload("res://art/city/parallax/infrastructure.png")
const NEAR_TEXTURE: Texture2D = preload("res://art/city/parallax/near_buildings.png")
const SEAMLESS_PANORAMA_SHADER: Shader = preload(
	"res://shaders/seamless_panorama.gdshader"
)
const SKY_LIFE_SCRIPT: Script = preload(
	"res://scripts/world/district_sky_life_runtime.gd"
)

const DISTRICT_TEXTURES: Dictionary = {
	&"BUSINESS": BUSINESS_PANORAMA,
	&"RESIDENTIAL": RESIDENTIAL_PANORAMA,
}
const DEPTH_TINTS: Dictionary = {
	&"BUSINESS": [Color("a8bec4"), Color("99adb1"), Color("8c9ea1")],
	&"RESIDENTIAL": [Color("90adac"), Color("849f9e"), Color("7b9190")],
}

var current_district_id: StringName = BUSINESS
var target_district_id: StringName = BUSINESS
var transition_count: int = 0
var post_warm_creation_count: int = 0
var _active_sky_index: int = 0
var _transition_elapsed: float = 0.0
var _transitioning: bool = false
var _sky_sprites: Array[Sprite2D] = []
var _depth_sprites: Array[Sprite2D] = []
var _depth_start_colors: Array[Color] = []
var _depth_target_colors: Array[Color] = []
var _ungraded_depth_colors: Array[Color] = []
var _sky_life: DistrictSkyLifeRuntime


func _ready() -> void:
	_build_fixed_bands()
	_apply_immediate(BUSINESS)
	set_process(true)


func _process(delta: float) -> void:
	_apply_motion_multiplier()
	if _sky_life != null:
		_sky_life.advance(delta)
	if not _transitioning:
		_apply_environment_style()
		return
	_transition_elapsed += delta
	var weight: float = clampf(_transition_elapsed / CROSSFADE_SECONDS, 0.0, 1.0)
	var eased: float = weight * weight * (3.0 - 2.0 * weight)
	var next_index: int = 1 - _active_sky_index
	_sky_sprites[_active_sky_index].modulate.a = 1.0 - eased
	_sky_sprites[next_index].modulate.a = eased
	for index: int in range(_depth_sprites.size()):
		_ungraded_depth_colors[index] = _depth_start_colors[index].lerp(
			_depth_target_colors[index],
			eased
		)
	if _sky_life != null:
		_sky_life.set_district_transition_weight(eased)
	_apply_environment_style()
	if weight >= 1.0:
		_finish_transition()


func transition_to(district_id: StringName, immediate: bool = false) -> bool:
	if not DISTRICT_TEXTURES.has(district_id):
		return false
	if immediate:
		_apply_immediate(district_id)
		return true
	if district_id == target_district_id and _transitioning:
		return false
	if district_id == current_district_id and not _transitioning:
		return false
	var next_index: int = 1 - _active_sky_index
	_sky_sprites[_active_sky_index].visible = true
	_sky_sprites[_active_sky_index].modulate.a = 1.0
	_sky_sprites[next_index].texture = DISTRICT_TEXTURES[district_id] as Texture2D
	_sky_sprites[next_index].visible = true
	_sky_sprites[next_index].modulate = Color(1.0, 1.0, 1.0, 0.0)
	_depth_start_colors.clear()
	_depth_target_colors.clear()
	var target_tints: Array = DEPTH_TINTS[district_id] as Array
	for index: int in range(_depth_sprites.size()):
		_depth_start_colors.append(_ungraded_depth_colors[index])
		_depth_target_colors.append(target_tints[index] as Color)
	if _sky_life != null:
		_sky_life.begin_district_transition(current_district_id, district_id)
	target_district_id = district_id
	_transition_elapsed = 0.0
	_transitioning = true
	transition_count += 1
	return true


func reset_to_business() -> void:
	for child: Node in get_children():
		var band: Parallax2D = child as Parallax2D
		if band != null:
			band.scroll_offset = Vector2.ZERO
	if _sky_life != null:
		_sky_life.reset_to_business()
	_apply_immediate(BUSINESS)


func compensate_origin(offset: Vector2) -> void:
	for child: Node in get_children():
		var band: Parallax2D = child as Parallax2D
		if band != null:
			band.scroll_offset += offset * band.scroll_scale
	if _sky_life != null:
		_sky_life.compensate_origin(offset)


func active_texture() -> Texture2D:
	return _sky_sprites[_active_sky_index].texture


func sky_sprite_count() -> int:
	return _sky_sprites.size()


func band_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is Parallax2D:
			count += 1
	return count


func is_transitioning() -> bool:
	return _transitioning


func panorama_repeat_width() -> float:
	var sky: Parallax2D = get_node_or_null(^"Sky") as Parallax2D
	return sky.repeat_size.x if sky != null else 0.0


func sky_life_runtime() -> DistrictSkyLifeRuntime:
	return _sky_life


func set_time_phase(phase: float) -> void:
	if _sky_life == null:
		return
	_sky_life.set_time_phase(phase)
	_apply_environment_style()


func time_phase() -> float:
	return _sky_life.time_phase if _sky_life != null else 0.0


func _build_fixed_bands() -> void:
	var panorama_repeat: Vector2 = Vector2(
		float(BUSINESS_PANORAMA.get_width()),
		0.0
	)
	var sky: Parallax2D = _create_band(
		"Sky",
		SKY_SCROLL_SCALE,
		-50,
		panorama_repeat
	)
	for index: int in range(2):
		var sprite: Sprite2D = _create_sprite(BUSINESS_PANORAMA, 0.0)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SEAMLESS_PANORAMA_SHADER
		sprite.material = material
		sprite.name = "DistrictPanorama%d" % index
		sprite.visible = index == 0
		sky.add_child(sprite)
		_sky_sprites.append(sprite)
	var far: Parallax2D = _create_band(
		"FarSkyline",
		FAR_SCROLL_SCALE,
		-40,
		DEPTH_REPEAT_SIZE
	)
	_depth_sprites.append(_add_depth_sprite(far, FAR_TEXTURE, 85.0))
	var infrastructure: Parallax2D = _create_band(
		"Infrastructure",
		INFRA_SCROLL_SCALE,
		-30,
		DEPTH_REPEAT_SIZE
	)
	_depth_sprites.append(_add_depth_sprite(infrastructure, INFRA_TEXTURE, 95.0))
	var near: Parallax2D = _create_band(
		"NearBuildings",
		NEAR_SCROLL_SCALE,
		-20,
		DEPTH_REPEAT_SIZE
	)
	_depth_sprites.append(_add_depth_sprite(near, NEAR_TEXTURE, 116.0))
	_sky_life = SKY_LIFE_SCRIPT.new() as DistrictSkyLifeRuntime
	_sky_life.name = "DistrictSkyLife"
	add_child(_sky_life)


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
	band.repeat_times = REPEAT_TIMES
	band.z_index = z_value
	add_child(band)
	return band


func _apply_motion_multiplier() -> void:
	var multiplier: float = float(RuntimeTweakAccess.live_value(
		&"world.parallax.motion_multiplier", 1.0
	))
	_set_band_motion(^"Sky", SKY_SCROLL_SCALE, multiplier)
	_set_band_motion(^"FarSkyline", FAR_SCROLL_SCALE, multiplier)
	_set_band_motion(^"Infrastructure", INFRA_SCROLL_SCALE, multiplier)
	_set_band_motion(^"NearBuildings", NEAR_SCROLL_SCALE, multiplier)


func _set_band_motion(path: NodePath, base: Vector2, multiplier: float) -> void:
	var band: Parallax2D = get_node_or_null(path) as Parallax2D
	if band != null:
		band.scroll_scale = Vector2(base.x * multiplier, base.y)


func _add_depth_sprite(band: Parallax2D, texture: Texture2D, y_offset: float) -> Sprite2D:
	var sprite: Sprite2D = _create_sprite(texture, y_offset)
	band.add_child(sprite)
	return sprite


func _create_sprite(texture: Texture2D, y_offset: float) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(0.0, y_offset)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sprite


func _apply_immediate(district_id: StringName) -> void:
	var texture: Texture2D = DISTRICT_TEXTURES[district_id] as Texture2D
	_sky_sprites[_active_sky_index].texture = texture
	_sky_sprites[_active_sky_index].visible = true
	_sky_sprites[_active_sky_index].modulate = Color.WHITE
	var inactive_index: int = 1 - _active_sky_index
	_sky_sprites[inactive_index].visible = false
	_sky_sprites[inactive_index].modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tints: Array = DEPTH_TINTS[district_id] as Array
	_ungraded_depth_colors.clear()
	for index: int in range(_depth_sprites.size()):
		_ungraded_depth_colors.append(tints[index] as Color)
	if _sky_life != null:
		_sky_life.apply_district(district_id)
	_apply_environment_style()
	current_district_id = district_id
	target_district_id = district_id
	_transition_elapsed = 0.0
	_transitioning = false
	_depth_start_colors.clear()
	_depth_target_colors.clear()


func _finish_transition() -> void:
	var previous_index: int = _active_sky_index
	_active_sky_index = 1 - _active_sky_index
	_sky_sprites[_active_sky_index].visible = true
	_sky_sprites[_active_sky_index].modulate = Color.WHITE
	_sky_sprites[previous_index].visible = false
	_sky_sprites[previous_index].modulate = Color(1.0, 1.0, 1.0, 0.0)
	current_district_id = target_district_id
	_transitioning = false
	if _sky_life != null:
		_sky_life.finish_district_transition()
	_apply_environment_style()


func _apply_environment_style() -> void:
	if _sky_life == null:
		return
	var grade: Color = _sky_life.district_grade()
	var cycle_tint: Color = _sky_life.cycle_tint()
	var brightness: float = _sky_life.cycle_brightness()
	var saturation: float = (
		_sky_life.district_saturation() * _sky_life.cycle_saturation()
	)
	for sprite: Sprite2D in _sky_sprites:
		var material: ShaderMaterial = sprite.material as ShaderMaterial
		material.set_shader_parameter(&"district_grade", grade)
		material.set_shader_parameter(&"cycle_tint", cycle_tint)
		material.set_shader_parameter(&"cycle_brightness", brightness)
		material.set_shader_parameter(&"cycle_saturation", saturation)
	for index: int in range(_depth_sprites.size()):
		var color: Color = _ungraded_depth_colors[index] * grade * cycle_tint
		color.r *= brightness
		color.g *= brightness
		color.b *= brightness
		color.a = _ungraded_depth_colors[index].a
		_depth_sprites[index].modulate = color
