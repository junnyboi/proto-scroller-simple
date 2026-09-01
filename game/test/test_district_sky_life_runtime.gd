extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const EXPECTED_ASSETS: Dictionary = {
	"CourierShuttle": "res://art/city/parallax/living/courier_shuttle.webp",
	"StateCarrier": "res://art/city/parallax/living/state_carrier.webp",
}


func test_living_sky_uses_fixed_prewarmed_art_and_node_budget() -> void:
	var city: CitySlice = await _spawn_city()
	var parallax: DistrictParallaxRuntime = city.get_node(^"ParallaxCity")
	var life: DistrictSkyLifeRuntime = parallax.sky_life_runtime()
	assert_not_null(life)
	assert_eq(life.band_count(), RuntimeBudget.SKY_LIFE_BANDS)
	assert_eq(life.sprite_count(), RuntimeBudget.SKY_LIFE_SPRITES)
	assert_eq(life.post_warm_creation_count, 0)
	assert_null(life.find_child("CloudBank", true, false))
	assert_null(life.find_child("CloudLife", true, false))
	var baseline_nodes: int = _node_count(life)
	for sprite_name: String in EXPECTED_ASSETS:
		var sprite: Sprite2D = life.find_child(sprite_name, true, false) as Sprite2D
		assert_not_null(sprite)
		assert_eq(sprite.texture.resource_path, EXPECTED_ASSETS[sprite_name])
	life.advance(10.0)
	assert_eq(_node_count(life), baseline_nodes)
	assert_eq(life.post_warm_creation_count, 0)


func test_all_districts_have_distinct_motion_and_color_profiles() -> void:
	var city: CitySlice = await _spawn_city()
	var life: DistrictSkyLifeRuntime = _life(city)
	var seen_grades: Dictionary[String, bool] = {}
	var seen_speeds: Dictionary[float, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		var profile: Dictionary = life.profile_for(district.district_id)
		assert_false(profile.is_empty())
		seen_grades[(profile.grade as Color).to_html()] = true
		seen_speeds[float(profile.traffic_speed)] = true
	assert_eq(seen_grades.size(), CityDistrictCatalog.DISTRICT_COUNT)
	assert_eq(seen_speeds.size(), CityDistrictCatalog.DISTRICT_COUNT)


func test_traffic_advances_and_wraps_without_cloud_allocation() -> void:
	var city: CitySlice = await _spawn_city()
	var life: DistrictSkyLifeRuntime = _life(city)
	var traffic_before: float = life.traffic_offset()
	var nodes_before: int = _node_count(life)
	life.advance(2.0)
	assert_gt(life.traffic_offset(), traffic_before)
	life.advance(DistrictSkyLifeRuntime.DAY_CYCLE_SECONDS * 4.0)
	assert_gte(life.traffic_offset(), 0.0)
	assert_lt(life.traffic_offset(), DistrictSkyLifeRuntime.TRAFFIC_REPEAT_WIDTH)
	assert_eq(_node_count(life), nodes_before)


func test_day_night_cycle_has_distinct_states_and_loop_continuity() -> void:
	var city: CitySlice = await _spawn_city()
	var parallax: DistrictParallaxRuntime = city.get_node(^"ParallaxCity")
	var life: DistrictSkyLifeRuntime = parallax.sky_life_runtime()
	parallax.set_time_phase(0.0)
	var night_tint: Color = life.cycle_tint()
	var night_brightness: float = life.cycle_brightness()
	parallax.set_time_phase(0.53)
	var day_tint: Color = life.cycle_tint()
	var day_brightness: float = life.cycle_brightness()
	parallax.set_time_phase(0.72)
	var dusk_tint: Color = life.cycle_tint()
	var dusk_brightness: float = life.cycle_brightness()
	assert_gt(day_brightness, dusk_brightness)
	assert_gt(dusk_brightness, night_brightness)
	assert_gt(_color_distance(day_tint, night_tint), 0.20)
	assert_gt(_color_distance(dusk_tint, night_tint), 0.12)
	parallax.set_time_phase(0.999)
	var before_wrap: Color = life.cycle_tint()
	life.advance(DistrictSkyLifeRuntime.DAY_CYCLE_SECONDS * 0.002)
	var after_wrap: Color = life.cycle_tint()
	assert_almost_eq(life.time_phase, 0.001, 0.0001)
	assert_lt(_color_distance(before_wrap, after_wrap), 0.03)


func test_district_transition_grades_panorama_depth_and_life_together() -> void:
	var city: CitySlice = await _spawn_city()
	var parallax: DistrictParallaxRuntime = city.get_node(^"ParallaxCity")
	var life: DistrictSkyLifeRuntime = parallax.sky_life_runtime()
	var start_grade: Color = life.district_grade()
	assert_true(parallax.transition_to(&"RESIDENTIAL"))
	parallax._process(DistrictParallaxRuntime.CROSSFADE_SECONDS * 0.5)
	var midpoint_grade: Color = life.district_grade()
	assert_gt(_color_distance(start_grade, midpoint_grade), 0.01)
	assert_gt(
		_color_distance(midpoint_grade, life.profile_for(&"RESIDENTIAL").grade),
		0.01
	)
	parallax._process(DistrictParallaxRuntime.CROSSFADE_SECONDS * 0.5)
	assert_eq(parallax.current_district_id, &"RESIDENTIAL")
	assert_eq(life.current_district_id, &"RESIDENTIAL")
	assert_eq(life.district_grade(), life.profile_for(&"RESIDENTIAL").grade)
	var active_sprite: Sprite2D = parallax.get_node(^"Sky/DistrictPanorama1")
	var material: ShaderMaterial = active_sprite.material as ShaderMaterial
	assert_eq(material.get_shader_parameter(&"district_grade"), life.district_grade())
	assert_almost_eq(
		float(material.get_shader_parameter(&"cycle_brightness")),
		life.cycle_brightness(),
		0.001
	)


func test_reset_preserves_world_clock_and_origin_compensation() -> void:
	var city: CitySlice = await _spawn_city()
	var parallax: DistrictParallaxRuntime = city.get_node(^"ParallaxCity")
	var life: DistrictSkyLifeRuntime = parallax.sky_life_runtime()
	parallax.set_time_phase(0.36)
	assert_true(parallax.transition_to(&"RESIDENTIAL", true))
	var traffic_before: float = life.traffic_offset()
	var offset: Vector2 = Vector2(-CityWorldStream.CHUNK_WIDTH, 0.0)
	parallax.compensate_origin(offset)
	assert_almost_eq(
		life.traffic_offset(),
		traffic_before + offset.x * DistrictSkyLifeRuntime.TRAFFIC_SCROLL_SCALE.x,
		0.001
	)
	CityWorldBuilder.reset_environment(city)
	assert_eq(parallax.current_district_id, &"BUSINESS")
	assert_eq(life.current_district_id, &"BUSINESS")
	assert_almost_eq(parallax.time_phase(), 0.36, 0.001)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _life(city: CitySlice) -> DistrictSkyLifeRuntime:
	var parallax: DistrictParallaxRuntime = city.get_node(^"ParallaxCity")
	return parallax.sky_life_runtime()


func _node_count(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _node_count(child)
	return count


func _color_distance(left: Color, right: Color) -> float:
	var delta: Vector3 = Vector3(left.r - right.r, left.g - right.g, left.b - right.b)
	return delta.length()
