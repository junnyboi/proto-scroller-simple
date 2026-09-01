extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const EXPECTED_PATHS: Dictionary = {
	&"BUSINESS": "res://art/city/parallax/districts/business_panorama.webp",
	&"RESIDENTIAL": "res://art/city/parallax/districts/residential_panorama.webp",
}


func test_both_districts_use_unique_prewarmed_panorama_assets() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: DistrictParallaxRuntime = city.get_node(^"ParallaxCity")
	var baseline_nodes: int = _node_count(runtime)
	assert_eq(runtime.band_count(), 4)
	assert_eq(runtime.sky_sprite_count(), 2)
	assert_eq(runtime.current_district_id, &"BUSINESS")
	assert_eq(runtime.active_texture().resource_path, EXPECTED_PATHS[&"BUSINESS"])
	var seen_paths: Dictionary[String, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		assert_true(runtime.transition_to(district.district_id, true))
		var path: String = runtime.active_texture().resource_path
		assert_eq(path, EXPECTED_PATHS[district.district_id])
		seen_paths[path] = true
		assert_eq(runtime.band_count(), 4)
		assert_eq(runtime.sky_sprite_count(), 2)
		assert_eq(_node_count(runtime), baseline_nodes)
	assert_eq(seen_paths.size(), CityDistrictCatalog.DISTRICT_COUNT)
	assert_eq(runtime.post_warm_creation_count, 0)


func test_all_panorama_tiles_repeat_at_imported_width_with_matched_edges() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: DistrictParallaxRuntime = city.get_node(^"ParallaxCity")
	var sky: Parallax2D = runtime.get_node(^"Sky") as Parallax2D
	assert_not_null(sky)
	assert_eq(sky.repeat_times, DistrictParallaxRuntime.REPEAT_TIMES)
	for child: Node in sky.get_children():
		var sprite: Sprite2D = child as Sprite2D
		assert_not_null(sprite)
		var material: ShaderMaterial = sprite.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(
			material.shader.resource_path,
			"res://shaders/seamless_panorama.gdshader"
		)
	for district_id: StringName in EXPECTED_PATHS:
		assert_true(runtime.transition_to(district_id, true))
		var texture: Texture2D = runtime.active_texture()
		assert_gt(texture.get_width(), 0)
		assert_almost_eq(
			runtime.panorama_repeat_width(),
			float(texture.get_width()),
			0.001
		)
	var far: Parallax2D = runtime.get_node(^"FarSkyline") as Parallax2D
	assert_eq(far.repeat_size, DistrictParallaxRuntime.DEPTH_REPEAT_SIZE)


func test_spatial_transition_crossfades_without_growing_the_scene_tree() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: DistrictParallaxRuntime = city.get_node(^"ParallaxCity")
	var baseline_nodes: int = _node_count(runtime)
	city._on_spatial_district_changed(
		&"BUSINESS",
		&"RESIDENTIAL",
		CityDistrictCatalog.CHUNKS_PER_DISTRICT
	)
	assert_true(runtime.is_transitioning())
	assert_eq(runtime.target_district_id, &"RESIDENTIAL")
	assert_eq(runtime.transition_count, 1)
	assert_false(runtime.transition_to(&"RESIDENTIAL"))
	runtime._process(DistrictParallaxRuntime.CROSSFADE_SECONDS)
	assert_false(runtime.is_transitioning())
	assert_eq(runtime.current_district_id, &"RESIDENTIAL")
	assert_eq(runtime.active_texture().resource_path, EXPECTED_PATHS[&"RESIDENTIAL"])
	assert_eq(_node_count(runtime), baseline_nodes)
	assert_eq(runtime.post_warm_creation_count, 0)
	assert_false(runtime.transition_to(&"UNKNOWN"))


func test_reset_returns_to_business_and_preserves_origin_compensation() -> void:
	var city: CitySlice = await _spawn_city()
	var runtime: DistrictParallaxRuntime = city.get_node(^"ParallaxCity")
	assert_true(runtime.transition_to(&"RESIDENTIAL", true))
	var offset: Vector2 = Vector2(-CityWorldStream.CHUNK_WIDTH * 3.0, 0.0)
	runtime.compensate_origin(offset)
	var far: Parallax2D = runtime.get_node(^"FarSkyline") as Parallax2D
	assert_almost_eq(
		far.scroll_offset.x,
		offset.x * DistrictParallaxRuntime.FAR_SCROLL_SCALE.x,
		0.001
	)
	CityWorldBuilder.reset_parallax(city)
	assert_eq(runtime.current_district_id, &"BUSINESS")
	assert_eq(runtime.active_texture().resource_path, EXPECTED_PATHS[&"BUSINESS"])
	for child: Node in runtime.get_children():
		var band: Parallax2D = child as Parallax2D
		if band != null:
			assert_eq(band.scroll_offset, Vector2.ZERO)


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
