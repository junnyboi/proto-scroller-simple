extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const EXPECTED_EFFECTS: Dictionary = {
	&"BUSINESS": &"acid_drizzle",
	&"RESIDENTIAL": &"utility_rain",
}


func test_both_districts_have_unique_fixed_budget_weather_profiles() -> void:
	var city: CitySlice = await _spawn_city()
	var weather: DistrictWeatherRuntime = city.get_node(^"DistrictWeather")
	var baseline_nodes: int = _node_count(weather)
	var effects: Dictionary[StringName, bool] = {}
	assert_eq(weather.layer, DistrictWeatherRuntime.WEATHER_LAYER)
	assert_lt(weather.layer, city.gameplay_hud.layer)
	assert_eq(weather.surface_count(), 1)
	assert_eq(weather.current_district_id, &"BUSINESS")
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		assert_true(weather.transition_to(district.district_id, true))
		var profile: Dictionary = weather.profile_for(district.district_id)
		assert_eq(weather.current_district_id, district.district_id)
		assert_eq(weather.active_effect(), EXPECTED_EFFECTS[district.district_id])
		assert_lte(float(profile.opacity), 0.42)
		assert_lte(weather.active_particle_count(), DistrictWeatherSurface.PARTICLE_CAPACITY)
		assert_eq(_node_count(weather), baseline_nodes)
		effects[weather.active_effect()] = true
	assert_eq(effects.size(), CityDistrictCatalog.DISTRICT_COUNT)
	assert_eq(weather.post_warm_creation_count, 0)
	assert_false(weather.transition_to(&"UNKNOWN_DISTRICT"))
	assert_false(weather.transition_to(&"UNKNOWN"))


func test_spatial_district_signal_synchronizes_weather_and_parallax() -> void:
	var city: CitySlice = await _spawn_city()
	var weather: DistrictWeatherRuntime = city.get_node(^"DistrictWeather")
	var parallax: DistrictParallaxRuntime = city.get_node(^"ParallaxCity")
	var weather_nodes: int = _node_count(weather)
	city._on_spatial_district_changed(
		&"BUSINESS",
		&"RESIDENTIAL",
		CityDistrictCatalog.CHUNKS_PER_DISTRICT
	)
	assert_true(weather.is_transitioning())
	assert_true(parallax.is_transitioning())
	assert_eq(weather.target_district_id, &"RESIDENTIAL")
	assert_eq(parallax.target_district_id, &"RESIDENTIAL")
	weather._process(DistrictWeatherRuntime.TRANSITION_SECONDS)
	parallax._process(DistrictParallaxRuntime.CROSSFADE_SECONDS)
	assert_false(weather.is_transitioning())
	assert_eq(weather.current_district_id, &"RESIDENTIAL")
	assert_eq(weather.active_effect(), &"utility_rain")
	assert_eq(parallax.current_district_id, &"RESIDENTIAL")
	assert_eq(_node_count(weather), weather_nodes)


func test_portrait_density_is_reduced_and_new_game_reset_returns_to_business() -> void:
	var city: CitySlice = await _spawn_city()
	var weather: DistrictWeatherRuntime = city.get_node(^"DistrictWeather")
	var landscape_count: int = weather.particle_count_for_viewport(
		&"RESIDENTIAL",
		Vector2(1280.0, 720.0)
	)
	var portrait_count: int = weather.particle_count_for_viewport(
		&"RESIDENTIAL",
		Vector2(720.0, 1280.0)
	)
	assert_eq(landscape_count, 112)
	assert_eq(portrait_count, 81)
	assert_lt(portrait_count, landscape_count)
	assert_eq(weather.particle_count_for_viewport(&"UNKNOWN", Vector2.ONE), 0)
	assert_true(weather.transition_to(&"RESIDENTIAL", true))
	assert_eq(weather.active_effect(), &"utility_rain")
	CityWorldBuilder.reset_environment(city)
	assert_eq(weather.current_district_id, &"BUSINESS")
	assert_eq(weather.active_effect(), &"acid_drizzle")
	assert_eq(
		(city.get_node(^"ParallaxCity") as DistrictParallaxRuntime).current_district_id,
		&"BUSINESS"
	)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _node_count(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _node_count(child)
	return count
