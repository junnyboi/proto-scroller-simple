extends SceneTree

const ARTIFACT_DIR: String = "res://artifacts/district_parallax_seams"
const MAX_FRAMES: int = 240
const DISTRICT_IDS: Array[StringName] = [
	&"BUSINESS",
	&"RESIDENTIAL",
]

var _elapsed_frames: int = 0
var _completed: bool = false


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred("_run")


func _on_process_frame() -> void:
	if _completed:
		return
	_elapsed_frames += 1
	if _elapsed_frames > MAX_FRAMES:
		push_error("District parallax seam scenario exceeded frame watchdog")
		quit(1)


func _run() -> void:
	var portrait: bool = OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1"
	var target_size: Vector2i = (
		Vector2i(720, 1280) if portrait else Vector2i(2048, 905)
	)
	root.get_window().content_scale_size = target_size
	root.size = target_size
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(ARTIFACT_DIR)
	)
	var runtime: DistrictParallaxRuntime = DistrictParallaxRuntime.new()
	runtime.name = "ParallaxSeamProbe"
	root.add_child(runtime)
	await process_frame
	for band_name: NodePath in [^"FarSkyline", ^"Infrastructure", ^"NearBuildings"]:
		var depth_band: Parallax2D = runtime.get_node(band_name) as Parallax2D
		depth_band.visible = false
	var sky: Parallax2D = runtime.get_node(^"Sky") as Parallax2D
	sky.scroll_offset = Vector2(runtime.panorama_repeat_width() * 0.5, 0.0)
	var report: Dictionary = {
		"done": false,
		"result": "FAIL",
		"orientation": "portrait" if portrait else "wide",
		"repeat_width": runtime.panorama_repeat_width(),
		"shots": [],
	}
	for district_id: StringName in DISTRICT_IDS:
		if not runtime.transition_to(district_id, true):
			push_error("Failed to select district panorama: %s" % district_id)
			quit(1)
			return
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var strip_height: int = mini(
			int(runtime.active_texture().get_height()),
			image.get_height()
		)
		image.crop(image.get_width(), strip_height)
		var suffix: String = "portrait" if portrait else "wide"
		var path: String = "%s/%s-%s.png" % [
			ARTIFACT_DIR,
			String(district_id).to_lower(),
			suffix,
		]
		var save_error: Error = image.save_png(ProjectSettings.globalize_path(path))
		if save_error != OK:
			push_error("Failed to save district parallax seam capture: %s" % path)
			quit(1)
			return
		report.shots.append(
			{
				"district": String(district_id),
				"path": path,
				"width": image.get_width(),
				"height": image.get_height(),
			}
		)
	report.done = true
	report.result = "PASS"
	var report_path: String = "%s/report-%s.json" % [
		ARTIFACT_DIR,
		"portrait" if portrait else "wide",
	]
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open district parallax seam report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	_completed = true
	print("[DISTRICT-PARALLAX-SEAMS-DONE] orientation=%s" % report.orientation)
	quit(0)
