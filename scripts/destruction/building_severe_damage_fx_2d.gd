class_name BuildingSevereDamageFx2D
extends Node2D

const SEVERE_THRESHOLD: float = 0.62
const FIRE_FRAME_COUNT: int = 24
const FIRE_COLUMNS: int = 8
const FIRE_FPS: float = 12.0
const FIRE_CELL_SIZE: Vector2 = Vector2(256.0, 169.0)
const FIRE_ATLAS: Texture2D = preload(
	"res://assets/destruction/damage_details/interior_fire_loop.webp"
)

static var _shared_fire_frames: SpriteFrames

var severity: float = 0.0
var destroyed_stage: bool = false
var fire_intensity: float = 0.0
var arc_intensity: float = 0.0
var activation_count: int = 0
var fire_sprite: AnimatedSprite2D
var _cell_size: Vector2 = Vector2.ONE
var _pattern_seed: int = 1
var _active: bool = false


func configure(cell_size: Vector2, pattern_seed: int) -> void:
	_cell_size = cell_size
	_pattern_seed = maxi(pattern_seed, 1)
	z_index = -1
	if fire_sprite == null:
		fire_sprite = AnimatedSprite2D.new()
		fire_sprite.name = "FireAnimation"
		fire_sprite.sprite_frames = _fire_frames()
		fire_sprite.animation = &"burn"
		fire_sprite.centered = true
		fire_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(fire_sprite)
	_configure_sprite_transform()
	reset_effect()


func set_damage_state(value: float, destroyed: bool, fire_selected: bool = true) -> void:
	severity = clampf(value, 0.0, 1.0)
	destroyed_stage = destroyed
	var next_active: bool = fire_selected and not destroyed_stage and severity >= SEVERE_THRESHOLD
	if next_active and not _active:
		activation_count += 1
	_active = next_active
	visible = _active
	if not _active:
		fire_intensity = 0.0
		arc_intensity = 0.0
		_stop_animation()
		return
	var severe_progress: float = inverse_lerp(SEVERE_THRESHOLD, 1.0, severity)
	fire_intensity = lerpf(0.62, 1.0, severe_progress)
	arc_intensity = 0.0
	fire_sprite.modulate = Color(1.0, 1.0, 1.0, lerpf(0.72, 1.0, severe_progress))
	fire_sprite.scale = _fire_scale() * lerpf(0.88, 1.0, severe_progress)
	fire_sprite.speed_scale = 0.96 + float(posmod(_pattern_seed, 9)) * 0.01
	if not fire_sprite.is_playing():
		fire_sprite.play(&"burn")


func reset_effect() -> void:
	severity = 0.0
	destroyed_stage = false
	fire_intensity = 0.0
	arc_intensity = 0.0
	activation_count = 0
	_active = false
	visible = false
	_stop_animation()


func is_active() -> bool:
	return _active


func _configure_sprite_transform() -> void:
	if fire_sprite == null:
		return
	fire_sprite.position = Vector2(0.0, _cell_size.y * 0.15)
	fire_sprite.scale = _fire_scale()
	fire_sprite.modulate = Color.WHITE
	fire_sprite.set_frame_and_progress(posmod(_pattern_seed, FIRE_FRAME_COUNT), 0.0)


func _fire_scale() -> Vector2:
	var target_size: Vector2 = Vector2(_cell_size.x * 0.58, _cell_size.y * 0.36)
	var fit_scale: float = minf(target_size.x / FIRE_CELL_SIZE.x, target_size.y / FIRE_CELL_SIZE.y)
	return Vector2.ONE * fit_scale


func _stop_animation() -> void:
	if fire_sprite == null:
		return
	fire_sprite.stop()
	fire_sprite.modulate = Color.WHITE
	fire_sprite.scale = _fire_scale()
	fire_sprite.set_frame_and_progress(posmod(_pattern_seed, FIRE_FRAME_COUNT), 0.0)


static func _fire_frames() -> SpriteFrames:
	if _shared_fire_frames != null:
		return _shared_fire_frames
	_shared_fire_frames = SpriteFrames.new()
	_shared_fire_frames.remove_animation(&"default")
	_shared_fire_frames.add_animation(&"burn")
	_shared_fire_frames.set_animation_loop(&"burn", true)
	_shared_fire_frames.set_animation_speed(&"burn", FIRE_FPS)
	for frame_index: int in range(FIRE_FRAME_COUNT):
		var atlas_texture: AtlasTexture = AtlasTexture.new()
		atlas_texture.atlas = FIRE_ATLAS
		atlas_texture.region = Rect2(
			float(frame_index % FIRE_COLUMNS) * FIRE_CELL_SIZE.x,
			float(frame_index / FIRE_COLUMNS) * FIRE_CELL_SIZE.y,
			FIRE_CELL_SIZE.x,
			FIRE_CELL_SIZE.y
		)
		_shared_fire_frames.add_frame(&"burn", atlas_texture)
	return _shared_fire_frames
