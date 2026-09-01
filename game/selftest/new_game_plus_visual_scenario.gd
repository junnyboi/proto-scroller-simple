extends SceneTree

const MAX_FRAMES: int = 180
const SHOT_PATH: String = "res://artifacts/new_game_plus/new-game-plus.png"

var elapsed_frames: int = 0
var completed: bool = false


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred(&"_run")


func _on_process_frame() -> void:
	if completed:
		return
	elapsed_frames += 1
	if elapsed_frames > MAX_FRAMES:
		push_error("New Game+ visual scenario exceeded frame watchdog")
		quit(1)


func _run() -> void:
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	if scene == null:
		quit(1)
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	city.rampage_session.run_score.safe_score = 42_500
	city._on_score_changed(42_500, 0)
	city.run_lifecycle._on_district_completed()
	await process_frame
	await RenderingServer.frame_post_draw
	if (
		not city.gameplay_hud.game_over_overlay.visible
		or not city.gameplay_hud.new_game_plus_badge.visible
	):
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		quit(0)
		return
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/new_game_plus")
	)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	if save_error != OK or image.get_size() != target_size:
		quit(1)
		return
	completed = true
	print("[NEW-GAME-PLUS-VISUAL-DONE] shot=%s" % SHOT_PATH)
	quit(0)


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)
