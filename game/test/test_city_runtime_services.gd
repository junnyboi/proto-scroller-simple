extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_music_duck_controller_smoothly_attacks_and_releases() -> void:
	var duck: MusicDuckController = MusicDuckController.new()
	duck.attack_seconds = 0.05
	duck.release_seconds = 0.05
	add_child_autofree(duck)
	await get_tree().process_frame
	var baseline_db: float = duck.current_volume_db()
	duck.set_ducked(true)
	for frame: int in range(8):
		await get_tree().physics_frame
	assert_almost_eq(duck.current_volume_db(), baseline_db + duck.duck_db, 0.1)
	duck.set_ducked(false)
	for frame: int in range(8):
		await get_tree().physics_frame
	assert_almost_eq(duck.current_volume_db(), baseline_db, 0.1)


func test_city_slice_delegates_runtime_infrastructure_below_line_budget() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/gameplay/city_slice.gd"
	)
	var line_count: int = source.split("\n").size()
	assert_lte(line_count, 650)
	assert_true(source.contains("runtime_services.build("))
	assert_false(source.contains("projectile_root = ProjectilePool.new()"))
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	assert_not_null(city.runtime_services)
	assert_same(city.projectile_root, city.runtime_services.projectile_root)
	assert_same(city.debris_pool, city.runtime_services.debris_pool)
	assert_same(city.impact_feedback_pool, city.runtime_services.impact_feedback_pool)
	assert_same(city.enemy_remains_factory, city.runtime_services.enemy_remains_factory)
	assert_same(city.music_duck_controller, city.runtime_services.music_duck_controller)
