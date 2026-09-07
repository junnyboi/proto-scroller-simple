extends SceneTree

const OUTPUT: String = "res://artifacts/pause-visual"
var main: Main


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main/main.tscn").instantiate() as Main
	root.add_child(main)
	main.start_game()
	await _settle(12)
	var city: CitySlice = main.city_slice
	city.encounter_director.stop()
	city.encounter_runtime.set_attack_gate(false)
	city.hit_stop.enabled = false
	city.gameplay_hud.first_run_tutorial.visible = false
	city.gameplay_hud.transmission_toast.visible = false
	var tank: EnemyActor2D = city.encounter_runtime.acquire(
		&"tank", city.robot.global_position + Vector2(240.0, 0.0)
	)
	_check(tank != null, "Tank acquired for fragment overlap")
	city.building_section_burst_pool.spawn(
		tank.global_position + Vector2(0.0, -10.0),
		Vector2.DOWN, 180.0, StructuralMaterialProfile.concrete()
	)
	city.building_section_burst_pool.spawn(
		city.robot.global_position + Vector2(15.0, -40.0),
		Vector2.DOWN, 180.0, StructuralMaterialProfile.glass()
	)
	await _settle(10)
	var token: int = city.runtime_services.simulation_pause.acquire(&"visual_capture")
	_capture("fragments-below-actors")
	city.runtime_services.simulation_pause.release(token)
	_check(main.open_gameplay_settings(), "Settings open")
	await _settle(8)
	_check(paused and not city.robot.can_process(), "Settings freeze the city: %s" % [{
		"tree_paused": paused,
		"robot_processing": city.robot.can_process(),
		"settings_open": main.gameplay_settings_open(),
		"modal_reasons": city.urban_siege.pause_coordinator.lease_reasons(),
	}])
	_capture("settings-landscape")
	main.close_gameplay_settings()
	_check(not paused, "Settings close releases the pause")
	for _cycle: int in range(3):
		_check(main.open_gameplay_settings(), "Repeated settings open")
		await _settle(4)
		_check(paused and not city.robot.can_process(), "Repeated settings freeze")
		main.close_gameplay_settings()
		_check(not paused, "Repeated settings close")
	city.upgrade_assembler.session.queue_level(2, 99001)
	await _settle(8)
	_check(paused and city.gameplay_hud.upgrade_choice_overlay.active, "Upgrade modal freezes")
	_capture("upgrade-landscape")
	var card: UpgradeChoiceCard = city.gameplay_hud.upgrade_choice_overlay.cards[0]
	card.pressed.emit()
	await _settle(8)
	_check(not paused, "Upgrade selection resumes")
	_check(city.weapon_shop_assembler.session.ensure_act_completion(0, 1), "Shop opens")
	await _settle(8)
	_check(paused and city.weapon_shop_assembler.overlay.can_process(), "Shop remains responsive")
	_capture("shop-dialogue-landscape")
	city.weapon_shop_assembler.overlay.dialogue_panel.continue_button.pressed.emit()
	await _settle(8)
	_check(paused, "Dismissing shop dialogue keeps the shop pause")
	_capture("shop-landscape")
	root.size = Vector2i(720, 1280)
	await _settle(8)
	_capture("shop-portrait")
	main.queue_free()
	await _settle(2)
	_check(not paused, "Teardown restores the tree")
	print("[PAUSE-VISUAL-PASS] fragments, settings, upgrades, shop, teardown")
	quit()


func _settle(frames: int) -> void:
	for _frame: int in range(frames):
		await process_frame


func _capture(label: String) -> void:
	RenderingServer.force_draw()
	var frame: Image = root.get_texture().get_image()
	_check(frame != null and not frame.is_empty(), "Native render exists")
	_check(frame.save_png("%s/%s.png" % [OUTPUT, label]) == OK, "Capture saved")


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("[PAUSE-VISUAL-FAIL] " + message)
		quit(1)
