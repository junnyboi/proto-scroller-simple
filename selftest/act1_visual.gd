extends SceneTree

var main: Main


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/act1-visual"))
	root.size = Vector2i(1280, 720)
	L10n.set_locale("en")
	main = load("res://scenes/main/main.tscn").instantiate() as Main
	root.add_child(main)
	await _settle()
	_capture("title-landscape")
	main.start_game()
	await _settle()
	_capture("gameplay-landscape")
	root.size = Vector2i(1728, 720)
	await _settle()
	_capture("gameplay-wide")
	root.size = Vector2i(720, 1280)
	await _settle()
	_capture("gameplay-portrait")
	main._return_to_title()
	L10n.set_locale("zh-CN")
	main.title_screen.select_language("zh-CN")
	await _settle()
	_capture("title-portrait-zh")
	L10n.set_locale("en", true)
	main.queue_free()
	await process_frame
	await process_frame
	print("[ACT1-VISUAL] captured original title and gameplay in both orientations")
	quit()


func _settle() -> void:
	for _frame: int in range(24):
		await process_frame
		await physics_frame


func _capture(label: String) -> void:
	RenderingServer.force_draw()
	var frame: Image = root.get_texture().get_image()
	var path: String = "res://artifacts/act1-visual/%s.png" % label
	assert(frame != null and not frame.is_empty(), "Missing native render")
	assert(frame.save_png(path) == OK, "Unable to save native render")
