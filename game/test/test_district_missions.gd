extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var city: CitySlice
var siege: UrbanSiegeRuntime
var session: DirectiveSession


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	siege = city.urban_siege
	session = siege.directives
	siege.start_run(7703)


func test_catalog_has_two_valid_pools_and_six_unique_missions() -> void:
	assert_true(DistrictMissionCatalog.validation_errors().is_empty())
	assert_eq(DistrictMissionCatalog.pools().size(), CityDistrictCatalog.DISTRICT_COUNT)
	assert_eq(DistrictMissionCatalog.all_profiles().size(), 6)
	var mission_ids: Dictionary[StringName, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		var profiles: Array[DirectiveProfile] = DistrictMissionCatalog.profiles_for(
			district.district_id
		)
		assert_eq(profiles.size(), DistrictMissionCatalog.CHOICES_PER_DISTRICT)
		for profile: DirectiveProfile in profiles:
			assert_eq(profile.district_id, district.district_id)
			assert_false(mission_ids.has(profile.directive_id))
			mission_ids[profile.directive_id] = true
			assert_ne(L10n.t(profile.display_name), profile.display_name)
			assert_ne(L10n.t(profile.instruction), profile.instruction)
	assert_eq(mission_ids.size(), 6)


func test_district_choices_are_deterministic_unique_and_call_order_independent() -> void:
	var expected: PackedStringArray = _choice_ids(
		DistrictMissionCatalog.choices_for(&"RESIDENTIAL", 991, 2)
	)
	DistrictMissionCatalog.choices_for(&"BUSINESS", 4, 1)
	DistrictMissionCatalog.choices_for(&"RESIDENTIAL", 181, 2)
	var repeated: PackedStringArray = _choice_ids(
		DistrictMissionCatalog.choices_for(&"RESIDENTIAL", 991, 2)
	)
	assert_eq(repeated, expected)
	assert_eq(expected.size(), DistrictMissionCatalog.CHOICES_PER_DISTRICT)
	var unique: Dictionary[String, bool] = {}
	for directive_id: String in expected:
		unique[directive_id] = true
	assert_eq(unique.size(), DistrictMissionCatalog.CHOICES_PER_DISTRICT)


func test_every_profile_accepts_its_authored_event_and_rejects_wrong_kind() -> void:
	for profile: DirectiveProfile in DistrictMissionCatalog.all_profiles():
		var event: GameplayEvent = _matching_event(profile)
		assert_true(profile.matches_event(event), String(profile.directive_id))
		var wrong: GameplayEvent = _matching_event(profile)
		wrong.kind = GameplayEvent.Kind.PLAYER_HEAVY_HIT
		if profile.objective_kind >= 0 and profile.objective_kind != wrong.kind:
			assert_false(profile.matches_event(wrong), String(profile.directive_id))


func test_boundary_withdraws_without_penalty_and_offers_destination_once() -> void:
	siege._offer_district_once(&"BUSINESS")
	assert_eq(siege.pause_coordinator.lease_count(), 1)
	assert_true(city.gameplay_hud.directive_choice_overlay.visible)
	var business: DirectiveProfile = city.gameplay_hud.directive_choice_overlay.profiles[0]
	assert_eq(business.district_id, &"BUSINESS")
	city.gameplay_hud.directive_choice_overlay.buttons[0].pressed.emit()
	assert_eq(session.active_profile.district_id, &"BUSINESS")
	assert_eq(siege.pause_coordinator.lease_count(), 0)
	var score_before: int = city.score

	siege._on_spatial_district_changed(&"BUSINESS", &"RESIDENTIAL", 8)
	assert_null(session.active_profile)
	assert_null(session.selected_profile)
	assert_eq(city.score, score_before)
	assert_true(city.gameplay_hud.directive_choice_overlay.visible)
	assert_eq(siege.pause_coordinator.lease_count(), 1)
	for profile: DirectiveProfile in city.gameplay_hud.directive_choice_overlay.profiles:
		assert_eq(profile.district_id, &"RESIDENTIAL")

	siege._on_spatial_district_changed(&"RESIDENTIAL", &"BUSINESS", 7)
	assert_false(city.gameplay_hud.directive_choice_overlay.visible)
	assert_eq(siege.pause_coordinator.lease_count(), 0)
	assert_eq(siege._offered_district_keys.size(), 2)


func test_withdrawal_invalidates_deferred_effect_generation() -> void:
	var profile: DirectiveProfile = DistrictMissionCatalog.profiles_for(&"RESIDENTIAL")[0]
	assert_true(session.select(profile))
	var generation_before: int = session._generation
	session.withdraw()
	assert_gt(session._generation, generation_before)
	assert_true(session._seen_aftershocks.is_empty())


func _choice_ids(profiles: Array[DirectiveProfile]) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for profile: DirectiveProfile in profiles:
		ids.append(String(profile.directive_id))
	return ids


func _matching_event(profile: DirectiveProfile) -> GameplayEvent:
	var kind: int = (
		profile.objective_kind
		if profile.objective_kind >= 0
		else GameplayEvent.Kind.CELL_DESTROYED
	)
	var event: GameplayEvent = GameplayEvent.new(
		StringName("district_mission_%s" % profile.directive_id),
		9000,
		kind,
		profile.objective_action_tag,
		100,
		5.0,
		profile.objective_requires_combo,
		Vector2.ZERO,
		profile.objective_material_id,
		0,
		0,
		profile.objective_cause
	)
	event.causal_depth = profile.objective_min_causal_depth
	return event
