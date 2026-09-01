extends SceneTree

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const ARTIFACT_DIR: String = "res://artifacts/living_district_skies"
const MAX_FRAMES: int = 900
const DISTRICT_IDS: Array[StringName] = [
	&"BUSINESS",
	&"RESIDENTIAL",
]
const TIME_STATES: Array[Dictionary] = [
	{"id": "day", "phase": 0.53},
	{"id": "dusk", "phase": 0.72},
	{"id": "night", "phase": 0.0},
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
		push_error("Living district skies scenario exceeded frame watchdog")
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
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	await process_frame
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	var parallax: DistrictParallaxRuntime = city.get_node(^"ParallaxCity")
	var weather: DistrictWeatherRuntime = city.get_node(^"DistrictWeather")
	var life: DistrictSkyLifeRuntime = parallax.sky_life_runtime()
	if life.find_child("CloudBank", true, false) != null:
		push_error("Cloud bank remains mounted after cloud-removal request")
		quit(1)
		return
	var report: Dictionary = {
		"done": false,
		"result": "FAIL",
		"orientation": "portrait" if portrait else "wide",
		"shots": [],
	}
	for district_id: StringName in DISTRICT_IDS:
		parallax.transition_to(district_id, true)
		weather.transition_to(district_id, true)
		for state: Dictionary in TIME_STATES:
			parallax.set_time_phase(float(state.phase))
			var traffic_before: float = life.traffic_offset()
			parallax._process(1.0)
			if is_equal_approx(traffic_before, life.traffic_offset()):
				push_error("Air traffic did not animate")
				quit(1)
				return
			await process_frame
			await RenderingServer.frame_post_draw
			var suffix: String = "portrait" if portrait else "wide"
			var path: String = "%s/%s-%s-%s.png" % [
				ARTIFACT_DIR,
				String(district_id).to_lower(),
				String(state.id),
				suffix,
			]
			var image: Image = root.get_texture().get_image()
			var save_error: Error = image.save_png(
				ProjectSettings.globalize_path(path)
			)
			if save_error != OK:
				push_error("Failed to save living sky capture: %s" % path)
				quit(1)
				return
			report.shots.append(
				{
					"district": String(district_id),
					"time": String(state.id),
					"path": path,
					"cloud_mounted": false,
					"traffic_offset": life.traffic_offset(),
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
		push_error("Failed to open living district skies report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	_completed = true
	print("[LIVING-DISTRICT-SKIES-DONE] orientation=%s" % report.orientation)
	quit(0)
