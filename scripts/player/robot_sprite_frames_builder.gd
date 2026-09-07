class_name RobotSpriteFramesBuilder
extends RefCounted

const ATLAS_SIZE: Vector2i = Vector2i(6400, 1792)
const CELL_SIZE: Vector2i = Vector2i(256, 256)
const FRAME_COUNT: int = 25
const DEFAULT_FPS: float = 12.0
const DEFINITIONS: Array[Dictionary] = [
	{"name": &"walk_e", "row": 0, "frames": FRAME_COUNT, "loop": true},
	{"name": &"walk_w", "row": 1, "frames": FRAME_COUNT, "loop": true},
	{"name": &"attack_e", "row": 2, "frames": FRAME_COUNT, "loop": false},
	{"name": &"attack_w", "row": 3, "frames": FRAME_COUNT, "loop": false},
	{"name": &"attack_se", "row": 4, "frames": FRAME_COUNT, "loop": false},
	{"name": &"attack_sw", "row": 5, "frames": FRAME_COUNT, "loop": false},
	{"name": &"idle_s", "row": 6, "frames": 1, "loop": false},
]


static func build(atlas: Texture2D) -> SpriteFrames:
	var library: SpriteFrames = SpriteFrames.new()
	library.remove_animation(&"default")
	if atlas == null or Vector2i(atlas.get_size()) != ATLAS_SIZE:
		push_error("Robot horizontal atlas is missing or has invalid dimensions.")
		return library
	for definition: Dictionary in DEFINITIONS:
		_add_animation(library, atlas, definition)
	return library


static func _add_animation(
	library: SpriteFrames,
	atlas: Texture2D,
	definition: Dictionary
) -> void:
	var animation: StringName = definition["name"]
	library.add_animation(animation)
	library.set_animation_speed(animation, DEFAULT_FPS)
	library.set_animation_loop_mode(
		animation,
		SpriteFrames.LOOP_LINEAR if bool(definition["loop"]) else SpriteFrames.LOOP_NONE
	)
	for frame_index: int in range(int(definition["frames"])):
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2i(
			frame_index * CELL_SIZE.x,
			int(definition["row"]) * CELL_SIZE.y,
			CELL_SIZE.x,
			CELL_SIZE.y
		)
		frame.filter_clip = true
		library.add_frame(animation, frame)
