extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const LEGACY_PREFERENCE_PATH: String = "user://combat_tutorial.cfg"


func before_each() -> void:
	L10n.set_locale("en")
	_remove_test_preference()


func after_each() -> void:
	L10n.set_locale("en")
	_remove_test_preference()


func test_mechanic_signals_advance_and_complete_the_six_step_uplink() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var tutorial: FirstRunCombatTutorial = city.gameplay_hud.first_run_tutorial
	tutorial.start_for_test()
	assert_true(tutorial.visible)
	assert_true(tutorial.tutorial_active)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.MOVE)
	assert_eq(tutorial.progress_label.text, "COMBAT UPLINK  01 / 06")
	city.robot.locomotion_changed.emit(GiantRobotController.LocomotionState.WALK)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.GROUND_SMASH)
	city.robot.attack_committed.emit(AttackSpec.Mode.GROUND_SMASH, 101)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.JAB_CROSS)
	city.robot.attack_committed.emit(AttackSpec.Mode.JAB_CROSS, 102)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.CHARGE_ATTACK)
	city.contextual_attacks.charge_released.emit(
		_jab_cross_spec(103, 0.8, 1.5),
		1.0,
		1.5
	)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.CHARGE_ATTACK)
	city.contextual_attacks.charge_released.emit(
		_jab_cross_spec(104, 0.8, 2.0),
		2.0,
		2.0
	)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.DASH)
	city.robot.dodge_started.emit(-1, 0.18)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.DASH_PUNCH)
	var moving_jab: AttackSpec = _jab_cross_spec(105, 0.8)
	city.contextual_attacks.attack_started.emit(moving_jab)
	city.robot.attack_committed.emit(AttackSpec.Mode.JAB_CROSS, moving_jab.attack_id)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.DASH_PUNCH)
	var dash_punch: AttackSpec = _jab_cross_spec(
		106,
		ContextualAttackController.DODGE_CANCEL_MELEE_MOMENTUM_RATIO
	)
	city.contextual_attacks.attack_started.emit(dash_punch)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.DASH_PUNCH)
	city.robot.attack_committed.emit(AttackSpec.Mode.JAB_CROSS, dash_punch.attack_id)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.COMPLETE)
	assert_true(tutorial.completed)
	assert_false(tutorial.tutorial_active)
	assert_false(tutorial.skipped)
	assert_eq(tutorial.title_label.text, "COMBAT UPLINK COMPLETE")
	assert_true(tutorial.body_label.text.contains("Dash + Punch"))
	_record_test_execution()


func test_skip_persists_current_tutorial_version() -> void:
	var first: FirstRunCombatTutorial = FirstRunCombatTutorial.new()
	first.setup(null, null)
	add_child_autofree(first)
	await get_tree().process_frame
	assert_true(first.tutorial_active)
	first.skip_button.pressed.emit()
	assert_true(first.completed)
	assert_true(first.skipped)
	assert_true(FileAccess.file_exists(LEGACY_PREFERENCE_PATH))
	first.queue_free()
	await get_tree().process_frame
	var second: FirstRunCombatTutorial = FirstRunCombatTutorial.new()
	second.setup(null, null)
	add_child_autofree(second)
	await get_tree().process_frame
	assert_true(second.completed)
	assert_false(second.tutorial_active)
	assert_false(second.visible)
	assert_eq(second.current_step, FirstRunCombatTutorial.Step.COMPLETE)
	_record_test_execution()


func test_completed_tutorial_stays_suppressed_on_next_title_launch() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	var first: FirstRunCombatTutorial = main.city_slice.gameplay_hud.first_run_tutorial
	assert_true(first.tutorial_active)
	var first_instance_id: int = first.get_instance_id()
	first.skip_button.pressed.emit()
	assert_true(first.completed)
	main._return_to_title()
	await get_tree().process_frame
	assert_not_null(main.title_screen)
	main.start_game()
	await get_tree().process_frame
	var second: FirstRunCombatTutorial = main.city_slice.gameplay_hud.first_run_tutorial
	assert_ne(second.get_instance_id(), first_instance_id)
	assert_true(second.completed)
	assert_false(second.tutorial_active)
	assert_false(second.visible)
	assert_eq(second.current_step, FirstRunCombatTutorial.Step.COMPLETE)
	_record_test_execution()


func test_legacy_seen_cache_does_not_suppress_a_new_tutorial() -> void:
	var legacy_config: ConfigFile = ConfigFile.new()
	legacy_config.set_value("combat_tutorial", "completed", true)
	assert_eq(legacy_config.save(LEGACY_PREFERENCE_PATH), OK)
	var tutorial: FirstRunCombatTutorial = FirstRunCombatTutorial.new()
	tutorial.setup(null, null)
	add_child_autofree(tutorial)
	await get_tree().process_frame
	assert_false(tutorial.completed)
	assert_true(tutorial.tutorial_active)
	assert_true(tutorial.visible)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.MOVE)
	_record_test_execution()


func test_tutorial_localizes_and_stays_inside_landscape_and_portrait() -> void:
	L10n.set_locale("zh-CN")
	var tutorial: FirstRunCombatTutorial = FirstRunCombatTutorial.new()
	tutorial.setup(null, null)
	add_child_autofree(tutorial)
	await get_tree().process_frame
	tutorial.start_for_test()
	assert_eq(tutorial.progress_label.text, "战斗连接  01 / 06")
	assert_eq(tutorial.skip_button.text, "跳过")
	_assert_chinese_copy(tutorial, "移动原型机", "左摇杆")
	tutorial._advance_to(FirstRunCombatTutorial.Step.GROUND_SMASH)
	_assert_chinese_copy(tutorial, "地面重击近战", "范围地面重击")
	tutorial._advance_to(FirstRunCombatTutorial.Step.JAB_CROSS)
	_assert_chinese_copy(tutorial, "刺拳连击近战", "两段拳击")
	tutorial._advance_to(FirstRunCombatTutorial.Step.CHARGE_ATTACK)
	_assert_chinese_copy(tutorial, "蓄力攻击", "核心闪出蓝白光")
	tutorial.apply_responsive_layout(Vector2(1280.0, 720.0))
	await get_tree().process_frame
	assert_eq(
		tutorial.body_label.get_visible_line_count(),
		tutorial.body_label.get_line_count()
	)
	tutorial._advance_to(FirstRunCombatTutorial.Step.DASH)
	_assert_chinese_copy(tutorial, "冲刺", "拨动左摇杆两次")
	tutorial._advance_to(FirstRunCombatTutorial.Step.DASH_PUNCH)
	_assert_chinese_copy(tutorial, "冲刺 + 出拳", "取消冲刺并向前出拳")
	tutorial.apply_responsive_layout(Vector2(1280.0, 720.0))
	await get_tree().process_frame
	assert_true(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)).encloses(
		Rect2(tutorial.panel.position, tutorial.panel.size)
	))
	assert_eq(
		tutorial.body_label.get_visible_line_count(),
		tutorial.body_label.get_line_count()
	)
	tutorial.apply_responsive_layout(Vector2(720.0, 1280.0))
	await get_tree().process_frame
	assert_true(Rect2(Vector2.ZERO, Vector2(720.0, 1280.0)).encloses(
		Rect2(tutorial.panel.position, tutorial.panel.size)
	))
	assert_eq(
		tutorial.body_label.get_visible_line_count(),
		tutorial.body_label.get_line_count()
	)
	assert_gte(tutorial.body_label.get_theme_font_size(&"font_size"), 20)
	tutorial._finish_tutorial(false)
	_assert_chinese_copy(tutorial, "战斗连接完成", "武器会自动开火")
	_record_test_execution()


func _assert_chinese_copy(
	tutorial: FirstRunCombatTutorial,
	expected_title: String,
	expected_body_phrase: String
) -> void:
	assert_eq(tutorial.title_label.text, expected_title)
	assert_true(tutorial.body_label.text.contains(expected_body_phrase))
	assert_false(tutorial.title_label.text.contains("tutorial."))
	assert_false(tutorial.body_label.text.contains("tutorial."))


func _remove_test_preference() -> void:
	if FileAccess.file_exists(LEGACY_PREFERENCE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_PREFERENCE_PATH))


func _jab_cross_spec(
	attack_id: int,
	speed_ratio: float,
	charge_multiplier: float = 1.0
) -> AttackSpec:
	var resolver: AttackResolver = AttackResolver.new()
	var spec: AttackSpec = resolver.resolve_jab_cross(attack_id, 1, speed_ratio)
	resolver.free()
	return spec.with_damage_multiplier(charge_multiplier)


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
