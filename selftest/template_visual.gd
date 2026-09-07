extends SceneTree

var main: Main
var captures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/template-visual"))
	for locale: String in ["en", "zh-CN"]:
		for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(720, 1280)]:
			root.size = viewport
			L10n.set_locale(locale)
			main = load("res://scenes/main/main.tscn").instantiate() as Main
			root.add_child(main)
			var suffix: String = "%s-%s" % [locale, "portrait" if viewport.y > viewport.x else "landscape"]
			await _capture("title-" + suffix)
			main.runtime_tweak_panel.open()
			await _capture("title-tuning-" + suffix)
			main.runtime_tweak_panel.close()
			main.title_screen.open_leaderboard()
			await _capture("leaderboard-" + suffix)
			main.title_screen.close_leaderboard()
			main.start_game()
			await _settle()
			main.city_slice.urban_siege.pause_coordinator.release_all()
			main.city_slice.gameplay_hud.first_run_tutorial.replay()
			await _capture("tutorial-" + suffix)
			main.pause_menu.open()
			await _capture("pause-" + suffix)
			main.open_gameplay_settings()
			await _capture("settings-" + suffix)
			main.gameplay_settings_screen.close_settings(false)
			main.runtime_tweak_panel.open()
			await _capture("pause-tuning-" + suffix)
			main.runtime_tweak_panel.close()
			main.pause_menu.close()
			main.city_slice.gameplay_hud.first_run_tutorial.hide()
			main.city_slice.run_lifecycle._finish_run(false)
			await _capture("debrief-" + suffix)
			main.runtime_tweak_panel.open()
			await _capture("debrief-tuning-" + suffix)
			main.runtime_tweak_panel.close()
			main.queue_free()
			await process_frame
			await process_frame
	L10n.set_locale("en")
	print("[TEMPLATE-VISUAL] %d native captures" % captures)
	quit()


func _settle() -> void:
	for _frame: int in range(10):
		await process_frame


func _capture(label: String) -> void:
	await _settle()
	RenderingServer.force_draw()
	var frame: Image = root.get_texture().get_image()
	assert(frame != null and not frame.is_empty())
	assert(frame.save_png("res://artifacts/template-visual/%s.png" % label) == OK)
	captures += 1
