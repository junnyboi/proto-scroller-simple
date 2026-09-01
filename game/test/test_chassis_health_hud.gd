extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func after_each() -> void:
	RuntimeTweakAccess.unbind_service()


func test_chassis_starts_at_five_hundred_health() -> void:
	var catalog: RuntimeTweakCatalog = RuntimeTweakCatalog.load_catalog()
	var descriptor: RuntimeTweakDescriptor = catalog.descriptor(
		&"player.health.max_health"
	)
	assert_not_null(descriptor)
	assert_eq(descriptor.default_value, 500.0)
	assert_eq(descriptor.maximum, 1000.0)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	assert_eq(city.robot.max_health, 500.0)
	assert_eq(city.robot.current_health, 500.0)
	assert_eq(city.gameplay_hud.health_label.text, "CHASSIS 500 / 500")
	assert_eq(
		city.gameplay_hud.health_label.modulate,
		GameplayHud.HEALTH_GREEN_COLOR
	)


func test_chassis_health_icon_and_color_thresholds() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var hud: GameplayHud = city.gameplay_hud
	assert_not_null(hud.health_icon)
	assert_eq(hud.health_icon.texture, GameplayHud.CHASSIS_HEART_TEXTURE)
	assert_lt(hud.health_icon.position.x, hud.health_label.position.x)
	hud.set_health(330.0, 500.0)
	assert_eq(hud.health_label.modulate, GameplayHud.HEALTH_GREEN_COLOR)
	hud.set_health(329.0, 500.0)
	assert_eq(hud.health_label.modulate, GameplayHud.HEALTH_ORANGE_COLOR)
	hud.set_health(165.0, 500.0)
	assert_eq(hud.health_label.modulate, GameplayHud.HEALTH_ORANGE_COLOR)
	hud.set_health(164.0, 500.0)
	assert_eq(hud.health_label.modulate, GameplayHud.HEALTH_RED_COLOR)
