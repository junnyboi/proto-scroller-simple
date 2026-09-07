class_name WeaponImpactEffect2D
extends Node2D

var active: bool = false
var paused: bool = false
var age: float = 0.0
var lifetime: float = 0.24
var activation_count: int = 0
var visual_key: StringName = &""
var current_frame: int = 0
var presentation_scale: float = 1.0
var sprite: Sprite2D
var particles: GPUParticles2D
var _base_scale: Vector2 = Vector2.ONE
var _uses_atlas_region: bool = false
var _uses_frame_sequence: bool = false
var _frame_cell_size: Vector2i = Vector2i.ONE
var _frame_count: int = 1
var _frame_columns: int = 1
var _playback_fps: float = 30.0
var _pivot_normalized: Vector2 = Vector2(0.5, 0.5)


func setup(
	texture: Texture2D,
	display_size: Vector2,
	p_lifetime: float,
	p_z_index: int,
	particle_amount: int = 6
) -> void:
	_ensure_nodes(p_lifetime, particle_amount)
	z_as_relative = false
	z_index = p_z_index
	_reset_animation_spec()
	_configure_visual(texture, Rect2i(), display_size, p_lifetime, Color.WHITE)
	deactivate()


func configure_from_spec(spec: Dictionary) -> bool:
	var texture: Texture2D = spec.get("texture") as Texture2D
	var region: Rect2i = spec.get("region", Rect2i())
	var display_size: Vector2 = spec.get("display_size", Vector2.ZERO)
	var next_lifetime: float = float(spec.get("lifetime", 0.24))
	var tint: Color = spec.get("tint", Color.WHITE)
	var frame_cell_size: Vector2i = spec.get("frame_cell_size", Vector2i.ZERO)
	var frame_count: int = int(spec.get("frame_count", 1))
	if texture == null or display_size.x <= 0.0 or display_size.y <= 0.0:
		return false
	_ensure_nodes(next_lifetime, 1)
	_reset_animation_spec()
	visual_key = StringName(spec.get("visual_key", &""))
	if frame_count > 1 and frame_cell_size.x > 0 and frame_cell_size.y > 0:
		_uses_frame_sequence = true
		_frame_cell_size = frame_cell_size
		_frame_count = frame_count
		_frame_columns = maxi(int(spec.get("columns", frame_count)), 1)
		_playback_fps = maxf(float(spec.get("playback_fps", 30.0)), 1.0)
		_pivot_normalized = spec.get("pivot_normalized", Vector2(0.5, 0.5))
		next_lifetime = float(_frame_count) / _playback_fps
	_configure_visual(texture, region, display_size, next_lifetime, tint)
	return true


func activate(
	world_position: Vector2,
	direction: Vector2 = Vector2.RIGHT,
	scale_multiplier: float = 1.0
) -> void:
	global_position = world_position
	rotation = direction.angle()
	presentation_scale = clampf(scale_multiplier, 0.1, 4.0)
	age = 0.0
	paused = false
	active = true
	visible = true
	sprite.visible = true
	current_frame = 0
	sprite.scale = (
		_base_scale * presentation_scale
		if _uses_frame_sequence
		else _base_scale * 0.76 * presentation_scale
	)
	sprite.modulate.a = 1.0
	if _uses_frame_sequence:
		_update_animation_frame()
	elif not _uses_atlas_region and particles.amount > 0:
		particles.restart()
		particles.emitting = true
	activation_count += 1
	set_process(true)


func deactivate() -> void:
	active = false
	paused = false
	age = 0.0
	current_frame = 0
	visual_key = &""
	presentation_scale = 1.0
	visible = false
	rotation = 0.0
	set_process(false)
	if sprite != null:
		sprite.visible = false
		sprite.scale = _base_scale
		sprite.rotation = 0.0
		sprite.position = Vector2.ZERO
		sprite.modulate.a = 1.0
	if particles != null:
		particles.emitting = false


func _process(delta: float) -> void:
	if not active or paused:
		return
	age += delta
	if _uses_frame_sequence:
		var next_frame: int = floori(age * _playback_fps)
		if next_frame >= _frame_count:
			deactivate()
			return
		if next_frame != current_frame:
			current_frame = next_frame
			_update_animation_frame()
		return
	var progress: float = clampf(age / lifetime, 0.0, 1.0)
	sprite.scale = _base_scale * lerpf(0.76, 1.18, progress) * presentation_scale
	sprite.modulate.a = 1.0 - progress
	if age >= lifetime:
		deactivate()


func _ensure_nodes(p_lifetime: float, particle_amount: int) -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "ImpactSprite"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
	if particles != null:
		return
	particles = GPUParticles2D.new()
	particles.name = "ImpactParticles"
	particles.amount = particle_amount
	particles.lifetime = p_lifetime * 1.15
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.35
	particles.visibility_rect = Rect2(-128.0, -128.0, 256.0, 256.0)
	var particle_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	particle_material.direction = Vector3(1.0, 0.0, 0.0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 95.0
	particle_material.initial_velocity_max = 210.0
	particle_material.gravity = Vector3(0.0, 180.0, 0.0)
	particle_material.scale_min = 0.035
	particle_material.scale_max = 0.075
	particles.process_material = particle_material
	add_child(particles)


func _configure_visual(
	texture: Texture2D,
	region: Rect2i,
	display_size: Vector2,
	p_lifetime: float,
	tint: Color
) -> void:
	lifetime = p_lifetime
	_uses_atlas_region = region.size != Vector2i.ZERO or _uses_frame_sequence
	sprite.texture = texture
	sprite.region_enabled = _uses_atlas_region
	if _uses_frame_sequence:
		sprite.region_rect = Rect2(Vector2.ZERO, Vector2(_frame_cell_size))
	else:
		sprite.region_rect = Rect2(region) if _uses_atlas_region else Rect2()
	var source_size: Vector2 = texture.get_size()
	if _uses_frame_sequence:
		source_size = Vector2(_frame_cell_size)
	elif _uses_atlas_region:
		source_size = Vector2(region.size)
	var fit_scale: float = minf(
		display_size.x / maxf(source_size.x, 1.0),
		display_size.y / maxf(source_size.y, 1.0)
	)
	_base_scale = Vector2.ONE * fit_scale
	sprite.scale = _base_scale
	if _uses_frame_sequence:
		var fitted_size: Vector2 = source_size * fit_scale
		sprite.position = (Vector2(0.5, 0.5) - _pivot_normalized) * fitted_size
	else:
		sprite.position = Vector2.ZERO
	sprite.modulate = tint
	particles.texture = texture if not _uses_atlas_region else null
	particles.visible = not _uses_atlas_region
	particles.amount = maxi(particles.amount, 1)
	particles.lifetime = p_lifetime * 1.15
	particles.emitting = false


func _reset_animation_spec() -> void:
	_uses_frame_sequence = false
	_frame_cell_size = Vector2i.ONE
	_frame_count = 1
	_frame_columns = 1
	_playback_fps = 30.0
	_pivot_normalized = Vector2(0.5, 0.5)
	current_frame = 0
	visual_key = &""


func _update_animation_frame() -> void:
	var column: int = current_frame % _frame_columns
	var row: int = floori(float(current_frame) / float(_frame_columns))
	sprite.region_rect = Rect2(
		Vector2(column * _frame_cell_size.x, row * _frame_cell_size.y),
		Vector2(_frame_cell_size)
	)
