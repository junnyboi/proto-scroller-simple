extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_rubble_pools_recycle_only_after_leaving_the_expanded_camera_view() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	assert_not_null(city.camera_rig)
	assert_same(city.debris_pool._culling_camera, city.camera_rig)
	assert_same(city.enemy_scrap_pool._culling_camera, city.camera_rig)
	var pool: DebrisPool = city.debris_pool
	var culling_rect: Rect2 = city.camera_rig.visible_world_rect(pool.cull_margin)
	var center: Vector2 = culling_rect.get_center()
	var near_edge: DebrisBody2D = pool.acquire(
		Transform2D(
			0.0,
			culling_rect.position + Vector2(1.0, culling_rect.size.y * 0.5)
		),
		Vector2.ZERO
	)
	pool.acquire(
		Transform2D(0.0, Vector2(culling_rect.position.x - 1.0, center.y)),
		Vector2.ZERO
	)
	pool.acquire(
		Transform2D(
			0.0,
			Vector2(culling_rect.position.x + culling_rect.size.x + 1.0, center.y)
		),
		Vector2.ZERO
	)
	pool.acquire(
		Transform2D(0.0, Vector2(center.x, culling_rect.position.y - 1.0)),
		Vector2.ZERO
	)
	pool.acquire(
		Transform2D(
			0.0,
			Vector2(center.x, culling_rect.position.y + culling_rect.size.y + 1.0)
		),
		Vector2.ZERO
	)
	assert_eq(pool.active_count(), 5)
	assert_eq(pool.cull_offscreen_now(), 4)
	assert_eq(pool.active_count(), 1)
	assert_true(pool.active_bodies().has(near_edge))
	assert_true(near_edge.visible)
	city.camera_rig.global_position.x += culling_rect.size.x * 2.0
	assert_eq(pool.cull_offscreen_now(), 1)
	assert_eq(pool.offscreen_recycle_count, 5)
	assert_eq(pool.active_count(), 0)
	assert_eq(pool.available_count(), pool.capacity)
	var reused_body: DebrisBody2D = pool.acquire(
		Transform2D(0.0, city.camera_rig.global_position),
		Vector2.ZERO
	)
	assert_same(reused_body, near_edge)
	pool.release(reused_body)
	var scrap_rect: Rect2 = city.camera_rig.visible_world_rect(
		city.enemy_scrap_pool.cull_margin
	)
	city.enemy_scrap_pool.acquire(
		Transform2D(
			0.0,
			Vector2(scrap_rect.position.x - 1.0, scrap_rect.get_center().y)
		),
		Vector2.ZERO
	)
	assert_eq(city.enemy_scrap_pool.cull_offscreen_now(), 1)
	assert_eq(city.enemy_scrap_pool.offscreen_recycle_count, 1)
	assert_eq(
		city.enemy_scrap_pool.available_count(),
		city.enemy_scrap_pool.capacity
	)
