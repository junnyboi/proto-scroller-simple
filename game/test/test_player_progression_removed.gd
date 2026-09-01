extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const REMOVED_RUNTIME_PATHS: PackedStringArray = [
	"res://scripts/rampage/run_experience.gd",
	"res://scripts/upgrades/player_upgrade_assembler.gd",
	"res://scripts/upgrades/upgrade_session.gd",
	"res://scripts/shop/weapon_shop_assembler.gd",
	"res://scripts/shop/weapon_shop_session.gd",
]
const REMOVED_NODE_NAMES: PackedStringArray = [
	"RunExperience",
	"PlayerUpgradeAssembler",
	"UpgradeSession",
	"UpgradeChoiceOverlay",
	"WeaponStatusStrip",
	"WeaponShopAssembler",
	"WeaponShopSession",
	"WeaponShopOverlay",
]


func test_progression_source_and_runtime_services_are_absent() -> void:
	for path: String in REMOVED_RUNTIME_PATHS:
		assert_false(FileAccess.file_exists(path), path)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for node_name: String in REMOVED_NODE_NAMES:
		assert_null(_find_descendant(city, node_name), node_name)
	assert_null(_find_descendant(city.gameplay_hud, "ExperienceTrack"))
	assert_false(get_tree().paused)


func test_large_score_award_does_not_open_a_level_or_upgrade_modal() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var score_event: GameplayEvent = GameplayEvent.new(
		&"progression_removed_score",
		1,
		GameplayEvent.Kind.PROP_DESTROYED,
		&"TEST_SCORE",
		1_000_000
	)
	assert_true(city.rampage_session.publish(score_event))
	await get_tree().process_frame
	assert_eq(city.score, 1_000_000)
	assert_false(get_tree().paused)
	for node_name: String in REMOVED_NODE_NAMES:
		assert_null(_find_descendant(city, node_name), node_name)


func test_district_pressure_is_authored_by_stage_not_player_level() -> void:
	var first: DistrictPressureProfile = DistrictPressureCatalog.authored_profile(&"BUSINESS")
	var final: DistrictPressureProfile = DistrictPressureCatalog.authored_profile(&"RESIDENTIAL")
	assert_not_null(first)
	assert_not_null(final)
	assert_eq(first.district_index, 0)
	assert_eq(final.district_index, 1)
	assert_gt(final.threat_allowance, first.threat_allowance)
	assert_lt(final.cadence_scale, first.cadence_scale)


func _find_descendant(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child: Node in root.get_children():
		var match: Node = _find_descendant(child, node_name)
		if match != null:
			return match
	return null
