extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")

var city: CitySlice


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()


func test_two_act_resource_matches_target_arc_and_duration() -> void:
	assert_eq(DISTRICT.acts.size(), 2)
	var beat_counts: Array[int] = []
	var target_duration: float = 0.0
	for act: DistrictAct in DISTRICT.acts:
		beat_counts.append(act.beats.size())
		target_duration += act.target_duration
	assert_eq(beat_counts, [4, 4])
	assert_eq(target_duration, 140.0)


func test_accelerated_arc_visits_every_act_and_completes() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	var visited: Array[String] = []
	director.phase_changed.connect(
		func(_index: int, display_name: String) -> void: visited.append(display_name)
	)
	director.start()
	var guard: int = 0
	while not director.completed and guard < 600:
		director.advance(1.0)
		_close_shop_if_active()
		city.encounter_runtime.release_all()
		guard += 1
	assert_true(director.completed)
	assert_eq(visited, [
		"encounter.contact",
		"encounter.containment",
	])
	assert_lte(director.elapsed, 180.0)


func test_hud_progress_strip_has_two_fixed_segments() -> void:
	var strip: SiegeProgressStrip = city.gameplay_hud.siege_progress
	assert_not_null(strip)
	assert_eq(strip.segments.size(), 2)
	city.gameplay_hud.set_siege_progress(1, 2, "encounter.containment", true)
	assert_eq(strip.current_index, 1)
	assert_true(strip.recovery_active)
	assert_string_contains(strip.label.text, L10n.t("objective.act", {
		"current": 2,
		"total": 2,
		"name": "",
	}).strip_edges())
	assert_string_contains(strip.label.text, L10n.t("siege.recovery"))


func test_bounded_overrun_advances_with_surviving_low_threat() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	director.start()
	director.beat_index = DISTRICT.acts[0].beats.size() - 1
	director.state = DistrictResponseDirector.STATE_WAITING
	director.act_elapsed = DISTRICT.acts[0].target_duration
	city.encounter_runtime.acquire(&"soldier", Vector2(1200.0, 542.5))
	director.advance(0.1)
	assert_eq(director.phase_index, 1)
	assert_false(city.weapon_shop_assembler.session.active)
	assert_eq(city.encounter_runtime.active_count(&"soldier"), 1)


func test_retained_acts_do_not_enable_late_act_systems() -> void:
	for act: DistrictAct in DISTRICT.acts:
		assert_false(act.elite_allowed)
		assert_false(act.chaos_enabled)
		assert_eq(act.hazard_pressure_budget, 0)
		assert_eq(act.hazard_events_per_beat, 0)


func _close_shop_if_active() -> void:
	if city.weapon_shop_assembler.session.active:
		city.weapon_shop_assembler.session.close_shop()
	if (
		city.urban_siege.pause_coordinator.is_paused()
		and not city.urban_siege.directives.is_active()
	):
		var choices: Array[DirectiveProfile] = DistrictMissionCatalog.choices_for(
			&"BUSINESS",
			city.urban_siege.run_seed,
			city.urban_siege.cycle_count
		)
		if not choices.is_empty():
			city.urban_siege.directives.select(choices[0])
