extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func after_each() -> void:
	get_tree().paused = false
	for action: StringName in [&"stomp", &"move_left", &"move_right", &"dodge"]:
		Input.action_release(action)


func test_modal_freezes_physics_attack_timers_boss_and_effect_lifetimes() -> void:
	var city: CitySlice = await _spawn_city()
	var boss: CommandBossSession = city.urban_siege.boss_session
	assert_true(boss.start())
	city.robot.gravity = 0.0
	city.robot.collision_mask = 0
	var debris: DebrisBody2D = city.debris_pool.acquire(
		Transform2D(0.0, city.robot.global_position + Vector2(0.0, -180.0)),
		Vector2(280.0, -180.0)
	)
	var burst: BuildingSectionBurst2D = city.building_section_burst_pool.spawn(
		debris.global_position, Vector2.UP, 320.0, StructuralMaterialProfile.concrete()
	)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_gt(city.contextual_attacks.request_attack(), 0)
	var token: int = city.urban_siege.pause_coordinator.acquire(&"upgrade_choice")
	var robot_position: Vector2 = city.robot.global_position
	var debris_position: Vector2 = debris.global_position
	var boss_elapsed: float = boss.elapsed_seconds
	var burst_age: float = burst._age
	var health: float = city.robot.current_health
	var hud_age: float = city.gameplay_hud._pulse_age
	var wait_seconds: float = city.contextual_attacks.current_spec.anticipation_seconds + 0.15
	await get_tree().create_timer(wait_seconds).timeout
	assert_true(get_tree().paused)
	assert_eq(city.robot.global_position, robot_position)
	assert_eq(debris.global_position, debris_position)
	assert_eq(boss.elapsed_seconds, boss_elapsed)
	assert_eq(burst._age, burst_age)
	assert_eq(city.robot.current_health, health)
	assert_eq(city.contextual_attacks.phase, ContextualAttackController.Phase.ANTICIPATION)
	assert_gt(city.gameplay_hud._pulse_age, hud_age, "Modal UI continues processing")
	assert_true(city.urban_siege.pause_coordinator.release(token))
	await get_tree().create_timer(wait_seconds).timeout
	assert_ne(debris.global_position, debris_position)
	assert_gt(boss.elapsed_seconds, boss_elapsed)
	assert_gt(burst._age, burst_age)
	assert_ne(city.contextual_attacks.phase, ContextualAttackController.Phase.ANTICIPATION)


func test_enabled_hit_stop_expires_on_wall_clock_without_changing_time_scale() -> void:
	var city: CitySlice = await _spawn_city()
	var hit_stop: HitStopLease = city.hit_stop
	hit_stop.enabled = true
	var time_scale: float = Engine.time_scale
	assert_true(hit_stop.request(110, 7001))
	assert_true(get_tree().paused)
	assert_false(city.robot.can_process())
	assert_true(hit_stop.can_process())
	assert_true(city.mobile_controls.controls_enabled())
	assert_false(city.urban_siege.pause_coordinator.is_paused())
	assert_false(hit_stop.request(110, 7001), "Duplicate impact does not extend the freeze")
	assert_true(hit_stop.request(1, 7002))
	assert_eq(hit_stop.last_duration_ms, HitStopLease.MINIMUM_DURATION_MS)
	assert_true(hit_stop.request(1000, 7003))
	assert_eq(hit_stop.last_duration_ms, HitStopLease.MAXIMUM_DURATION_MS)
	await _wait_wall_seconds(0.18)
	assert_false(hit_stop.is_active())
	assert_false(get_tree().paused)
	assert_true(city.robot.can_process())
	assert_eq(hit_stop.restore_count, 1)
	assert_eq(Engine.time_scale, time_scale)


func test_nested_modals_and_hit_stop_release_only_their_own_leases() -> void:
	var city: CitySlice = await _spawn_city()
	var pause: RunPauseCoordinator = city.urban_siege.pause_coordinator
	city.hit_stop.enabled = true
	assert_true(city.hit_stop.request(110))
	var first: int = pause.acquire(&"upgrade_choice")
	var second: int = pause.acquire(&"weapon_shop")
	city.hit_stop.cancel_and_restore()
	assert_true(get_tree().paused)
	assert_true(pause.release(first))
	assert_false(pause.release(first))
	assert_true(get_tree().paused)
	assert_false(city.mobile_controls.controls_enabled())
	assert_true(pause.release(second))
	assert_false(get_tree().paused)
	assert_true(city.mobile_controls.controls_enabled())
	first = pause.acquire(&"field_briefing")
	assert_true(city.hit_stop.request(110))
	pause.release_all()
	assert_true(get_tree().paused, "Modal close must not cancel an active hit-stop")
	city.hit_stop.cancel_and_restore()
	assert_false(get_tree().paused)
	assert_false(pause.release(first))


func test_tuning_and_briefing_share_pause_ownership_and_restore_disabled_state() -> void:
	var city: CitySlice = await _spawn_city()
	city.robot.set_physics_process(false)
	city.mobile_controls.set_controls_enabled(false)
	city.encounter_runtime.process_mode = Node.PROCESS_MODE_DISABLED
	city.encounter_runtime.set_attack_gate(false)
	var adapter: RuntimeTweakPauseAdapter = RuntimeTweakPauseAdapter.new()
	assert_true(adapter.acquire(city))
	var other: int = city.urban_siege.pause_coordinator.acquire(&"other_modal")
	assert_true(adapter.release())
	assert_true(get_tree().paused)
	assert_true(city.urban_siege.pause_coordinator.release(other))
	assert_false(get_tree().paused)
	assert_false(city.robot.is_physics_processing())
	assert_false(city.mobile_controls.controls_enabled())
	assert_eq(city.encounter_runtime.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(city.encounter_runtime.attack_gate_enabled)
	assert_true(city.gameplay_hud.field_briefing.open())
	assert_true(city.gameplay_hud.field_briefing.close(false))
	assert_false(city.robot.is_physics_processing())
	assert_false(city.mobile_controls.controls_enabled())


func test_modal_ui_accepts_keyboard_selection_while_world_is_paused() -> void:
	var city: CitySlice = await _spawn_city()
	var session: UpgradeSession = city.upgrade_assembler.session
	assert_true(session.queue_level(2, 90001))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(get_tree().paused)
	var card: UpgradeChoiceCard = city.gameplay_hud.upgrade_choice_overlay.cards[0]
	var selected_id: StringName = card.upgrade_id
	card.grab_focus()
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(session.rank_of(selected_id), 1)
	assert_false(get_tree().paused)
	assert_false(city.gameplay_hud.upgrade_choice_overlay.active)


func test_touch_release_during_hit_stop_is_deferred_once_until_resume() -> void:
	var city: CitySlice = await _spawn_city()
	var controls: MobileControls = city.mobile_controls
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = 71
	event.position = controls.smash_bounds().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	assert_true(city.contextual_attacks.is_charging())
	city.hit_stop.enabled = true
	assert_true(city.hit_stop.request(110))
	event = event.duplicate() as InputEventScreenTouch
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	assert_true(city.contextual_attacks.is_charging())
	assert_eq(controls.smash_release_count, 0)
	assert_eq(controls.smash_touch_index(), -1)
	city.hit_stop.cancel_and_restore()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(city.contextual_attacks.is_charging())
	assert_eq(controls.smash_release_count, 1)


func test_keyboard_release_during_hit_stop_cannot_leave_charge_stuck() -> void:
	var city: CitySlice = await _spawn_city()
	Input.action_press(&"stomp")
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_true(city.contextual_attacks.is_charging())
	city.hit_stop.enabled = true
	assert_true(city.hit_stop.request(110))
	Input.action_release(&"stomp")
	await _wait_wall_seconds(0.18)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_false(city.contextual_attacks.is_charging())
	assert_false(get_tree().paused)


func test_modal_close_discards_same_frame_combat_presses() -> void:
	var city: CitySlice = await _spawn_city()
	var token: int = city.urban_siege.pause_coordinator.acquire(&"weapon_shop")
	Input.action_press(&"stomp")
	Input.action_press(&"dodge")
	assert_true(city.urban_siege.pause_coordinator.release(token))
	city.robot._physics_process(1.0 / 60.0)
	assert_false(city.contextual_attacks.is_busy())
	assert_eq(city.robot.dodge_count, 0)
	for _frame: int in range(2):
		await get_tree().physics_frame
		await get_tree().process_frame
	Input.action_press(&"stomp")
	city.robot._physics_process(1.0 / 60.0)
	assert_true(city.contextual_attacks.is_charging(), "Fresh input works after resume")


func test_scene_teardown_and_preexisting_tree_pause_restore_correctly() -> void:
	var city: CitySlice = await _spawn_city()
	city.hit_stop.enabled = true
	assert_true(city.hit_stop.request(110))
	city.urban_siege.pause_coordinator.acquire(&"weapon_shop")
	city.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(get_tree().paused, "Removing the city releases all simulation owners")
	var owner: SimulationPause = SimulationPause.new()
	add_child_autofree(owner)
	get_tree().paused = true
	var token: int = owner.acquire(&"existing_pause")
	assert_true(owner.release(token))
	assert_true(get_tree().paused, "An external preexisting pause must be preserved")
	get_tree().paused = false


func _spawn_city() -> CitySlice:
	RuntimeTweakAccess.unbind_service()
	get_tree().root.size = Vector2i(1280, 720)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_director.stop()
	city.encounter_runtime.set_attack_gate(false)
	return city


func _wait_wall_seconds(seconds: float) -> void:
	var deadline: int = Time.get_ticks_usec() + int(seconds * 1_000_000.0)
	while Time.get_ticks_usec() < deadline:
		await get_tree().process_frame
	await get_tree().process_frame
