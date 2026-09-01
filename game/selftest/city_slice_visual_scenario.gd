extends SceneTree

const MAX_FRAMES: int = 180
const SHOT_PATH: String = "res://artifacts/city_slice/city-slice-initial.png"

var elapsed_frames: int = 0
var completed: bool = false


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred("_run")


func _on_process_frame() -> void:
	if completed:
		return
	elapsed_frames += 1
	if elapsed_frames > MAX_FRAMES:
		push_error("City visual scenario exceeded frame watchdog")
		quit(1)


func _run() -> void:
	var target_size: Vector2i = _target_size()
	var show_tweak_disclaimer: bool = (
		OS.get_environment("PROTO_SCROLLER_TWEAK_DISCLAIMER") == "1"
	)
	if show_tweak_disclaimer:
		L10n.set_locale("en")
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	if scene == null:
		quit(1)
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	if show_tweak_disclaimer:
		city.gameplay_hud._set_tuning_provenance({"ranked_eligible": false})
		city.gameplay_hud._apply_responsive_layout()
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		city.encounter_runtime.release_all()
		var helicopter: HelicopterEnemy = city.encounter_runtime.acquire(
			&"helicopter",
			Vector2(city.robot.global_position.x, 180.0)
		) as HelicopterEnemy
		if helicopter != null:
			helicopter.set_physics_process(false)
	await physics_frame
	await physics_frame
	if show_tweak_disclaimer and not _tweak_disclaimer_valid(city, target_size):
		push_error("Tweak disclaimer is outside its bottom-right HUD group")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		quit(0)
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/city_slice")
	)
	var shot_path: String = SHOT_PATH
	if show_tweak_disclaimer:
		shot_path = "res://artifacts/city_slice/city-slice-tweak-disclaimer%s.png" % (
			"-portrait" if target_size.y > target_size.x else ""
		)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(shot_path))
	if save_error != OK or image.get_size() != target_size:
		quit(1)
		return
	completed = true
	print("[CITY-VISUAL-DONE] path=%s" % shot_path)
	quit(0)


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)


func _tweak_disclaimer_valid(city: CitySlice, viewport_size: Vector2) -> bool:
	var hud: GameplayHud = city.gameplay_hud
	var button: Button = hud.tweak_controls_button
	var disclaimer: Label = hud.tweak_leaderboard_disclaimer
	return (
		disclaimer.visible
		and disclaimer.text == "tweaks active, leaderboard disabled"
		and disclaimer.position.y + disclaimer.size.y <= button.position.y
		and disclaimer.position.x + disclaimer.size.x <= viewport_size.x
		and disclaimer.position.y + disclaimer.size.y <= viewport_size.y
	)
